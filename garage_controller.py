import platform
import os

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
    # Use mock GPIO for development on non-Pi systems
    print("Using mock GPIO for development")
    from mock_rpi import GPIO
    GPIO_LIB = 'mock'
import time
import threading
from typing import Dict, Callable
from enum import Enum

class DoorStatus(Enum):
    OPEN = "open"
    CLOSED = "closed"
    OPENING = "opening"
    CLOSING = "closing"
    UNKNOWN = "unknown"

class GarageDoorController:
    def __init__(self):
        # Initialize GPIO handle for lgpio
        self.gpio_handle = None
        
        # GPIO pin configuration
        self.DOOR1_RELAY = 9     # GPIO 9 for door 1 relay
        self.DOOR2_RELAY = 12    # GPIO 12 for door 2 relay
        self.DOOR1_SENSOR = 11   # GPIO 11 for door 1 sensor (HIGH = closed)
        self.DOOR2_SENSOR = 4    # GPIO 4 for door 2 sensor (HIGH = closed)
        
        # Door states
        self.door_states = {
            1: DoorStatus.UNKNOWN,
            2: DoorStatus.UNKNOWN
        }
        
        # Status change callbacks
        self.status_callbacks: Dict[int, Callable] = {}
        
        # Setup GPIO
        self._setup_gpio()
        
        # Start monitoring thread
        self.monitoring = True
        self.monitor_thread = threading.Thread(target=self._monitor_doors, daemon=True)
        self.monitor_thread.start()
    
    def _setup_gpio(self):
        """Initialize GPIO pins"""
        if GPIO_LIB == 'lgpio':
            # Initialize lgpio
            self.gpio_handle = GPIO.gpiochip_open(0)
            
            # Setup relay pins (output, initially HIGH - relay off)
            GPIO.gpio_claim_output(self.gpio_handle, self.DOOR1_RELAY, 1)
            GPIO.gpio_claim_output(self.gpio_handle, self.DOOR2_RELAY, 1)
            
            # Setup sensor pins (input with pull-up)
            GPIO.gpio_claim_input(self.gpio_handle, self.DOOR1_SENSOR, GPIO.SET_PULL_UP)
            if self.DOOR2_SENSOR != self.DOOR1_SENSOR:  # Only claim if different pin
                GPIO.gpio_claim_input(self.gpio_handle, self.DOOR2_SENSOR, GPIO.SET_PULL_UP)
                
        else:
            # Traditional RPi.GPIO setup
            GPIO.setmode(GPIO.BCM)
            GPIO.setwarnings(False)
            
            # Setup relay pins (output, initially HIGH - relay off)
            GPIO.setup(self.DOOR1_RELAY, GPIO.OUT, initial=GPIO.HIGH)
            GPIO.setup(self.DOOR2_RELAY, GPIO.OUT, initial=GPIO.HIGH)
            
            # Setup sensor pins (input with pull-up)
            GPIO.setup(self.DOOR1_SENSOR, GPIO.IN, pull_up_down=GPIO.PUD_UP)
            GPIO.setup(self.DOOR2_SENSOR, GPIO.IN, pull_up_down=GPIO.PUD_UP)
        
        # Initialize door states
        self._update_door_status(1)
        self._update_door_status(2)
    
    def _get_sensor_pin(self, door_id: int) -> int:
        """Get sensor pin for door"""
        return self.DOOR1_SENSOR if door_id == 1 else self.DOOR2_SENSOR
    
    def _get_relay_pin(self, door_id: int) -> int:
        """Get relay pin for door"""
        return self.DOOR1_RELAY if door_id == 1 else self.DOOR2_RELAY
    
    def _gpio_read(self, pin: int) -> bool:
        """Read GPIO pin value"""
        if GPIO_LIB == 'lgpio':
            return GPIO.gpio_read(self.gpio_handle, pin) == 1
        else:
            return GPIO.input(pin) == GPIO.HIGH
    
    def _gpio_write(self, pin: int, value: bool):
        """Write GPIO pin value"""
        if GPIO_LIB == 'lgpio':
            GPIO.gpio_write(self.gpio_handle, pin, 1 if value else 0)
        else:
            GPIO.output(pin, GPIO.HIGH if value else GPIO.LOW)
    
    def _read_sensor(self, door_id: int) -> bool:
        """Read door sensor (True = open, False = closed)"""
        sensor_pin = self._get_sensor_pin(door_id)
        sensor_value = self._gpio_read(sensor_pin)
        # Sensors are HIGH when door is closed, so invert the logic
        return not sensor_value
    
    def _update_door_status(self, door_id: int):
        """Update door status based on sensor reading"""
        is_open = self._read_sensor(door_id)
        new_status = DoorStatus.OPEN if is_open else DoorStatus.CLOSED
        
        if self.door_states[door_id] != new_status:
            self.door_states[door_id] = new_status
            if door_id in self.status_callbacks:
                self.status_callbacks[door_id](door_id, new_status)
    
    def _monitor_doors(self):
        """Monitor door sensors for status changes"""
        while self.monitoring:
            self._update_door_status(1)
            self._update_door_status(2)
            time.sleep(0.5)  # Check every 500ms
    
    def trigger_door(self, door_id: int, duration: float = 0.5):
        """Trigger garage door opener (simulate button press)"""
        if door_id not in [1, 2]:
            raise ValueError("Door ID must be 1 or 2")
        
        relay_pin = self._get_relay_pin(door_id)
        
        # Set door to transitioning state
        current_status = self.door_states[door_id]
        if current_status == DoorStatus.CLOSED:
            self.door_states[door_id] = DoorStatus.OPENING
        elif current_status == DoorStatus.OPEN:
            self.door_states[door_id] = DoorStatus.CLOSING
        
        if door_id in self.status_callbacks:
            self.status_callbacks[door_id](door_id, self.door_states[door_id])
        
        # Trigger relay (LOW activates relay)
        self._gpio_write(relay_pin, False)  # LOW to activate relay
        time.sleep(duration)
        self._gpio_write(relay_pin, True)   # HIGH to deactivate relay
        
        # Wait longer for door closing (15 seconds) vs opening (2 seconds)
        if current_status == DoorStatus.OPEN:
            # Door is closing - wait 15 seconds before checking final state
            threading.Timer(15.0, self._update_door_status, args=[door_id]).start()
        else:
            # Door is opening - wait 2 seconds before checking final state
            threading.Timer(2.0, self._update_door_status, args=[door_id]).start()
    
    def get_door_status(self, door_id: int) -> DoorStatus:
        """Get current door status"""
        if door_id not in [1, 2]:
            raise ValueError("Door ID must be 1 or 2")
        return self.door_states[door_id]
    
    def get_all_doors_status(self) -> Dict[int, str]:
        """Get status of both doors"""
        return {
            1: self.door_states[1].value,
            2: self.door_states[2].value
        }
    
    def register_status_callback(self, door_id: int, callback: Callable):
        """Register callback for door status changes"""
        self.status_callbacks[door_id] = callback
    
    def cleanup(self):
        """Clean up GPIO resources"""
        self.monitoring = False
        if self.monitor_thread.is_alive():
            self.monitor_thread.join(timeout=1.0)
        
        if GPIO_LIB == 'lgpio':
            if self.gpio_handle is not None:
                GPIO.gpiochip_close(self.gpio_handle)
                self.gpio_handle = None
        else:
            GPIO.cleanup()

# Global controller instance
garage_controller = None

def get_garage_controller() -> GarageDoorController:
    """Get global garage controller instance"""
    global garage_controller
    if garage_controller is None:
        garage_controller = GarageDoorController()
    return garage_controller