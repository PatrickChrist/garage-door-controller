from datetime import datetime, timedelta
from typing import Optional
from fastapi import HTTPException, Security, status, Request, Depends
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials, HTTPBasic, HTTPBasicCredentials
from passlib.context import CryptContext
from jose import JWTError, jwt
import os
from dotenv import load_dotenv
from users import user_manager

load_dotenv()

# Security configuration
SECRET_KEY = os.getenv("SECRET_KEY", "your-default-secret-key-change-this")
API_KEY = os.getenv("API_KEY", "your-default-api-key")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = int(os.getenv("TOKEN_EXPIRE_MINUTES", "60"))
ENABLE_AUTH = os.getenv("ENABLE_AUTH", "true").lower() == "true"

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
security = HTTPBearer(auto_error=False)
basic_auth = HTTPBasic(auto_error=False)

def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Verify a password against its hash"""
    return pwd_context.verify(plain_password, hashed_password)

def get_password_hash(password: str) -> str:
    """Hash a password"""
    return pwd_context.hash(password)

def create_access_token(data: dict, expires_delta: Optional[timedelta] = None):
    """Create a JWT access token"""
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt

def verify_token(token: str) -> Optional[dict]:
    """Verify and decode a JWT token"""
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        return payload
    except JWTError:
        return None

def verify_api_key(api_key: str) -> bool:
    """Verify API key"""
    return api_key == API_KEY

async def get_current_user(credentials: HTTPAuthorizationCredentials = Security(security)):
    """Get current authenticated user"""
    if not ENABLE_AUTH:
        return {"user": "anonymous", "authenticated": False}
    
    if credentials is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Not authenticated",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    # Check if it's an API key
    if verify_api_key(credentials.credentials):
        return {"user": "api_user", "authenticated": True, "auth_type": "api_key"}
    
    # Check if it's a JWT token
    payload = verify_token(credentials.credentials)
    if payload is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authentication credentials",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    user = user_manager.get_user_by_id(payload.get("user_id"))
    if not user or not user["is_active"]:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User account inactive",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    return {"user": user["username"], "authenticated": True, "auth_type": "jwt", "user_data": user}

async def require_admin(current_user: dict = Depends(get_current_user)):
    """Require admin privileges"""
    if not current_user["authenticated"]:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authentication required"
        )
    
    # API key users have admin access
    if current_user["auth_type"] == "api_key":
        return current_user
    
    # Check if user is admin
    if "user_data" in current_user and not current_user["user_data"]["is_admin"]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Admin privileges required"
        )
    
    return current_user

def authenticate_user(username: str, password: str) -> Optional[dict]:
    """Authenticate user with username and password"""
    user = user_manager.verify_user(username, password)
    if user:
        user_manager.update_last_login(user["id"])
    return user

def create_user_token(user: dict) -> str:
    """Create JWT token for authenticated user"""
    token_data = {
        "sub": user["username"],
        "user_id": user["id"],
        "is_admin": user["is_admin"]
    }
    return create_access_token(token_data)

async def get_current_web_user(request: Request):
    """Get current authenticated user for web interface"""
    if not ENABLE_AUTH:
        return {"user": "anonymous", "authenticated": False}
    
    # Check session cookie first
    session_token = request.cookies.get("session_token")
    if session_token:
        payload = verify_token(session_token)
        if payload:
            user = user_manager.get_user_by_id(payload.get("user_id"))
            if user and user["is_active"]:
                return {"user": user["username"], "authenticated": True, "auth_type": "session", "user_data": user}
    
    # Check Bearer token from Authorization header
    authorization = request.headers.get("Authorization", "")
    if authorization.startswith("Bearer "):
        token = authorization.split(" ", 1)[1]
        
        # Check API key
        if verify_api_key(token):
            return {"user": "api_user", "authenticated": True, "auth_type": "api_key"}
        
        # Check JWT token
        payload = verify_token(token)
        if payload:
            user = user_manager.get_user_by_id(payload.get("user_id"))
            if user and user["is_active"]:
                return {"user": user["username"], "authenticated": True, "auth_type": "jwt", "user_data": user}
    
    # Check Basic auth from Authorization header
    if authorization.startswith("Basic "):
        import base64
        try:
            encoded_credentials = authorization.split(" ", 1)[1]
            decoded_credentials = base64.b64decode(encoded_credentials).decode("utf-8")
            username, password = decoded_credentials.split(":", 1)
            user = authenticate_user(username, password)
            if user:
                return {"user": user["username"], "authenticated": True, "auth_type": "basic", "user_data": user}
        except (ValueError, UnicodeDecodeError):
            pass
    
    # Return unauthenticated user for web interface (will redirect to login)
    return {"user": "anonymous", "authenticated": False}

async def get_optional_user(credentials: HTTPAuthorizationCredentials = Security(security)):
    """Get user if authenticated, but don't require authentication"""
    if not ENABLE_AUTH:
        return {"user": "anonymous", "authenticated": False}
    
    if credentials is None:
        return {"user": "anonymous", "authenticated": False}
    
    # Check API key
    if verify_api_key(credentials.credentials):
        return {"user": "api_user", "authenticated": True, "auth_type": "api_key"}
    
    # Check JWT token
    payload = verify_token(credentials.credentials)
    if payload is not None:
        user = user_manager.get_user_by_id(payload.get("user_id"))
        if user and user["is_active"]:
            return {"user": user["username"], "authenticated": True, "auth_type": "jwt", "user_data": user}
    
    return {"user": "anonymous", "authenticated": False}