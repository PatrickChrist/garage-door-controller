from datetime import datetime, timedelta
from typing import Optional
from fastapi import HTTPException, Security, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from passlib.context import CryptContext
from jose import JWTError, jwt
import os
from dotenv import load_dotenv

load_dotenv()

# Security configuration
SECRET_KEY = os.getenv("SECRET_KEY", "your-default-secret-key-change-this")
API_KEY = os.getenv("API_KEY", "your-default-api-key")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = int(os.getenv("TOKEN_EXPIRE_MINUTES", "60"))
ENABLE_AUTH = os.getenv("ENABLE_AUTH", "true").lower() == "true"

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
security = HTTPBearer(auto_error=False)

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
    
    return {"user": payload.get("sub"), "authenticated": True, "auth_type": "jwt"}

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
        return {"user": payload.get("sub"), "authenticated": True, "auth_type": "jwt"}
    
    return {"user": "anonymous", "authenticated": False}