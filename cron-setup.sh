#!/bin/bash

# Cron Job Setup Script for Garage Door Controller
# Sets up all necessary cron jobs for maintenance and monitoring

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

check_user() {
    if [ "$EUID" -eq 0 ]; then
        print_error "Please do not run this script as root. Run as a regular user."
        exit 1
    fi
    
    CURRENT_USER=$(whoami)
    print_status "Setting up cron jobs for user: $CURRENT_USER"
}

backup_existing_crontab() {
    print_status "Backing up existing crontab..."
    
    if crontab -l > /dev/null 2>&1; then
        crontab -l > ~/crontab_backup_$(date +%Y%m%d_%H%M%S).txt
        print_success "Existing crontab backed up"
    else
        print_status "No existing crontab found"
    fi
}

setup_maintenance_cron_jobs() {
    print_status "Setting up maintenance cron jobs..."
    
    INSTALL_DIR="$USER_HOME/garage-controller"
    
    # Remove existing garage-related cron jobs to avoid duplicates
    crontab -l 2>/dev/null | grep -v "garage" | grep -v "maintenance.sh" | crontab -
    
    # Add maintenance cron jobs
    (crontab -l 2>/dev/null; cat << CRON_EOF

# Garage Door Controller Maintenance Jobs
# Health check every 15 minutes
*/15 * * * * $INSTALL_DIR/maintenance.sh health >/dev/null 2>&1

# Daily backup at 2 AM
0 2 * * * $INSTALL_DIR/maintenance.sh backup >/dev/null 2>&1

# Weekly system update check on Sundays at 3 AM
0 3 * * 0 $INSTALL_DIR/maintenance.sh update >/dev/null 2>&1

# Monthly comprehensive maintenance on 1st day at 4 AM
0 4 1 * * $INSTALL_DIR/maintenance.sh all >/dev/null 2>&1

CRON_EOF
    ) | crontab -
    
    print_success "Maintenance cron jobs installed"
}

setup_duckdns_cron_job() {
    print_status "Checking for DuckDNS configuration..."
    
    # Check if DuckDNS is configured
    if [ -f "$USER_HOME/duckdns/duck.sh" ]; then
        print_status "DuckDNS script found, adding cron job..."
        
        # Remove existing DuckDNS cron jobs to avoid duplicates
        crontab -l 2>/dev/null | grep -v "duck.sh" | crontab -
        
        # Add DuckDNS update cron job
        (crontab -l 2>/dev/null; echo "*/5 * * * * $USER_HOME/duckdns/duck.sh >/dev/null 2>&1") | crontab -
        
        print_success "DuckDNS cron job added (updates every 5 minutes)"
    else
        print_warning "DuckDNS script not found. Run ./duckdns-setup.sh to configure"
    fi
}

setup_ssl_renewal_cron_job() {
    print_status "Checking for SSL certificates..."
    
    # Check if certbot is installed and certificates exist
    if command -v certbot >/dev/null 2>&1; then
        if [ -d "/etc/letsencrypt/live" ] && [ -n "$(ls -A /etc/letsencrypt/live 2>/dev/null)" ]; then
            print_status "SSL certificates found, adding renewal cron job..."
            
            # Remove existing certbot cron jobs to avoid duplicates
            crontab -l 2>/dev/null | grep -v "certbot" | crontab -
            
            # Add SSL renewal cron job
            (crontab -l 2>/dev/null; echo "0 12 * * * /usr/bin/certbot renew --quiet") | crontab -
            
            print_success "SSL renewal cron job added (daily check at noon)"
        else
            print_warning "No SSL certificates found"
        fi
    else
        print_warning "Certbot not installed, skipping SSL renewal cron job"
    fi
}

setup_log_rotation() {
    print_status "Setting up log rotation..."
    
    # Add log rotation cron job for garage controller logs
    (crontab -l 2>/dev/null; cat << 'LOG_CRON_EOF'

# Log rotation for garage controller
0 1 * * 0 find /var/log -name "*garage*" -type f -mtime +7 -delete >/dev/null 2>&1

LOG_CRON_EOF
    ) | crontab -
    
    print_success "Log rotation cron job added"
}

setup_system_monitoring() {
    print_status "Setting up system monitoring..."
    
    # Create monitoring script if it doesn't exist
    MONITOR_SCRIPT="$USER_HOME/garage-controller/monitor.sh"
    
    if [ ! -f "$MONITOR_SCRIPT" ]; then
        print_status "Creating system monitoring script..."
        
        cat > "$MONITOR_SCRIPT" << MONITOR_EOF
#!/bin/bash
# System Monitoring Script for Garage Door Controller

LOG_FILE="/var/log/garage-controller-monitor.log"
USER_HOME="$USER_HOME"
INSTALL_DIR="$USER_HOME/garage-controller"

# Function to log with timestamp
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $1" >> "$LOG_FILE"
}

