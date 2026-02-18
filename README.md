<div align="center">

<img src="https://img.shields.io/badge/PhoneCam-Use%20Your%20Phone%20as%20a%20Webcam-6C63FF?style=for-the-badge&logo=android&logoColor=white" alt="PhoneCam"/>

# 📱 PhoneCam — Phone as Webcam for Mac

**The fastest, highest-quality way to use your Android phone as a webcam on macOS.**  
Stream at **1080p/60fps** over USB or WiFi. Works with OBS Studio, Zoom, Google Meet, Teams, FaceTime — any app that uses a camera.

[![GitHub release](https://img.shields.io/github/v/release/RanaAhmar/phonecam?style=flat-square&color=6C63FF)](https://github.com/RanaAhmar/phonecam/releases/latest)
[![Android](https://img.shields.io/badge/Android-8.0%2B-green?style=flat-square&logo=android)](https://github.com/RanaAhmar/phonecam/releases/latest)
[![macOS](https://img.shields.io/badge/macOS-12.3%2B-blue?style=flat-square&logo=apple)](https://github.com/RanaAhmar/phonecam/releases/latest)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow?style=flat-square)](LICENSE)
[![Stars](https://img.shields.io/github/stars/RanaAhmar/phonecam?style=flat-square&color=orange)](https://github.com/RanaAhmar/phonecam/stargazers)

---

### 🚀 One-Click Install

| Platform | Download |
|----------|----------|
| 🍎 **Mac** (macOS 12.3+) | [⬇️ Download PhoneCam.dmg](https://github.com/RanaAhmar/phonecam/releases/latest/download/PhoneCam.dmg) |
| 🤖 **Android** (Android 8+) | [⬇️ Download PhoneCam.apk](https://github.com/RanaAhmar/phonecam/releases/latest/download/PhoneCam.apk) |

> **Mac**: Open the `.dmg`, drag PhoneCam to Applications, and launch it.  
> **Android**: Open the `.apk` on your phone. If prompted, allow "Install from unknown sources".

---

</div>

## ✨ Why PhoneCam?

Your phone has a **better camera than most webcams** — 4K sensor, optical image stabilization, portrait mode. PhoneCam unlocks it as a professional webcam with zero subscription fees.

| Feature | PhoneCam | Camo | DroidCam |
|---------|----------|------|----------|
| **USB (wired) mode** | ✅ | ❌ | ✅ |
| **1080p / 60fps** | ✅ | ✅ | ❌ |
| **OBS Virtual Camera** | ✅ | Partial | ❌ |
| **Auto-discovery (mDNS)** | ✅ | ✅ | ❌ |
| **Open source** | ✅ | ❌ | ❌ |
| **Price** | **Free** | $39.99/yr | Freemium |

---

## 🎯 Key Features

- **⚡ Ultra-low latency** — < 30ms over USB, < 100ms over WiFi
- **🎥 1080p/60fps** — full HD, silky smooth
- **🔌 USB-first** — wired connection for zero-lag OBS streaming
- **📡 WiFi streaming** — go wireless when you need to move around
- **🔍 Auto-discovery** — finds your phone automatically via Bonjour/mDNS
- **🔄 Auto-reconnect** — recovers from drops automatically
- **📺 Virtual camera** — appears as "PhoneCam" in every app on your Mac
- **🎛️ OBS Studio optimized** — plug and play, no configuration needed
- **🔒 100% local** — no cloud, no accounts, no data leaves your network
- **🆓 Free & open source** — MIT licensed

---

## 📦 Installation

### Mac App — One Click

1. **[Download PhoneCam.dmg](https://github.com/RanaAhmar/phonecam/releases/latest/download/PhoneCam.dmg)**
2. Open the `.dmg` file
3. Drag **PhoneCam** into your **Applications** folder
4. Launch PhoneCam from Applications or Spotlight (`⌘ Space` → "PhoneCam")
5. On first launch: **System Preferences → Privacy & Security → Allow** (for the virtual camera extension)

> PhoneCam lives in your **menu bar** — look for the 📷 icon.

### Android App — One Click

**Option A: Direct APK (easiest)**
1. **[Download PhoneCam.apk](https://github.com/RanaAhmar/phonecam/releases/latest/download/PhoneCam.apk)**
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

---

## 🚀 Quick Start (30 seconds)

### USB Connection — Best for OBS & Streaming

```
1. Enable USB Debugging on your Android phone  →  see USB_DEBUGGING.md
2. Install ADB on Mac:  brew install android-platform-tools
3. Connect phone to Mac via USB cable
4. Open PhoneCam on Mac  →  phone is detected automatically
5. Open PhoneCam on Android  →  streaming starts
6. OBS: Add Source → Video Capture Device → "PhoneCam"  ✅
```

### WiFi Connection — Best for Flexibility

```
1. Connect phone and Mac to the same WiFi network
2. Open PhoneCam on Mac
3. Open PhoneCam on Android  →  your Mac appears in the list
4. Tap your Mac  →  streaming starts instantly  ✅
```

---

## 🎬 OBS Studio Setup

1. Open OBS Studio
2. **Sources** panel → click **+** → **Video Capture Device**
3. Name it (e.g. "Phone Camera") → **OK**
4. **Device** dropdown → select **"PhoneCam"**
5. Click **OK** — your phone's camera appears in OBS at 1080p/60fps ✅

📖 [Full OBS Setup Guide →](docs/OBS_SETUP.md)

---

## ⚙️ System Requirements

### Mac
| Requirement | Minimum |
|-------------|---------|
| macOS | 12.3 Monterey or later |
| Chip | Apple Silicon (M1+) or Intel |
| RAM | 4 GB |
| Xcode (build only) | 14+ |

### Android
| Requirement | Minimum |
|-------------|---------|
| Android | 8.0 (Oreo) or later |
| Camera | Camera2 API support |
| Connection | WiFi or USB |

---

## 🏗️ Architecture

```
Android Phone                          Mac
─────────────────────────────────────────────────────
Camera2 API                            CoreMediaIO
    ↓                                  Virtual Camera
MediaCodec (H.264)                         ↑
    ↓                                  VideoToolbox
TCP Stream ──── USB/WiFi ──────────→  H.264 Decoder
    ↓                                      ↑
Droid Protocol                         WifiReceiver /
(binary framing)                       UsbReceiver
```

📖 [Full Architecture Docs →](docs/ARCHITECTURE.md)

---

## 📚 Documentation

| Guide | Description |
|-------|-------------|
| [📖 OBS Setup](docs/OBS_SETUP.md) | Step-by-step OBS Studio configuration |
| [🔌 USB Debugging](docs/USB_DEBUGGING.md) | Enable ADB on your Android phone |
| [🏗️ Architecture](docs/ARCHITECTURE.md) | Technical deep-dive |
| [📡 Protocol Spec](protocol/PROTOCOL.md) | Binary streaming protocol |

---

## 🛠️ Building from Source

### Prerequisites
- **Android**: Android Studio / JDK 17
- **Mac**: Xcode 14+, macOS 12.3+, Apple Developer account (for virtual camera signing)

### Android
```bash
git clone https://github.com/RanaAhmar/phonecam.git
cd phonecam/android
./gradlew assembleDebug
adb install app/build/outputs/apk/debug/app-debug.apk
```

### Mac
```bash
git clone https://github.com/RanaAhmar/phonecam.git
open phonecam/mac/PhoneCam.xcodeproj
# Set your Team in Signing & Capabilities → Build & Run (⌘R)
```

> **Note on virtual camera signing**: The virtual camera (CoreMediaIO System Extension) requires a valid Apple Developer certificate. Without it, the app preview works but the camera won't appear in OBS/Zoom. [Learn more →](docs/ARCHITECTURE.md#virtual-camera)

---

## 🤝 Contributing

Contributions are welcome! Please:

1. Fork the repo
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## 📄 License

MIT License — see [LICENSE](LICENSE) for details.

---

## 🙏 Acknowledgements

Built with:
- [Camera2 API](https://developer.android.com/training/camera2) — Android camera capture
- [MediaCodec](https://developer.android.com/reference/android/media/MediaCodec) — Hardware H.264 encoding
- [VideoToolbox](https://developer.apple.com/documentation/videotoolbox) — Hardware H.264 decoding
- [CoreMediaIO](https://developer.apple.com/documentation/coremediaio) — Virtual camera driver
- [Bonjour](https://developer.apple.com/bonjour/) — Zero-config device discovery

---

<div align="center">

**Made with ❤️ for content creators, streamers, and developers**

[⬆ Back to top](#-phonecam--phone-as-webcam-for-mac)

</div>
