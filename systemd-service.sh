#!/bin/bash

# Install Garage Door Controller as systemd service
# Run with: sudo ./systemd-service.sh

if [ "$EUID" -ne 0 ]; then
    echo "Please run as root (use sudo)"
    exit 1
fi

# Get current directory and user
INSTALL_DIR=$(pwd)
CURRENT_USER=${SUDO_USER:-$(whoami)}

echo "Installing Garage Door Controller service..."
echo "Install directory: $INSTALL_DIR"
echo "User: $CURRENT_USER"

# Create systemd service file
cat > /etc/systemd/system/garage-controller.service << EOF
[Unit]
Description=Garage Door Controller
After=network.target

[Service]
Type=simple
User=$CURRENT_USER
WorkingDirectory=$INSTALL_DIR
Environment=PATH=$INSTALL_DIR/venv/bin
ExecStart=$INSTALL_DIR/venv/bin/python main.py
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd and enable service
systemctl daemon-reload
systemctl enable garage-controller

echo "Service installed successfully!"
echo "To start: sudo systemctl start garage-controller"
echo "To check status: sudo systemctl status garage-controller"
echo "To view logs: sudo journalctl -u garage-controller -f"