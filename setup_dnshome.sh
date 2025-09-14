#!/bin/bash

# DynDNS Setup für dnshome.de auf Raspberry Pi
# Speziell für frankenpower.dnshome.eu

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

print_info "DynDNS Setup für dnshome.de"
echo "=================================="

# Your dnshome.de details
DOMAIN="frankenpower.dnshome.eu"
UPDATE_URL="https://www.dnshome.de/dyndns.php"

print_info "Domain: $DOMAIN"
print_info "Update URL: $UPDATE_URL"

# Get password
echo ""
read -s -p "Passwort für $DOMAIN: " PASSWORD
echo ""

if [ -z "$PASSWORD" ]; then
    print_error "Passwort darf nicht leer sein"
    exit 1
fi

# Install required packages
print_info "Installiere curl und cron..."
apt update
apt install -y curl cron

# Create update script
print_info "Erstelle DynDNS Update Script..."

cat > /usr/local/bin/update-dnshome.sh << EOF
#!/bin/bash

# DynDNS Update Script für dnshome.de
DOMAIN="$DOMAIN"
PASSWORD="$PASSWORD"
UPDATE_URL="$UPDATE_URL"
LOG_FILE="/var/log/dyndns.log"

# Get current public IP
PUBLIC_IP=\$(curl -s --max-time 10 "https://checkip.amazonaws.com/" | tr -d '\n')

if [ -z "\$PUBLIC_IP" ]; then
    PUBLIC_IP=\$(curl -s --max-time 10 "https://ipinfo.io/ip" | tr -d '\n')
fi

if [ -z "\$PUBLIC_IP" ]; then
    echo "\$(date): FEHLER - Konnte öffentliche IP nicht ermitteln" >> \$LOG_FILE
    exit 1
fi

# Check if IP has changed
LAST_IP_FILE="/tmp/last_dyndns_ip"
if [ -f "\$LAST_IP_FILE" ]; then
    LAST_IP=\$(cat \$LAST_IP_FILE)
    if [ "\$PUBLIC_IP" = "\$LAST_IP" ]; then
        # IP hasn't changed, but update anyway every hour for safety
        if [ "\$(find \$LAST_IP_FILE -mmin +60)" ]; then
            echo "\$(date): IP unverändert (\$PUBLIC_IP), aber Stunden-Update" >> \$LOG_FILE
        else
            exit 0
        fi
    fi
fi

# Update DynDNS
echo "\$(date): Aktualisiere DynDNS für \$DOMAIN mit IP \$PUBLIC_IP" >> \$LOG_FILE

# dnshome.de specific update call
RESPONSE=\$(curl -s --max-time 30 "\$UPDATE_URL?username=\$DOMAIN&password=\$PASSWORD&ip=\$PUBLIC_IP" 2>&1)

if echo "\$RESPONSE" | grep -qi "good\|nochg"; then
    echo "\$(date): SUCCESS - DynDNS Update erfolgreich: \$RESPONSE" >> \$LOG_FILE
    echo "\$PUBLIC_IP" > \$LAST_IP_FILE
    exit 0
elif echo "\$RESPONSE" | grep -qi "noauth\|badauth"; then
    echo "\$(date): FEHLER - Authentifizierung fehlgeschlagen: \$RESPONSE" >> \$LOG_FILE
    exit 1
elif echo "\$RESPONSE" | grep -qi "notfqdn\|nohost"; then
    echo "\$(date): FEHLER - Domain nicht gefunden: \$RESPONSE" >> \$LOG_FILE
    exit 1
else
    echo "\$(date): WARNING - Unbekannte Antwort: \$RESPONSE" >> \$LOG_FILE
    exit 1
fi
EOF

# Make script executable
chmod +x /usr/local/bin/update-dnshome.sh
chown root:root /usr/local/bin/update-dnshome.sh

print_success "Update Script erstellt"

# Test the script
print_info "Teste DynDNS Update..."
if /usr/local/bin/update-dnshome.sh; then
    print_success "Erster DynDNS Update erfolgreich!"
