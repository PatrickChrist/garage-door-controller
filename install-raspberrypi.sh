#!/bin/bash

# Garage Door Controller - Raspberry Pi Auto Installation Script
# Run with: curl -sSL https://raw.githubusercontent.com/your-repo/reisserpi/main/install-raspberrypi.sh | bash
# Or: wget -qO- https://raw.githubusercontent.com/your-repo/reisserpi/main/install-raspberrypi.sh | bash

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration - will be set dynamically based on current user
INSTALL_DIR=""
SERVICE_NAME="garage-controller"
PYTHON_VERSION="3.9"

# Functions
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_root() {
    if [ "$EUID" -eq 0 ]; then
        print_error "Please do not run this script as root. Run as user 'pi'."
        exit 1
    fi
}

check_raspberry_pi() {
    if ! grep -q "Raspberry Pi" /proc/device-tree/model 2>/dev/null && ! grep -q "BCM" /proc/cpuinfo; then
        print_warning "This doesn't appear to be a Raspberry Pi. GPIO functionality may not work."
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

install_system_dependencies() {
    print_status "Updating system packages..."
    sudo apt update
    sudo apt upgrade -y

    print_status "Installing system dependencies..."
    sudo apt install -y \
        python3 \
        python3-pip \
        python3-venv \
        python3-dev \
        git \
        curl \
        wget \
        nginx \
        ufw \
        fail2ban \
        htop \
        vim \
        build-essential \
        libffi-dev \
        libssl-dev

    # Install RPi.GPIO dependencies
    if grep -q "Raspberry Pi" /proc/device-tree/model 2>/dev/null || grep -q "BCM" /proc/cpuinfo; then
        print_status "Installing Raspberry Pi GPIO libraries..."
        sudo apt install -y python3-rpi.gpio
    fi
}

setup_user_permissions() {
    print_status "Setting up user permissions..."
    
    # Get current user
    CURRENT_USER=${SUDO_USER:-$(whoami)}
    
    # Check if user exists
    if ! id "$CURRENT_USER" &>/dev/null; then
        print_error "User '$CURRENT_USER' does not exist"
        exit 1
    fi
    
    print_status "Setting up permissions for user: $CURRENT_USER"
    
    # Add user to gpio group
    sudo usermod -a -G gpio "$CURRENT_USER"
    
    # Add user to systemd-journal group for log access
    sudo usermod -a -G systemd-journal "$CURRENT_USER"
    
    print_success "User permissions configured for $CURRENT_USER"
}

clone_repository() {
    print_status "Cloning garage door controller repository..."
    
    # Repository URL
    REPO_URL="https://github.com/PatrickChrist/garage-door-controller.git"
    
    # Remove existing installation if it exists
    if [ -d "$INSTALL_DIR" ]; then
        print_warning "Existing installation found. Backing up..."
        sudo mv "$INSTALL_DIR" "${INSTALL_DIR}.backup.$(date +%Y%m%d_%H%M%S)"
    fi
    
    # Clone repository
    if git clone "$REPO_URL" "$INSTALL_DIR"; then
        print_success "Repository cloned successfully"
        cd "$INSTALL_DIR"
    else
        print_error "Failed to clone repository. Falling back to manual setup..."
        create_application_files_fallback
    fi
}

create_application_files_fallback() {
    print_status "Creating application files..."
    
    # Create requirements.txt
    cat > requirements.txt << 'EOF'
fastapi==0.104.1
uvicorn==0.24.0
RPi.GPIO==0.7.1
websockets==12.0
python-multipart==0.0.6
jinja2==3.1.2
aiofiles==23.2.1
python-jose[cryptography]==3.3.0
passlib[bcrypt]==1.7.4
python-dotenv==1.0.0
EOF

    # Create .env file with secure defaults
    cat > .env << 'EOF'
# Garage Door Controller Configuration

# API Security - CHANGE THESE IN PRODUCTION!
SECRET_KEY=change-this-secret-key-in-production
API_KEY=change-this-api-key-in-production

# Default Admin User (for initial setup)
DEFAULT_ADMIN_USERNAME=admin
DEFAULT_ADMIN_PASSWORD=garage123!

# GPIO Configuration
DOOR1_RELAY_PIN=9
DOOR2_RELAY_PIN=12
DOOR1_SENSOR_PIN=4
DOOR2_SENSOR_PIN=4

# Server Configuration
HOST=0.0.0.0
PORT=8000
DEBUG=false

# Security Settings
ENABLE_AUTH=true
TOKEN_EXPIRE_MINUTES=60

# DuckDNS Configuration
DUCKDNS_DOMAIN=
DUCKDNS_TOKEN=
DUCKDNS_ENABLED=false

# SSL Configuration
SSL_ENABLED=false
SSL_CERT_PATH=/etc/letsencrypt/live/
SSL_KEY_PATH=/etc/letsencrypt/live/

# Network Configuration
LOCAL_NETWORK=192.168.1.0/24
EXTERNAL_ACCESS_ENABLED=false

# Monitoring and Maintenance
UPDATE_CHECK_ENABLED=true
BACKUP_ENABLED=true
BACKUP_RETENTION_DAYS=30
EOF

    print_success "Application files created"
}

setup_python_environment() {
    print_status "Creating Python virtual environment..."
    
    cd "$INSTALL_DIR"
    python3 -m venv venv
    source venv/bin/activate
    
    print_status "Upgrading pip..."
    pip install --upgrade pip setuptools wheel
    
    print_status "Installing Python dependencies..."
    pip install -r requirements.txt
    
    print_success "Python environment configured"
}

setup_systemd_service() {
    print_status "Creating systemd service..."
    
    sudo tee /etc/systemd/system/${SERVICE_NAME}.service > /dev/null << EOF
[Unit]
Description=Garage Door Controller
After=network.target

[Service]
Type=simple
User=pi
Group=pi
WorkingDirectory=${INSTALL_DIR}
Environment=PATH=${INSTALL_DIR}/venv/bin
ExecStart=${INSTALL_DIR}/venv/bin/python main.py
Restart=always
RestartSec=3
StandardOutput=journal
StandardError=journal

# Security settings
NoNewPrivileges=yes
PrivateTmp=yes
ProtectSystem=strict
ProtectHome=yes
ReadWritePaths=${INSTALL_DIR}

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable ${SERVICE_NAME}
    
    print_success "Systemd service configured"
}

setup_homekit_service() {
    print_status "Setting up HomeKit bridge service..."
    
    sudo tee /etc/systemd/system/garage-homekit.service > /dev/null << EOF
[Unit]
Description=Garage Door HomeKit Bridge
After=network.target garage-controller.service
Wants=garage-controller.service

[Service]
Type=simple
User=pi
Group=pi
WorkingDirectory=${INSTALL_DIR}
Environment=PATH=${INSTALL_DIR}/venv/bin
ExecStart=${INSTALL_DIR}/venv/bin/python homekit_bridge.py
Restart=always
RestartSec=3
StandardOutput=journal
StandardError=journal

# Security settings
NoNewPrivileges=yes
PrivateTmp=yes
ProtectSystem=strict
ProtectHome=yes
ReadWritePaths=${INSTALL_DIR}

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable garage-homekit
    
    print_success "HomeKit bridge service configured"
}

setup_nginx() {
    print_status "Configuring Nginx reverse proxy..."
    
    sudo tee /etc/nginx/sites-available/garage-controller > /dev/null << 'EOF'
server {
    listen 80;
    server_name _;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }

    # WebSocket support
    location /ws {
        proxy_pass http://127.0.0.1:8000/ws;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF

    # Enable the site
    sudo ln -sf /etc/nginx/sites-available/garage-controller /etc/nginx/sites-enabled/
    sudo rm -f /etc/nginx/sites-enabled/default
    
    # Test nginx configuration
    sudo nginx -t
    
    # Restart nginx
    sudo systemctl restart nginx
    sudo systemctl enable nginx
    
    print_success "Nginx configured"
}

setup_firewall() {
    print_status "Configuring firewall..."
    
    # Reset UFW
    sudo ufw --force reset
    
    # Default policies
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    
    # Allow SSH
    sudo ufw allow ssh
    
    # Allow HTTP and HTTPS
    sudo ufw allow 80/tcp
    sudo ufw allow 443/tcp
    
    # Allow local network access to API directly (optional)
    # sudo ufw allow from 192.168.0.0/16 to any port 8000
    
    # Enable firewall
    sudo ufw --force enable
    
    print_success "Firewall configured"
}

setup_fail2ban() {
    print_status "Configuring Fail2Ban..."
    
    sudo tee /etc/fail2ban/jail.local > /dev/null << 'EOF'
[DEFAULT]
bantime = 1h
findtime = 10m
maxretry = 5

[sshd]
enabled = true

[nginx-http-auth]
enabled = true
port = http,https
logpath = /var/log/nginx/error.log

[nginx-limit-req]
enabled = true
port = http,https
logpath = /var/log/nginx/error.log
maxretry = 10
EOF

    sudo systemctl restart fail2ban
    sudo systemctl enable fail2ban
    
    print_success "Fail2Ban configured"
}

generate_secure_keys() {
    print_status "Generating secure keys..."
    
    # Generate random secret key
    SECRET_KEY=$(openssl rand -base64 32)
    API_KEY=$(openssl rand -base64 24)
    
    # Update .env file
    sed -i "s/change-this-secret-key-in-production/${SECRET_KEY}/" "${INSTALL_DIR}/.env"
    sed -i "s/change-this-api-key-in-production/${API_KEY}/" "${INSTALL_DIR}/.env"
    
    print_success "Secure keys generated"
}

setup_maintenance_cron_jobs() {
    print_status "Setting up maintenance cron jobs..."
    
    # Create maintenance script
    cat > "${INSTALL_DIR}/maintenance.sh" << 'EOF'
#!/bin/bash
# Garage Door Controller Maintenance Script

LOG_FILE="/var/log/garage-controller-maintenance.log"
INSTALL_DIR="$INSTALL_DIR"

# Function to log with timestamp
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $1" >> "$LOG_FILE"
}

# System health check
health_check() {
    log_message "Starting health check"
    
    # Check service status
    if ! systemctl is-active --quiet garage-controller; then
        log_message "WARNING: garage-controller service is not running"
        systemctl restart garage-controller
        log_message "Attempted to restart garage-controller service"
    fi
    
    # Check disk space
    DISK_USAGE=$(df / | awk 'NR==2 {print substr($5, 1, length($5)-1)}')
    if [ "$DISK_USAGE" -gt 85 ]; then
        log_message "WARNING: Disk usage is at ${DISK_USAGE}%"
    fi
    
    # Check memory usage
    MEM_USAGE=$(free | awk 'FNR==2{printf "%.0f", $3/($3+$4)*100}')
    if [ "$MEM_USAGE" -gt 85 ]; then
        log_message "WARNING: Memory usage is at ${MEM_USAGE}%"
    fi
    
    log_message "Health check completed"
}

# Backup database and configuration
backup_data() {
    log_message "Starting backup"
    
    BACKUP_DIR="${INSTALL_DIR}/backups"
    mkdir -p "$BACKUP_DIR"
    
    # Create backup with timestamp
    TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
    BACKUP_FILE="${BACKUP_DIR}/garage_backup_${TIMESTAMP}.tar.gz"
    
    # Backup database and config files
    tar -czf "$BACKUP_FILE" -C "$INSTALL_DIR" \
        users.db .env *.py static/ 2>/dev/null
    
    if [ $? -eq 0 ]; then
        log_message "Backup created: $BACKUP_FILE"
        
        # Clean old backups (keep last 30 days)
        find "$BACKUP_DIR" -name "garage_backup_*.tar.gz" -mtime +30 -delete
        log_message "Old backups cleaned"
    else
        log_message "ERROR: Backup failed"
    fi
}

# Update system packages
update_system() {
    log_message "Starting system update check"
    
    # Check for updates
    apt list --upgradable 2>/dev/null | grep -q upgradable
    if [ $? -eq 0 ]; then
        log_message "Updates available, installing security updates"
        apt update -qq
        apt upgrade -y -qq --only-upgrade $(apt list --upgradable 2>/dev/null | grep -i security | awk -F'/' '{print $1}')
        log_message "Security updates installed"
    else
        log_message "No updates available"
    fi
}

# Log rotation
rotate_logs() {
    # Rotate maintenance log if larger than 10MB
    if [ -f "$LOG_FILE" ] && [ $(stat -c%s "$LOG_FILE") -gt 10485760 ]; then
        mv "$LOG_FILE" "${LOG_FILE}.old"
        touch "$LOG_FILE"
        log_message "Log file rotated"
    fi
}

# Main execution based on argument
case "$1" in
    "health")
        health_check
        ;;
    "backup")
        backup_data
        ;;
    "update")
        update_system
        ;;
    "all")
        health_check
        backup_data
        update_system
        rotate_logs
        ;;
    *)
        echo "Usage: $0 {health|backup|update|all}"
        exit 1
        ;;
