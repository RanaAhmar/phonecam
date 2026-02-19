# OBS Studio Setup Guide

This guide explains how to use **PhoneCam** as a video source in OBS Studio.

## Prerequisites

- OBS Studio installed ([obsproject.com](https://obsproject.com))
- PhoneCam Mac app running
- Android phone connected (USB or WiFi)
- Virtual camera started in PhoneCam

## Step 1: Start the Virtual Camera

1. Open **PhoneCam** from the menu bar (camera icon)
2. Click **"Open PhoneCam..."**
3. Connect your phone (USB or WiFi)
4. Click **"Start Virtual Camera"**
5. The button changes to **"Stop Virtual Camera"** when the camera is active

## Step 2: Add the Camera Source in OBS

1. Open **OBS Studio**
2. In the **Sources** panel, click the **+** button
3. Select **Video Capture Device**
4. Name it (e.g., "Phone Camera") and click **OK**
5. In the **Device** dropdown, select **"PhoneCam"**
6. Click **OK**

Your phone's camera feed now appears in OBS at **1080p/60fps**.

## Step 3: Configure OBS for Best Quality

**Resolution Settings**
- In OBS: Settings > Video
- Set **Base (Canvas) Resolution** to `1920x1080`
- Set **Output (Scaled) Resolution** to `1920x1080`
- Set **Common FPS Values** to `60`

**Source Properties (Optional)**

Right-click the source > Properties:
- Resolution/FPS Type: Custom
- Resolution: 1920x1080
- FPS: 60

**For Streaming (Recommended Encoder Settings)**
- Settings > Output > Streaming
- Use a hardware encoder (VideoToolbox on Mac) to offload the CPU
- Bitrate: 6000 to 8000 Kbps for 1080p at 60fps

## Troubleshooting

**"PhoneCam" doesn't appear in OBS**
1. Make sure the virtual camera is **started** in the PhoneCam app
2. Restart OBS — it may need to rescan devices
3. Check that the Mac app has the required System Extension permission:
   - System Preferences > Privacy & Security > scroll down to find the extension
   - Click **Allow**

**Black screen in OBS**
1. Make sure your phone is connected and streaming (green status in Mac app)
2. Try disconnecting and reconnecting the phone
3. Check that the Android app is in the foreground

**Low frame rate or stuttering**

USB mode is recommended for OBS. Make sure your USB cable supports data transfer (not charge-only) and close other apps on your Mac to free up CPU.

**Camera appears rotated**

Use OBS's built-in Transform > Rotate to correct orientation, or use the rotation controls in the PhoneCam Mac app.

## Tips for Content Creators

USB connection gives the lowest latency and is ideal for live streaming. Use 1080p/60fps for the best quality in OBS. The virtual camera supports OBS's built-in filters and effects, and is compatible with OBS Virtual Camera output so you can chain them. It also works with NDI Tools if you have the NDI OBS plugin installed.
