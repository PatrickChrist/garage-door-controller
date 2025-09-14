#!/usr/bin/env python3
"""
Door 1 Specific Debug Script
Compare Door 1 vs Door 2 functionality
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

def debug_door1():
    """Debug Door 1 specific issues"""
    print("=== Door 1 Debug Script ===\n")
    
    # Current pin assignments
    DOOR1_RELAY = 26    # GPIO 26 for door 1 relay
    DOOR2_RELAY = 12    # GPIO 12 for door 2 relay (working)
    DOOR1_SENSOR = 4    # GPIO 4 for door 1 sensor (shared with door 2)
    DOOR2_SENSOR = 4    # GPIO 4 for door 2 sensor (shared sensor)
    
    gpio_handle = None
    
    try:
        if GPIO_LIB == 'lgpio':
            gpio_handle = GPIO.gpiochip_open(0)
            print(f"GPIO handle: {gpio_handle}")
            
            # Setup pins
            print("\nSetting up GPIO pins...")
            
            # Relay pins
            GPIO.gpio_claim_output(gpio_handle, DOOR1_RELAY, 1)  # HIGH = relay off
            GPIO.gpio_claim_output(gpio_handle, DOOR2_RELAY, 1)  # HIGH = relay off
            
            # Sensor pins
            GPIO.gpio_claim_input(gpio_handle, DOOR1_SENSOR, GPIO.SET_PULL_UP)
            GPIO.gpio_claim_input(gpio_handle, DOOR2_SENSOR, GPIO.SET_PULL_UP)
            
        else:
            GPIO.setmode(GPIO.BCM)
            GPIO.setwarnings(False)
            
            # Relay pins
            GPIO.setup(DOOR1_RELAY, GPIO.OUT, initial=GPIO.HIGH)  # HIGH = relay off
            GPIO.setup(DOOR2_RELAY, GPIO.OUT, initial=GPIO.HIGH)  # HIGH = relay off
            
            # Sensor pins
            GPIO.setup(DOOR1_SENSOR, GPIO.IN, pull_up_down=GPIO.PUD_UP)
            GPIO.setup(DOOR2_SENSOR, GPIO.IN, pull_up_down=GPIO.PUD_UP)
        
        # Test 1: Compare sensor readings
        print("\n=== Test 1: Sensor Comparison ===")
        for i in range(10):
            if GPIO_LIB == 'lgpio':
                sensor1 = GPIO.gpio_read(gpio_handle, DOOR1_SENSOR)
                sensor2 = GPIO.gpio_read(gpio_handle, DOOR2_SENSOR)
            else:
                sensor1 = GPIO.input(DOOR1_SENSOR)
                sensor2 = GPIO.input(DOOR2_SENSOR)
            
            # Convert to door status (HIGH = closed, so invert)
            door1_status = "CLOSED" if sensor1 else "OPEN"
            door2_status = "CLOSED" if sensor2 else "OPEN" 
            
            print(f"Reading {i+1:2d}: Door1 GPIO{DOOR1_SENSOR}={sensor1} ({door1_status}) | Door2 GPIO{DOOR2_SENSOR}={sensor2} ({door2_status})")
            time.sleep(0.5)
        
        # Test 2: Individual relay tests
        print(f"\n=== Test 2: Individual Relay Tests ===")
        
        # Test Door 1 relay multiple times
        print("Testing Door 1 relay (GPIO 26):")
        for i in range(3):
            print(f"  Cycle {i+1}: Activating relay (LOW)...")
            if GPIO_LIB == 'lgpio':
                GPIO.gpio_write(gpio_handle, DOOR1_RELAY, 0)  # LOW = activate
            else:
                GPIO.output(DOOR1_RELAY, GPIO.LOW)
            
            time.sleep(1.5)  # Hold for 1.5 seconds
            
            print(f"  Cycle {i+1}: Deactivating relay (HIGH)...")
            if GPIO_LIB == 'lgpio':
                GPIO.gpio_write(gpio_handle, DOOR1_RELAY, 1)  # HIGH = deactivate
            else:
                GPIO.output(DOOR1_RELAY, GPIO.HIGH)
            
            time.sleep(2)  # Wait between cycles
        
        # Test Door 2 relay (known working)
        print("Testing Door 2 relay (GPIO 12) - known working:")
        for i in range(1):
            print(f"  Cycle {i+1}: Activating relay (LOW)...")
            if GPIO_LIB == 'lgpio':
                GPIO.gpio_write(gpio_handle, DOOR2_RELAY, 0)  # LOW = activate
            else:
                GPIO.output(DOOR2_RELAY, GPIO.LOW)
            
            time.sleep(1.5)  # Hold for 1.5 seconds
            
            print(f"  Cycle {i+1}: Deactivating relay (HIGH)...")
            if GPIO_LIB == 'lgpio':
                GPIO.gpio_write(gpio_handle, DOOR2_RELAY, 1)  # HIGH = deactivate
            else:
                GPIO.output(DOOR2_RELAY, GPIO.HIGH)
            
            time.sleep(2)
        
        # Test 3: Pin state verification
        print(f"\n=== Test 3: Pin State Verification ===")
        
        # Check relay pin states
        if GPIO_LIB == 'lgpio':
            door1_relay_state = GPIO.gpio_read(gpio_handle, DOOR1_RELAY)
            door2_relay_state = GPIO.gpio_read(gpio_handle, DOOR2_RELAY)
        else:
            door1_relay_state = GPIO.input(DOOR1_RELAY)
            door2_relay_state = GPIO.input(DOOR2_RELAY)
        
        print(f"Door 1 relay (GPIO {DOOR1_RELAY}): {door1_relay_state} ({'OFF' if door1_relay_state else 'ON'})")
        print(f"Door 2 relay (GPIO {DOOR2_RELAY}): {door2_relay_state} ({'OFF' if door2_relay_state else 'ON'})")
        
        # Test 4: Alternative GPIO pins for Door 1
        print(f"\n=== Test 4: Alternative GPIO Pins ===")
        alternative_pins = [5, 6, 13, 16, 17, 20, 21, 22, 27]
        print("Testing alternative pins for Door 1 sensor:")
        
        for pin in alternative_pins:
            try:
                if GPIO_LIB == 'lgpio':
                    GPIO.gpio_claim_input(gpio_handle, pin, GPIO.SET_PULL_UP)
                    value = GPIO.gpio_read(gpio_handle, pin)
                    print(f"  GPIO {pin:2d}: Available, value={value}")
                    GPIO.gpio_free(gpio_handle, pin)
                else:
                    GPIO.setup(pin, GPIO.IN, pull_up_down=GPIO.PUD_UP)
                    value = GPIO.input(pin)
                    print(f"  GPIO {pin:2d}: Available, value={value}")
            except Exception as e:
                print(f"  GPIO {pin:2d}: ERROR - {e}")
        
        # Test 5: Wiring validation suggestions
        print(f"\n=== Test 5: Wiring Validation ===")
        print("Check the following:")
        print(f"1. Door 1 relay wiring:")
        print(f"   - Relay control wire connected to GPIO 26 (Physical pin 37)")
        print(f"   - Relay power/ground connected properly")
        print(f"   - Relay should click when activated")
        print(f"")
        print(f"2. Door 1 sensor wiring:")
        print(f"   - Sensor wire connected to GPIO 4 (Physical pin 7) - SHARED WITH DOOR 2")
        print(f"   - Sensor ground connected to GND")
        print(f"   - Sensor should read HIGH when door is closed")
        print(f"")
        print(f"3. Compare with working Door 2:")
        print(f"   - Door 2 relay: GPIO 12 (Physical pin 32)")
        print(f"   - Door 2 sensor: GPIO 4 (Physical pin 7) - SHARED SENSOR")
        print(f"")
        print(f"4. Test with multimeter:")
        print(f"   - Measure voltage on GPIO 26 (should be 3.3V normally, 0V when activated)")
        print(f"   - Measure continuity in relay circuit")
        
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
    print("This script will test Door 1 specific functionality")
    print("Make sure to run with: sudo python3 door1_debug.py")
    print("Press Ctrl+C to stop at any time")
    print("=" * 50)
    
    try:
        debug_door1()
    except KeyboardInterrupt:
        print("\n\nScript interrupted by user")
    except Exception as e:
        print(f"\nUnexpected error: {e}")
        import traceback
        traceback.print_exc()