esac
EOF

    chmod +x "${INSTALL_DIR}/maintenance.sh"
    
    # Setup cron jobs for pi user
    print_status "Installing cron jobs..."
    
    # Remove existing garage-related cron jobs to avoid duplicates
    crontab -l 2>/dev/null | grep -v "garage" | grep -v "maintenance.sh" | crontab -
    
    # Add maintenance cron jobs
    (crontab -l 2>/dev/null; cat << 'CRON_EOF'
# Garage Door Controller Maintenance
# Health check every 15 minutes
*/15 * * * * $INSTALL_DIR/maintenance.sh health >/dev/null 2>&1

# Daily backup at 2 AM
0 2 * * * $INSTALL_DIR/maintenance.sh backup >/dev/null 2>&1

# Weekly system update check on Sundays at 3 AM
0 3 * * 0 $INSTALL_DIR/maintenance.sh update >/dev/null 2>&1

# Monthly log rotation on 1st day at 4 AM
0 4 1 * * $INSTALL_DIR/maintenance.sh all >/dev/null 2>&1
CRON_EOF
    ) | crontab -
    
    print_success "Maintenance cron jobs configured"
}

test_installation() {
    print_status "Testing installation..."
    
    # Start service
    sudo systemctl start ${SERVICE_NAME}
    
    # Wait for service to start
    sleep 5
    
    # Check service status
    if sudo systemctl is-active --quiet ${SERVICE_NAME}; then
        print_success "Service is running"
    else
        print_error "Service failed to start"
        sudo systemctl status ${SERVICE_NAME}
        return 1
    fi
    
    # Test HTTP endpoint
    if curl -f -s http://localhost:8000/api/status >/dev/null; then
        print_success "HTTP endpoint responding"
    else
        print_error "HTTP endpoint not responding"
        return 1
    fi
}

