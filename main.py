from fastapi import FastAPI, HTTPException, WebSocket, WebSocketDisconnect, Depends
from fastapi.staticfiles import StaticFiles
from fastapi.responses import HTMLResponse, FileResponse
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
import json
import asyncio
from typing import List, Optional
import uvicorn
from garage_controller import get_garage_controller, DoorStatus
from dotenv import load_dotenv
import os
from auth import verify_token

# Load environment variables
load_dotenv()

# Security
security = HTTPBearer(auto_error=False)

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
    message = json.dumps({
        "type": "status_update",
        "door_id": door_id,
        "status": status.value
    })
    asyncio.create_task(manager.broadcast(message))

controller.register_status_callback(1, door_status_changed)
controller.register_status_callback(2, door_status_changed)

@app.get("/")
async def read_root():
    """Serve the main web interface"""
    return FileResponse("static/index.html")

@app.get("/api/status")
async def get_status():
    """Get current status of both garage doors"""
    return controller.get_all_doors_status()

@app.get("/api/status/{door_id}")
async def get_door_status(door_id: int):
    """Get status of specific door"""
    try:
        status = controller.get_door_status(door_id)
        return {"door_id": door_id, "status": status.value}
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

async def get_current_user(credentials: HTTPAuthorizationCredentials = Depends(security)):
    """Get current user from token if authentication is enabled"""
    if not os.getenv("ENABLE_AUTH", "false").lower() == "true":
        return None  # Auth disabled
    
    if not credentials:
        raise HTTPException(status_code=401, detail="Authentication required")
    
    user = verify_token(credentials.credentials)
    if not user:
        raise HTTPException(status_code=401, detail="Invalid token")
    
    return user

@app.post("/api/trigger/{door_id}")
async def trigger_door(door_id: int, current_user=Depends(get_current_user)):
    """Trigger garage door opener"""
    try:
        controller.trigger_door(door_id)
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

# Mount static files
app.mount("/static", StaticFiles(directory="static"), name="static")

@app.on_event("shutdown")
def shutdown_event():
    """Clean up GPIO on shutdown"""
    controller.cleanup()

if __name__ == "__main__":
    host = os.getenv("HOST", "0.0.0.0")
    port = int(os.getenv("PORT", 8000))
    debug = os.getenv("DEBUG", "false").lower() == "true"
    
    uvicorn.run(app, host=host, port=port, reload=debug)