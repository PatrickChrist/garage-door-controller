#!/bin/bash

# Raspberry Pi Backup Setup Script
# Creates comprehensive backup solution to NAS

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

if [ "$EUID" -ne 0 ]; then
    print_error "Please run with sudo"
    exit 1
fi

print_info "Raspberry Pi Backup Setup"
echo "=========================="

# Gather NAS information
echo ""
print_info "NAS Configuration"
read -p "NAS IP Address: " NAS_IP
read -p "NAS Share Name (e.g., backup): " NAS_SHARE
read -p "Username for NAS: " NAS_USER
read -s -p "Password for NAS: " NAS_PASS
echo ""
read -p "Use SMB/CIFS? (y/n, default: y): " USE_SMB
USE_SMB=${USE_SMB:-y}

# Install required packages
print_info "Installing backup tools..."
apt update
apt install -y rsync cifs-utils pv pigz

# Create mount point and backup directories
MOUNT_POINT="/mnt/nas-backup"
BACKUP_DIR="$MOUNT_POINT/rpi-backups/$(hostname)"
LOCAL_BACKUP_DIR="/opt/backups"

mkdir -p "$MOUNT_POINT"
mkdir -p "$LOCAL_BACKUP_DIR"

print_success "Directories created"

# Setup NAS mounting
if [[ "$USE_SMB" =~ ^[Yy]$ ]]; then
    print_info "Setting up SMB/CIFS mount..."
    
    # Create credentials file
    cat > /etc/cifs-credentials << EOF
username=$NAS_USER
password=$NAS_PASS
domain=
EOF
    chmod 600 /etc/cifs-credentials
    
    # Add to fstab
    if ! grep -q "$NAS_IP" /etc/fstab; then
        echo "//$NAS_IP/$NAS_SHARE $MOUNT_POINT cifs credentials=/etc/cifs-credentials,uid=1000,gid=1000,iocharset=utf8,file_mode=0777,dir_mode=0777,noperm,_netdev 0 0" >> /etc/fstab
    fi
    
    # Test mount
    if mount "$MOUNT_POINT"; then
        print_success "NAS mounted successfully"
    else
        print_error "Failed to mount NAS - check credentials and network"
        exit 1
    fi
else
    print_warning "Manual NFS setup required - add to /etc/fstab"
    print_info "Example: $NAS_IP:/$NAS_SHARE $MOUNT_POINT nfs defaults,_netdev 0 0"
fi

# Create backup directory on NAS
mkdir -p "$BACKUP_DIR"/{full-images,incremental,system-files,database}

# Create comprehensive backup script
print_info "Creating backup scripts..."

# 1. Full SD Card Image Backup Script
cat > /usr/local/bin/backup-full-image.sh << 'EOF'
#!/bin/bash

# Full SD Card Image Backup
BACKUP_DIR="/mnt/nas-backup/rpi-backups/$(hostname)"
DATE=$(date +%Y%m%d_%H%M%S)
HOSTNAME=$(hostname)

echo "Starting full SD card image backup..."

# Create compressed image using dd and pigz
echo "Creating compressed disk image..."
dd if=/dev/mmcblk0 bs=1M status=progress | \
    pigz -1 > "$BACKUP_DIR/full-images/${HOSTNAME}_${DATE}.img.gz"

if [ $? -eq 0 ]; then
    echo "✓ Full backup completed: ${HOSTNAME}_${DATE}.img.gz"
    
    # Keep only last 3 full backups to save space
    cd "$BACKUP_DIR/full-images"
    ls -t ${HOSTNAME}_*.img.gz | tail -n +4 | xargs -r rm
    
    echo "✓ Old backups cleaned up"
else
    echo "✗ Backup failed!"
    exit 1
fi
EOF

# 2. Incremental System Backup Script
cat > /usr/local/bin/backup-incremental.sh << 'EOF'
#!/bin/bash

# Incremental System Backup using rsync
BACKUP_DIR="/mnt/nas-backup/rpi-backups/$(hostname)"
DATE=$(date +%Y%m%d_%H%M%S)
HOSTNAME=$(hostname)

