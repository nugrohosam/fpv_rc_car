# Connection Troubleshooting

## Issue: Can't connect from PC browser to phone

### Step 1: Verify TailScale Connection

On your **PC**, run:
```bash
ping <phone-tailscale-ip>
```

Replace `<phone-tailscale-ip>` with the IP you entered in the app (e.g., `ping 100.x.x.x`)

**If ping fails:**
- TailScale is not properly connected between PC and phone
- Both devices need to be on the same TailScale network
- Check TailScale status on both devices

### Step 2: Check if Port 8080 is Open

The current setup requires an HTTP signaling server, but **Flutter mobile apps cannot run HTTP servers**.

### Solution: Use Alternative Signaling

We need to either:
1. Run the signaling server on your PC (not phone)
2. Use a cloud-based signaling service
3. Use WebRTC with manual SDP exchange

### Quick Test: WebRTC Direct Connection

For testing, try this approach:
1. Phone app captures camera/mic
2. Browser creates WebRTC offer
3. Manually copy/paste SDP between phone and browser

This removes the need for a signaling server but requires manual steps.

## Recommended Solution

Run the signaling server on your **PC** instead of the phone:

```bash
# On your PC
dart bin/signaling_server.dart
```

Then update the phone app to connect to YOUR PC's IP instead of trying to run the server on the phone.
