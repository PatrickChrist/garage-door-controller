# Remote Access Setup Guide

Complete guide for accessing your garage door controller from anywhere using DuckDNS dynamic DNS.

## 🌐 Overview

This guide enables remote access to your Raspberry Pi garage controller from anywhere in the world using:
- **DuckDNS** - Free dynamic DNS service
- **Let's Encrypt** - Free SSL certificates
- **Port Forwarding** - Router configuration
- **Security hardening** - Rate limiting and firewall

## 🚀 Quick Setup

### Automated DuckDNS Setup
```bash
# Run on your Raspberry Pi
./duckdns-setup.sh
```

This script will:
1. ✅ Configure DuckDNS dynamic DNS
2. ✅ Set up automatic IP updates
3. ✅ Install SSL certificates
4. ✅ Configure Nginx for external access
5. ✅ Update firewall rules
6. ✅ Enable security features

## 📋 Prerequisites

### 1. DuckDNS Account Setup
1. **Visit** [duckdns.org](https://www.duckdns.org)
2. **Sign in** with Google, GitHub, or Reddit
3. **Create a subdomain** (e.g., `mygarage.duckdns.org`)
4. **Copy your token** (36-character string)

### 2. Router Access
- **Admin access** to your home router
- **Ability to configure** port forwarding
- **Static IP** for Raspberry Pi (recommended)

## 🔧 Manual Setup (Alternative)

### Step 1: DuckDNS Configuration

Create DuckDNS update script:
```bash
mkdir -p /home/pi/duckdns
nano /home/pi/duckdns/duck.sh
```

```bash
#!/bin/bash
echo url="https://www.duckdns.org/update?domains=YOURSUBDOMAIN&token=YOURTOKEN&ip=" | curl -k -o /home/pi/duckdns/duck.log -K -
```

Make executable and test:
```bash
chmod +x /home/pi/duckdns/duck.sh
/home/pi/duckdns/duck.sh
cat /home/pi/duckdns/duck.log  # Should show "OK"
```

### Step 2: Automatic Updates

Add to crontab for updates every 5 minutes:
```bash
crontab -e
```
Add line:
```
*/5 * * * * /home/pi/duckdns/duck.sh >/dev/null 2>&1
```

### Step 3: SSL Certificate

Install certbot and get certificate:
```bash
sudo apt install certbot python3-certbot-nginx
sudo certbot --nginx -d yoursubdomain.duckdns.org
```

## 🏠 Router Configuration

### Port Forwarding Setup

Configure your router to forward these ports to your Raspberry Pi:

| Service | External Port | Internal Port | Internal IP | Protocol |
|---------|---------------|---------------|-------------|----------|
| HTTP | 80 | 80 | 192.168.1.100 | TCP |
| HTTPS | 443 | 443 | 192.168.1.100 | TCP |

### Common Router Interfaces

**Linksys/Cisco:**
1. Navigate to **Smart Wi-Fi Tools** → **Port Forwarding**
2. Add new rule with above settings

**Netgear:**
1. Go to **Advanced** → **Port Forwarding/Port Triggering**
2. Add port forwarding rules

**TP-Link:**
1. Advanced → NAT Forwarding → **Port Forwarding**
2. Add new entries

**ASUS:**
1. **Adaptive QoS** → **Traditional QoS** → **Port Forwarding**
2. Enable and configure

**Generic Steps:**
1. Find **Port Forwarding** or **Virtual Server** in admin panel
2. Create rule: External Port 80 → Internal IP:80
3. Create rule: External Port 443 → Internal IP:443
4. **Save** and **restart** router

### Static IP Assignment

**Option 1: Router DHCP Reservation**
1. Find **DHCP** settings in router
2. Look for **Address Reservation** or **Static DHCP**
3. Add Pi's MAC address with desired IP

**Option 2: Pi Static Configuration**
```bash
sudo nano /etc/dhcpcd.conf
```
Add:
```
interface eth0
static ip_address=192.168.1.100/24
static routers=192.168.1.1
static domain_name_servers=1.1.1.1 8.8.8.8
```

## 🔐 Security Configuration

### Nginx Security Headers

The setup script configures security headers:
```nginx
# Rate limiting
limit_req_zone $binary_remote_addr zone=garage_limit:10m rate=10r/m;

# Security headers
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-Content-Type-Options "nosniff" always;
add_header X-XSS-Protection "1; mode=block" always;
```

### Firewall Rules

UFW firewall is configured for:
```bash
# Allow local network
sudo ufw allow from 192.168.0.0/16

# Allow external HTTP/HTTPS
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Rate limiting in Nginx handles abuse
```

### Additional Security (Optional)

**VPN Access Only:**
```bash
# Only allow VPN subnet
sudo ufw delete allow 80/tcp
sudo ufw delete allow 443/tcp
sudo ufw allow from 10.0.0.0/8 to any port 80
sudo ufw allow from 10.0.0.0/8 to any port 443
```

**IP Whitelist:**
```bash
# Only allow specific IPs
sudo ufw allow from YOUR_OFFICE_IP to any port 80
sudo ufw allow from YOUR_PHONE_CARRIER_IP to any port 443
```

## 📱 iOS App Configuration

### Update Server URL

In `GarageController.swift`:
```swift
init(baseURL: String = "yoursubdomain.duckdns.org") {
    // Use HTTPS for external access
    self.baseURL = baseURL
}
```

### HTTPS Support

Update WebSocket URL:
```swift
func connect() {
    let protocol = baseURL.contains("duckdns.org") ? "wss" : "ws"
    let scheme = baseURL.contains("duckdns.org") ? "https" : "http"
    
    guard let url = URL(string: "\(protocol)://\(baseURL)/ws") else {
        print("Invalid WebSocket URL")
        return
    }
    // ... rest of connection code
}
```

### App Settings

Add settings for URL configuration:
```swift
struct SettingsView: View {
    @AppStorage("garage_base_url") var baseURL = "192.168.1.100:8000"
    @AppStorage("use_external_access") var useExternal = false
    
    var body: some View {
        Form {
            Section("Connection") {
                TextField("Server URL", text: $baseURL)
                Toggle("External Access", isOn: $useExternal)
            }
        }
    }
}
```

## 🧪 Testing Remote Access

### Basic Connectivity
```bash
# Test from external network
curl -I https://yoursubdomain.duckdns.org/health

# Should return: HTTP/2 200 
```

### API Testing
```bash
# Test garage door API
curl https://yoursubdomain.duckdns.org/api/status

# Should return: {"1": "closed", "2": "closed"}
```

### WebSocket Testing
```javascript
// Browser console test
const ws = new WebSocket('wss://yoursubdomain.duckdns.org/ws');
ws.onopen = () => console.log('Connected');
ws.onmessage = (e) => console.log('Message:', e.data);
```

## 📊 Monitoring and Maintenance

### DuckDNS Status
```bash
# Check update log
tail -f /home/pi/duckdns/duck.log

# Manual update
/home/pi/duckdns/duck.sh
```

### SSL Certificate
```bash
# Check certificate expiry
sudo certbot certificates

# Test renewal
sudo certbot renew --dry-run

# Manual renewal
sudo certbot renew
```

### System Status
```bash
# Check Nginx status
sudo systemctl status nginx

# Check garage controller
sudo systemctl status garage-controller

# View access logs
sudo tail -f /var/log/nginx/access.log
```

## 🚨 Troubleshooting

### Common Issues

**DuckDNS not updating:**
```bash
# Check cron job
crontab -l

# Test manual update
/home/pi/duckdns/duck.sh
cat /home/pi/duckdns/duck.log
```

**Port forwarding not working:**
1. **Check router configuration**
2. **Test from external network** (mobile data)
3. **Verify Pi static IP** hasn't changed
4. **Check firewall rules**

**SSL certificate issues:**
```bash
# Check certificate status
sudo certbot certificates

# Recreate certificate
sudo certbot delete --cert-name yoursubdomain.duckdns.org
sudo certbot --nginx -d yoursubdomain.duckdns.org
```

**Rate limiting too strict:**
```bash
# Adjust Nginx rate limiting
sudo nano /etc/nginx/sites-available/garage-controller

# Change: rate=10r/m to rate=30r/m
# Then: sudo systemctl reload nginx
```

### Debug Commands

```bash
# Check external IP
curl https://ipv4.icanhazip.com/

# Test DNS resolution
nslookup yoursubdomain.duckdns.org

# Check open ports
sudo netstat -tlnp | grep :80
sudo netstat -tlnp | grep :443

# Test SSL
openssl s_client -connect yoursubdomain.duckdns.org:443
```

## 🔒 Security Best Practices

### Strong Authentication
- Enable garage door controller authentication
- Use strong API keys
- Consider 2FA for critical operations

### Network Security
- Keep router firmware updated
- Use WPA3 Wi-Fi security
- Regular security audits

### Monitoring
- Monitor access logs regularly
- Set up log alerts for suspicious activity
- Regular security updates

### Backup Access
- Keep local access available
- Document emergency procedures
- Test failover scenarios

## 📚 Additional Resources

### DuckDNS Documentation
- [DuckDNS Setup Guide](https://www.duckdns.org/install.jsp)
- [DuckDNS API Documentation](https://www.duckdns.org/spec.jsp)

### Let's Encrypt
- [Certbot Documentation](https://certbot.eff.org/)
- [SSL Best Practices](https://ssl-config.mozilla.org/)

### Nginx Security
- [Nginx Security Guide](https://nginx.org/en/docs/http/securing_http_traffic_ssl.html)
- [Rate Limiting](https://nginx.org/en/docs/http/ngx_http_limit_req_module.html)

---

With this setup, you can access your garage door controller from anywhere in the world securely using https://yoursubdomain.duckdns.org! 🌐🏠