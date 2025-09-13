# Apple Ecosystem Integration Guide

Complete guide for Apple device integration with the Garage Door Controller.

## 🍎 Apple Integration Features

### 1. **Apple Watch App**
- Native watchOS app with complications
- Control garage doors directly from watch
- Real-time status updates
- Haptic feedback for actions
- Watch face complications showing door status

### 2. **Siri Shortcuts**
- Voice control: "Hey Siri, open garage door"
- Custom intents for each door
- Works across all Apple devices
- Customizable phrases

### 3. **HomeKit Integration**
- Native Apple Home app support
- Secure HomeKit accessory protocol
- Works with all Apple devices
- Voice control through Siri
- Automation and scenes

### 4. **iOS Widgets**
- Home screen widgets (iOS 14+)
- Lock screen widgets (iOS 16+)
- Multiple widget sizes
- Quick door control buttons

### 5. **Push Notifications**
- Real-time status notifications
- Security alerts
- Daily status reports
- Actionable notifications

## 📱 iOS App Setup

### Prerequisites
- iOS 15.0 or later
- Xcode 15.0 or later
- Apple Developer account (for device deployment)

### Installation Steps

1. **Open Xcode Project**
```bash
open ios-app/GarageDoorCarPlay/GarageDoorCarPlay.xcodeproj
```

2. **Configure Bundle Identifier**
- Update bundle identifier to your unique ID
- Configure development team

3. **Add Required Capabilities**
- Background App Refresh
- Push Notifications  
- Siri & Shortcuts
- HomeKit (if using HomeKit bridge)

4. **Update Server URL**
In `GarageController.swift`, update the default base URL:
```swift
init(baseURL: String = "YOUR_RASPBERRY_PI_IP:8000") {
```

## ⌚ Apple Watch Setup

### Watch App Features
- **Native watchOS app** with SwiftUI interface
- **Watch complications** showing door status on watch face
- **Quick actions** from watch face
- **Haptic feedback** for successful operations
- **Real-time sync** with iPhone app

### Adding Complications

1. **Long press** on watch face
2. Tap **"Edit"**
3. Swipe to **complications view**
4. Tap **complication slot**
5. Select **"Garage Door Controller"**
6. Choose **complication style**

### Supported Complications
- **Modular Small/Large**
- **Circular Small**
- **Graphic Corner/Circular/Rectangular**
- **Extra Large**

## 🗣️ Siri Shortcuts

### Built-in Phrases
- "Hey Siri, open garage door"
- "Hey Siri, close garage door" 
- "Hey Siri, check garage status"
- "Hey Siri, trigger door 1"
- "Hey Siri, trigger door 2"

### Custom Setup

1. **Open Shortcuts app**
2. Tap **"+"** to create new shortcut
3. Add **"Trigger Garage Door"** intent
4. Configure **door number** (1 or 2)
5. Set **custom phrase**
6. Test with **"Hey Siri, [your phrase]"**

### Advanced Automation
```
IF location = Home
AND time = 6:00 PM
THEN trigger garage door 1
```

## 🏠 HomeKit Integration

### Setup HomeKit Bridge

1. **Install HomeKit bridge** on Raspberry Pi:
```bash
# Included in main installation script
python3 homekit_bridge.py
```

2. **Find setup code** in terminal output
3. **Open Apple Home app** on iPhone/iPad
4. Tap **"+"** → **"Add Accessory"**
5. **Scan setup code** or enter manually
6. Follow **setup wizard**

### HomeKit Features
- **Native Home app** control
- **Siri voice control**
- **Automation scenes**
- **Family sharing**
- **Remote access** (with Apple TV/HomePod)

### Example Automations
```
Arrive Home → Open Garage Door 1
Leave Home → Close All Garage Doors  
10 PM → Close All Garage Doors
Good Morning Scene → Check Garage Status
```

### Configuration
Set environment variables in `.env`:
```bash
# HomeKit Configuration
HOMEKIT_BRIDGE_NAME="Garage Door Bridge"
HOMEKIT_PIN_CODE="123-45-678"
GARAGE_API_URL="127.0.0.1:8000"
```

## 📲 iOS Widgets

### Widget Sizes

**Small Widget:**
- Door status indicators
- Compact view for both doors