echo "Starting incremental system backup..."

# Create directories
mkdir -p "$BACKUP_DIR/incremental/current"
mkdir -p "$BACKUP_DIR/incremental/snapshots"

# Backup system files with rsync
rsync -avHAXS --delete \
    --exclude='/dev/*' \
    --exclude='/proc/*' \
    --exclude='/sys/*' \
    --exclude='/tmp/*' \
    --exclude='/run/*' \
    --exclude='/mnt/*' \
    --exclude='/media/*' \
    --exclude='/lost+found' \
    --exclude='/var/log/journal/*' \
    --exclude='/var/cache/*' \
    --exclude='/var/tmp/*' \
    --exclude='/home/*/.cache/*' \
    --exclude='/root/.cache/*' \
    --link-dest="$BACKUP_DIR/incremental/current" \
    / "$BACKUP_DIR/incremental/snapshots/backup_$DATE"

if [ $? -eq 0 ]; then
    # Update current symlink
    rm -f "$BACKUP_DIR/incremental/current"
    ln -s "snapshots/backup_$DATE" "$BACKUP_DIR/incremental/current"
    
    echo "✓ Incremental backup completed: backup_$DATE"
    
    # Keep only last 30 incremental backups
    cd "$BACKUP_DIR/incremental/snapshots"
    ls -t backup_* | tail -n +31 | xargs -r rm -rf
    
    echo "✓ Old incremental backups cleaned up"
else
    echo "✗ Incremental backup failed!"
    exit 1
fi
EOF

# 3. Application Data Backup Script
cat > /usr/local/bin/backup-app-data.sh << 'EOF'
#!/bin/bash

# Application Data Backup (Garage Controller specific)
BACKUP_DIR="/mnt/nas-backup/rpi-backups/$(hostname)"
DATE=$(date +%Y%m%d_%H%M%S)
APP_BACKUP_DIR="$BACKUP_DIR/system-files/$DATE"

echo "Starting application data backup..."

mkdir -p "$APP_BACKUP_DIR"

# Backup garage controller files
if [ -d "/home/$(logname)/garage-controller" ]; then
    echo "Backing up garage controller..."
    tar -czf "$APP_BACKUP_DIR/garage-controller.tar.gz" \
        -C "/home/$(logname)" garage-controller
fi

# Backup databases
if [ -f "/home/$(logname)/garage-controller/users.db" ]; then
    echo "Backing up database..."
    cp "/home/$(logname)/garage-controller/users.db" \
       "$BACKUP_DIR/database/users_$DATE.db"
    
    # Keep last 100 database backups
    cd "$BACKUP_DIR/database"
    ls -t users_*.db | tail -n +101 | xargs -r rm
fi

# Backup system configuration
echo "Backing up system config..."
tar -czf "$APP_BACKUP_DIR/system-config.tar.gz" \
    /etc/systemd/system/garage-controller.* \
    /etc/crontab \
    /etc/fstab \
    /etc/hostname \
    /etc/hosts \
    /boot/config.txt \
    /etc/dhcpcd.conf \
    /etc/wpa_supplicant/wpa_supplicant.conf 2>/dev/null || true

