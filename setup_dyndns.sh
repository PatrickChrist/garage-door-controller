#!/bin/bash

# DynDNS Setup Script für Raspberry Pi
# Unterstützt verschiedene DynDNS Anbieter

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    print_error "Bitte mit sudo ausführen"
    exit 1
fi

print_info "DynDNS Setup für Raspberry Pi"
echo "=================================="

# Install ddclient
print_info "Installiere ddclient..."
apt update
apt install -y ddclient

# Stop service for configuration
systemctl stop ddclient

print_info "Welchen DynDNS Anbieter möchtest du verwenden?"
echo "1) DuckDNS (kostenlos, einfach)"
echo "2) No-IP (kostenlos)"
echo "3) DynDNS.org"
echo "4) Strato"
echo "5) Custom/Andere"
echo ""
read -p "Wähle (1-5): " provider_choice

case $provider_choice in
    1)
        PROVIDER="duckdns"
        print_info "DuckDNS gewählt"
        read -p "DuckDNS Domain (ohne .duckdns.org): " DOMAIN
        read -p "DuckDNS Token: " TOKEN
        FULL_DOMAIN="${DOMAIN}.duckdns.org"
        ;;
    2)
        PROVIDER="noip"
        print_info "No-IP gewählt"
        read -p "No-IP Domain: " FULL_DOMAIN
        read -p "No-IP Benutzername: " USERNAME
        read -s -p "No-IP Passwort: " PASSWORD
        echo ""
        ;;
    3)
        PROVIDER="dyndns"
        print_info "DynDNS.org gewählt"
        read -p "DynDNS Domain: " FULL_DOMAIN
        read -p "DynDNS Benutzername: " USERNAME
        read -s -p "DynDNS Passwort: " PASSWORD
        echo ""
        ;;
    4)
        PROVIDER="strato"
        print_info "Strato gewählt"
        read -p "Strato Domain: " FULL_DOMAIN
        read -p "Strato Benutzername: " USERNAME
        read -s -p "Strato Passwort: " PASSWORD
        echo ""
        ;;
    5)
        PROVIDER="custom"
        print_info "Custom Provider gewählt"
        read -p "Server URL: " SERVER
        read -p "Protocol: " PROTOCOL
        read -p "Domain: " FULL_DOMAIN
        read -p "Benutzername: " USERNAME
        read -s -p "Passwort: " PASSWORD
        echo ""
        ;;
    *)
        print_error "Ungültige Auswahl"
        exit 1
        ;;
esac

# Create ddclient configuration
print_info "Erstelle ddclient Konfiguration..."

if [ "$PROVIDER" = "duckdns" ]; then
    cat > /etc/ddclient.conf << EOF
# DuckDNS Configuration
daemon=300
syslog=yes
pid=/var/run/ddclient.pid
protocol=duckdns
use=web, web=checkip.dyndns.com/, web-skip='IP Address'
server=www.duckdns.org
login=$DOMAIN
password=$TOKEN
$FULL_DOMAIN
EOF

elif [ "$PROVIDER" = "noip" ]; then
    cat > /etc/ddclient.conf << EOF
# No-IP Configuration
daemon=300
syslog=yes
pid=/var/run/ddclient.pid
protocol=noip
use=web, web=checkip.dyndns.com/, web-skip='IP Address'
server=dynupdate.no-ip.com
login=$USERNAME
password='$PASSWORD'
$FULL_DOMAIN
EOF

elif [ "$PROVIDER" = "dyndns" ]; then
    cat > /etc/ddclient.conf << EOF
# DynDNS.org Configuration
daemon=300
syslog=yes
pid=/var/run/ddclient.pid
protocol=dyndns2
use=web, web=checkip.dyndns.com/, web-skip='IP Address'
server=members.dyndns.org
login=$USERNAME
password='$PASSWORD'
$FULL_DOMAIN
EOF

elif [ "$PROVIDER" = "strato" ]; then
    cat > /etc/ddclient.conf << EOF
# Strato Configuration
daemon=300
syslog=yes
pid=/var/run/ddclient.pid
protocol=dyndns2
use=web, web=checkip.dyndns.com/, web-skip='IP Address'
server=dyndns.strato.com
login=$USERNAME
password='$PASSWORD'
$FULL_DOMAIN
EOF

elif [ "$PROVIDER" = "custom" ]; then
    cat > /etc/ddclient.conf << EOF