# Check system resources
check_system_resources() {
    # Check CPU usage
    CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    if (( $(echo "$CPU_USAGE > 80" | bc -l) )); then
        log_message "WARNING: High CPU usage: $CPU_USAGE%"
    fi
    
    # Check memory usage
    MEM_USAGE=$(free | awk 'FNR==2{printf "%.1f", $3/($3+$4)*100}')
    if (( $(echo "$MEM_USAGE > 85" | bc -l) )); then
        log_message "WARNING: High memory usage: $MEM_USAGE%"
    fi
    
    # Check disk space
    DISK_USAGE=$(df / | awk 'NR==2 {printf "%.1f", $3/$2*100}')
    if (( $(echo "$DISK_USAGE > 90" | bc -l) )); then
        log_message "WARNING: Low disk space: $DISK_USAGE% used"
    fi
    
    # Check garage service
    if ! systemctl is-active --quiet garage-controller; then
        log_message "ERROR: garage-controller service is not running"
        # Attempt restart
        sudo systemctl restart garage-controller
        log_message "INFO: Attempted to restart garage-controller service"
    fi
    
    # Check network connectivity
    if ! ping -c 1 google.com >/dev/null 2>&1; then
        log_message "WARNING: Network connectivity issues detected"
    fi
}

# Check DuckDNS status
check_duckdns_status() {
    if [ -f "$USER_HOME/duckdns/duck.log" ]; then
        LAST_UPDATE=$(tail -1 $USER_HOME/duckdns/duck.log)
        if [[ "$LAST_UPDATE" == *"failed"* ]]; then
            log_message "WARNING: DuckDNS update failed - $LAST_UPDATE"
        fi
    fi
}

# Main monitoring function
main() {
    check_system_resources
    check_duckdns_status
    
    # Rotate log if it gets too large (>10MB)
    if [ -f "$LOG_FILE" ] && [ $(stat -c%s "$LOG_FILE") -gt 10485760 ]; then
        mv "$LOG_FILE" "${LOG_FILE}.old"
        log_message "Log file rotated due to size"
    fi
}

main
MONITOR_EOF
        
        chmod +x "$MONITOR_SCRIPT"
        print_success "System monitoring script created"
    fi
    
    # Add monitoring cron job
    (crontab -l 2>/dev/null; echo "*/30 * * * * $USER_HOME/garage-controller/monitor.sh >/dev/null 2>&1") | crontab -
    
    print_success "System monitoring cron job added (every 30 minutes)"
}

display_cron_summary() {
    print_success "All cron jobs configured successfully!"
    echo
    echo "=========================================="
    echo "  Cron Jobs Summary"
    echo "=========================================="
    echo
    echo "📋 Installed Cron Jobs:"
    echo "  • Health Check: Every 15 minutes"
    echo "  • Daily Backup: 2:00 AM"
    echo "  • System Updates: Sundays 3:00 AM"
    echo "  • Monthly Maintenance: 1st day 4:00 AM"
    echo "  • System Monitor: Every 30 minutes"
    echo "  • Log Rotation: Sundays 1:00 AM"
    
    if [ -f "$USER_HOME/duckdns/duck.sh" ]; then
        echo "  • DuckDNS Updates: Every 5 minutes"
    fi
    
    if command -v certbot >/dev/null 2>&1 && [ -d "/etc/letsencrypt/live" ]; then
        echo "  • SSL Renewal: Daily 12:00 PM"
    fi
    
    echo
    echo "📁 Log Files:"
    echo "  • Maintenance: /var/log/garage-controller-maintenance.log"
    echo "  • Monitoring: /var/log/garage-controller-monitor.log"
    
    if [ -f "$USER_HOME/duckdns/duck.log" ]; then
        echo "  • DuckDNS: $USER_HOME/duckdns/duck.log"
    fi
    
    echo
    echo "🔧 Management Commands:"
    echo "  • View cron jobs: crontab -l"
    echo "  • Edit cron jobs: crontab -e"
    echo "  • View logs: tail -f /var/log/garage-controller-*.log"
    echo
    echo "📋 Manual Commands:"
    echo "  • Health check: $USER_HOME/garage-controller/maintenance.sh health"
    echo "  • Backup: $USER_HOME/garage-controller/maintenance.sh backup"
    echo "  • Update: $USER_HOME/garage-controller/maintenance.sh update"
    echo
}

# Main execution
main() {
    echo
    echo "=========================================="
    echo "  Garage Door Controller - Cron Setup"
    echo "=========================================="
    echo
    
    check_user
    backup_existing_crontab
    setup_maintenance_cron_jobs
    setup_duckdns_cron_job
    setup_ssl_renewal_cron_job
    setup_log_rotation
    setup_system_monitoring
    
    display_cron_summary
}

# Set up user paths
CURRENT_USER=$(whoami)
USER_HOME="/home/$CURRENT_USER"

# Run main function
main "$@"