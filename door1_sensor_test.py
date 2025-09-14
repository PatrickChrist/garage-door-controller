#!/usr/bin/env python3
"""
Door 1 Sensor Voltage Test
Test different pull resistor configurations for weak voltage signal
"""
import platform
import os
import time

# GPIO handling for different Pi models
try:
    # Check if we're on a Raspberry Pi 5
    with open('/proc/device-tree/model', 'r') as f:
        pi_model = f.read().strip()
    
    if 'Raspberry Pi 5' in pi_model:
        print(f"Detected {pi_model} - using lgpio")
        import lgpio as GPIO
        GPIO_LIB = 'lgpio'
    else:
        print(f"Detected {pi_model} - using RPi.GPIO")
        import RPi.GPIO as GPIO
        GPIO_LIB = 'RPi.GPIO'
except (ImportError, FileNotFoundError):
    print("Using mock GPIO for development")
    from mock_rpi import GPIO
    GPIO_LIB = 'mock'

def test_door1_sensor():
    """Test Door 1 sensor with different configurations"""
    print("=== Door 1 Sensor Voltage Test ===\n")
    
    DOOR1_SENSOR = 17   # GPIO 17 for door 1 sensor
    gpio_handle = None
    
    try:
        if GPIO_LIB == 'lgpio':
            gpio_handle = GPIO.gpiochip_open(0)
            print(f"GPIO handle: {gpio_handle}")
        else:
            GPIO.setmode(GPIO.BCM)
            GPIO.setwarnings(False)
        
        # Test 1: Pull-up configuration (original)
        print("=== Test 1: Pull-up Configuration ===")
        print("Testing with internal pull-up resistor (original setup)")
        
        if GPIO_LIB == 'lgpio':
            try:
                GPIO.gpio_free(gpio_handle, DOOR1_SENSOR)  # Free if already claimed
            except:
                pass
            GPIO.gpio_claim_input(gpio_handle, DOOR1_SENSOR, GPIO.SET_PULL_UP)
        else:
            GPIO.setup(DOOR1_SENSOR, GPIO.IN, pull_up_down=GPIO.PUD_UP)
        
        print("Pull-up readings (HIGH=closed expected):")
        for i in range(10):
            if GPIO_LIB == 'lgpio':
                value = GPIO.gpio_read(gpio_handle, DOOR1_SENSOR)
            else:
                value = GPIO.input(DOOR1_SENSOR)
            
            status = "CLOSED" if value else "OPEN"
            print(f"  Reading {i+1:2d}: GPIO{DOOR1_SENSOR}={value} ({status})")
            time.sleep(0.5)
        
        # Test 2: Pull-down configuration (for weak signals)
        print("\n=== Test 2: Pull-down Configuration ===")
        print("Testing with internal pull-down resistor (for weak signals)")
        
        if GPIO_LIB == 'lgpio':
            GPIO.gpio_free(gpio_handle, DOOR1_SENSOR)
            GPIO.gpio_claim_input(gpio_handle, DOOR1_SENSOR, GPIO.SET_PULL_DOWN)
        else:
            GPIO.setup(DOOR1_SENSOR, GPIO.IN, pull_up_down=GPIO.PUD_DOWN)
        
        print("Pull-down readings (LOW=closed expected for weak signal):")
        for i in range(10):
            if GPIO_LIB == 'lgpio':
                value = GPIO.gpio_read(gpio_handle, DOOR1_SENSOR)
            else:
                value = GPIO.input(DOOR1_SENSOR)
            
            status = "OPEN" if value else "CLOSED"  # Inverted for pull-down
            print(f"  Reading {i+1:2d}: GPIO{DOOR1_SENSOR}={value} ({status})")
            time.sleep(0.5)
        
        # Test 3: No pull resistor (floating)
        print("\n=== Test 3: No Pull Resistor (Floating) ===")
        print("Testing without internal pull resistors")
        
        if GPIO_LIB == 'lgpio':
            GPIO.gpio_free(gpio_handle, DOOR1_SENSOR)
            GPIO.gpio_claim_input(gpio_handle, DOOR1_SENSOR, 0)  # No pull
        else:
            GPIO.setup(DOOR1_SENSOR, GPIO.IN, pull_up_down=GPIO.PUD_OFF)
        
        print("No-pull readings (may be unstable):")
        for i in range(10):
            if GPIO_LIB == 'lgpio':
                value = GPIO.gpio_read(gpio_handle, DOOR1_SENSOR)
            else:
                value = GPIO.input(DOOR1_SENSOR)
            
            print(f"  Reading {i+1:2d}: GPIO{DOOR1_SENSOR}={value}")
            time.sleep(0.5)
        
        # Analysis and recommendations
        print("\n=== Analysis and Recommendations ===")
        print("1. If sensor gives weak voltage when closed:")
        print("   - Use pull-down resistor (Test 2)")
        print("   - Closed door = LOW (0V + weak signal = still LOW)")
        print("   - Open door = HIGH (3.3V pull-down overcome by disconnect)")
        print("")
        print("2. If sensor gives strong voltage when closed:")
        print("   - Use pull-up resistor (Test 1)")
        print("   - Closed door = HIGH (strong signal overcomes pull-up)")
        print("   - Open door = LOW (3.3V pull-up with disconnect)")
        print("")
        print("3. Physical wiring check:")
        print("   - Measure actual voltage with multimeter")
        print("   - Door closed: should be close to 0V or 3.3V")
        print("   - Door open: should be opposite of closed")
        print("")
        print("4. Alternative solutions:")
        print("   - Add external pull-down resistor (10kΩ)")
        print("   - Use voltage divider circuit")
        print("   - Try different GPIO pin")
        
    except Exception as e:
        print(f"ERROR: {e}")
        import traceback
        traceback.print_exc()
    
    finally:
        # Cleanup
        if GPIO_LIB == 'lgpio' and gpio_handle is not None:
            try:
                GPIO.gpiochip_close(gpio_handle)
            except:
                pass
        elif GPIO_LIB == 'RPi.GPIO':
            GPIO.cleanup()
        print(f"\nGPIO cleanup complete")

if __name__ == "__main__":
    print("Door 1 Sensor Voltage Test")
    print("This script tests different pull resistor configurations")
    print("Run with: sudo python3 door1_sensor_test.py")
    print("Manually open/close Door 1 during each test phase")
    print("=" * 60)
    
    try:
        test_door1_sensor()
    except KeyboardInterrupt:
        print("\n\nScript interrupted by user")
    except Exception as e:
        print(f"\nUnexpected error: {e}")
        import traceback
        traceback.print_exc()