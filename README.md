# FPV RC Car - Low-Latency WebRTC Streaming

A Flutter-based FPV (First Person View) RC car project using WebRTC for ultra-low-latency video and audio streaming. Mount a phone on your RC car and view the stream from any web browser!

## Features

- **Ultra-Low Latency Streaming**: Optimized WebRTC configuration for minimal delay
- **TailScale Integration**: Direct P2P connections using TailScale IPs (100.x.x.x)
- **Web Browser Viewing**: Watch the stream from any device with a web browser
- **Real-Time Stats**: Bitrate, FPS, and packet loss monitoring in the browser
- **Simple Setup**: Just one app on the vehicle phone, view from anywhere

## Quick Start

### Prerequisites

1. Install [Flutter](https://flutter.dev/docs/get-started/install)
2. Install [TailScale](https://tailscale.com/) on your phone and viewing device
3. A phone to mount on your RC car

### Setup

```bash
# Install dependencies
flutter pub get

# Run on vehicle device (phone mounted on RC car)
flutter run -d <phone_device_id>
```

### Viewing the Stream

1. **Start Vehicle Mode**: Open the app on your phone and tap "Start Vehicle Mode"
2. **Grant Permissions**: Allow camera and microphone access
3. **Start Signaling Server**: On your computer, run:
   ```bash
   dart bin/signaling_server.dart
   ```
4. **Get Phone IP**: Run `tailscale ip -4` on your phone to get its TailScale IP
5. **Open Browser**: Navigate to `http://<phone-ip>:8080/viewer/`
6. **Connect**: Enter the phone's TailScale IP and click "Connect"

That's it! You should now see the live video stream from your RC car.

## Web Browser Viewer

The web viewer provides:
- **Live Video Stream**: Low-latency video and audio from the vehicle
- **Real-Time Stats**: Bitrate (kbps), FPS, and packet loss percentage
- **Connection Status**: Visual indicators for connection and signal state
- **Responsive Design**: Works on desktop, tablet, and mobile browsers

## Low-Latency Optimizations

This project implements several optimizations for minimal latency:

### WebRTC Configuration
- **Bundle Policy**: `max-bundle` - all streams over single transport
- **RTCP Mux Policy**: `require` - RTCP multiplexed with RTP
- **Minimal STUN**: Only fallback STUN, relies on direct TailScale IPs

### Video Settings
- **Vehicle**: 960x540 @ 60fps (ultra-low latency)
- **Hardware Acceleration**: Native WebRTC rendering

### Network
- **Direct IP**: P2P connections over TailScale mesh network
- **HTTP Signaling**: Lightweight SDP/ICE exchange

## Project Structure

```
lib/
├── main.dart                    # App entry point
├── services/
│   ├── webrtc_service.dart      # WebRTC connection management
│   └── signaling_service.dart   # HTTP signaling utilities
├── providers/
│   └── webrtc_provider.dart     # Riverpod state management
└── screens/
    ├── home_screen.dart         # Start vehicle mode
    └── vehicle_screen.dart      # Vehicle mode UI

bin/
└── signaling_server.dart        # HTTP signaling server

web/viewer/
└── index.html                   # Web browser viewer
```

## Hardware Integration (Future)

For actual motor/servo control from the vehicle phone:

```dart
// Example: USB-Serial to ESP32/Arduino
void _sendMotorCommand(double throttle, double steering) {
  // Send via USB OTG, Bluetooth, or WiFi
  // to motor controller (ESP32/Arduino)
}
```

## Troubleshooting

### Connection Issues
- Ensure phone and viewing device are on the same TailScale network
- Check that TailScale IPs are correct (100.x.x.x range)
- Verify camera and microphone permissions on the phone
- Make sure the signaling server is running: `dart bin/signaling_server.dart`
- Check that port 8080 is not blocked by firewall

### High Latency
- Check network signal strength
- Ensure good WiFi or cellular connection
- Reduce video resolution in `_ultraLowLatencyVideoConstraints`
- Use 5GHz WiFi if available

### Web Browser Issues
- Use Chrome or Firefox for best WebRTC support
- Check browser console for errors
- Verify the signaling server is running
- Try clearing browser cache and reloading

## Dependencies

- `flutter_webrtc: ^0.9.48` - WebRTC implementation
- `flutter_riverpod: ^2.5.1` - State management
- `http: ^1.2.2` - HTTP signaling
- `permission_handler: ^11.3.1` - Camera/mic permissions

## License

MIT License - feel free to use this project for your own FPV builds!

## Contributing

Contributions are welcome! Please feel free to submit pull requests or open issues for bugs and feature requests.
