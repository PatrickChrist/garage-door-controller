#!/usr/bin/env python3
"""
HomeKit Bridge for Garage Door Controller
Exposes garage doors as HomeKit accessories
"""

import asyncio
import logging
import signal
import os
import requests
from typing import Optional

try:
    from pyhap.accessory import Accessory, Bridge
    from pyhap.accessory_driver import AccessoryDriver
    from pyhap.const import CATEGORY_GARAGE_DOOR_OPENER
    from pyhap import loader
except ImportError:
    print("HAP-python not installed. Install with: pip install HAP-python[QRCode]")
    exit(1)

# Configure logging
logging.basicConfig(level=logging.INFO, format='[%(module)s] %(message)s')
logger = logging.getLogger(__name__)

class GarageDoorAccessory(Accessory):
    """A garage door opener accessory."""
    
    category = CATEGORY_GARAGE_DOOR_OPENER
    
    def __init__(self, driver, door_id: int, door_name: str, api_base_url: str):
        self.door_id = door_id
        self.api_base_url = api_base_url
        super().__init__(driver, door_name)
        
        # Add Garage Door Opener Service
        self.garage_door_service = self.add_preload_service('GarageDoorOpener')
        
        # Current Door State (0=Open, 1=Closed, 2=Opening, 3=Closing, 4=Stopped)
        self.current_door_state = self.garage_door_service.configure_char(
            'CurrentDoorState', value=1
        )
        
        # Target Door State (0=Open, 1=Closed)
        self.target_door_state = self.garage_door_service.configure_char(
            'TargetDoorState', value=1, setter_callback=self.set_target_door_state
        )
        
        # Obstruction Detected
        self.obstruction_detected = self.garage_door_service.configure_char(
            'ObstructionDetected', value=False
        )
        
        # Start status monitoring
        self.monitor_task = None
        
    @Accessory.run_at_interval(5)  # Check every 5 seconds
    async def update_status(self):
        """Update door status from API."""
        try:
            response = requests.get(
                f"http://{self.api_base_url}/api/status/{self.door_id}",
                timeout=3
            )
            
            if response.status_code == 200:
                data = response.json()
                status = data.get('status', 'unknown').lower()
                
                # Map API status to HomeKit values
                homekit_current_state = {
                    'open': 0,      # Open
                    'closed': 1,    # Closed
                    'opening': 2,   # Opening
                    'closing': 3,   # Closing
                    'unknown': 4    # Stopped (as fallback)
                }.get(status, 4)
                
                # Update current door state
                if self.current_door_state.value != homekit_current_state:
                    self.current_door_state.set_value(homekit_current_state)
                    logger.info(f"Door {self.door_id} status updated to {status}")
                
                # Update target door state to match current for final states
                if status in ['open', 'closed']:
                    target_state = 0 if status == 'open' else 1
                    if self.target_door_state.value != target_state:
                        self.target_door_state.set_value(target_state)
                        
        except Exception as e:
            logger.error(f"Error updating status for door {self.door_id}: {e}")
    
    async def set_target_door_state(self, value):
        """Handle HomeKit request to change door state."""
        logger.info(f"Door {self.door_id} target state set to {value}")
        
        try:
            # Trigger the door (toggle action)
            response = requests.post(
                f"http://{self.api_base_url}/api/trigger/{self.door_id}",
                timeout=5
            )
            
            if response.status_code == 200:
                logger.info(f"Successfully triggered door {self.door_id}")
                
                # Set intermediate state based on current state
                current_state = self.current_door_state.value
                if current_state == 1:  # Currently closed, now opening
                    self.current_door_state.set_value(2)  # Opening
                elif current_state == 0:  # Currently open, now closing  
                    self.current_door_state.set_value(3)  # Closing
                    
            else:
                logger.error(f"Failed to trigger door {self.door_id}: HTTP {response.status_code}")
                # Reset target state on failure
                self.target_door_state.set_value(1 if value == 0 else 0)
                
        except Exception as e:
            logger.error(f"Error triggering door {self.door_id}: {e}")
            # Reset target state on failure  
            self.target_door_state.set_value(1 if value == 0 else 0)

class GarageDoorBridge(Bridge):
    """Bridge for multiple garage door accessories."""
    
    category = CATEGORY_GARAGE_DOOR_OPENER

def main():
    """Main entry point."""
    # Configuration
    api_base_url = os.getenv('GARAGE_API_URL', '127.0.0.1:8000')
    bridge_name = os.getenv('HOMEKIT_BRIDGE_NAME', 'Garage Door Bridge')
    pin_code = os.getenv('HOMEKIT_PIN_CODE', '123-45-678')
    
    # Create the bridge
    bridge = GarageDoorBridge(None, bridge_name)
    
    # Add garage door accessories
    door1 = GarageDoorAccessory(None, 1, "Garage Door 1", api_base_url)
    door2 = GarageDoorAccessory(None, 2, "Garage Door 2", api_base_url)
    
    bridge.add_accessory(door1)
    bridge.add_accessory(door2)
    
    # Create the accessory driver
    driver = AccessoryDriver(
        bridge,
        port=51827,
        persist_file='garage_door_homekit.state'
    )
    
    # Set custom pin code if provided
    if pin_code != '123-45-678':
        driver.state.pincode = pin_code.encode('utf-8')
    
    # Signal handler for graceful shutdown
    def signal_handler(signum, frame):
        logger.info("Shutting down HomeKit bridge...")
        driver.stop()
    
    signal.signal(signal.SIGTERM, signal_handler)
    signal.signal(signal.SIGINT, signal_handler)
    
    # Start the accessory driver
    logger.info(f"Starting HomeKit bridge: {bridge_name}")
    logger.info(f"Setup code: {pin_code}")
    logger.info("Use the Apple Home app to add this bridge")
    
    try:
        driver.start()
    except KeyboardInterrupt:
        logger.info("Received keyboard interrupt")
    finally:
        driver.stop()

if __name__ == '__main__':
    main()