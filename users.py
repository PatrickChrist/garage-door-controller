"""
User management system for garage door controller
"""
import sqlite3
import os
from typing import Optional, Dict, List
from passlib.context import CryptContext
from datetime import datetime

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

class UserManager:
    def __init__(self, db_path: str = "users.db"):
        self.db_path = db_path
        self.init_database()
    
    def init_database(self):
        """Initialize the users database"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS users (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                username TEXT UNIQUE NOT NULL,
                email TEXT UNIQUE,
                password_hash TEXT NOT NULL,
                is_active BOOLEAN DEFAULT 1,
                is_admin BOOLEAN DEFAULT 0,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                last_login TIMESTAMP
            )
        """)
        
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS sessions (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id INTEGER,
                session_token TEXT UNIQUE NOT NULL,
                expires_at TIMESTAMP NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (user_id) REFERENCES users (id)
            )
        """)
        
        conn.commit()
        conn.close()
    
    def create_user(self, username: str, password: str, email: Optional[str] = None, is_admin: bool = False) -> bool:
        """Create a new user"""
        try:
            password_hash = pwd_context.hash(password)
            
            conn = sqlite3.connect(self.db_path)
            cursor = conn.cursor()
            
            cursor.execute("""
                INSERT INTO users (username, email, password_hash, is_admin)
                VALUES (?, ?, ?, ?)
            """, (username, email, password_hash, is_admin))
            
            conn.commit()
            conn.close()
            return True
        except sqlite3.IntegrityError:
            return False
    
    def verify_user(self, username: str, password: str) -> Optional[Dict]:
        """Verify user credentials"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute("""
            SELECT id, username, email, password_hash, is_active, is_admin
            FROM users 
            WHERE username = ? AND is_active = 1
        """, (username,))
        
        user = cursor.fetchone()
        conn.close()
        
        if user and pwd_context.verify(password, user[3]):
            return {
                "id": user[0],
                "username": user[1],
                "email": user[2],
                "is_admin": user[5],
                "is_active": user[4]
            }
        return None
    
    def get_user_by_id(self, user_id: int) -> Optional[Dict]:
        """Get user by ID"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute("""
            SELECT id, username, email, is_active, is_admin, created_at, last_login
            FROM users 
            WHERE id = ?
        """, (user_id,))
        
        user = cursor.fetchone()
        conn.close()
        
        if user:
            return {
                "id": user[0],
                "username": user[1],
                "email": user[2],
                "is_active": user[3],
                "is_admin": user[4],
                "created_at": user[5],
                "last_login": user[6]
            }
        return None
    
    def get_user_by_username(self, username: str) -> Optional[Dict]:
        """Get user by username"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute("""
            SELECT id, username, email, is_active, is_admin, created_at, last_login
            FROM users 
            WHERE username = ?
        """, (username,))
        
        user = cursor.fetchone()
        conn.close()
        
        if user:
            return {
                "id": user[0],
                "username": user[1],
                "email": user[2],
                "is_active": user[3],
                "is_admin": user[4],
                "created_at": user[5],
                "last_login": user[6]
            }
        return None
    
    def update_last_login(self, user_id: int):
        """Update user's last login timestamp"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute("""
            UPDATE users 
            SET last_login = CURRENT_TIMESTAMP
            WHERE id = ?
        """, (user_id,))
        
        conn.commit()
        conn.close()
    
    def change_password(self, user_id: int, new_password: str) -> bool:
        """Change user password"""
        try:
            password_hash = pwd_context.hash(new_password)
            
            conn = sqlite3.connect(self.db_path)
            cursor = conn.cursor()
            
            cursor.execute("""
                UPDATE users 
                SET password_hash = ?
                WHERE id = ?
            """, (password_hash, user_id))
            
            conn.commit()
            conn.close()
            return True
        except:
            return False
    
    def list_users(self) -> List[Dict]:
        """List all users (admin only)"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute("""
            SELECT id, username, email, is_active, is_admin, created_at, last_login
            FROM users 
            ORDER BY created_at DESC
        """)
        
        users = cursor.fetchall()
        conn.close()
        
        return [{
            "id": user[0],
            "username": user[1],
            "email": user[2],
            "is_active": user[3],
            "is_admin": user[4],
            "created_at": user[5],
            "last_login": user[6]
        } for user in users]
    
    def delete_user(self, user_id: int) -> bool:
        """Delete a user (admin only)"""
        try:
            conn = sqlite3.connect(self.db_path)
            cursor = conn.cursor()
            
            cursor.execute("DELETE FROM sessions WHERE user_id = ?", (user_id,))
            cursor.execute("DELETE FROM users WHERE id = ?", (user_id,))
            
            conn.commit()
            conn.close()
            return True
        except:
            return False

# Global user manager instance
user_manager = UserManager()

def create_default_admin():
    """Create default admin user if none exists"""
    from dotenv import load_dotenv
    load_dotenv()
    
    # Check if any admin users exist
    users = user_manager.list_users()
    admin_exists = any(user["is_admin"] for user in users)
    
    if not admin_exists:
        default_username = os.getenv("DEFAULT_ADMIN_USERNAME", "admin")
        default_password = os.getenv("DEFAULT_ADMIN_PASSWORD", "garage123!")
        
        success = user_manager.create_user(
            username=default_username,
            password=default_password,
            email="admin@garage.local",
            is_admin=True
        )
        
        if success:
            print(f"Created default admin user: {default_username}")
            print(f"Default password: {default_password}")
            print("Please change the password after first login!")
        else:
            print("Failed to create default admin user")

if __name__ == "__main__":
    create_default_admin()