else
    print_error "DynDNS Update fehlgeschlagen - prüfe Zugangsdaten"
    print_info "Log anzeigen: tail -f /var/log/dyndns.log"
    exit 1
fi

# Create systemd service for more reliable updates
print_info "Erstelle systemd Service..."

cat > /etc/systemd/system/dyndns-dnshome.service << EOF
[Unit]
Description=DynDNS Update Service for dnshome.de
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/update-dnshome.sh
User=root
EOF

cat > /etc/systemd/system/dyndns-dnshome.timer << EOF
[Unit]
Description=Run DynDNS update every 5 minutes
Requires=dyndns-dnshome.service

[Timer]
OnBootSec=2min
OnUnitActiveSec=5min
AccuracySec=1min

[Install]
WantedBy=timers.target
EOF

# Enable and start timer
systemctl daemon-reload
systemctl enable dyndns-dnshome.timer
systemctl start dyndns-dnshome.timer

print_success "systemd Timer aktiviert (Update alle 5 Minuten)"

# Create monitoring script
print_info "Erstelle Monitoring Script..."
cat > /usr/local/bin/check-dnshome.sh << 'EOF'
#!/bin/bash
# DynDNS Monitoring für dnshome.de

DOMAIN="frankenpower.dnshome.eu"
PUBLIC_IP=$(curl -s --max-time 10 "https://checkip.amazonaws.com/" | tr -d '\n')
RESOLVED_IP=$(nslookup $DOMAIN 8.8.8.8 2>/dev/null | grep -A1 "Name:" | tail -1 | awk '{print $2}' 2>/dev/null)

echo "=================================="
echo "DynDNS Status Check"
echo "=================================="
echo "Domain: $DOMAIN"
echo "Öffentliche IP: $PUBLIC_IP"
echo "DNS aufgelöste IP: $RESOLVED_IP"
echo ""

if [ "$RESOLVED_IP" = "$PUBLIC_IP" ]; then
    echo "✓ DynDNS funktioniert korrekt"
    echo "✓ Garage Controller erreichbar unter: http://$DOMAIN:8000/"
    exit 0
else
    echo "✗ IP-Mismatch - DNS eventuell noch nicht aktualisiert"
    echo "  (DNS Propagation kann bis zu 24h dauern)"
    
    # Show last log entries
    echo ""
    echo "Letzte DynDNS Logs:"
    tail -5 /var/log/dyndns.log 2>/dev/null || echo "Keine Logs gefunden"
    exit 1
fi
EOF

chmod +x /usr/local/bin/check-dnshome.sh

# Initial DNS check
print_info "Warte auf DNS Propagation..."
sleep 15

print_info "Überprüfe DNS Auflösung..."
/usr/local/bin/check-dnshome.sh

# Show service status
print_info "Service Status:"
systemctl status dyndns-dnshome.timer --no-pager -l

print_success "Setup abgeschlossen!"
echo ""
echo "=================================="
echo "NÄCHSTE SCHRITTE:"
echo "=================================="
echo ""
echo "1. FRITZ!Box konfigurieren:"
echo "   - Öffne http://fritz.box"
echo "   - Internet → Permits → DynDNS → DEAKTIVIEREN"
echo "   - Internet → Permits → Port Sharing"
echo "   - Neue Regel: TCP, Port 8000 → $(hostname -I | awk '{print $1}'):8000"
echo ""
echo "2. Zugriff testen:"
echo "   - Intern: http://$(hostname -I | awk '{print $1}'):8000/"
echo "   - Extern: http://$DOMAIN:8000/"
echo ""
echo "3. Überwachung:"
echo "   - Status: sudo /usr/local/bin/check-dnshome.sh"
echo "   - Logs: tail -f /var/log/dyndns.log"
echo "   - Service: systemctl status dyndns-dnshome.timer"
echo ""
print_success "Deine neue Garage Controller Adresse: http://$DOMAIN:8000/"