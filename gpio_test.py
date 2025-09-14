#!/usr/bin/env python3
"""
GPIO Test Script for Garage Door Controller
Tests GPIO pins and relay functionality
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

def test_gpio_pins():
    """Test GPIO pin functionality"""
    print(f"\n=== GPIO Test Script ===")
    print(f"GPIO Library: {GPIO_LIB}")
    
    # Pin definitions
    DOOR1_RELAY = 9     # GPIO 9 for door 1 relay
    DOOR2_RELAY = 12    # GPIO 12 for door 2 relay
    DOOR1_SENSOR = 11   # GPIO 11 for door 1 sensor
    DOOR2_SENSOR = 4    # GPIO 4 for door 2 sensor
    
    gpio_handle = None
    
    try:
        if GPIO_LIB == 'lgpio':
            # Initialize lgpio
            gpio_handle = GPIO.gpiochip_open(0)
            print(f"GPIO handle opened: {gpio_handle}")
            
            # Setup relay pins (output, initially HIGH - relay off)
            print(f"\nSetting up relay pins...")
            GPIO.gpio_claim_output(gpio_handle, DOOR1_RELAY, 1)
            GPIO.gpio_claim_output(gpio_handle, DOOR2_RELAY, 1)
            print(f"Door 1 relay (GPIO {DOOR1_RELAY}): Setup complete")
            print(f"Door 2 relay (GPIO {DOOR2_RELAY}): Setup complete")
            
            # Setup sensor pins (input with pull-up)
            print(f"\nSetting up sensor pins...")
            try:
                GPIO.gpio_claim_input(gpio_handle, DOOR1_SENSOR, GPIO.SET_PULL_UP)
                print(f"Door 1 sensor (GPIO {DOOR1_SENSOR}): Setup complete")
            except Exception as e:
                print(f"ERROR setting up Door 1 sensor (GPIO {DOOR1_SENSOR}): {e}")
            
            try:
                GPIO.gpio_claim_input(gpio_handle, DOOR2_SENSOR, GPIO.SET_PULL_UP)
                print(f"Door 2 sensor (GPIO {DOOR2_SENSOR}): Setup complete")
            except Exception as e:
                print(f"ERROR setting up Door 2 sensor (GPIO {DOOR2_SENSOR}): {e}")
                
        else:
            # Traditional RPi.GPIO setup
            GPIO.setmode(GPIO.BCM)
            GPIO.setwarnings(False)
            
            # Setup relay pins (output, initially HIGH - relay off)
            GPIO.setup(DOOR1_RELAY, GPIO.OUT, initial=GPIO.HIGH)
            GPIO.setup(DOOR2_RELAY, GPIO.OUT, initial=GPIO.HIGH)
            print(f"Door 1 relay (GPIO {DOOR1_RELAY}): Setup complete")
            print(f"Door 2 relay (GPIO {DOOR2_RELAY}): Setup complete")
            
            # Setup sensor pins (input with pull-up)
            GPIO.setup(DOOR1_SENSOR, GPIO.IN, pull_up_down=GPIO.PUD_UP)
            GPIO.setup(DOOR2_SENSOR, GPIO.IN, pull_up_down=GPIO.PUD_UP)
            print(f"Door 1 sensor (GPIO {DOOR1_SENSOR}): Setup complete")
            print(f"Door 2 sensor (GPIO {DOOR2_SENSOR}): Setup complete")
        
        # Test sensor readings
        print(f"\n=== Sensor Readings ===")
        for i in range(5):
            if GPIO_LIB == 'lgpio':
                sensor1_raw = GPIO.gpio_read(gpio_handle, DOOR1_SENSOR)
                sensor2_raw = GPIO.gpio_read(gpio_handle, DOOR2_SENSOR)
            else:
                sensor1_raw = GPIO.input(DOOR1_SENSOR)
                sensor2_raw = GPIO.input(DOOR2_SENSOR)
            
            # Invert readings (HIGH = closed)
            sensor1_status = "CLOSED" if sensor1_raw else "OPEN"
            sensor2_status = "CLOSED" if sensor2_raw else "OPEN"
            
            print(f"Reading {i+1}: Door1 sensor={sensor1_raw} ({sensor1_status}), Door2 sensor={sensor2_raw} ({sensor2_status})")
            time.sleep(1)
        
        # Test relay functionality
        print(f"\n=== Relay Test ===")
        print("Testing Door 1 relay...")
        
        if GPIO_LIB == 'lgpio':
            # Activate relay (LOW)
            print("Activating Door 1 relay (LOW)...")
            GPIO.gpio_write(gpio_handle, DOOR1_RELAY, 0)
            time.sleep(2)
            
            # Deactivate relay (HIGH)
            print("Deactivating Door 1 relay (HIGH)...")
            GPIO.gpio_write(gpio_handle, DOOR1_RELAY, 1)
        else:
            # Activate relay (LOW)
            print("Activating Door 1 relay (LOW)...")
            GPIO.output(DOOR1_RELAY, GPIO.LOW)
            time.sleep(2)
            
            # Deactivate relay (HIGH)
            print("Deactivating Door 1 relay (HIGH)...")
            GPIO.output(DOOR1_RELAY, GPIO.HIGH)
        
        print("Door 1 relay test complete")
        
        print("\nTesting Door 2 relay...")
        
        if GPIO_LIB == 'lgpio':
            # Activate relay (LOW)
            print("Activating Door 2 relay (LOW)...")
            GPIO.gpio_write(gpio_handle, DOOR2_RELAY, 0)
            time.sleep(2)
            
            # Deactivate relay (HIGH)
            print("Deactivating Door 2 relay (HIGH)...")
            GPIO.gpio_write(gpio_handle, DOOR2_RELAY, 1)
        else:
            # Activate relay (LOW)
            print("Activating Door 2 relay (LOW)...")
            GPIO.output(DOOR2_RELAY, GPIO.LOW)
            time.sleep(2)
            
            # Deactivate relay (HIGH)
            print("Deactivating Door 2 relay (HIGH)...")
            GPIO.output(DOOR2_RELAY, GPIO.HIGH)
        
        print("Door 2 relay test complete")
        
        # Test GPIO pin availability
        print(f"\n=== GPIO Pin Availability Test ===")
        test_pins = [4, 9, 11, 12, 18, 19, 23, 24]
        
        for pin in test_pins:
            try:
                if GPIO_LIB == 'lgpio':
                    # Try to claim as input
                    GPIO.gpio_claim_input(gpio_handle, pin, GPIO.SET_PULL_UP)
                    value = GPIO.gpio_read(gpio_handle, pin)
                    print(f"GPIO {pin}: Available, value={value}")
                    GPIO.gpio_free(gpio_handle, pin)
                else:
                    GPIO.setup(pin, GPIO.IN, pull_up_down=GPIO.PUD_UP)
                    value = GPIO.input(pin)
                    print(f"GPIO {pin}: Available, value={value}")
            except Exception as e:
                print(f"GPIO {pin}: ERROR - {e}")
        
    except Exception as e:
        print(f"CRITICAL ERROR: {e}")
    finally:
        # Cleanup
        if GPIO_LIB == 'lgpio' and gpio_handle is not None:
            GPIO.gpiochip_close(gpio_handle)
        elif GPIO_LIB == 'RPi.GPIO':
            GPIO.cleanup()
        print(f"\nGPIO cleanup complete")

if __name__ == "__main__":
    test_gpio_pins()