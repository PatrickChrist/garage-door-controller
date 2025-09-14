from fastapi import FastAPI, HTTPException, WebSocket, WebSocketDisconnect, Depends, Request, Response, status
from fastapi.staticfiles import StaticFiles
from fastapi.responses import HTMLResponse, FileResponse, RedirectResponse
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from pydantic import BaseModel
import json
import asyncio
from typing import List, Optional
import uvicorn
from garage_controller import get_garage_controller, DoorStatus
from dotenv import load_dotenv
import os
from auth import (
    get_current_web_user, get_current_user, get_optional_user, 
    authenticate_user, create_user_token, require_admin, ENABLE_AUTH
)
from users import user_manager, create_default_admin

# Load environment variables
load_dotenv()

# Security
security = HTTPBearer(auto_error=False)

# Pydantic models
class LoginRequest(BaseModel):
    username: str
    password: str
    remember_me: bool = False

class PasswordChangeRequest(BaseModel):
    current_password: str
    new_password: str

class UserCreateRequest(BaseModel):
    username: str
    password: str
    email: Optional[str] = None
    is_admin: bool = False

app = FastAPI(title="Garage Door Controller", version="1.0.0")

# WebSocket connection manager
class ConnectionManager:
    def __init__(self):
        self.active_connections: List[WebSocket] = []

    async def connect(self, websocket: WebSocket):
        await websocket.accept()
        self.active_connections.append(websocket)

    def disconnect(self, websocket: WebSocket):
        self.active_connections.remove(websocket)

    async def broadcast(self, message: str):
        for connection in self.active_connections:
            try:
                await connection.send_text(message)
            except:
                # Connection closed, remove it
                self.active_connections.remove(connection)

manager = ConnectionManager()

# Initialize garage controller
controller = get_garage_controller()

# Register status change callbacks
def door_status_changed(door_id: int, status: DoorStatus):
    """Callback for door status changes"""
    # Log status changes
    user_manager.log_door_activity(door_id, f"status_changed_to_{status.value}")
    
    message = json.dumps({
        "type": "status_update",
        "door_id": door_id,
        "status": status.value
    })
    asyncio.create_task(manager.broadcast(message))

controller.register_status_callback(1, door_status_changed)
controller.register_status_callback(2, door_status_changed)

# Create default admin user on startup
create_default_admin()

@app.get("/")
async def read_root(request: Request):
    """Serve the main web interface"""
    if ENABLE_AUTH:
        try:
            user = await get_current_web_user(request)
            if not user["authenticated"]:
                return RedirectResponse(url="/login.html")
        except HTTPException:
            return RedirectResponse(url="/login.html")
    return FileResponse("static/index.html")

@app.get("/login.html")
async def login_page():
    """Serve login page"""
    return FileResponse("static/login.html")

@app.get("/api/status")
async def get_status(request: Request):
    """Get current status of both garage doors"""
    if ENABLE_AUTH:
        # Allow optional authentication for status endpoint
        try:
            current_user = await get_current_web_user(request)
        except HTTPException:
            raise HTTPException(status_code=401, detail="Authentication required")
    
    return controller.get_all_doors_status()

@app.get("/api/status/{door_id}")
async def get_door_status(door_id: int, request: Request):
    """Get status of specific door"""
    if ENABLE_AUTH:
        try:
            current_user = await get_current_web_user(request)
        except HTTPException:
            raise HTTPException(status_code=401, detail="Authentication required")
    
    try:
        status = controller.get_door_status(door_id)
        return {"door_id": door_id, "status": status.value}
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

# Authentication endpoints
@app.post("/auth/login")
async def login(login_data: LoginRequest, response: Response):
    """Authenticate user and create session"""
    user = authenticate_user(login_data.username, login_data.password)
    
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid username or password"
        )
    
    # Create JWT token
    token = create_user_token(user)
    
    # Set secure session cookie
    cookie_max_age = 2592000 if login_data.remember_me else None  # 30 days or session
    response.set_cookie(
        key="session_token",
        value=token,
        max_age=cookie_max_age,
        httponly=True,
        secure=True,
        samesite="strict",
        path="/"
    )
    
    return {
        "message": "Login successful",
        "user": user["username"],
        "session_token": token,
        "remember_me": login_data.remember_me
    }

@app.post("/auth/logout")
async def logout(response: Response):
    """Logout user and clear session"""
    response.delete_cookie(
        key="session_token",
        path="/",
        secure=True,
        samesite="strict"
    )
    return {"message": "Logged out successfully"}