display_completion_info() {
    print_success "Installation completed successfully!"
    echo
    echo "=========================================="
    echo "  Garage Door Controller - Installation Complete"
    echo "=========================================="
    echo
    echo "🏠 Web Interface: http://$(hostname -I | awk '{print $1}')"
    echo "📋 API Documentation: http://$(hostname -I | awk '{print $1}')/docs"
    echo
    echo "🔧 Service Management:"
    echo "  Status: sudo systemctl status garage-controller"
    echo "  Start:  sudo systemctl start garage-controller"
    echo "  Stop:   sudo systemctl stop garage-controller"
    echo "  Logs:   sudo journalctl -u garage-controller -f"
    echo
    echo "📁 Installation Directory: ${INSTALL_DIR}"
    echo "⚙️  Configuration File: ${INSTALL_DIR}/.env"
    echo
    echo "🔒 Security:"
    echo "  • Firewall (UFW) is enabled"
    echo "  • Fail2Ban is configured"
    echo "  • Authentication is enabled by default"
    echo "  • Change default credentials in ${INSTALL_DIR}/.env"
    echo
    echo "⚡ Hardware Setup:"
    echo "  • Connect Door 1 Relay to GPIO 9"
    echo "  • Connect Door 2 Relay to GPIO 12"
    echo "  • Connect Door Sensor to GPIO 4 (shared)"
    echo
    echo "🌐 Remote Access Setup:"
    echo "  • For external access, run: ./duckdns-setup.sh"
    echo "  • This enables access from anywhere via DuckDNS"
    echo "  • Includes SSL certificates and security hardening"
    echo "  • DuckDNS credentials can be configured in .env file"
    echo
    echo "📖 Documentation:"
    echo "  • README.md - Main setup guide"
    echo "  • HARDWARE_SETUP.md - Hardware wiring guide"
    echo "  • REMOTE_ACCESS.md - DuckDNS and external access"
    echo "  • APPLE_INTEGRATION.md - iOS, Apple Watch, HomeKit"
    echo
    print_warning "Please reboot your Raspberry Pi to ensure all changes take effect:"
    echo "  sudo reboot"
}

# Main installation flow
main() {
    echo
    echo "=========================================="
    echo "  Garage Door Controller - Auto Installer"
    echo "=========================================="
    echo

    # Set installation directory based on current user
    CURRENT_USER=${SUDO_USER:-$(whoami)}
    if [ "$CURRENT_USER" = "root" ]; then
        print_error "Please run this script as a regular user with sudo, not as root directly"
        exit 1
    fi
    INSTALL_DIR="/home/$CURRENT_USER/garage-controller"
    print_status "Installing to: $INSTALL_DIR"

    check_root
    check_raspberry_pi
    
    print_status "Starting installation..."
    
    install_system_dependencies
    setup_user_permissions
    clone_repository
    setup_python_environment
    setup_systemd_service
    setup_homekit_service
    setup_nginx
    setup_firewall
    setup_fail2ban
    generate_secure_keys
    setup_maintenance_cron_jobs
    test_installation
    
    display_completion_info
}

# Run installation
main "$@"