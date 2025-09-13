#!/bin/bash

# System Requirements Validation Script
# Run with: ./validate-system.sh

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Validation results
CHECKS_PASSED=0
CHECKS_FAILED=0
CHECKS_WARNING=0

print_header() {
    echo
    echo "=========================================="
    echo "  Garage Door Controller - System Validation"
    echo "=========================================="
    echo
}

print_check() {
    echo -e "${BLUE}[CHECK]${NC} $1"
}

print_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((CHECKS_PASSED++))
}

print_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((CHECKS_FAILED++))
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
    ((CHECKS_WARNING++))
}

check_raspberry_pi() {
    print_check "Checking if running on Raspberry Pi..."
    
    if grep -q "Raspberry Pi" /proc/device-tree/model 2>/dev/null; then
        PI_MODEL=$(cat /proc/device-tree/model | tr -d '\0')
        print_pass "Running on $PI_MODEL"
    elif grep -q "BCM" /proc/cpuinfo; then
        print_warn "Running on BCM-based system (possibly Pi)"
    else
        print_fail "Not running on Raspberry Pi - GPIO functionality will not work"
    fi
}

check_os_version() {
    print_check "Checking operating system..."
    
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        print_pass "OS: $PRETTY_NAME"
        
        # Check for Raspberry Pi OS specifically
        if [[ "$NAME" == *"Raspbian"* ]] || [[ "$NAME" == *"Raspberry Pi OS"* ]]; then
            print_pass "Running Raspberry Pi OS (recommended)"
        else
            print_warn "Not running Raspberry Pi OS - some features may not work optimally"
        fi
    else
        print_fail "Cannot determine operating system"
    fi
}

check_python_version() {
    print_check "Checking Python version..."
    
    if command -v python3 &> /dev/null; then
        PYTHON_VERSION=$(python3 --version | cut -d' ' -f2)
        PYTHON_MAJOR=$(echo $PYTHON_VERSION | cut -d'.' -f1)
        PYTHON_MINOR=$(echo $PYTHON_VERSION | cut -d'.' -f2)
        
        if [ "$PYTHON_MAJOR" -eq 3 ] && [ "$PYTHON_MINOR" -ge 8 ]; then
            print_pass "Python $PYTHON_VERSION (compatible)"
        else
            print_fail "Python $PYTHON_VERSION (requires Python 3.8+)"
        fi
    else
        print_fail "Python 3 not installed"
    fi
}

check_pip() {
    print_check "Checking pip..."
    
    if command -v pip3 &> /dev/null; then
        PIP_VERSION=$(pip3 --version | cut -d' ' -f2)
        print_pass "pip $PIP_VERSION installed"
    else
        print_fail "pip3 not installed"
    fi
}

check_venv() {
    print_check "Checking virtual environment support..."
    
    if python3 -m venv --help &> /dev/null; then
        print_pass "Python venv module available"
    else
        print_fail "Python venv module not available"
    fi
}

check_gpio_access() {
    print_check "Checking GPIO access..."
    
    if [ -d "/sys/class/gpio" ]; then
        print_pass "GPIO sysfs interface available"
        
        # Check if user is in gpio group
        if groups | grep -q gpio; then
            print_pass "User is in gpio group"
        else
            print_warn "User not in gpio group - will need to add with: sudo usermod -a -G gpio \$USER"
        fi
    else
        print_fail "GPIO interface not available"
    fi
}

check_memory() {
    print_check "Checking system memory..."
    
    TOTAL_MEM=$(free -m | awk 'NR==2{printf "%.0f", $2}')
    
    if [ "$TOTAL_MEM" -ge 512 ]; then
        print_pass "System memory: ${TOTAL_MEM}MB (sufficient)"
    else
        print_warn "System memory: ${TOTAL_MEM}MB (may be insufficient for optimal performance)"
    fi
}

check_disk_space() {
    print_check "Checking disk space..."
    
    AVAILABLE_SPACE=$(df / | tail -1 | awk '{print $4}')
    AVAILABLE_MB=$((AVAILABLE_SPACE / 1024))
    
    if [ "$AVAILABLE_MB" -ge 1024 ]; then
        print_pass "Available disk space: ${AVAILABLE_MB}MB (sufficient)"
    else
        print_warn "Available disk space: ${AVAILABLE_MB}MB (may be insufficient)"
    fi
}

