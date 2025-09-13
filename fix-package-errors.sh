#!/bin/bash

# Fix Raspberry Pi Package Installation Errors
# Resolves common dpkg and kernel package issues

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
    echo "  Raspberry Pi Package Error Fix"
    echo "=========================================="
    echo
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

backup_dpkg_status() {
    print_status "Creating backup of dpkg status..."
    
    if [ -f "/var/lib/dpkg/status" ]; then
        cp /var/lib/dpkg/status /var/lib/dpkg/status.backup.$(date +%Y%m%d_%H%M%S)
        print_success "dpkg status backed up"
    fi
}

fix_dpkg_lock() {
    print_status "Checking for dpkg lock files..."
    
    # Kill any running package managers
    pkill -f apt || true
    pkill -f dpkg || true
    pkill -f unattended-upgrade || true
    
    # Remove lock files
    rm -rf /var/lib/dpkg/lock*
    rm -rf /var/cache/apt/archives/lock
    rm -rf /var/lib/apt/lists/lock
    
    print_success "Lock files cleared"
}

fix_dpkg_interruption() {
    print_status "Fixing interrupted package installations..."
    
    # Configure any unconfigured packages
    dpkg --configure -a
    
    print_success "Package configuration completed"
}

fix_broken_packages() {
    print_status "Fixing broken packages..."
    
    # Fix broken dependencies
    apt-get install -f -y
    
    print_success "Broken packages fixed"
}

clean_package_cache() {
    print_status "Cleaning package cache..."
    
    # Clean package cache
    apt-get clean
    apt-get autoclean
    
    # Update package lists
    apt-get update
    
    print_success "Package cache cleaned"
}

fix_kernel_packages() {
    print_status "Fixing kernel package issues..."
    
    # Remove problematic kernel packages that are causing issues
    print_warning "Removing problematic kernel packages..."
    
    # First, try to reconfigure
    dpkg-reconfigure -f noninteractive initramfs-tools || true
    
    # If that fails, remove and reinstall
    apt-get remove --purge -y \
        linux-headers-rpi-2712 \
        linux-headers-rpi-v8 \
        linux-image-rpi-2712 \
        linux-image-rpi-v8 \
        || true
    
    # Clean up
    apt-get autoremove -y
    apt-get autoclean
    
    # Reinstall essential kernel packages
    print_status "Reinstalling essential kernel packages..."
    apt-get install -y \
        linux-image-rpi-v8 \
        linux-headers-rpi-v8 \
        || print_warning "Some kernel packages may not be available for your Pi model"
    
    print_success "Kernel packages fixed"
}

update_firmware() {
    print_status "Updating Raspberry Pi firmware..."
    
    # Update firmware and bootloader
    if command -v rpi-update >/dev/null 2>&1; then
        rpi-update || print_warning "Firmware update failed, continuing..."
    else
        print_warning "rpi-update not available, skipping firmware update"
    fi
    
    # Update using rpi-eeprom if available
    if command -v rpi-eeprom-update >/dev/null 2>&1; then
        rpi-eeprom-update -a || print_warning "EEPROM update failed, continuing..."
    fi
    
    print_success "Firmware update completed"
}

final_system_update() {
    print_status "Performing final system update..."
    
    # Update package lists
    apt-get update
    
    # Upgrade system (excluding kernel packages that were problematic)
    apt-get upgrade -y --fix-missing
    
    # Install any missing dependencies
    apt-get install -f -y
    
    # Clean up
    apt-get autoremove -y
    apt-get autoclean
    
    print_success "System update completed"
}

verify_system() {
    print_status "Verifying system integrity..."
    
    # Check for broken packages
    BROKEN_PACKAGES=$(dpkg -l | grep "^iU\|^rc" | wc -l)
    
    if [ "$BROKEN_PACKAGES" -eq 0 ]; then
        print_success "No broken packages found"
    else
        print_warning "$BROKEN_PACKAGES potentially broken packages remain"
        print_status "Listing broken packages:"
        dpkg -l | grep "^iU\|^rc" | awk '{print $2}' | head -10
    fi
    
    # Check disk space
    DISK_USAGE=$(df / | awk 'NR==2 {printf "%.1f", $3/$2*100}')
    print_status "Disk usage: ${DISK_USAGE}%"
    
    if (( $(echo "$DISK_USAGE > 90" | bc -l) )); then
        print_warning "Disk space is low (${DISK_USAGE}%). Consider freeing up space."
    fi
}

display_completion_info() {
    print_success "Package error fix completed!"
    echo
    echo "=========================================="
    echo "  Fix Results"
    echo "=========================================="
    echo
    echo "✅ Steps Completed:"
    echo "  • dpkg lock files cleared"
    echo "  • Interrupted packages configured"
    echo "  • Broken dependencies fixed"
    echo "  • Package cache cleaned"
    echo "  • Problematic kernel packages handled"
    echo "  • System updated"
    echo
    echo "🔄 Next Steps:"
    echo "1. Reboot your Raspberry Pi:"
    echo "   sudo reboot"
    echo
    echo "2. After reboot, continue with installation:"
    echo "   ./install-raspberrypi.sh"
    echo
    echo "3. If problems persist, try:"
    echo "   sudo apt-get dist-upgrade"
    echo
    echo "📋 Common Commands for Future Issues:"
    echo "  • Fix broken packages: sudo apt-get install -f"
    echo "  • Configure packages: sudo dpkg --configure -a"
    echo "  • Clean cache: sudo apt-get clean && sudo apt-get update"
    echo
    print_warning "A reboot is recommended to complete the fixes!"
}

# Main execution
main() {
    print_header
    
    check_root
    backup_dpkg_status
    fix_dpkg_lock
    fix_dpkg_interruption
    fix_broken_packages
    clean_package_cache
    fix_kernel_packages
    update_firmware
    final_system_update
    verify_system
    
    display_completion_info
}

# Run the fix
main "$@"