# Quick Start Guide - PC Browser Viewing

## Setup Steps

### 1. Start the Signaling Server on Your PC

Open a terminal on your PC and run:

```bash
cd /Users/nugrohosam/Work/Internal/fpv_rc_car
dart bin/signaling_server.dart
```

You should see:
```
🚀 Signaling server running on http://0.0.0.0:8080
📱 Ready to receive WebRTC signals from browsers and Flutter apps
```

### 2. Get Your PC's TailScale IP

On your PC, run:
```bash
tailscale ip -4
```

Example output: `100.x.x.x`

### 3. Open Web Browser on Your PC

Open your web browser and navigate to:
```
http://localhost:8080/viewer/
```

### 4. Connect to Vehicle

In the web browser:
1. Enter your **phone's** TailScale IP (the one you set up in the app)
2. Click "Connect"

### 5. Connection Flow

```
PC Browser <--HTTP--> PC Signaling Server <--HTTP--> Phone App
                    (localhost:8080)         (via TailScale)
```

## How It Works

1. **Phone App**: Captures camera/mic, waits for connections
2. **PC Signaling Server**: Handles WebRTC handshake (SDP exchange)
3. **Web Browser**: Connects to signaling server, receives video stream

## Troubleshooting

### Can't connect?

1. **Check signaling server is running on PC**:
   ```bash
   curl http://localhost:8080/viewer/
   ```

2. **Check phone IP is correct**:
   - On phone: Check the IP you entered in setup
   - On PC: `ping <phone-ip>`

3. **Check firewall**:
   - Ensure port 8080 is not blocked
   - Try: `telnet localhost 8080`

4. **Check phone app**:
   - Make sure "Vehicle Mode" is active
   - Check camera/mic permissions granted
   - Look for connection status in app

## Architecture

```
┌─────────────┐         ┌──────────────────┐         ┌─────────────┐
│  Web Browser│ �───────▶│  Signaling Server│ ────────▶│  Phone App  │
│  (on PC)    │ HTTP    │  (running on PC) │ HTTP    │  (Vehicle)  │
│             │         │  localhost:8080  │         │             │
└─────────────┘         └──────────────────┘         └─────────────┘
                                                              │
                                                              │ WebRTC
                                                              │ (Video/Audio)
                                                              ▼
                                                     ┌─────────────┐
                                                     │  Camera/Mic │
                                                     └─────────────┘
```

The signaling server acts as a middleman to establish the WebRTC connection. Once connected, video flows directly from phone to browser via P2P WebRTC.
