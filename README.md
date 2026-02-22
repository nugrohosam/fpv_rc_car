# FPV RC Car - Low-Latency WebRTC Streaming

A Flutter-based FPV (First Person View) RC car project using WebRTC for ultra-low-latency video streaming. Mount a phone on your RC car and view the stream from any web browser!

## Features

- **Ultra-Low Latency Streaming**: Optimized WebRTC configuration for minimal delay
- **TailScale Integration**: Direct P2P connections using TailScale IPs (100.x.x.x)
- **Web Browser Viewing**: Watch the stream from any device with a web browser
- **Real-Time Stats**: Bitrate, FPS, and packet loss monitoring in the browser
- **Simple Setup**: Just one app on the vehicle phone, view from anywhere
- **Screen Wake Lock**: Phone screen stays on while vehicle mode is active

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

## Viewing the Stream

### Step 1: Start the Signaling Server on your PC

```bash
dart bin/signaling_server.dart
```

Expected output:
```
Signaling server running on http://0.0.0.0:8888
Ready to receive WebRTC signals from browsers and Flutter apps
```

### Step 2: Get your PC's TailScale IP

```bash
tailscale ip -4
```

Example output: `100.x.x.x` — save this IP.

### Step 3: Start Vehicle Mode on the phone

1. Open the app on your phone
2. Grant camera permission when prompted
3. Tap **"Start Vehicle Mode"**

### Step 4: Open the web viewer

In your browser, navigate to:
```
http://localhost:8888/viewer/
```

### Step 5: Connect

1. Enter your phone's TailScale IP
2. Click **"Connect"**
3. Video stream appears

### Connection Flow

```
PC Browser <--HTTP--> PC Signaling Server (localhost:8888) <--HTTP--> Phone App (via TailScale)
                                                                              |
                                                                              | WebRTC P2P
                                                                              v
                                                                       Phone Camera
```

1. Browser creates a WebRTC offer and sends it to the signaling server
2. Phone polls the signaling server every 2 seconds for pending offers
3. Phone creates an answer and sends it back through the signaling server
4. Direct P2P video connection is established over TailScale

## Web Browser Viewer

The web viewer provides:
- **Live Video Stream**: Low-latency video from the vehicle
- **Real-Time Stats**: Bitrate (kbps), FPS, and packet loss percentage
- **Connection Status**: Visual indicators for connection and signal state
- **Responsive Design**: Works on desktop, tablet, and mobile browsers

## Low-Latency Optimizations

### WebRTC Configuration
- **Bundle Policy**: `max-bundle` — all streams over single transport
- **RTCP Mux Policy**: `require` — RTCP multiplexed with RTP
- **No STUN/TURN**: `iceServers: []` — relies entirely on direct TailScale IPs

### Video Settings
- **Resolution**: 160×120 (QCIF) — minimal payload
- **Framerate**: ideal 12fps, max 15fps
- **Codec**: VP8 preferred via SDP reordering
- **Bitrate**: capped at 200 kbps via `b=AS:200` in SDP
- **Audio**: Disabled — video-only

### Network
- **Direct IP**: P2P connections over TailScale mesh network
- **HTTP Signaling**: Lightweight SDP/ICE exchange on port 8888

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

## Hardware Integration (Future)

For actual motor/servo control from the vehicle phone:

- **USB-Serial**: ESP32/Arduino via USB OTG
- **Bluetooth**: BLE to microcontroller
- **WiFi**: UDP commands to WiFi-enabled motor controller

## Troubleshooting

### Can't connect from browser to phone

**1. Verify TailScale is connected on both devices**
```bash
ping <phone-tailscale-ip>
```
If ping fails, check TailScale status on both devices.

**2. Verify the signaling server is running**
```bash
curl http://localhost:8888/viewer/
```
Should return an HTML page.

**3. Verify the phone app can reach the PC**

The phone polls `http://<PC-TailScale-IP>:8888/poll` every 2 seconds. Confirm the PC IP is correctly entered in the app and that port 8888 is not blocked by a firewall.

**4. Check signaling server logs**

The terminal running `dart bin/signaling_server.dart` should show:
- `GET /viewer/` — browser loading the page
- `Signal: offer` — browser sending an offer
- `Answer received` — phone responding

**5. Check phone app permissions**

Camera permission must be granted. Microphone permission is not required (audio is disabled).

### High latency

- Check network signal strength on both devices
- Ensure a good WiFi or cellular connection
- Use 5GHz WiFi if available
- The video resolution is already at minimum (160×120 QCIF)

### Web browser issues

- Use Chrome or Firefox for best WebRTC support
- Check the browser console (F12) for errors
- Try clearing browser cache and reloading

## Dependencies

- `flutter_webrtc: ^1.3.0` — WebRTC implementation
- `flutter_riverpod: ^2.5.1` — State management
- `http: ^1.2.2` — HTTP signaling
- `permission_handler: ^11.3.1` — Camera permissions
- `shared_preferences: ^2.2.2` — Persistent IP storage
- `wakelock_plus: ^1.3.4` — Keep screen on while streaming

## License

MIT License — feel free to use this project for your own FPV builds!
