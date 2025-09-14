#!/usr/bin/env python3
"""
Check GPIO pin usage and conflicts
"""
import os
import subprocess

def check_gpio_usage():
    """Check which GPIO pins are in use"""
    print("=== GPIO Pin Usage Check ===\n")
    
    # Check if running on Raspberry Pi
    try:
        with open('/proc/device-tree/model', 'r') as f:
            pi_model = f.read().strip()
        print(f"Detected: {pi_model}")
    except:
        print("Not running on Raspberry Pi")
        return
    
    # Check for GPIO exports
    print("\n=== Exported GPIO pins ===")
    gpio_export_path = "/sys/class/gpio"
    if os.path.exists(gpio_export_path):
        exported_pins = []
        for item in os.listdir(gpio_export_path):
            if item.startswith('gpio'):
                pin_num = item[4:]  # Remove 'gpio' prefix
                exported_pins.append(pin_num)
        
        if exported_pins:
            print(f"Exported pins: {', '.join(exported_pins)}")
            for pin in exported_pins:
                pin_path = f"{gpio_export_path}/gpio{pin}"
                try:
                    with open(f"{pin_path}/direction", 'r') as f:
                        direction = f.read().strip()
                    with open(f"{pin_path}/value", 'r') as f:
                        value = f.read().strip()
                    print(f"  GPIO {pin}: direction={direction}, value={value}")
                except:
                    print(f"  GPIO {pin}: Could not read details")
        else:
            print("No GPIO pins currently exported")
    
    # Check device tree overlays
    print("\n=== Device Tree Overlays ===")
    try:
        with open('/boot/config.txt', 'r') as f:
            config_content = f.read()
        
        overlays = []
        for line in config_content.split('\n'):
            line = line.strip()
            if line.startswith('dtoverlay=') and not line.startswith('#'):
                overlays.append(line)
        
        if overlays:
            print("Active overlays:")
            for overlay in overlays:
                print(f"  {overlay}")
        else:
            print("No custom overlays found")
    except Exception as e:
        print(f"Could not read /boot/config.txt: {e}")
    
    # Check for running processes using GPIO
    print("\n=== Processes using GPIO ===")
    try:
        # Check for processes with gpio in the name
        result = subprocess.run(['pgrep', '-f', 'gpio'], capture_output=True, text=True)
        if result.stdout.strip():
            pids = result.stdout.strip().split('\n')
            for pid in pids:
                try:
                    cmd_result = subprocess.run(['ps', '-p', pid, '-o', 'comm='], capture_output=True, text=True)
                    if cmd_result.stdout.strip():
                        print(f"  PID {pid}: {cmd_result.stdout.strip()}")
                except:
                    pass
        else:
            print("No GPIO-related processes found")
    except:
        print("Could not check for GPIO processes")
    
    # Check systemd services
    print("\n=== GPIO-related systemd services ===")
    try:
        result = subprocess.run(['systemctl', 'list-units', '--type=service', '--state=active'], 
                              capture_output=True, text=True)
        gpio_services = []
        for line in result.stdout.split('\n'):
            if 'gpio' in line.lower() or 'garage' in line.lower():
                gpio_services.append(line.strip())
        
        if gpio_services:
            for service in gpio_services:
                print(f"  {service}")
        else:
            print("No GPIO-related services found")
    except:
        print("Could not check systemd services")
    
    # Hardware-specific pin mappings
    print("\n=== Pin Mappings (BCM numbering) ===")
    print("Physical Pin | BCM GPIO | Current Usage")
    print("-" * 40)
    pin_map = {
        7: 4,    # GPIO 4
        11: 17,  # Not GPIO 11!
        13: 27,  # Not GPIO 11!
        15: 22,  # Not GPIO 11!
        16: 23,  # GPIO 23
        18: 24,  # GPIO 24
        19: 10,  # GPIO 10
        21: 9,   # GPIO 9 (SPI MISO)
        23: 11,  # GPIO 11 (SPI CLK) - This might be the issue!
        24: 8,   # GPIO 8 (SPI CE0)
        26: 7,   # GPIO 7 (SPI CE1)
        29: 5,   # GPIO 5
        31: 6,   # GPIO 6
        32: 12,  # GPIO 12
        33: 13,  # GPIO 13
        35: 19,  # GPIO 19
        36: 16,  # GPIO 16
        37: 26,  # GPIO 26
        38: 20,  # GPIO 20
        40: 21   # GPIO 21
    }
    
    # Check which physical pin corresponds to GPIO 11
    gpio11_physical = None
    for phys, bcm in pin_map.items():
        if bcm == 11:
            gpio11_physical = phys
            break
    
    print(f"Physical Pin 23 | BCM GPIO 11 | SPI CLK - MAY BE RESERVED!")
    if gpio11_physical:
        print(f"GPIO 11 is on physical pin {gpio11_physical}")
    
    print("\nAlternative GPIO pins to try:")
    safe_pins = [5, 6, 13, 16, 17, 20, 21, 22, 26, 27]
    for pin in safe_pins:
        print(f"  GPIO {pin}")

if __name__ == "__main__":
    check_gpio_usage()