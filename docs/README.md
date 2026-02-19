# PhoneCam

**Turn your Android phone into a high-quality wireless webcam for your Mac.**

PhoneCam streams your phone's camera to your Mac over USB or WiFi, creating a virtual webcam device that works with OBS Studio, Zoom, Google Meet, Microsoft Teams, FaceTime, and any app that uses a standard macOS camera.

## Features

**USB connection** gives you a wired connection via ADB with under 30ms latency, while **WiFi support** provides wireless convenience at under 100ms. Both modes support **1080p at 60fps**. PhoneCam appears in OBS as a standard Video Capture Device and in every other macOS camera app automatically. It finds your devices on the network through Bonjour and reconnects on its own if the connection drops.

## Requirements

**Android App**
- Android 8.0 (API 26) or higher
- Camera2 API support
- WiFi or USB connectivity

**Mac App**
- macOS 12.3 (Monterey) or higher
- Apple Silicon or Intel
- 4GB RAM minimum
- Apple Developer certificate (for virtual camera System Extension)

## Quick Start

### USB Connection (Recommended for OBS)

1. **Enable USB Debugging** on your Android phone:
   - Go to Settings > About Phone > tap Build Number 7 times
   - Go to Settings > Developer Options > enable USB Debugging
   - See [USB_DEBUGGING.md](USB_DEBUGGING.md) for detailed instructions

2. **Install ADB** on your Mac:
   ```bash
   brew install android-platform-tools
   ```

3. **Connect your phone** to your Mac via USB cable

4. **Launch PhoneCam** on your Mac — it will auto-detect the phone

5. **Open the Android app** — streaming starts automatically

6. **Open OBS** > Add Source > Video Capture Device > select **"PhoneCam"**

See [OBS_SETUP.md](OBS_SETUP.md) for the full OBS guide.

### WiFi Connection

1. Ensure your phone and Mac are on the **same WiFi network**
2. Launch the **Mac app** and it will start listening for connections
3. Open the **Android app** — your Mac appears in the device list
4. Tap your Mac to connect and streaming starts automatically

## Building from Source

**Android App**

```bash
cd android
./gradlew assembleDebug
adb install app/build/outputs/apk/debug/app-debug.apk
```

Requirements: Android Studio, JDK 17

**Mac App**

1. Open `mac/DroidCam.xcodeproj` in Xcode
2. Set your Team (Apple Developer account) in Signing & Capabilities
3. Product > Build (⌘B)
4. Product > Run (⌘R)

Requirements: Xcode 14+, macOS 12.3+, Apple Developer account

> **Note**: The virtual camera requires a valid Apple Developer certificate. Without signing, the virtual camera won't be visible to other apps, but the app will still run and show the preview.

## Project Structure

```
PhoneCam/
├── android/          Android app (Kotlin)
├── mac/              Mac app (Swift)
├── protocol/         Streaming protocol specification
└── docs/             Documentation
```

See [ARCHITECTURE.md](ARCHITECTURE.md) for technical details.

## Performance

| Connection | Latency | Frame Rate | Quality |
|------------|---------|------------|---------|
| USB | under 30ms | 60fps | Lossless |
| WiFi | under 100ms | 60fps | H.264 8Mbps |

## Compared to Alternatives

| App | USB | Price | OBS Ready |
|-----|-----|-------|-----------|
| **PhoneCam** | Yes | Free | Yes |
| Camo | No | $39.99/yr | Partial |
| DroidCam | Yes | Freemium | No |
| Iriun | No | Freemium | No |

## License

MIT License. See LICENSE file for details.
