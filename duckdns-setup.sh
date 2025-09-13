#!/bin/bash

# DuckDNS Setup Script for Garage Door Controller
# Enables remote access through dynamic DNS

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

print_header() {
    echo
    echo "=========================================="
    echo "  DuckDNS Setup for Garage Door Controller"
    echo "=========================================="
    echo
}

check_requirements() {
    print_status "Checking requirements..."
    
    if ! command -v curl &> /dev/null; then
        print_error "curl is required but not installed"
        exit 1
    fi
    
    if ! command -v crontab &> /dev/null; then
        print_error "cron is required but not installed"
        exit 1
    fi
    
    print_success "Requirements check passed"
}

get_duckdns_info() {
    print_status "Setting up DuckDNS configuration..."
    echo
    echo "To use DuckDNS, you need:"
    echo "1. A DuckDNS account (free at https://www.duckdns.org)"
    echo "2. A subdomain (e.g., mygarage.duckdns.org)"
    echo "3. Your DuckDNS token"
    echo
    
    # Get subdomain
    while true; do
        read -p "Enter your DuckDNS subdomain (without .duckdns.org): " DUCKDNS_DOMAIN
        if [[ $DUCKDNS_DOMAIN =~ ^[a-zA-Z0-9-]+$ ]]; then
            break
        else
            print_error "Invalid subdomain. Use only letters, numbers, and hyphens."
        fi
    done
    
    # Get token
    while true; do
        read -p "Enter your DuckDNS token: " DUCKDNS_TOKEN
        if [[ ${#DUCKDNS_TOKEN} -eq 36 ]]; then
            break
        else
            print_error "DuckDNS token should be 36 characters long."
        fi
    done
    
    DUCKDNS_URL="${DUCKDNS_DOMAIN}.duckdns.org"
    print_success "DuckDNS configuration: ${DUCKDNS_URL}"
}

test_duckdns_connection() {
    print_status "Testing DuckDNS connection..."
    
    # Test update
    RESPONSE=$(curl -s "https://www.duckdns.org/update?domains=${DUCKDNS_DOMAIN}&token=${DUCKDNS_TOKEN}&ip=")
    
    if [[ $RESPONSE == "OK" ]]; then
        print_success "DuckDNS connection successful"
    else
        print_error "DuckDNS connection failed: $RESPONSE"
        exit 1
    fi
}

create_duckdns_script() {
    print_status "Creating DuckDNS update script..."
    
    # Create DuckDNS directory
    mkdir -p "$DUCKDNS_DIR"
    
    # Create update script
    cat > "$DUCKDNS_DIR/duck.sh" << EOF
#!/bin/bash

# DuckDNS Update Script
# Updates IP address for ${DUCKDNS_URL}

DOMAIN="${DUCKDNS_DOMAIN}"
TOKEN="${DUCKDNS_TOKEN}"
LOGFILE="$DUCKDNS_DIR/duck.log"

# Get current external IP
CURRENT_IP=\$(curl -s https://ipv4.icanhazip.com/)

# Update DuckDNS
echo "\$(date): Updating \${DOMAIN}.duckdns.org to IP \${CURRENT_IP}" >> \$LOGFILE
RESPONSE=\$(curl -s "https://www.duckdns.org/update?domains=\${DOMAIN}&token=\${TOKEN}&ip=\${CURRENT_IP}")

if [[ \$RESPONSE == "OK" ]]; then
    echo "\$(date): Update successful" >> \$LOGFILE
else
    echo "\$(date): Update failed: \$RESPONSE" >> \$LOGFILE
fi
EOF

    chmod +x "$DUCKDNS_DIR/duck.sh"
    chown "$CURRENT_USER:$CURRENT_USER" -R "$DUCKDNS_DIR"
    
    print_success "DuckDNS update script created"
}

setup_cron_job() {
    print_status "Setting up automatic IP updates..."
    
    # Remove existing DuckDNS cron jobs to avoid duplicates
    crontab -l 2>/dev/null | grep -v "duck.sh" | crontab -
    
    # Add cron job to update every 5 minutes
    (crontab -l 2>/dev/null; echo "*/5 * * * * $DUCKDNS_DIR/duck.sh >/dev/null 2>&1") | crontab -
    
    print_success "Cron job configured (updates every 5 minutes)"
}

configure_nginx_for_duckdns() {
    print_status "Configuring Nginx for DuckDNS domain..."
    
    # Update Nginx configuration
    sudo tee /etc/nginx/sites-available/garage-controller > /dev/null << EOF
server {
    listen 80;
    server_name ${DUCKDNS_URL} localhost;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;

    # Rate limiting for external access
    limit_req_zone \$binary_remote_addr zone=garage_limit:10m rate=10r/m;
    limit_req zone=garage_limit burst=5 nodelay;

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
        
        # Timeout settings for external access
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    # WebSocket support
    location /ws {
        proxy_pass http://127.0.0.1:8000/ws;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        # Longer timeouts for WebSocket
        proxy_connect_timeout 7200s;
        proxy_send_timeout 7200s;
        proxy_read_timeout 7200s;
    }

    # Health check endpoint
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
}
EOF

    # Test and reload Nginx
    sudo nginx -t && sudo systemctl reload nginx
    
    print_success "Nginx configured for ${DUCKDNS_URL}"
}

update_environment_config() {
    print_status "Updating application configuration..."
    
    # Update .env file if it exists
    if [ -f "/home/pi/garage-controller/.env" ]; then
        # Update DuckDNS configuration
        sed -i "s/^DUCKDNS_DOMAIN=.*/DUCKDNS_DOMAIN=${DUCKDNS_DOMAIN}/" "/home/pi/garage-controller/.env"
        sed -i "s/^DUCKDNS_TOKEN=.*/DUCKDNS_TOKEN=${DUCKDNS_TOKEN}/" "/home/pi/garage-controller/.env"
        sed -i "s/^DUCKDNS_ENABLED=.*/DUCKDNS_ENABLED=true/" "/home/pi/garage-controller/.env"
        sed -i "s/^EXTERNAL_ACCESS_ENABLED=.*/EXTERNAL_ACCESS_ENABLED=true/" "/home/pi/garage-controller/.env"
        
        # Add missing variables if they don't exist
        if ! grep -q "DUCKDNS_URL=" "/home/pi/garage-controller/.env"; then
            echo "DUCKDNS_URL=${DUCKDNS_URL}" >> "/home/pi/garage-controller/.env"
        else
            sed -i "s/^DUCKDNS_URL=.*/DUCKDNS_URL=${DUCKDNS_URL}/" "/home/pi/garage-controller/.env"
        fi
        
        if ! grep -q "EXTERNAL_URL=" "/home/pi/garage-controller/.env"; then
            echo "EXTERNAL_URL=http://${DUCKDNS_URL}" >> "/home/pi/garage-controller/.env"
        else
            sed -i "s|^EXTERNAL_URL=.*|EXTERNAL_URL=http://${DUCKDNS_URL}|" "/home/pi/garage-controller/.env"
        fi
    fi
    
    print_success "Environment configuration updated"
}

setup_ssl_certificate() {
    print_status "Setting up SSL certificate with Let's Encrypt..."
    
    # Install certbot
    sudo apt update
    sudo apt install -y certbot python3-certbot-nginx
    
    # Get certificate
    print_warning "Obtaining SSL certificate..."
    print_warning "Make sure port 80 is forwarded to this Pi before continuing!"
    
    read -p "Is port 80 forwarded to this Raspberry Pi? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if sudo certbot --nginx -d ${DUCKDNS_URL} --non-interactive --agree-tos --register-unsafely-without-email; then
            print_success "SSL certificate installed successfully"
            
            # Setup auto-renewal
            (crontab -l 2>/dev/null; echo "0 12 * * * /usr/bin/certbot renew --quiet") | crontab -
            print_success "Auto-renewal configured"
            
            # Update environment with HTTPS URL
            if [ -f "/home/pi/garage-controller/.env" ]; then
                sed -i "s|^EXTERNAL_URL=.*|EXTERNAL_URL=https://${DUCKDNS_URL}|" "/home/pi/garage-controller/.env"
                sed -i "s/^SSL_ENABLED=.*/SSL_ENABLED=true/" "/home/pi/garage-controller/.env"
                sed -i "s|^SSL_CERT_PATH=.*|SSL_CERT_PATH=/etc/letsencrypt/live/${DUCKDNS_URL}/|" "/home/pi/garage-controller/.env"
                sed -i "s|^SSL_KEY_PATH=.*|SSL_KEY_PATH=/etc/letsencrypt/live/${DUCKDNS_URL}/|" "/home/pi/garage-controller/.env"
            fi
            
        else
            print_warning "SSL certificate setup failed. You can retry later with:"
            print_warning "sudo certbot --nginx -d ${DUCKDNS_URL}"
        fi
    else
        print_warning "SSL certificate skipped. Set up port forwarding first."
        print_warning "Run this script again after configuring your router."
    fi
}

update_firewall() {
    print_status "Updating firewall for external access..."
    
    # Allow HTTP and HTTPS from anywhere
    sudo ufw allow 80/tcp
    sudo ufw allow 443/tcp
    
    # Reload firewall
    sudo ufw reload
    
    print_success "Firewall updated for external access"
}

run_initial_update() {
    print_status "Running initial DuckDNS update..."
    
    /home/pi/duckdns/duck.sh
    
    print_success "Initial DuckDNS update completed"
}

display_completion_info() {
    print_success "DuckDNS setup completed successfully!"
    echo
    echo "=========================================="
    echo "  DuckDNS Configuration Complete"
    echo "=========================================="
    echo
    echo "🌐 Your DuckDNS URL: https://${DUCKDNS_URL}"
    echo "🏠 Local URL: http://$(hostname -I | awk '{print $1}')"
    echo
    echo "📋 Next Steps:"
    echo "1. Configure your router to forward ports to this Pi:"
    echo "   • Port 80 (HTTP) → $(hostname -I | awk '{print $1}'):80"
    echo "   • Port 443 (HTTPS) → $(hostname -I | awk '{print $1}'):443"
    echo
    echo "2. Test external access:"
    echo "   • From outside network: https://${DUCKDNS_URL}"
    echo "   • Health check: https://${DUCKDNS_URL}/health"
    echo
    echo "3. Update iOS app with external URL:"
    echo "   • Use: ${DUCKDNS_URL}"
    echo "   • Enable HTTPS in app settings"
    echo
    echo "🔒 Security Notes:"
    echo "   • Rate limiting enabled (10 requests/minute)"
    echo "   • SSL certificate auto-renews"
    echo "   • DuckDNS updates every 5 minutes"
    echo
    echo "📁 Files Created:"
    echo "   • $DUCKDNS_DIR/duck.sh (update script)"
    echo "   • $DUCKDNS_DIR/duck.log (update log)"
    echo
    echo "🔧 Management Commands:"
    echo "   • Check IP updates: tail -f $DUCKDNS_DIR/duck.log"
    echo "   • Manual update: $DUCKDNS_DIR/duck.sh"
    echo "   • Test SSL: curl -I https://${DUCKDNS_URL}/health"
    echo
}

# Main execution
main() {
    print_header
    
    check_requirements
    get_duckdns_info
    test_duckdns_connection
    create_duckdns_script
    setup_cron_job
    configure_nginx_for_duckdns
    update_environment_config
    setup_ssl_certificate
    update_firewall
    run_initial_update
    
    display_completion_info
}

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    print_error "Please do not run this script as root. Run as a regular user."
    exit 1
fi

# Set up user paths
CURRENT_USER=$(whoami)
USER_HOME="/home/$CURRENT_USER"
DUCKDNS_DIR="$USER_HOME/duckdns"
INSTALL_DIR="$USER_HOME/garage-controller"

# Run setup
main "$@"