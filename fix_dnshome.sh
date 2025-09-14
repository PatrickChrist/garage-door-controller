#!/bin/bash

# Fix für dnshome.de DynDNS Update
# Korrigiert das URL Format

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

if [ "$EUID" -ne 0 ]; then
    print_error "Bitte mit sudo ausführen"
    exit 1
fi

DOMAIN="frankenpower.dnshome.eu"

print_info "Korrigiere dnshome.de DynDNS Update Script..."

# Get password
echo ""
read -s -p "Passwort für $DOMAIN: " PASSWORD
echo ""

if [ -z "$PASSWORD" ]; then
    print_error "Passwort darf nicht leer sein"
    exit 1
fi

# Test different URL formats
print_info "Teste verschiedene URL Formate..."

PUBLIC_IP=$(curl -s --max-time 10 "https://checkip.amazonaws.com/" | tr -d '\n')
print_info "Öffentliche IP: $PUBLIC_IP"

echo ""
print_info "Test 1: Standard Format"
RESPONSE1=$(curl -s --max-time 30 "https://www.dnshome.de/dyndns.php?username=$DOMAIN&password=$PASSWORD&ip=$PUBLIC_IP" 2>&1)
echo "Antwort 1: $RESPONSE1"

echo ""
print_info "Test 2: Mit myip Parameter"
RESPONSE2=$(curl -s --max-time 30 "https://www.dnshome.de/dyndns.php?username=$DOMAIN&password=$PASSWORD&myip=$PUBLIC_IP" 2>&1)
echo "Antwort 2: $RESPONSE2"

echo ""
print_info "Test 3: Ohne IP (automatische Erkennung)"
RESPONSE3=$(curl -s --max-time 30 "https://www.dnshome.de/dyndns.php?username=$DOMAIN&password=$PASSWORD" 2>&1)
echo "Antwort 3: $RESPONSE3"

echo ""
print_info "Test 4: Mit hostname Parameter"
RESPONSE4=$(curl -s --max-time 30 "https://www.dnshome.de/dyndns.php?hostname=$DOMAIN&password=$PASSWORD&myip=$PUBLIC_IP" 2>&1)
echo "Antwort 4: $RESPONSE4"

echo ""
print_info "Test 5: DynDNS2 Standard Format"
RESPONSE5=$(curl -s --max-time 30 "https://www.dnshome.de/dyndns.php?hostname=$DOMAIN&myip=$PUBLIC_IP" --user "$DOMAIN:$PASSWORD" 2>&1)
echo "Antwort 5: $RESPONSE5"

# Check which format worked
SUCCESS_FORMAT=""
if echo "$RESPONSE1" | grep -qi "good\|nochg"; then
    SUCCESS_FORMAT="1"
elif echo "$RESPONSE2" | grep -qi "good\|nochg"; then
    SUCCESS_FORMAT="2"
elif echo "$RESPONSE3" | grep -qi "good\|nochg"; then
    SUCCESS_FORMAT="3"
elif echo "$RESPONSE4" | grep -qi "good\|nochg"; then
    SUCCESS_FORMAT="4"
elif echo "$RESPONSE5" | grep -qi "good\|nochg"; then
    SUCCESS_FORMAT="5"
fi

if [ -n "$SUCCESS_FORMAT" ]; then
    print_success "Format $SUCCESS_FORMAT funktioniert!"
    
    # Update the script with working format
    case $SUCCESS_FORMAT in
        1)
            WORKING_URL="https://www.dnshome.de/dyndns.php?username=$DOMAIN&password=$PASSWORD&ip=\$PUBLIC_IP"
            ;;
        2)
            WORKING_URL="https://www.dnshome.de/dyndns.php?username=$DOMAIN&password=$PASSWORD&myip=\$PUBLIC_IP"
            ;;
        3)
            WORKING_URL="https://www.dnshome.de/dyndns.php?username=$DOMAIN&password=$PASSWORD"
            ;;
        4)
            WORKING_URL="https://www.dnshome.de/dyndns.php?hostname=$DOMAIN&password=$PASSWORD&myip=\$PUBLIC_IP"
            ;;
        5)
            WORKING_URL="https://www.dnshome.de/dyndns.php?hostname=$DOMAIN&myip=\$PUBLIC_IP"
            USE_AUTH="yes"
            ;;
    esac
    
    print_info "Aktualisiere Update Script..."
    
    if [ "$SUCCESS_FORMAT" = "5" ]; then
        # Format 5 uses HTTP Basic Auth
        cat > /usr/local/bin/update-dnshome.sh << EOF
