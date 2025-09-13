# 🔒 Security Guide & Hosting Recommendations

Comprehensive security and hosting guide for your Raspberry Pi garage door controller.

## 🛡️ Security Features Implemented

### Authentication System
- **User Management**: SQLite database with bcrypt password hashing
- **Session Management**: JWT tokens with secure HttpOnly cookies
- **Role-Based Access**: Admin and user roles with different privileges
- **Default Admin**: Auto-created on first run (change password immediately!)

### API Security
- **Authentication Required**: All garage control endpoints require authentication
- **CSRF Protection**: Secure SameSite cookies prevent cross-site attacks
- **Rate Limiting**: Nginx configuration includes rate limiting
- **HTTPS Enforcement**: SSL/TLS encryption for all communications

### Default Credentials
```
Username: admin
Password: garage123!
```
**⚠️ CHANGE THESE IMMEDIATELY AFTER FIRST LOGIN!**

## 🏠 Local Network Security

### Network Isolation
```bash
# Isolate on IoT VLAN (if supported by router)
# Configure router to create separate VLAN for IoT devices
# Example: 192.168.10.0/24 for IoT, 192.168.1.0/24 for main network
```

### Firewall Configuration
```bash
# UFW is configured automatically by install script
sudo ufw status
sudo ufw allow from 192.168.0.0/16 to any port 22  # SSH from local only
sudo ufw allow from 192.168.0.0/16 to any port 80   # HTTP from local only
sudo ufw allow from 192.168.0.0/16 to any port 443  # HTTPS from local only
```

## 🌐 Remote Access Security

### DuckDNS + Let's Encrypt
- **Dynamic DNS**: Automatic IP updates every 5 minutes
- **SSL Certificates**: Auto-renewal with Let's Encrypt
- **HTTPS Only**: All communications encrypted in transit
- **HSTS Headers**: HTTP Strict Transport Security enabled

### Rate Limiting
```nginx
# Nginx configuration (already included)
limit_req_zone $binary_remote_addr zone=garage_limit:10m rate=10r/m;
limit_req zone=garage_limit burst=5 nodelay;
```

### Security Headers
```nginx
# Already configured in Nginx
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-Content-Type-Options "nosniff" always;
add_header X-XSS-Protection "1; mode=block" always;
add_header Referrer-Policy "strict-origin-when-cross-origin" always;
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
```

## 🏢 Professional Hosting Recommendations

### Option 1: Cloud VPS with Secure Tunnel
**Best for: Professional deployments, multiple sites**

#### Providers:
- **DigitalOcean**: $5/month droplet
- **Linode**: $5/month nanode
- **AWS Lightsail**: $3.50/month instance
- **Vultr**: $2.50/month instance

#### Setup:
```bash
# On VPS (Ubuntu 22.04)
apt update && apt upgrade -y
apt install nginx certbot python3-certbot-nginx fail2ban

# Install WireGuard for secure tunnel
apt install wireguard

# Configure tunnel between VPS and Raspberry Pi
# VPS acts as reverse proxy to Pi over encrypted tunnel
```

#### Architecture:
```
Internet → VPS (Public IP) → WireGuard Tunnel → Raspberry Pi (Private)
```

**Benefits:**
- Professional SSL certificates
- DDoS protection
- Redundancy options
- Professional monitoring

### Option 2: Tailscale/ZeroTier Mesh VPN
**Best for: Personal use, easy setup**

#### Tailscale Setup:
```bash
# On Raspberry Pi
curl -fsSL https://tailscale.com/install.sh | sh
tailscale up

# Enable subnet routing for local network
tailscale up --advertise-routes=192.168.1.0/24
```

#### Benefits:
- Zero-configuration VPN
- End-to-end encryption
- Device authentication
- Works behind NAT/firewalls

### Option 3: Cloudflare Tunnel (Free)
**Best for: Free SSL, DDoS protection**

#### Setup:
```bash
# Install cloudflared on Raspberry Pi
curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64 -o cloudflared
chmod +x cloudflared
sudo mv cloudflared /usr/local/bin/

# Create tunnel
cloudflared tunnel create garage-door
cloudflared tunnel configure garage-door

# Configure tunnel to point to local service
# Edit ~/.cloudflared/config.yml
```

#### Benefits:
- Free tier available
- Professional DDoS protection
- Global CDN
- Analytics and monitoring

### Option 4: Self-Hosted with Dynamic DNS
**Best for: Full control, learning**

#### Enhanced Security Setup:
```bash
# Additional security measures for self-hosting

# Install and configure Fail2Ban
sudo apt install fail2ban
sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local

# Configure custom filter for garage app
cat > /etc/fail2ban/filter.d/garage-door.conf << 'EOF'
[Definition]
failregex = ^.*"POST /auth/login.*" 401.*$
ignoreregex =
EOF

# Add jail for garage app
cat >> /etc/fail2ban/jail.local << 'EOF'
[garage-door]
enabled = true
port = http,https
filter = garage-door
logpath = /var/log/nginx/access.log
maxretry = 5
bantime = 3600
EOF

# Restart fail2ban
sudo systemctl restart fail2ban

# Set up automated backups
crontab -e
# Add: 0 2 * * * /usr/bin/rsync -av /home/pi/garage-controller/ /mnt/backup/garage-controller/
```

## 🔐 Additional Security Hardening