# Custom Provider Configuration
daemon=300
syslog=yes
pid=/var/run/ddclient.pid
protocol=$PROTOCOL
use=web, web=checkip.dyndns.com/, web-skip='IP Address'
server=$SERVER
login=$USERNAME
password='$PASSWORD'
$FULL_DOMAIN
EOF
fi

# Set permissions
chmod 600 /etc/ddclient.conf
chown root:root /etc/ddclient.conf

print_success "ddclient Konfiguration erstellt"

# Enable and start service
print_info "Starte ddclient Service..."
systemctl enable ddclient
systemctl start ddclient

# Wait a moment for first update
sleep 5

# Check status
print_info "Überprüfe ddclient Status..."
if systemctl is-active --quiet ddclient; then
    print_success "ddclient läuft erfolgreich"
else
    print_error "ddclient Service Problem"
    systemctl status ddclient
fi

# Show logs
print_info "Aktuelle Logs:"
journalctl -u ddclient -n 10 --no-pager

# Test DNS resolution
print_info "Teste DNS Auflösung..."
sleep 10  # Wait for DNS propagation
if nslookup $FULL_DOMAIN > /dev/null 2>&1; then
    RESOLVED_IP=$(nslookup $FULL_DOMAIN | grep -A1 "Name:" | tail -1 | awk '{print $2}')
    PUBLIC_IP=$(curl -s checkip.dyndns.com | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+')
    
    print_info "Domain: $FULL_DOMAIN"
    print_info "Aufgelöste IP: $RESOLVED_IP"
    print_info "Öffentliche IP: $PUBLIC_IP"
    
    if [ "$RESOLVED_IP" = "$PUBLIC_IP" ]; then
        print_success "DNS Auflösung erfolgreich!"
    else
        print_warning "DNS Auflösung noch nicht aktualisiert (kann bis zu 24h dauern)"
    fi
else
    print_warning "DNS Auflösung fehlgeschlagen - Domain eventuell noch nicht verfügbar"
fi

# FRITZ!Box configuration notes
print_info "FRITZ!Box Konfiguration:"
echo "=================================="
echo "1. FRITZ!Box Admin öffnen (http://fritz.box)"
echo "2. Internet → Permits → Port Sharing"
echo "3. Neue Regel erstellen:"
echo "   - Gerät: Raspberry Pi auswählen"
echo "   - Protokoll: TCP"
echo "   - Externe Ports: 8000"
echo "   - An Port: 8000"
echo "   - An IPv4-Adresse: $(hostname -I | awk '{print $1}')"
echo ""
echo "4. Internet → Permits → DynDNS"
echo "   - DynDNS DEAKTIVIEREN (da jetzt über Pi läuft)"
echo ""

print_success "DynDNS Setup abgeschlossen!"
print_info "Deine neue Adresse: http://$FULL_DOMAIN:8000/"

# Create monitoring script
print_info "Erstelle Monitoring Script..."
cat > /usr/local/bin/check-dyndns.sh << 'EOF'
#!/bin/bash
# DynDNS Monitoring Script

DOMAIN=$(grep -E "^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$" /etc/ddclient.conf | tail -1)
PUBLIC_IP=$(curl -s --max-time 10 checkip.dyndns.com | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+')
RESOLVED_IP=$(nslookup $DOMAIN 2>/dev/null | grep -A1 "Name:" | tail -1 | awk '{print $2}' 2>/dev/null)

echo "Domain: $DOMAIN"
echo "Public IP: $PUBLIC_IP"
echo "Resolved IP: $RESOLVED_IP"

if [ "$RESOLVED_IP" = "$PUBLIC_IP" ]; then
    echo "✓ DynDNS is working correctly"
    exit 0
else
    echo "✗ DynDNS mismatch - forcing update"
    ddclient -force
    exit 1
fi
EOF

chmod +x /usr/local/bin/check-dyndns.sh

# Add to crontab for monitoring
print_info "Richte automatische Überwachung ein..."
(crontab -l 2>/dev/null; echo "*/15 * * * * /usr/local/bin/check-dyndns.sh >> /var/log/dyndns-check.log 2>&1") | crontab -

print_success "Setup komplett!"
print_info "Überwachung läuft alle 15 Minuten"
print_info "Logs: journalctl -u ddclient -f"
print_info "Check: /usr/local/bin/check-dyndns.sh"