#!/bin/bash

# Garage Door Controller Update Script
# Safely updates the codebase while preserving the database

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$SCRIPT_DIR/backup_$(date +%Y%m%d_%H%M%S)"
SERVICE_NAME="garage-controller"

# Functions
print_info() {
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

# Check if running with sufficient privileges
check_privileges() {
    if [ "$EUID" -ne 0 ]; then
        print_error "Please run with sudo privileges"
        exit 1
    fi
}

# Create backup directory and backup critical files
create_backup() {
    print_info "Creating backup directory: $BACKUP_DIR"
    mkdir -p "$BACKUP_DIR"
    
    # Backup database if exists
    if [ -f "$SCRIPT_DIR/users.db" ]; then
        print_info "Backing up users.db database"
        cp "$SCRIPT_DIR/users.db" "$BACKUP_DIR/"
    fi
    
    # Backup .env file if exists
    if [ -f "$SCRIPT_DIR/.env" ]; then
        print_info "Backing up .env configuration"
        cp "$SCRIPT_DIR/.env" "$BACKUP_DIR/"
    fi
    
    # Backup any custom configuration files
    if [ -f "$SCRIPT_DIR/config.json" ]; then
        print_info "Backing up config.json"
        cp "$SCRIPT_DIR/config.json" "$BACKUP_DIR/"
    fi
    
    print_success "Backup created successfully"
}

# Stop the service
stop_service() {
    print_info "Stopping $SERVICE_NAME service"
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        systemctl stop "$SERVICE_NAME"
        print_success "Service stopped"
    else
        print_warning "Service was not running"
    fi
}

# Start the service
start_service() {
    print_info "Starting $SERVICE_NAME service"
    systemctl start "$SERVICE_NAME"
    sleep 3
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        print_success "Service started successfully"
    else
        print_error "Failed to start service"
        return 1
    fi
}

# Update git repository
update_repository() {
    print_info "Updating git repository"
    cd "$SCRIPT_DIR"
    
    # Fetch latest changes
    git fetch origin
    
    # Check if there are updates available
    LOCAL_COMMIT=$(git rev-parse HEAD)
    REMOTE_COMMIT=$(git rev-parse origin/main 2>/dev/null || git rev-parse origin/master 2>/dev/null)
    
    if [ "$LOCAL_COMMIT" = "$REMOTE_COMMIT" ]; then
        print_info "Already up to date"
        return 0
    fi
    
    print_info "Updates available, pulling changes"
    git pull origin main 2>/dev/null || git pull origin master 2>/dev/null
    
    print_success "Repository updated successfully"
}

# Update token expiration in .env file
update_token_expiration() {
    print_info "Updating token expiration to 360 days"
    
    if [ -f "$SCRIPT_DIR/.env" ]; then
        # Update existing .env file
        if grep -q "TOKEN_EXPIRE_MINUTES" "$SCRIPT_DIR/.env"; then
            sed -i 's|TOKEN_EXPIRE_MINUTES=.*|TOKEN_EXPIRE_MINUTES=518400|g' "$SCRIPT_DIR/.env"
        else
            echo "TOKEN_EXPIRE_MINUTES=518400" >> "$SCRIPT_DIR/.env"
        fi
    else
        # Create .env from example
        if [ -f "$SCRIPT_DIR/.env.example" ]; then
            print_info "Creating .env from .env.example"
            cp "$SCRIPT_DIR/.env.example" "$SCRIPT_DIR/.env"
            sed -i 's|TOKEN_EXPIRE_MINUTES=.*|TOKEN_EXPIRE_MINUTES=518400|g' "$SCRIPT_DIR/.env"
        else
            print_error ".env.example file not found"
            return 1
        fi
    fi
    
    print_success "Token expiration updated to 360 days"
}

# Restore database from backup
restore_database() {
    if [ -f "$BACKUP_DIR/users.db" ]; then
        print_info "Restoring users.db database from backup"
        cp "$BACKUP_DIR/users.db" "$SCRIPT_DIR/"
        print_success "Database restored"
    fi
}

# Update Python dependencies
update_dependencies() {
    print_info "Updating Python dependencies"
    cd "$SCRIPT_DIR"
    
    if [ -d "venv" ]; then
        source venv/bin/activate
        pip install --upgrade -r requirements.txt
        deactivate
        print_success "Dependencies updated"
    else
        print_warning "Virtual environment not found, skipping dependency update"
    fi
}

# Set proper permissions
set_permissions() {
    print_info "Setting proper file permissions"
    CURRENT_USER=${SUDO_USER:-$(whoami)}
    
    # Set ownership
    chown -R "$CURRENT_USER:$CURRENT_USER" "$SCRIPT_DIR"
    
    # Set execute permissions on scripts
    chmod +x "$SCRIPT_DIR"/*.sh
    
    # Set proper permissions on database
    if [ -f "$SCRIPT_DIR/users.db" ]; then
        chmod 600 "$SCRIPT_DIR/users.db"
    fi
    
    print_success "Permissions updated"
}

# Rollback function in case of failure
rollback() {
    print_error "Update failed, attempting rollback"
    
    # Restore database if backup exists
    if [ -f "$BACKUP_DIR/users.db" ]; then
        cp "$BACKUP_DIR/users.db" "$SCRIPT_DIR/"
        print_info "Database restored from backup"
    fi
    
    # Restore .env if backup exists
    if [ -f "$BACKUP_DIR/.env" ]; then
        cp "$BACKUP_DIR/.env" "$SCRIPT_DIR/"
        print_info "Configuration restored from backup"
    fi
    
    # Try to restart service
    start_service || true
    
    print_error "Rollback completed. Please check the logs and try again."
    exit 1
}

# Main update process
main() {
    print_info "Starting Garage Door Controller update process"
    echo "=================================="
    
    # Set trap for cleanup on error
    trap rollback ERR
    
    # Check privileges
    check_privileges
    
    # Create backup
    create_backup
    
    # Stop service
    stop_service
    
    # Update repository
    update_repository
    
    # Update token expiration
    update_token_expiration
    
    # Restore database (preserve existing database)
    restore_database
    
    # Update dependencies
    update_dependencies
    
    # Set permissions
    set_permissions
    
    # Start service
    if ! start_service; then
        rollback
    fi
    
    # Verify service is running
    print_info "Verifying service status"
    sleep 5
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        print_success "Update completed successfully!"
        print_info "Service is running and operational"
        print_info "Backup stored in: $BACKUP_DIR"
        
        # Show service status
        echo ""
        print_info "Service Status:"
        systemctl status "$SERVICE_NAME" --no-pager -l
    else
        print_error "Service verification failed"
        rollback
    fi
    
    echo "=================================="
    print_success "Update process completed"
}

# Show usage if help requested
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    echo "Garage Door Controller Update Script"
    echo "Usage: sudo ./update.sh"
    echo ""
    echo "This script will:"
    echo "  - Create a backup of your database and configuration"
    echo "  - Update the code from the git repository"
    echo "  - Increase token expiration to 360 days"
    echo "  - Preserve your existing database"
    echo "  - Update Python dependencies"
    echo "  - Restart the service"
    echo ""
    echo "Options:"
    echo "  -h, --help    Show this help message"
    exit 0
fi

# Run main function
main "$@"