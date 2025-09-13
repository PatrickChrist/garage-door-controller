#!/usr/bin/env python3
"""
Admin setup script for garage door controller
Creates admin user and configures initial settings
"""

import os
import sys
import getpass
from dotenv import load_dotenv, set_key
from users import user_manager

def create_admin_user():
    """Create admin user with custom credentials"""
    print("=== Garage Door Controller - Admin Setup ===\n")
    
    # Check if admin already exists
    users = user_manager.list_users()
    admin_exists = any(user["is_admin"] for user in users)
    
    if admin_exists:
        print("Admin user already exists!")
        response = input("Do you want to create another admin user? (y/N): ").strip().lower()
        if response != 'y':
            print("Setup cancelled.")
            return False
    
    print("Creating admin user for garage door controller...")
    
    # Get username
    while True:
        username = input("Admin username: ").strip()
        if not username:
            print("Username cannot be empty!")
            continue
        if len(username) < 3:
            print("Username must be at least 3 characters!")
            continue
        break
    
    # Get password
    while True:
        password = getpass.getpass("Admin password: ").strip()
        if not password:
            print("Password cannot be empty!")
            continue
        if len(password) < 8:
            print("Password must be at least 8 characters!")
            continue
        
        password_confirm = getpass.getpass("Confirm password: ").strip()
        if password != password_confirm:
            print("Passwords do not match!")
            continue
        break
    
    # Get email (optional)
    email = input("Admin email (optional): ").strip()
    if not email:
        email = None
    
    # Create user
    success = user_manager.create_user(
        username=username,
        password=password,
        email=email,
        is_admin=True
    )
    
    if success:
        print(f"\n✅ Admin user '{username}' created successfully!")
        return True
    else:
        print(f"\n❌ Failed to create admin user. Username '{username}' may already exist.")
        return False

def configure_duckdns_settings():
    """Configure DuckDNS settings in .env file"""
    print("\n=== DuckDNS Configuration ===")
    
    env_file = ".env"
    load_dotenv()
    
    print("Configure DuckDNS for remote access (optional):")
    configure_dns = input("Do you want to configure DuckDNS now? (y/N): ").strip().lower()
    
    if configure_dns == 'y':
        # Get DuckDNS domain
        while True:
            domain = input("DuckDNS subdomain (without .duckdns.org): ").strip()
            if not domain:
                print("Skipping DuckDNS configuration")
                return
            if domain.replace('-', '').replace('_', '').isalnum():
                break
            print("Invalid domain. Use only letters, numbers, hyphens, and underscores.")
        
        # Get DuckDNS token
        while True:
            token = input("DuckDNS token (36 characters): ").strip()
            if not token:
                print("Skipping DuckDNS configuration")
                return
            if len(token) == 36:
                break
            print("DuckDNS token must be exactly 36 characters.")
        
        # Update .env file
        set_key(env_file, "DUCKDNS_DOMAIN", domain)
        set_key(env_file, "DUCKDNS_TOKEN", token)
        set_key(env_file, "DUCKDNS_ENABLED", "true")
        set_key(env_file, "EXTERNAL_ACCESS_ENABLED", "true")
        
        print(f"✅ DuckDNS configured for {domain}.duckdns.org")
        print("   Run ./duckdns-setup.sh to complete the setup")
    else:
        print("ℹ️  DuckDNS configuration skipped")
        print("   You can configure it later by editing .env or running ./duckdns-setup.sh")

def configure_security_settings():
    """Configure security settings in .env file"""
    print("\n=== Security Configuration ===")
    
    env_file = ".env"
    if not os.path.exists(env_file):
        print("Creating .env file...")
        with open(env_file, 'w') as f:
            f.write("# Garage Door Controller Configuration\n\n")
    
    load_dotenv()
    
    # Generate secure keys
    import secrets
    import string
    
    def generate_secure_key(length=32):
        alphabet = string.ascii_letters + string.digits + "!@#$%^&*"
        return ''.join(secrets.choice(alphabet) for _ in range(length))
    
    # Secret key for JWT tokens
    current_secret = os.getenv("SECRET_KEY", "")
    if not current_secret or current_secret.startswith("change-this") or current_secret == "your-default-secret-key-change-this":
        new_secret = generate_secure_key(64)
        set_key(env_file, "SECRET_KEY", new_secret)
        print("✅ Generated new SECRET_KEY")
    else:
        print("✅ SECRET_KEY already configured")
    
    # API key
    current_api_key = os.getenv("API_KEY", "")
    if not current_api_key or current_api_key.startswith("change-this") or current_api_key == "your-default-api-key":
        new_api_key = generate_secure_key(32)
        set_key(env_file, "API_KEY", new_api_key)
        print("✅ Generated new API_KEY")
    else:
        print("✅ API_KEY already configured")
    
    # Enable authentication
    enable_auth = os.getenv("ENABLE_AUTH", "true").lower()
    if enable_auth != "true":
        set_key(env_file, "ENABLE_AUTH", "true")
        print("✅ Enabled authentication")
    else:
        print("✅ Authentication already enabled")
    
    # Token expiration
    token_expire = os.getenv("TOKEN_EXPIRE_MINUTES", "60")
    if token_expire == "60":
        response = input(f"JWT token expiration (minutes, default 60): ").strip()
        if response:
            try:
                expire_minutes = int(response)
                if expire_minutes > 0:
                    set_key(env_file, "TOKEN_EXPIRE_MINUTES", str(expire_minutes))
                    print(f"✅ Set token expiration to {expire_minutes} minutes")
            except ValueError:
                print("❌ Invalid number, keeping default (60 minutes)")
    
    print(f"\n✅ Security configuration updated in {env_file}")

def show_next_steps():
    """Show next steps after setup"""
    print("\n=== Next Steps ===")
    print("1. Start the garage door controller:")
    print("   python3 main.py")
    print()
    print("2. Or install as systemd service:")
    print("   sudo ./install-raspberrypi.sh")
    print()
    print("3. Access the web interface:")
    print("   http://your-pi-ip:8000")
    print()
    print("4. For remote access, configure DuckDNS:")
    print("   ./duckdns-setup.sh")
    print()
    print("5. Change default passwords and review SECURITY_GUIDE.md")
    print()
    print("📖 Documentation:")
    print("   • README.md - Main setup guide")
    print("   • SECURITY_GUIDE.md - Security best practices")
    print("   • REMOTE_ACCESS.md - Remote access setup")
    print("   • HARDWARE_SETUP.md - Hardware wiring guide")

def main():
    """Main setup function"""
    try:
        # Change to script directory
        script_dir = os.path.dirname(os.path.abspath(__file__))
        os.chdir(script_dir)
        
        print("Garage Door Controller - Admin Setup")
        print("=" * 40)
        
        # Create admin user
        admin_created = create_admin_user()
        
        # Configure security settings
        configure_security_settings()
        
        # Configure DuckDNS settings
        configure_duckdns_settings()
        
        # Show next steps
        show_next_steps()
        
        print("\n🎉 Setup completed successfully!")
        
        if admin_created:
            print("\n⚠️  IMPORTANT: Please change the default admin password after first login!")
        
    except KeyboardInterrupt:
        print("\n\nSetup cancelled by user.")
        sys.exit(1)
    except Exception as e:
        print(f"\n❌ Setup failed: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()