# Backup user data
echo "Backing up user data..."
tar -czf "$APP_BACKUP_DIR/user-data.tar.gz" \
    /home/*/.*rc \
    /home/*/.ssh \
    /home/*/.profile \
    /root/.ssh 2>/dev/null || true

echo "✓ Application data backup completed: $DATE"

# Keep only last 10 system file backups
cd "$BACKUP_DIR/system-files"
ls -t | tail -n +11 | xargs -r rm -rf

echo "✓ Old application backups cleaned up"
EOF

# 4. Master backup script
cat > /usr/local/bin/backup-master.sh << 'EOF'
#!/bin/bash

# Master Backup Script - Choose backup type
echo "Raspberry Pi Backup System"
echo "=========================="
echo "1) Quick incremental backup (daily)"
echo "2) Full system backup (weekly)"
echo "3) Application data only (hourly)"
echo "4) Full SD card image (monthly)"
echo ""

if [ "$1" ]; then
    CHOICE="$1"
else
    read -p "Choose backup type (1-4): " CHOICE
fi

case $CHOICE in
    1|incremental)
        /usr/local/bin/backup-incremental.sh
        ;;
    2|full)
        /usr/local/bin/backup-incremental.sh
        /usr/local/bin/backup-app-data.sh
        ;;
    3|app)
        /usr/local/bin/backup-app-data.sh
        ;;
    4|image)
        /usr/local/bin/backup-full-image.sh
        ;;
    *)
        echo "Invalid choice"
        exit 1
        ;;
esac
EOF

# Make scripts executable
chmod +x /usr/local/bin/backup-*.sh

print_success "Backup scripts created"

# Setup automated backups with cron
print_info "Setting up automated backups..."

# Add cron jobs
(crontab -l 2>/dev/null; cat << 'EOF'
# Raspberry Pi Automated Backups
# Application data backup every 6 hours
0 */6 * * * /usr/local/bin/backup-master.sh app >> /var/log/backup.log 2>&1

# Incremental backup daily at 2 AM
0 2 * * * /usr/local/bin/backup-master.sh incremental >> /var/log/backup.log 2>&1

# Full system backup weekly on Sunday at 3 AM
0 3 * * 0 /usr/local/bin/backup-master.sh full >> /var/log/backup.log 2>&1

# Full SD image backup monthly on 1st at 4 AM
0 4 1 * * /usr/local/bin/backup-master.sh image >> /var/log/backup.log 2>&1
EOF
) | crontab -

print_success "Automated backup schedule created"

# Create restore documentation
cat > /usr/local/bin/restore-help.txt << EOF
Raspberry Pi Restore Guide
=========================

1. RESTORE FROM FULL SD IMAGE:
   - Flash .img.gz file to new SD card using:
     gunzip -c backup.img.gz | dd of=/dev/sdX bs=1M status=progress

2. RESTORE INCREMENTAL BACKUP:
   - Mount backup location
   - Use rsync to restore files:
     rsync -avHAXS /mnt/nas-backup/rpi-backups/hostname/incremental/current/ /

3. RESTORE APPLICATION DATA:
   - Extract system-files backup:
     tar -xzf system-config.tar.gz -C /
     tar -xzf garage-controller.tar.gz -C /home/username/
   - Restore database:
     cp users_DATE.db /home/username/garage-controller/users.db

4. RESTORE SYSTEM CONFIGURATION:
   - Restore from system-config.tar.gz
   - Restart services: systemctl daemon-reload && systemctl restart garage-controller

BACKUP LOCATIONS:
- Full Images: $BACKUP_DIR/full-images/
- Incremental: $BACKUP_DIR/incremental/
- App Data: $BACKUP_DIR/system-files/
- Database: $BACKUP_DIR/database/

MANUAL BACKUP COMMANDS:
- Full backup: sudo /usr/local/bin/backup-master.sh full
- Quick backup: sudo /usr/local/bin/backup-master.sh app
- Image backup: sudo /usr/local/bin/backup-master.sh image

LOG FILE: /var/log/backup.log
EOF

# Test initial backup
print_info "Running initial backup test..."
if /usr/local/bin/backup-master.sh app; then
    print_success "Initial backup test successful!"
else
    print_warning "Initial backup test failed - check configuration"
fi

# Show summary
echo ""
print_success "Backup system setup complete!"
echo "=================================="
echo "NAS Mount Point: $MOUNT_POINT"
echo "Backup Directory: $BACKUP_DIR"
echo "Backup Schedule:"
echo "  - Application data: Every 6 hours"
echo "  - Incremental: Daily at 2 AM"
echo "  - Full system: Weekly on Sunday at 3 AM"
echo "  - SD card image: Monthly on 1st at 4 AM"
echo ""
echo "Manual Commands:"
echo "  - Quick backup: sudo backup-master.sh app"
echo "  - Full backup: sudo backup-master.sh full"
echo "  - View logs: tail -f /var/log/backup.log"
echo "  - Restore help: cat /usr/local/bin/restore-help.txt"
echo ""
print_info "Backup will start automatically according to schedule"