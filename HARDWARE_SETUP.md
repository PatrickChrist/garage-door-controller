# Hardware Setup Guide

Complete hardware setup instructions for the Garage Door Controller.

## ⚠️ Safety Warning

**IMPORTANT: This project involves working with garage door mechanisms and electrical connections. Garage doors are heavy and can cause serious injury or death if not handled properly.**

- **Always disconnect power** to garage door opener before making connections
- **Test all connections** before connecting to actual garage door
- **Ensure emergency manual release** always works
- **Have a qualified electrician** review your setup if unsure
- **Follow all local electrical codes** and regulations

## Required Components

### Electronic Components
| Component | Quantity | Purpose |
|-----------|----------|---------|
| Raspberry Pi 3B+ or newer | 1 | Main controller |
| MicroSD Card (16GB+) | 1 | Operating system storage |
| 5V 2-Channel Relay Module | 1 | Door opener control |
| Reed Switches (Normally Open) | 2 | Door position sensing |
| Jumper Wires (Male-Female) | 10+ | Connections |
| Breadboard or PCB | 1 | Wire organization |
| 5V Power Supply | 1 | Raspberry Pi power |
| Enclosure/Case | 1 | Protection |

### Optional Components
| Component | Purpose |
|-----------|---------|
| LED Indicators | Visual status |
| Buzzer | Audio notifications |
| Emergency Stop Button | Manual safety cutoff |
| Ethernet Cable | Wired network connection |

## GPIO Pinout Reference

### Raspberry Pi GPIO Layout
```
    3.3V  1 ┃ 2   5V
   GPIO2  3 ┃ 4   5V
   GPIO3  5 ┃ 6   GND
   GPIO4  7 ┃ 8   GPIO14  ← Door Sensor (shared)
     GND  9 ┃ 10  GPIO15
  GPIO17 11 ┃ 12  GPIO18
  GPIO27 13 ┃ 14  GND
  GPIO22 15 ┃ 16  GPIO23
     3.3V 17 ┃ 18  GPIO24
  GPIO10 19 ┃ 20  GND
   GPIO9 21 ┃ 22  GPIO25  ← Door 1 Relay
  GPIO11 23 ┃ 24  GPIO8
     GND 25 ┃ 26  GPIO7
   GPIO0 27 ┃ 28  GPIO1
   GPIO5 29 ┃ 30  GND
   GPIO6 31 ┃ 32  GPIO12  ← Door 2 Relay
  GPIO13 33 ┃ 34  GND
  GPIO19 35 ┃ 36  GPIO16
  GPIO26 37 ┃ 38  GPIO20
     GND 39 ┃ 40  GPIO21
```

### Default Pin Assignment
- **GPIO 9**: Door 1 Relay Control
- **GPIO 12**: Door 2 Relay Control  
- **GPIO 4**: Door Position Sensor (shared for both doors)

## Component Wiring

### 1. Relay Module Connections

The relay module controls the garage door openers by simulating button presses.

**Relay Module → Raspberry Pi:**
```
VCC → 5V (Pin 2 or 4)
GND → GND (Pin 6, 9, 14, 20, 25, 30, 34, or 39)
IN1 → GPIO 9 (Pin 21) - Door 1
IN2 → GPIO 12 (Pin 32) - Door 2
```

**Relay Module → Garage Door Opener:**
```
Door 1: COM1 and NO1 → Garage Door 1 button terminals
Door 2: COM2 and NO2 → Garage Door 2 button terminals
```

### 2. Reed Switch Connections

Reed switches detect door position (open/closed).

**Door Sensor (Shared):**
```
Door Sensor Terminal 1 → GPIO 4 (Pin 7)
Door Sensor Terminal 2 → GND (any ground pin)
```

**Note:** This configuration uses a single sensor shared between both doors.
The sensor detects when any door is in motion or position change.
```

### 3. Power Connections

```
Raspberry Pi: 5V 2.5A+ power supply → microUSB/USB-C
Relay Module: Powered from Pi's 5V rail
```

## Physical Installation

### 1. Raspberry Pi Mounting

- **Location**: Mount in a dry, ventilated area near garage door opener
- **Temperature**: Operating range 0°C to 85°C
- **Enclosure**: Use a ventilated case to protect from dust/moisture
- **Access**: Ensure easy access to SD card and ports

### 2. Relay Module Installation

- **Mounting**: Secure to wall or enclosure near garage door opener
- **Distance**: Keep within 3 feet of door opener for reliable connections
- **Protection**: Protect from moisture and debris

### 3. Reed Switch Installation

#### Door Position Detection Options:

**Option A: Door-Mounted Reed Switch**
```
┌─────────────┐  ← Garage Door
│   [MAGNET]  │
└─────────────┘
      ↕
┌─────────────┐  ← Door Frame
│ [Door Sensor] │  ← Wired to GPIO 4
└─────────────┘
```

**Option B: Track-Mounted Detection**
```
    Track
═══════════════
    ↕  [Magnet on door]