#!/bin/bash

# DynDNS Update Script für dnshome.de (Format 5 - HTTP Auth)
DOMAIN="$DOMAIN"
PASSWORD="$PASSWORD"
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
        if [ "\$(find \$LAST_IP_FILE -mmin +60)" ]; then
            echo "\$(date): IP unverändert (\$PUBLIC_IP), aber Stunden-Update" >> \$LOG_FILE
        else
            exit 0
        fi
    fi
fi

# Update DynDNS with HTTP Basic Auth
echo "\$(date): Aktualisiere DynDNS für \$DOMAIN mit IP \$PUBLIC_IP" >> \$LOG_FILE

RESPONSE=\$(curl -s --max-time 30 "https://www.dnshome.de/dyndns.php?hostname=\$DOMAIN&myip=\$PUBLIC_IP" --user "\$DOMAIN:\$PASSWORD" 2>&1)

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
    # Try to update anyway if we get an unclear response
    echo "\$PUBLIC_IP" > \$LAST_IP_FILE
    exit 0
fi
EOF
    else
        # Formats 1-4 use URL parameters
        cat > /usr/local/bin/update-dnshome.sh << EOF
#!/bin/bash

# DynDNS Update Script für dnshome.de (Format $SUCCESS_FORMAT)
DOMAIN="$DOMAIN"
PASSWORD="$PASSWORD"
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
        if [ "\$(find \$LAST_IP_FILE -mmin +60)" ]; then
            echo "\$(date): IP unverändert (\$PUBLIC_IP), aber Stunden-Update" >> \$LOG_FILE
        else
            exit 0
        fi
    fi
fi

# Update DynDNS
echo "\$(date): Aktualisiere DynDNS für \$DOMAIN mit IP \$PUBLIC_IP" >> \$LOG_FILE

RESPONSE=\$(curl -s --max-time 30 "$WORKING_URL" 2>&1)

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
    # Try to update anyway if we get an unclear response
    echo "\$PUBLIC_IP" > \$LAST_IP_FILE
    exit 0
fi
EOF
    fi
    
    chmod +x /usr/local/bin/update-dnshome.sh
    chown root:root /usr/local/bin/update-dnshome.sh
    
    # Test the updated script
    print_info "Teste korrigiertes Script..."
    if /usr/local/bin/update-dnshome.sh; then
        print_success "Update Script funktioniert jetzt!"
        
        # Restart the timer
        systemctl restart dyndns-dnshome.timer
        print_success "Service neu gestartet"
        
        # Check DNS after a moment
        sleep 30
        print_info "Prüfe DNS Auflösung..."
        /usr/local/bin/check-dnshome.sh
        
    else
        print_error "Update Script funktioniert immer noch nicht"
        tail -5 /var/log/dyndns.log
    fi
    
else
    print_error "Keines der Formate funktionierte!"
    echo ""
    echo "Mögliche Probleme:"
    echo "1. Passwort falsch"
    echo "2. Domain nicht aktiv bei dnshome.de"
    echo "3. API Format hat sich geändert"
    echo ""
    echo "Bitte prüfe:"
    echo "- Domain Status bei dnshome.de"
    echo "- Passwort korrekt"
    echo "- API Dokumentation auf https://www.dnshome.de/"
fi