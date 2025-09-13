# Garage Door Controller

A Raspberry Pi-based garage door controller with web interface, REST API, WebSocket support, and iOS CarPlay integration.

## Features

- **Dual Door Control**: Support for 2 garage doors with individual control
- **Real-time Status**: WebSocket updates for door status changes
- **Web Interface**: Modern responsive web UI
- **REST API**: Complete API for external integrations
- **iOS CarPlay**: Native iOS app with CarPlay support
- **Authentication**: Optional JWT-based authentication
- **Hardware Integration**: Direct GPIO control for relays and sensors

## Hardware Requirements

### Raspberry Pi Setup
- Raspberry Pi 3B+ or newer
- MicroSD card (16GB+)
- 2x Relay modules (5V)
- 2x Reed switches or magnetic sensors
- Jumper wires and breadboard
- Power supply

### GPIO Pinout (default)
- Door 1 Relay: GPIO 9
- Door 2 Relay: GPIO 12
- Door Sensor: GPIO 4 (shared for both doors)

## Quick Installation

### Automated Installation (Recommended)
```bash
# Download and run the installation script
curl -sSL https://raw.githubusercontent.com/PatrickChrist/garage-door-controller/main/install-raspberrypi.sh | bash

# Or download first, then run
wget https://raw.githubusercontent.com/PatrickChrist/garage-door-controller/main/install-raspberrypi.sh
chmod +x install-raspberrypi.sh
./install-raspberrypi.sh
```

### Manual Installation

#### 1. Raspberry Pi Setup
```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install Python and pip
sudo apt install python3 python3-pip python3-venv git -y

# Clone repository
git clone https://github.com/PatrickChrist/garage-door-controller.git garage-controller
cd garage-controller
```

#### 2. Python Environment
```bash
# Create virtual environment
python3 -m venv venv
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt
```

#### 3. Configuration
```bash
# Copy environment template
cp .env.example .env

# Edit configuration
nano .env
```

#### 4. Hardware Connections

#### Relay Modules
- Connect relay modules to 5V, GND, and GPIO pins 9 & 12
- Connect relay outputs to garage door opener button terminals

#### Door Sensor
- Connect door sensor between GPIO pin 4 and GND
- Single sensor shared for both doors
- Use internal pull-up resistors (configured in software)

## Configuration

### Environment Variables (.env)

```bash
# API Security
SECRET_KEY=your-super-secret-key-here-change-this
API_KEY=your-api-key-for-external-access

# GPIO Configuration
DOOR1_RELAY_PIN=18
DOOR2_RELAY_PIN=19
DOOR1_SENSOR_PIN=23
DOOR2_SENSOR_PIN=24

# Server Configuration
HOST=0.0.0.0
PORT=8000
DEBUG=false

# Security Settings
ENABLE_AUTH=true
TOKEN_EXPIRE_MINUTES=60
```

### GPIO Pin Customization
Modify the GPIO pins in `.env` if using different wiring:
- Relay pins control the garage door openers
- Sensor pins read door position (LOW=closed, HIGH=open)

## Running the Application

### Development Mode
```bash
source venv/bin/activate
python main.py
```

### Production Mode with systemd

1. Create systemd service:
```bash
sudo nano /etc/systemd/system/garage-controller.service
```

```ini
[Unit]
Description=Garage Door Controller
After=network.target

[Service]
Type=simple
User=pi
WorkingDirectory=/home/pi/garage-controller
Environment=PATH=/home/pi/garage-controller/venv/bin
ExecStart=/home/pi/garage-controller/venv/bin/python main.py
Restart=always

[Install]
WantedBy=multi-user.target
```

2. Enable and start service:
```bash
sudo systemctl enable garage-controller
sudo systemctl start garage-controller
sudo systemctl status garage-controller
```

## API Documentation

### Endpoints

#### GET /api/status
Get status of both garage doors
```json
{
  "1": "closed",
  "2": "open"
}
```

#### GET /api/status/{door_id}
Get status of specific door
```json
{
  "door_id": 1,
  "status": "closed"
}
```

#### POST /api/trigger/{door_id}
Trigger garage door opener (requires authentication if enabled)
```json
{
  "message": "Door 1 triggered successfully"
}
```

### WebSocket /ws
Real-time updates for door status changes
```json
{
  "type": "status_update",
  "door_id": 1,
  "status": "opening"
}
```

## iOS CarPlay App

### Building the iOS App

1. Open `ios-app/GarageDoorCarPlay/GarageDoorCarPlay.xcodeproj` in Xcode
2. Configure your development team and bundle identifier
3. Update the server URL in `GarageController.swift`
4. Build and run on your device

### CarPlay Configuration

1. Enable CarPlay capability in Xcode project settings
2. Add CarPlay entitlements to your Apple Developer account
3. Test with CarPlay simulator or compatible vehicle

## Authentication

### Enabling Authentication
Set `ENABLE_AUTH=true` in `.env` file

### Getting Access Token
```bash
curl -X POST http://your-pi:8000/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username": "admin", "password": "password"}'
```

### Using Token in Requests
```bash
curl -X POST http://your-pi:8000/api/trigger/1 \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

## Safety Considerations

### Important Safety Notes
- **Test thoroughly** before connecting to actual garage doors
- **Use proper electrical isolation** for relay connections
- **Ensure emergency manual override** always works
- **Test sensor reliability** before deployment
- **Use HTTPS in production** for secure remote access

### Recommended Safety Features
- Physical emergency stop button
- Manual door override capability
- Status LED indicators
- Network connectivity monitoring
- Automatic timeout for door operations

## Troubleshooting

### Common Issues

1. **GPIO Permission Denied**
   ```bash
   sudo usermod -a -G gpio pi
   # Logout and login again
   ```

2. **RPi.GPIO Installation Issues**
   ```bash
   # On development machines, mock GPIO is used automatically
   # On Raspberry Pi, ensure RPi.GPIO is properly installed
   pip install RPi.GPIO
   ```

3. **Service Won't Start**
   ```bash
   sudo journalctl -u garage-controller -f
   # Check logs for specific error messages
   ```

4. **Door Status Not Updating**
   - Check sensor connections
   - Verify GPIO pin configuration
   - Test sensor with multimeter

### Log Monitoring
```bash
# View service logs
sudo journalctl -u garage-controller -f

# View system logs
tail -f /var/log/syslog | grep garage
```

## Development

### Local Development (Non-Pi)
The application includes mock GPIO functionality for development on non-Raspberry Pi systems.

```bash
# Mock GPIO will be used automatically
python main.py
```

### Testing
- Web interface: http://localhost:8000
- API documentation: http://localhost:8000/docs
- WebSocket testing: Use browser developer tools

## License

MIT License - see LICENSE file for details.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## Support

For issues and questions:
1. Check the troubleshooting section
2. Review system logs
3. Open an issue on GitHub with detailed information