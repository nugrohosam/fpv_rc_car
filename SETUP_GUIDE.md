# 🚀 FPV RC Car - Automatic Connection Setup

## Architecture (Fixed)

```
PC Browser ←→ PC Signaling Server (localhost:8888) ←→ Phone App (via TailScale)
```

## Step-by-Step Setup

### Step 1: Start Signaling Server on PC

```bash
cd /Users/nugrohosam/Work/Internal/fpv_rc_car
dart bin/signaling_server.dart
```

You should see:
```
🚀 Signaling server running on http://0.0.0.0:8888
```

### Step 2: Get Your PC's TailScale IP

```bash
tailscale ip -4
```

Example: `100.x.x.x`

### Step 3: Open Web Browser

Navigate to:
```
http://localhost:8888/viewer/
```

### Step 4: Enter Your Phone's IP

In the browser:
1. Enter your **phone's** TailScale IP (the one you set in the app)
2. Click "Connect"

### Step 5: The Magic Happens ✨

The browser will:
1. Create a WebRTC offer
2. Send it to the signaling server
3. Server waits for your phone to respond
4. Phone automatically accepts and streams video!

**Your phone app needs to be updated to auto-connect to the signaling server.**

---

## Current Issue

The phone app is **passively waiting** but not actively connecting to the signaling server. It needs to:
1. Poll the signaling server for pending offers
2. Automatically respond to connection requests

Let me update the phone app to do this automatically!

---

## Quick Test

While I update the app, try this:

**Open browser console** (F12) and look for errors when you click "Connect". This will show us exactly what's happening.