**Medium Widget:**
- Door status with labels
- Quick access message

**Large Widget:**
- Full door cards with status
- Action buttons for each door
- Last updated timestamp

### Adding Widgets

1. **Long press** on home screen
2. Tap **"+"** in top corner
3. Search **"Garage Door"**
4. Select **widget size**
5. Tap **"Add Widget"**
6. **Position** and configure

## 🔔 Notifications

### Notification Types

**Status Updates:**
- Door opened/closed notifications
- Automatic delivery for state changes

**Security Alerts:**
- Unusual activity detection
- Critical system notifications

**Daily Reports:**
- Scheduled at 8 PM daily
- Summary of door activity

### Configuration

Notifications are automatically configured, but users can:
1. **Allow notifications** when prompted
2. **Customize in Settings** → **Notifications** → **Garage Door Controller**
3. **Choose alert style** and sounds

## 🔧 Advanced Configuration

### Custom Server URL
Set in iOS app settings or update code:
```swift
UserDefaults.standard.set("192.168.1.100:8000", forKey: "garage_base_url")
```

### Notification Scheduling
```swift
// Custom notification times
NotificationManager.shared.scheduleDailyStatusReport()
```

### Watch Complications Update
```swift
// Force complication update
CLKComplicationServer.sharedInstance().activeComplications?.forEach {
    CLKComplicationServer.sharedInstance().reloadTimeline(for: $0)
}
```

## 🚀 Deployment

### Development Deployment

1. **Connect iPhone** to Mac
2. **Select device** in Xcode
3. **Build and run** (⌘+R)
4. **Trust developer** on device if prompted

### App Store Distribution

1. **Archive app** in Xcode
2. **Upload to App Store Connect**
3. **Submit for review**
4. **Configure metadata** and screenshots

### TestFlight Beta
1. **Archive and upload** to App Store Connect
2. **Add external testers**
3. **Send invitations**

## 🔐 Security Considerations

### HomeKit Security
- **End-to-end encryption** for all communications
- **Local network only** by default
- **Authentication required** for remote access

### API Security
- **HTTPS recommended** for remote access
- **API key authentication** optional
- **Network isolation** recommended

### Best Practices
- **Regular updates** of iOS apps
- **Strong HomeKit codes** (avoid default 123-45-678)
- **Network security** for Raspberry Pi

## 🐛 Troubleshooting

### Common Issues

**Apple Watch not connecting:**
- Ensure iPhone and Watch are paired
- Check Bluetooth connectivity
- Restart both devices

**Siri shortcuts not working:**
- Re-record voice commands
- Check microphone permissions
- Verify shortcut configuration

**HomeKit bridge not appearing:**
- Check Raspberry Pi network connectivity
- Verify HomeKit bridge is running
- Reset HomeKit database if needed

**Widgets not updating:**
- Check background app refresh
- Verify network connectivity
- Remove and re-add widget

### Debug Commands

**Check HomeKit bridge status:**
```bash
sudo systemctl status garage-homekit
sudo journalctl -u garage-homekit -f
```

**Test API connectivity:**
```bash
curl http://192.168.1.100:8000/api/status
```

**Reset HomeKit:**
```bash
rm garage_door_homekit.state
python3 homekit_bridge.py
```

## 📚 Additional Resources

### Apple Documentation
- [HomeKit Accessory Protocol](https://developer.apple.com/homekit/)
- [SiriKit Intents](https://developer.apple.com/documentation/sirikit)
- [WidgetKit](https://developer.apple.com/documentation/widgetkit)
- [WatchKit](https://developer.apple.com/documentation/watchkit)

### Community
- [HAP-python Documentation](https://github.com/ikalchev/HAP-python)
- [HomeKit Specification](https://github.com/homebridge/HAP-NodeJS)

## 🔄 Updates and Maintenance

### Regular Tasks
- **Update iOS apps** from App Store
- **Restart HomeKit bridge** monthly
- **Check notification permissions** after iOS updates
- **Update Siri shortcuts** as needed

### Monitoring
- **Watch for HomeKit disconnections**
- **Monitor notification delivery**
- **Check widget functionality** after updates

This comprehensive Apple integration provides seamless control across all Apple devices with native app experiences, voice control, automation, and real-time updates.