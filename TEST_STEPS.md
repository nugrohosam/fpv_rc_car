# 🎯 Complete Testing Steps for Automatic Connection

## What's Been Set Up

✅ Phone app with camera/mic capture
✅ WebRTC service in phone app
✅ PC signaling server (port 8888)
✅ Web browser viewer
✅ Phone polls signaling server for connections

## 🚀 How to Test Right Now

### Step 1: Start Signaling Server

Open terminal on your PC:
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

Example output: `100.x.x.x` - **save this IP!**

### Step 3: Run Phone App

```bash
flutter run -d 7011e0dbfcf5
```

### Step 4: On Phone App

1. Complete setup (enter TailScale IP if first time)
2. Tap "Start Vehicle Mode"
3. Grant camera/mic permissions

**Important:** The phone app needs to know your **PC's IP** to poll for connections!

### Step 5: Open Web Browser

```
http://localhost:8888/viewer/
```

### Step 6: Connect

In the browser:
1. Enter your **phone's** TailScale IP
2. Click "Connect"

## What Should Happen

1. Browser creates WebRTC offer
2. Sends to signaling server (localhost:8888)
3. Phone polls server, finds offer
4. Phone creates answer and sends back
5. Browser receives answer
6. **Video stream appears!** 🎥

## 🔧 If It Doesn't Work

### Check Signaling Server
```bash
curl http://localhost:8888/viewer/
```
Should show HTML page.

### Check Phone Can Reach PC
On phone (if you have terminal):
```bash
ping <your-pc-tailscale-ip>
```

### Check Server Logs
The terminal running `dart bin/signaling_server.dart` should show:
- `📨 GET /` - Browser loading page
- `📦 Signal: offer` - Browser sending offer
- `📦 Answer received from phone` - Phone responding

---

## 🎯 The Key Insight

The phone needs to poll `http://<YOUR-PC-IP>:8888/poll` every 2 seconds to check for browser connection requests.

Currently the phone app is configured but might need your **PC's IP** to connect to!