@app.get("/auth/me")
async def get_current_user_info(request: Request):
    """Get current user information"""
    if not ENABLE_AUTH:
        return {"user": "anonymous", "authenticated": False}
    
    try:
        user = await get_current_web_user(request)
        return user
    except HTTPException:
        return {"user": "anonymous", "authenticated": False}

@app.post("/auth/change-password")
async def change_password(password_data: PasswordChangeRequest, request: Request):
    """Change user password"""
    current_user = await get_current_web_user(request)
    
    # Verify current password
    user_data = current_user["user_data"]
    if not authenticate_user(user_data["username"], password_data.current_password):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Current password is incorrect"
        )
    
    # Update password
    success = user_manager.change_password(user_data["id"], password_data.new_password)
    if not success:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to update password"
        )
    
    return {"message": "Password updated successfully"}

# Admin endpoints
@app.get("/admin/users")
async def list_users(current_user: dict = Depends(require_admin)):
    """List all users (admin only)"""
    users = user_manager.list_users()
    # Remove sensitive data
    for user in users:
        user.pop("password_hash", None)
    return users

@app.post("/admin/users")
async def create_user(user_data: UserCreateRequest, current_user: dict = Depends(require_admin)):
    """Create new user (admin only)"""
    success = user_manager.create_user(
        username=user_data.username,
        password=user_data.password,
        email=user_data.email,
        is_admin=user_data.is_admin
    )
    
    if not success:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Username already exists"
        )
    
    return {"message": "User created successfully"}

@app.delete("/admin/users/{user_id}")
async def delete_user(user_id: int, current_user: dict = Depends(require_admin)):
    """Delete user (admin only)"""
    success = user_manager.delete_user(user_id)
    
    if not success:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Failed to delete user"
        )
    
    return {"message": "User deleted successfully"}

@app.get("/api/activity")
async def get_door_activity(request: Request, limit: int = 50):
    """Get door activity log"""
    if ENABLE_AUTH:
        current_user = await get_current_web_user(request)
        if not current_user["authenticated"]:
            raise HTTPException(status_code=401, detail="Authentication required")
    
    activities = user_manager.get_door_activity_log(limit)
    return {"activities": activities}

@app.post("/api/trigger/{door_id}")
async def trigger_door(door_id: int, request: Request):
    """Trigger garage door opener"""
    current_user_info = None
    if ENABLE_AUTH:
        current_user_info = await get_current_web_user(request)
        if not current_user_info["authenticated"]:
            raise HTTPException(status_code=401, detail="Authentication required")
    
    try:
        controller.trigger_door(door_id)
        
        # Log the door activity
        user_id = current_user_info["user_data"]["id"] if current_user_info and current_user_info.get("user_data") else None
        user_name = current_user_info["user_data"]["username"] if current_user_info and current_user_info.get("user_data") else "anonymous"
        user_manager.log_door_activity(door_id, "triggered", user_id, user_name)
        
        return {"message": f"Door {door_id} triggered successfully"}
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    """WebSocket endpoint for real-time updates"""
    await manager.connect(websocket)
    try:
        # Send initial status
        initial_status = {
            "type": "initial_status",
            "doors": controller.get_all_doors_status()
        }
        await websocket.send_text(json.dumps(initial_status))
        
        # Keep connection alive
        while True:
            try:
                # Wait for client messages (ping/pong)
                message = await websocket.receive_text()
                if message == "ping":
                    await websocket.send_text("pong")
            except WebSocketDisconnect:
                break
    except Exception as e:
        print(f"WebSocket error: {e}")
    finally:
        manager.disconnect(websocket)

# Health check endpoint (public)
@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {"status": "healthy", "service": "garage-controller"}

# Mount static files
app.mount("/static", StaticFiles(directory="static"), name="static")

@app.on_event("startup")
async def startup_event():
    """Initialize application on startup"""
    print("Garage Door Controller starting up...")
    if ENABLE_AUTH:
        print("Authentication is enabled")
    else:
        print("Authentication is disabled")

@app.on_event("shutdown")
def shutdown_event():
    """Clean up GPIO on shutdown"""
    controller.cleanup()

if __name__ == "__main__":
    host = os.getenv("HOST", "0.0.0.0")
    port = int(os.getenv("PORT", 8000))
    debug = os.getenv("DEBUG", "false").lower() == "true"
    
    uvicorn.run(app, host=host, port=port, reload=debug)