[Door Sensor]  ← Wired to GPIO 4
```

**Installation Steps:**
1. **Choose mounting location** where switch reliably detects door position
2. **Test switch operation** with multimeter before final installation
3. **Secure wiring** to prevent damage from door movement
4. **Test door movement** doesn't interfere with switch/wiring

### 4. Wiring Route Planning

- **Avoid moving parts** - keep wires away from door tracks, springs, cables
- **Secure connections** - use wire nuts or terminal blocks
- **Label wires** - for future maintenance
- **Leave slack** - allow for door movement without tension on wires

## Garage Door Opener Integration

### Connection Points

Most garage door openers have terminals for external button connections:

**Common Terminal Labels:**
- **Red/White terminals**: Wall button connection
- **Common terminals**: Usually marked as "COM" 
- **Button terminals**: Usually marked as "PUSH" or "PB"

### Connection Procedure

1. **Power OFF** the garage door opener
2. **Identify button terminals** on the opener motor unit
3. **Connect relay outputs** to the same terminals as wall button
4. **Test with multimeter** - relay should show continuity when activated
5. **Power ON** and test operation

### Wiring Diagram Example

```
Garage Door Opener Motor Unit
┌─────────────────────────────┐
│  [Motor]     ┌─────────────┐ │
│              │   Control   │ │
│              │    Board    │ │
│              │             │ │
│              │ RED   WHITE │ │ ← Wall Button Terminals
│              │  ●     ●   │ │
└──────────────┴──┬──────┬──┴─┘
                    │      │
                    └──────┴─── Connect Relay COM1 & NO1
                               (Door 1)

┌────────────────────────────────┐
│     Relay Module               │
│                                │
│  IN1●  IN2●   VCC● GND●       │
│   │     │      │    │         │
│   │     │      │    │         │
│ COM1   COM2   NO1  NO2        │
│  ●●●    ●●●    ●●●  ●●●        │
└────────────────────────────────┘
   ││      ││      ││   ││
   ││      ││      ││   └┴─ To Door 2 Opener
   ││      ││      └┴─ To Door 1 Opener  
   ││      └┴─ GPIO 12 (Door 2)
   └┴─ GPIO 9 (Door 1)
```

## Testing and Validation

### 1. Component Testing (Power OFF)

**Test Relay Module:**
```bash
# Test GPIO control
echo 18 > /sys/class/gpio/export
echo out > /sys/class/gpio/gpio18/direction
echo 0 > /sys/class/gpio/gpio18/value  # Relay ON
echo 1 > /sys/class/gpio/gpio18/value  # Relay OFF
```

**Test Reed Switches:**
```bash
# Test sensor reading
echo 23 > /sys/class/gpio/export
echo in > /sys/class/gpio/gpio23/direction
cat /sys/class/gpio/gpio23/value  # Should change with door position
```

### 2. System Integration Testing

1. **Install software** using installation script
2. **Start application** in debug mode
3. **Monitor logs** for GPIO activity
4. **Test web interface** door status updates
5. **Verify WebSocket** real-time updates

### 3. Safety Testing

1. **Emergency release** - ensure manual operation always works
2. **Power failure** - test door operation without controller
3. **Network failure** - ensure local manual control works
4. **Sensor failure** - verify safe operation with unknown status

## Configuration

### GPIO Pin Customization

If default pins conflict with other hardware, modify `.env` file:

```bash
# Custom GPIO pins
DOOR1_RELAY_PIN=22
DOOR2_RELAY_PIN=27
DOOR1_SENSOR_PIN=5
DOOR2_SENSOR_PIN=6
```

### Sensor Logic Adjustment

Reed switch logic can be inverted if needed. Modify `garage_controller.py`:

```python
def _read_sensor(self, door_id: int) -> bool:
    """Read door sensor (True = open, False = closed)"""
    sensor_pin = self._get_sensor_pin(door_id)
    reading = GPIO.input(sensor_pin) == GPIO.HIGH
    return not reading  # Invert logic if needed
```

## Troubleshooting

### Common Issues

**Relays not activating:**
- Check 5V power connection to relay module
- Verify GPIO pin configuration
- Test with LED instead of relay for debugging

**Sensors not reading:**
- Check magnet alignment with reed switch
- Verify pull-up resistor configuration
- Test switch continuity with multimeter

**Door not responding:**
- Verify connections to door opener terminals
- Check door opener manual/remote still works
- Ensure relay contacts are making good connection

**Intermittent operation:**
- Check for loose connections
- Verify power supply capacity
- Look for electrical interference

### Debug Commands

```bash
# Check GPIO status
cat /sys/class/gpio/gpio*/direction
cat /sys/class/gpio/gpio*/value

# Monitor system logs
sudo journalctl -u garage-controller -f

# Test network connectivity
curl http://localhost:8000/api/status

# Check service status
sudo systemctl status garage-controller
```

## Maintenance

### Regular Checks

- **Monthly**: Test manual emergency release
- **Quarterly**: Inspect all connections for corrosion/loosening
- **Annually**: Clean relay contacts if accessible
- **As needed**: Update software and security patches

### Connection Protection

- Use **dielectric grease** on outdoor connections
- Apply **heat shrink tubing** to splice points  
- Install **drip loops** to prevent water entry
- Check **wire strain relief** at connection points

## Advanced Features

### Optional Enhancements

**Status LEDs:**
```
GPIO 26 → LED 1 (Door 1 Status) → Resistor → GND
GPIO 16 → LED 2 (Door 2 Status) → Resistor → GND
```

**Emergency Stop Button:**
```
GPIO 21 → Emergency Stop Switch → GND
```

**Buzzer/Alarm:**
```
GPIO 20 → Buzzer/Piezo → GND
```

## Support

For hardware-related questions:
1. Check wiring against this guide
2. Test individual components
3. Verify power and ground connections  
4. Consult garage door opener manual
5. Consider professional installation for electrical work