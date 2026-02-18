# Droid Camera

**Turn your Android phone into a high-quality wireless webcam for your Mac.**

Droid Camera streams your phone's camera to your Mac over USB or WiFi, creating a virtual webcam device that works with OBS Studio, Zoom, Google Meet, Microsoft Teams, FaceTime, and any app that uses a standard macOS camera.

---

## Features

- **USB-first** — zero-latency wired connection via ADB (< 30ms)
- **WiFi support** — wireless convenience (< 100ms)
- **1080p/60fps** — full HD streaming at 60 frames per second
- **OBS-optimized** — appears as a standard Video Capture Device in OBS
- **Virtual camera** — works with all macOS camera apps automatically
- **Auto-discovery** — finds devices on your network via Bonjour/mDNS
- **Auto-reconnect** — recovers from network interruptions automatically

---

## Requirements

### Android App
- Android 8.0 (API 26) or higher
- Camera2 API support
- WiFi or USB connectivity

### Mac App
- macOS 12.3 (Monterey) or higher
- Apple Silicon or Intel
- 4GB RAM minimum
- Apple Developer certificate (for virtual camera System Extension)

---

## Quick Start

### USB Connection (Recommended for OBS)

1. **Enable USB Debugging** on your Android phone:
   - Go to Settings → About Phone → tap Build Number 7 times
   - Go to Settings → Developer Options → enable USB Debugging
   - See [USB_DEBUGGING.md](USB_DEBUGGING.md) for detailed instructions

2. **Install ADB** on your Mac:
   ```bash
   brew install android-platform-tools
   ```

3. **Connect your phone** to your Mac via USB cable

4. **Launch Droid Camera** on your Mac — it will auto-detect the phone

5. **Open the Android app** — streaming starts automatically

6. **Open OBS** → Add Source → Video Capture Device → select **"Droid Camera"**

See [OBS_SETUP.md](OBS_SETUP.md) for the full OBS guide.

### WiFi Connection

1. Ensure your phone and Mac are on the **same WiFi network**
2. Launch the **Mac app** — it starts listening for connections
3. Open the **Android app** — your Mac appears in the device list
4. Tap your Mac to connect
5. Streaming starts automatically

---

## Building from Source

### Android App

```bash
cd android
./gradlew assembleDebug
adb install app/build/outputs/apk/debug/app-debug.apk
```

Requirements: Android Studio, JDK 17

### Mac App

```
1. Open mac/DroidCam.xcodeproj in Xcode
2. Set your Team (Apple Developer account) in Signing & Capabilities
3. Product → Build (⌘B)
4. Product → Run (⌘R)
```

Requirements: Xcode 14+, macOS 12.3+, Apple Developer account

> **Note**: The virtual camera (CoreMediaIO System Extension) requires a valid Apple Developer certificate. Without signing, the virtual camera won't be visible to other apps, but the app will still run and show the preview.

---

## Project Structure

```
Droid/
├── android/          Android app (Kotlin)
├── mac/              Mac app (Swift)
├── protocol/         Streaming protocol specification
└── docs/             Documentation
```

See [ARCHITECTURE.md](ARCHITECTURE.md) for technical details.

---

## Performance

| Connection | Latency | Frame Rate | Quality |
|------------|---------|------------|---------|
| USB        | < 30ms  | 60fps      | Lossless |
| WiFi       | < 100ms | 60fps      | H.264 8Mbps |

---

## Competitors

| App | USB | Price | OBS-Optimized |
|-----|-----|-------|---------------|
| **Droid Camera** | ✅ | Free | ✅ |
| Camo | ❌ | $39.99/yr | Partial |
| DroidCam | ✅ | Freemium | No |
| Iriun | ❌ | Freemium | No |

---

## License

MIT License — see LICENSE file.
