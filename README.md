<div align="center">

<img src="https://img.shields.io/badge/PhoneCam-Use%20Your%20Phone%20as%20a%20Webcam-6C63FF?style=for-the-badge&logo=android&logoColor=white" alt="PhoneCam"/>

# PhoneCam

**The fastest, highest-quality way to use your Android phone as a webcam on macOS.**
Stream at **1080p/60fps** over USB or WiFi. Works with OBS Studio, Zoom, Google Meet, Teams, FaceTime and any app that uses a camera.

[![GitHub release](https://img.shields.io/github/v/release/RanaAhmar/phonecam?style=flat-square&color=6C63FF)](https://github.com/RanaAhmar/phonecam/releases/latest)
[![Android](https://img.shields.io/badge/Android-8.0%2B-green?style=flat-square&logo=android)](https://github.com/RanaAhmar/phonecam/releases/latest)
[![macOS](https://img.shields.io/badge/macOS-12.3%2B-blue?style=flat-square&logo=apple)](https://github.com/RanaAhmar/phonecam/releases/latest)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow?style=flat-square)](LICENSE)
[![Stars](https://img.shields.io/github/stars/RanaAhmar/phonecam?style=flat-square&color=orange)](https://github.com/RanaAhmar/phonecam/stargazers)

</div>

## Download

| Platform | Download |
|----------|----------|
| 🍎 **Mac** (macOS 12.3+) | [Download PhoneCam.dmg](https://github.com/RanaAhmar/phonecam/releases/latest/download/PhoneCam.dmg) |
| 🤖 **Android** (Android 8+) | [Download PhoneCam.apk](https://github.com/RanaAhmar/phonecam/releases/latest/download/PhoneCam.apk) |

**Mac:** Open the `.dmg`, drag PhoneCam to Applications, and launch it.
**Android:** Open the `.apk` on your phone. If prompted, allow "Install from unknown sources".

## Why PhoneCam?

Your phone has a better camera than most webcams — 4K sensor, optical image stabilization, portrait mode. PhoneCam unlocks it as a professional webcam with no subscription fees.

| Feature | PhoneCam | Camo | DroidCam |
|---------|----------|------|----------|
| **USB (wired) mode** | Yes | No | Yes |
| **1080p at 60fps** | Yes | Yes | No |
| **OBS Virtual Camera** | Yes | Partial | No |
| **Auto-discovery (mDNS)** | Yes | Yes | No |
| **Open source** | Yes | No | No |
| **Price** | **Free** | $39.99/yr | Freemium |

## Features

- **Ultra-low latency** — under 30ms over USB, under 100ms over WiFi
- **1080p/60fps** — full HD, smooth streaming
- **USB connection** — wired for zero-lag OBS streaming
- **WiFi streaming** — go wireless when you need flexibility
- **Auto-discovery** — finds your phone automatically via Bonjour
- **Auto-reconnect** — recovers from connection drops on its own
- **Virtual camera** — appears as "PhoneCam" in every app on your Mac
- **OBS Studio ready** — plug and play, no configuration needed
- **100% local** — no cloud, no accounts, no data leaves your network
- **Free and open source** — MIT licensed

## Installation

### Mac App

1. [Download PhoneCam.dmg](https://github.com/RanaAhmar/phonecam/releases/latest/download/PhoneCam.dmg)
2. Open the `.dmg` file
3. Drag **PhoneCam** into your **Applications** folder
4. Launch PhoneCam from Applications or Spotlight
5. On first launch: System Preferences > Privacy & Security > Allow (for the virtual camera extension)

PhoneCam lives in your **menu bar** — look for the camera icon.

### Android App

**Option A: Direct APK (easiest)**
1. [Download PhoneCam.apk](https://github.com/RanaAhmar/phonecam/releases/latest/download/PhoneCam.apk)
2. Open the file on your Android phone
3. Tap **Install** (allow "Install from unknown sources" if prompted)
4. Open PhoneCam and grant camera permission

**Option B: Build from source**
```bash
git clone https://github.com/RanaAhmar/phonecam.git
cd phonecam/android
./gradlew assembleRelease
adb install app/build/outputs/apk/release/app-release.apk
```

## Quick Start

### USB Connection (Best for OBS and streaming)

1. Enable USB Debugging on your Android phone — see [USB_DEBUGGING.md](docs/USB_DEBUGGING.md)
2. Install ADB on Mac: `brew install android-platform-tools`
3. Connect your phone to Mac via USB cable
4. Open PhoneCam on Mac — the phone is detected automatically
5. Open PhoneCam on Android — streaming starts
6. In OBS: Add Source > Video Capture Device > "PhoneCam"

### WiFi Connection (Best for flexibility)

1. Connect your phone and Mac to the same WiFi network
2. Open PhoneCam on Mac
3. Open PhoneCam on Android — your Mac appears in the list
4. Tap your Mac and streaming starts instantly

## OBS Studio Setup

1. Open OBS Studio
2. In the **Sources** panel, click **+** and select **Video Capture Device**
3. Name it (e.g. "Phone Camera") and click **OK**
4. In the **Device** dropdown, select **"PhoneCam"**
5. Click **OK** — your phone's camera appears in OBS at 1080p/60fps

[Full OBS Setup Guide](docs/OBS_SETUP.md)

## System Requirements

**Mac**

| Requirement | Minimum |
|-------------|---------|
| macOS | 12.3 Monterey or later |
| Chip | Apple Silicon or Intel |
| RAM | 4 GB |
| Xcode (build only) | 14+ |

**Android**

| Requirement | Minimum |
|-------------|---------|
| Android | 8.0 or later |
| Camera | Camera2 API support |
| Connection | WiFi or USB |

## Architecture

```
Android Phone                    Mac
Camera2 API                      CoreMediaIO Virtual Camera
    |                                    |
MediaCodec (H.264)               VideoToolbox H.264 Decoder
    |                                    |
TCP Stream over USB or WiFi      WifiReceiver / UsbReceiver
```

[Full Architecture Docs](docs/ARCHITECTURE.md)

## Documentation

| Guide | Description |
|-------|-------------|
| [OBS Setup](docs/OBS_SETUP.md) | Step-by-step OBS Studio configuration |
| [USB Debugging](docs/USB_DEBUGGING.md) | Enable ADB on your Android phone |
| [Architecture](docs/ARCHITECTURE.md) | Technical deep-dive |
| [Protocol Spec](protocol/PROTOCOL.md) | Binary streaming protocol |

## Building from Source

**Prerequisites**

- Android: Android Studio and JDK 17
- Mac: Xcode 14+, macOS 12.3+, Apple Developer account (for virtual camera signing)

**Android**
```bash
git clone https://github.com/RanaAhmar/phonecam.git
cd phonecam/android
./gradlew assembleDebug
adb install app/build/outputs/apk/debug/app-debug.apk
```

**Mac**
```bash
git clone https://github.com/RanaAhmar/phonecam.git
open phonecam/mac/PhoneCam.xcodeproj
# Set your Team in Signing & Capabilities then Build and Run
```

The virtual camera (CoreMediaIO System Extension) requires a valid Apple Developer certificate. Without it, the app preview works but the camera won't appear in OBS or Zoom. [Learn more](docs/ARCHITECTURE.md)

## Contributing

Contributions are welcome! Fork the repo, create a feature branch, commit your changes, and open a Pull Request.

## License

MIT License. See [LICENSE](LICENSE) for details.

## Acknowledgements

Built with [Camera2 API](https://developer.android.com/training/camera2), [MediaCodec](https://developer.android.com/reference/android/media/MediaCodec), [VideoToolbox](https://developer.apple.com/documentation/videotoolbox), [CoreMediaIO](https://developer.apple.com/documentation/coremediaio), and [Bonjour](https://developer.apple.com/bonjour/).

<div align="center">

Made with care for content creators, streamers, and developers.

</div>


---
### 🌟 Part of the [Stackaura](https://github.com/RanaAhmar) Ecosystem
*Empowering developers with automated tools and high-performance solutions.*

**Explore more:**
- 🚀 [All Projects](https://github.com/RanaAhmar?tab=repositories)
- 🛠️ [Daily Coding Tips](https://github.com/RanaAhmar/daily-coding-tips)
- 📊 [Profile Dashboard](https://github.com/RanaAhmar/RanaAhmar)

*If you find this project useful, please consider giving it a star! ⭐*