check_network() {
    print_check "Checking network connectivity..."
    
    if ping -c 1 8.8.8.8 &> /dev/null; then
        print_pass "Internet connectivity available"
    else
        print_fail "No internet connectivity - required for installation"
    fi
}

check_systemd() {
    print_check "Checking systemd..."
    
    if command -v systemctl &> /dev/null; then
        print_pass "systemd available"
    else
        print_fail "systemd not available - service management will not work"
    fi
}

check_gpio_pins() {
    print_check "Checking GPIO pins availability..."
    
    # Check if GPIO pins are not already in use
    PINS_TO_CHECK=(18 19 23 24)
    PIN_CONFLICTS=0
    
    for pin in "${PINS_TO_CHECK[@]}"; do
        if [ -d "/sys/class/gpio/gpio${pin}" ]; then
            print_warn "GPIO ${pin} already exported - may be in use by another application"
            ((PIN_CONFLICTS++))
        fi
    done
    
    if [ $PIN_CONFLICTS -eq 0 ]; then
        print_pass "All required GPIO pins (9, 12, 4) are available"
    fi
}

check_ports() {
    print_check "Checking port availability..."
    
    PORTS_TO_CHECK=(80 8000)
    
    for port in "${PORTS_TO_CHECK[@]}"; do
        if netstat -tuln 2>/dev/null | grep -q ":${port} "; then
            print_warn "Port ${port} is already in use"
        else
            print_pass "Port ${port} is available"
        fi
    done
}

check_hardware_interfaces() {
    print_check "Checking hardware interfaces..."
    
    # Check for I2C
    if [ -c "/dev/i2c-1" ]; then
        print_pass "I2C interface available"
    else
        print_warn "I2C interface not available (may need to enable in raspi-config)"
    fi
    
    # Check for SPI
    if [ -c "/dev/spidev0.0" ]; then
        print_pass "SPI interface available"
    else
        print_warn "SPI interface not available (not required for basic functionality)"
    fi
}

check_dependencies() {
    print_check "Checking system dependencies..."
    
    REQUIRED_PACKAGES=("git" "curl" "wget" "build-essential")
    MISSING_PACKAGES=()
    
    for package in "${REQUIRED_PACKAGES[@]}"; do
        if ! dpkg -l | grep -q "^ii  ${package} "; then
            MISSING_PACKAGES+=("$package")
        fi
    done
    
    if [ ${#MISSING_PACKAGES[@]} -eq 0 ]; then
        print_pass "All required packages are installed"
    else
        print_fail "Missing packages: ${MISSING_PACKAGES[*]}"
        echo "       Install with: sudo apt install ${MISSING_PACKAGES[*]}"
    fi
}

print_summary() {
    echo
    echo "=========================================="
    echo "  Validation Summary"
    echo "=========================================="
    echo
    echo -e "${GREEN}Checks Passed:${NC} $CHECKS_PASSED"
    echo -e "${YELLOW}Warnings:${NC} $CHECKS_WARNING"
    echo -e "${RED}Checks Failed:${NC} $CHECKS_FAILED"
    echo
    
    if [ $CHECKS_FAILED -eq 0 ]; then
        echo -e "${GREEN}✅ System appears ready for installation!${NC}"
        if [ $CHECKS_WARNING -gt 0 ]; then
            echo -e "${YELLOW}⚠️  Please review warnings above before proceeding.${NC}"
        fi
    else
        echo -e "${RED}❌ System is not ready for installation.${NC}"
        echo -e "${RED}Please address the failed checks above before proceeding.${NC}"
    fi
    
    echo
    echo "Run the installation script with:"
    echo "  curl -sSL <your-install-script-url> | bash"
    echo "Or:"
    echo "  ./install-raspberrypi.sh"
}

# Main execution
main() {
    print_header
    
    check_raspberry_pi
    check_os_version
    check_python_version
    check_pip
    check_venv
    check_gpio_access
    check_memory
    check_disk_space
    check_network
    check_systemd
    check_gpio_pins
    check_ports
    check_hardware_interfaces
    check_dependencies
    
    print_summary
}

# Run validation
main "$@"