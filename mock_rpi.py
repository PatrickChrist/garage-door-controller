# Mock RPi.GPIO module for development on non-RPi systems
import time
import threading
from typing import Dict, Any

class GPIO:
    BCM = "BCM"
    OUT = "OUT"
    IN = "IN"
    HIGH = 1
    LOW = 0
    PUD_UP = "PUD_UP"
    
    _pin_states: Dict[int, int] = {}
    _pin_modes: Dict[int, str] = {}
    _warnings_enabled = True
    
    @classmethod
    def setmode(cls, mode):
        print(f"[MOCK GPIO] Set mode: {mode}")
    
    @classmethod
    def setwarnings(cls, enabled: bool):
        cls._warnings_enabled = enabled
        print(f"[MOCK GPIO] Warnings: {enabled}")
    
    @classmethod
    def setup(cls, pin: int, mode: str, initial: int = None, pull_up_down: str = None):
        cls._pin_modes[pin] = mode
        if initial is not None:
            cls._pin_states[pin] = initial
        print(f"[MOCK GPIO] Setup pin {pin}: mode={mode}, initial={initial}, pull_up_down={pull_up_down}")
    
    @classmethod
    def output(cls, pin: int, value: int):
        cls._pin_states[pin] = value
        print(f"[MOCK GPIO] Pin {pin} output: {value}")
    
    @classmethod
    def input(cls, pin: int) -> int:
        # Simulate sensor readings - you can modify this for testing
        # For garage door sensors: HIGH=open, LOW=closed
        if pin in [23, 24]:  # Sensor pins
            # Simulate closed doors by default
            state = cls.LOW
        else:
            state = cls._pin_states.get(pin, cls.LOW)
        print(f"[MOCK GPIO] Pin {pin} input: {state}")
        return state
    
    @classmethod
    def cleanup(cls):
        cls._pin_states.clear()
        cls._pin_modes.clear()
        print("[MOCK GPIO] Cleanup completed")

# Replace the actual RPi.GPIO import in garage_controller.py