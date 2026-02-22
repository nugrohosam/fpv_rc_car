# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Flutter-based FPV (First Person View) RC car project using WebRTC for **ultra-low-latency** video-only streaming. A phone mounted on the RC car streams video to web browsers over TailScale/LAN.

**Architecture**:
- Vehicle (Flutter app on phone) <---WebRTC---> Web Browser (viewer)

**Key Design Goals**:
- Minimize latency through WebRTC optimizations
- Direct IP connections via TailScale (no STUN/TURN)
- Simple vehicle-only app with web browser viewing

## Development Commands

```bash
# Install Flutter dependencies
flutter pub get

# Run the app (vehicle mode - phone on car)
flutter run -d <phone_device_id>

# Build for release
flutter build apk                    # Android
flutter build ios                    # iOS

# Run tests
flutter test

# Analyze code
flutter analyze

# Start the signaling server (REQUIRED for web browser viewing)
dart bin/signaling_server.dart
```

## Low-Latency Optimizations Implemented

### WebRTC Configuration
- **Bundle Policy**: `max-bundle` - all streams bundled over single transport
- **RTCP Mux Policy**: `require` - RTCP multiplexed with RTP
- **ICE Transport Policy**: `all` - allows direct candidate selection
- **No STUN/TURN**: `iceServers: []` — relies entirely on direct TailScale IPs

### Video Settings
- **Resolution**: 160×120 (QCIF) — minimal payload
- **Framerate**: ideal 12fps, max 15fps
- **Codec**: VP8 preferred via SDP reordering
- **Bitrate**: capped at 200 kbps via `b=AS:200` in SDP
- **Audio**: Disabled — video-only to reduce payload
- **Camera**: Rear-facing environment camera

### Network
- **Direct IP**: No STUN/TURN, pure direct TailScale P2P
- **HTTP Signaling**: Lightweight HTTP POST for SDP/ICE exchange
- **TailScale**: Use TailScale IPs (100.x.x.x) for direct P2P connections

## Architecture

### Vehicle Mode (Flutter app on phone)
- **Camera Capture**: flutter_webrtc with QCIF constraints (no audio)
- **WebRTC Sender**: Creates offer, sends video-only track
- **Signaling**: HTTP endpoint on port 8888 for SDP/ICE exchange with browsers
- **UI**: Shows streaming status, viewer URL, and "Stop & Disconnect" button

### Web Browser Viewer
- **HTML/JS Viewer**: Located at `web/viewer/index.html`
- **Watch-Only**: No controls, just video stream + stats
- **Real-Time Stats**: Bitrate, FPS, packet loss display
- **HTTP Signaling**: Connects via vehicle's HTTP signaling endpoint (port 8888)

### Signaling Server
- **Dart HTTP Server**: `bin/signaling_server.dart`
- **Port 8888**: Handles SDP exchange and ICE candidates
- **CORS Enabled**: Allows web browser connections
- **Embedded Viewer**: Serves the HTML viewer at `/viewer/`

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
    └── vehicle_screen.dart      # Vehicle mode UI with viewer info + disconnect

bin/
└── signaling_server.dart        # HTTP signaling server for web viewers

web/viewer/
└── index.html                   # Web browser viewer interface
```

## Connection Flow

### Web Browser → Vehicle
1. Vehicle app starts on phone, begins capturing camera (video only)
2. Vehicle starts HTTP signaling server on port 8888
3. Browser opens `http://vehicle-ip:8888/viewer/`
4. Browser creates WebRTC offer (VP8-preferred SDP, b=AS:200)
5. Offer sent via HTTP POST to `/signal`
6. Vehicle responds with answer + ICE candidates
7. P2P connection established directly via TailScale IP
8. Browser receives video-only stream (read-only)

## SDP Modifications Applied

Both Flutter (`webrtc_service.dart`) and the web viewer (`index.html`) apply `_modifySdp` / `modifySdp` to every offer and answer:
- Reorders video payload types to put VP8 first
- Inserts `b=AS:200` after the `c=` line in the video section

## Common Technologies & Packages

- **flutter_webrtc**: ^0.9.48 - WebRTC implementation
- **flutter_riverpod**: ^2.5.1 - State management
- **http**: ^1.2.2 - HTTP signaling
- **permission_handler**: ^11.3.1 - Camera permissions

## Platform Permissions

### Android
- Camera, Internet, Network state permissions in `AndroidManifest.xml`

### iOS
- Camera, Local Network usage descriptions in `Info.plist`

## Development Notes

- **TailScale Network**: Ensure phone and viewing device are on the same TailScale network
- **IP Discovery**: Use `tailscale ip -4` on the phone to get its IP
- **Permission Handling**: Camera permission required on first launch (microphone no longer needed)
- **Connection States**: Proper UI feedback for initializing/streaming/disconnected states
- **Signaling Server**: MUST be running for web browser connections
- **Disconnect**: Use the "Stop & Disconnect" button in the app to properly stop the camera

## Hardware Integration (Future)

For actual motor/servo control from vehicle phone:
- USB-Serial: ESP32/Arduino via USB OTG
- Bluetooth: BLE to microcontroller
- WiFi: UDP commands to WiFi-enabled motor controller

## Testing Connection

1. Start the Flutter app on the phone (Vehicle Mode)
2. Start signaling server: `dart bin/signaling_server.dart`
3. Get phone's TailScale IP: `tailscale ip -4`
4. On another device, open browser to: `http://phone-ip:8888/viewer/`
5. Enter the phone's TailScale IP and click "Connect"
6. Video stream should appear in browser

## Usage

1. Install app on phone
2. Grant camera permission
3. Tap "Start Vehicle Mode"
4. The app will show the viewer URL
5. On your computer/other device, open the browser to the shown URL
6. View the live FPV stream with real-time stats
7. Tap "Stop & Disconnect" to stop streaming and release the camera