### SSH Security
```bash
# Disable password authentication
sudo nano /etc/ssh/sshd_config
# Set: PasswordAuthentication no
# Set: PubkeyAuthentication yes
# Set: PermitRootLogin no

# Restart SSH
sudo systemctl restart ssh

# Generate SSH key pair (on your computer)
ssh-keygen -t ed25519 -C "your-email@example.com"
ssh-copy-id pi@your-pi-ip
```

### System Updates
```bash
# Enable automatic security updates
sudo apt install unattended-upgrades
sudo dpkg-reconfigure unattended-upgrades

# Configure auto-updates
sudo nano /etc/apt/apt.conf.d/50unattended-upgrades
# Uncomment security updates line
```

### Log Monitoring
```bash
# Install logwatch for daily email reports
sudo apt install logwatch

# Configure logwatch
sudo nano /etc/cron.daily/00logwatch
# Add your email for daily security reports
```

## 📊 Monitoring and Alerts

### System Monitoring
```bash
# Install monitoring tools
sudo apt install htop iotop nethogs

# Set up basic monitoring script
cat > /home/pi/monitor.sh << 'EOF'
#!/bin/bash
# Check system health and send alerts

# Check CPU usage
CPU=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
if (( $(echo "$CPU > 80" | bc -l) )); then
    echo "High CPU usage: $CPU%" | mail -s "Pi Alert: High CPU" your-email@example.com
fi

# Check memory usage
MEM=$(free | grep Mem | awk '{printf("%.1f", $3/$2 * 100.0)}')
if (( $(echo "$MEM > 85" | bc -l) )); then
    echo "High memory usage: $MEM%" | mail -s "Pi Alert: High Memory" your-email@example.com
fi

# Check disk space
DISK=$(df / | awk 'NR==2 {printf "%.1f", $3/$2*100}')
if (( $(echo "$DISK > 90" | bc -l) )); then
    echo "Low disk space: $DISK% used" | mail -s "Pi Alert: Low Disk Space" your-email@example.com
fi

# Check garage service
if ! systemctl is-active --quiet garage-controller; then
    echo "Garage controller service is down" | mail -s "Pi Alert: Service Down" your-email@example.com
    sudo systemctl restart garage-controller
fi
EOF

chmod +x /home/pi/monitor.sh

# Run every 15 minutes
crontab -e
# Add: */15 * * * * /home/pi/monitor.sh
```

### Uptime Monitoring
Consider external monitoring services:
- **UptimeRobot**: Free tier monitors from multiple locations
- **Pingdom**: Professional uptime monitoring
- **StatusCake**: Free and paid tiers available

## 🚨 Incident Response

### Emergency Access
1. **SSH Access**: Always maintain SSH access with key-based authentication
2. **Physical Access**: Keep monitor and keyboard available for Pi
3. **Backup Access**: Document all credentials in secure password manager
4. **Recovery Plan**: Test disaster recovery procedures

### Security Incident Checklist
1. **Isolate**: Disconnect from network if compromise suspected
2. **Assess**: Check logs for unauthorized access
3. **Document**: Record all findings
4. **Recover**: Restore from known-good backup
5. **Harden**: Implement additional security measures

## 📝 Security Maintenance

### Weekly Tasks
- [ ] Check system and application logs
- [ ] Verify SSL certificate status
- [ ] Review failed authentication attempts
- [ ] Check system resource usage

### Monthly Tasks
- [ ] Update system packages
- [ ] Review and rotate passwords
- [ ] Test backup and recovery procedures
- [ ] Review firewall rules and access logs

### Quarterly Tasks
- [ ] Security audit and penetration testing
- [ ] Review and update access permissions
- [ ] Update documentation
- [ ] Test disaster recovery plan

## 🔧 Troubleshooting Security Issues

### Common Issues

**Certificate Renewal Failures:**
```bash
# Check certificate status
sudo certbot certificates

# Test renewal
sudo certbot renew --dry-run

# Manual renewal
sudo certbot renew --force-renewal
```

**Authentication Issues:**
```bash
# Check user database
sqlite3 users.db "SELECT username, is_active, created_at FROM users;"

# Reset admin password
python3 -c "
from users import user_manager
user_manager.change_password(1, 'new_password_here')
print('Password updated')
"
```

**Firewall Blocking Access:**
```bash
# Check UFW status
sudo ufw status verbose

# Temporarily disable for testing
sudo ufw disable

# Re-enable with proper rules
sudo ufw enable
```

## 🌟 Best Practices Summary

1. **Strong Passwords**: Use unique, complex passwords for all accounts
2. **Regular Updates**: Keep system and applications updated
3. **Least Privilege**: Grant minimum necessary permissions
4. **Defense in Depth**: Multiple layers of security
5. **Monitoring**: Continuous monitoring and alerting
6. **Backup**: Regular, tested backups
7. **Documentation**: Keep security procedures documented
8. **Training**: Stay informed about security threats

## 📞 Emergency Contacts

Document your emergency contacts and procedures:
- System Administrator: [Your contact info]
- Hosting Provider Support: [Provider contact]
- Domain/DNS Provider: [Provider contact]
- Local IT Support: [Contact if applicable]

---

**Remember**: Security is an ongoing process, not a one-time setup. Regular maintenance and monitoring are essential for keeping your garage door controller secure.