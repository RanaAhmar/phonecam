# Architecture Overview

## System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        Android Phone                             │
│                                                                  │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────────┐  │
│  │  Camera2 API │───▶│  MediaCodec  │───▶│ StreamingService │  │
│  │  (Capture)   │    │  (H.264 enc) │    │ (Foreground Svc) │  │
│  └──────────────┘    └──────────────┘    └────────┬─────────┘  │
│                                                    │             │
│                                          ┌─────────▼─────────┐  │
│                                          │  Transport Layer   │  │
│                                          │  ┌─────────────┐  │  │
│                                          │  │ WifiStreamer │  │  │
│                                          │  │  TCP :7878  │  │  │
│                                          │  └─────────────┘  │  │
│                                          │  ┌─────────────┐  │  │
│                                          │  │  UsbStreamer │  │  │
│                                          │  │  TCP :7878  │  │  │
│                                          │  └─────────────┘  │  │
│                                          └───────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                              │
                    ┌─────────▼─────────┐
                    │  Droid Protocol   │
                    │  Binary framing   │
                    │  over TCP         │
                    │  (USB or WiFi)    │
                    └─────────┬─────────┘
                              │
┌─────────────────────────────▼───────────────────────────────────┐
│                          Mac App                                  │
│                                                                   │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────────┐   │
│  │ WifiReceiver │    │  UsbReceiver │    │ BonjourDiscovery │   │
│  │  TCP client  │    │  IOKit +ADB  │    │  mDNS browser    │   │
│  └──────┬───────┘    └──────┬───────┘    └──────────────────┘   │
│         └──────────┬────────┘                                     │
│                    │                                              │
│           ┌────────▼────────┐                                    │
│           │  VideoDecoder   │                                    │
│           │  VideoToolbox   │                                    │
│           │  VTDecompression│                                    │
│           └────────┬────────┘                                    │
│                    │ CVPixelBuffer                                │
│         ┌──────────▼──────────┐                                  │
│         │  VirtualCameraDriver│                                  │
│         │  CoreMediaIO        │                                  │
│         │  CMIOExtension      │                                  │
│         └──────────┬──────────┘                                  │
│                    │                                              │
│         ┌──────────▼──────────────────────────────────────────┐  │
│         │           macOS Camera Framework                     │  │
│         │  OBS Studio │ Zoom │ Meet │ Teams │ FaceTime │ Any  │  │
│         └─────────────────────────────────────────────────────┘  │
└───────────────────────────────────────────────────────────────────┘
```

---

## Component Details

### Android App

| Component | File | Responsibility |
|-----------|------|----------------|
| CameraManager | `camera/CameraManager.kt` | Camera2 capture + MediaCodec H.264 encoding |
| StreamingService | `streaming/StreamingService.kt` | Foreground service coordinating camera + transport |
| WifiStreamer | `network/WifiStreamer.kt` | TCP server, protocol handshake, frame delivery |
| UsbStreamer | `network/UsbStreamer.kt` | Same as WiFi but loopback-only (ADB tunnel) |
| MdnsDiscovery | `discovery/MdnsDiscovery.kt` | NsdManager for mDNS registration and discovery |
| HomeFragment | `ui/HomeFragment.kt` | Device list, connect buttons |
| CameraFragment | `ui/CameraFragment.kt` | Live preview, controls |
| SettingsFragment | `ui/SettingsFragment.kt` | Resolution, FPS, bitrate settings |

### Mac App

| Component | File | Responsibility |
|-----------|------|----------------|
| AppDelegate | `AppDelegate.swift` | App lifecycle, menu bar setup |
| MenuBarController | `MenuBarController.swift` | Status item, quick actions |
| BonjourDiscovery | `discovery/BonjourDiscovery.swift` | NetServiceBrowser + NetService publishing |
| DroidProtocol | `network/DroidProtocol.swift` | Binary packet framing/parsing |
| WifiReceiver | `network/WifiReceiver.swift` | TCP client, protocol handshake, frame reception |
| UsbReceiver | `network/UsbReceiver.swift` | IOKit USB monitoring, ADB port forwarding |
| VideoDecoder | `video/VideoDecoder.swift` | VTDecompressionSession H.264 → CVPixelBuffer |
| VirtualCameraDriver | `video/VirtualCameraDriver.swift` | CMIOExtension virtual camera device |
| MainWindowController | `MainWindowController.swift` | Main UI, preview, device selection |
| SettingsWindowController | `SettingsWindowController.swift` | Settings UI |

---

## Streaming Protocol

See [../protocol/PROTOCOL.md](../protocol/PROTOCOL.md) for the full binary protocol specification.

**Summary:**
- 22-byte header: `DROID` magic + type + seq + timestamp + payload length
- H.264 Annex B video frames (type `0x10`)
- JSON handshake (HELLO/HELLO_ACK)
- Keepalive PING/PONG every 2 seconds
- Same protocol over both USB and WiFi transports

---

## USB Mode Architecture

```
Android (port 7878)  ←──────────────────────────────────────────┐
     ↑                                                           │
     │ TCP server                                                │
     │                                                           │
  USB cable                                                      │
     │                                                           │
     ↓                                                           │
Mac: adb forward tcp:7878 tcp:7878                               │
     │                                                           │
     ↓                                                           │
Mac localhost:7878 ──── WifiReceiver (same code) ───────────────┘
```

The USB transport reuses the exact same protocol and receiver code as WiFi. ADB port forwarding creates a transparent tunnel — the Mac connects to `localhost:7878` which ADB forwards to the Android device's port `7878`.

---

## Performance Design Decisions

1. **Hardware H.264 encoding** on Android (MediaCodec with `CONFIGURE_FLAG_ENCODE`) — offloads CPU, enables 60fps at 1080p
2. **Hardware H.264 decoding** on Mac (VideoToolbox with `EnableHardwareAcceleratedVideoDecoder`) — minimal CPU overhead
3. **TCP with `tcpNoDelay`** — disables Nagle's algorithm for lowest latency
4. **Zero-copy pixel buffers** — `CVPixelBuffer` with `IOSurface` backing for GPU-accelerated display
5. **Annex B → AVCC conversion** in the decoder — required by VideoToolbox but done in-place without extra copies
6. **CMIOExtension** (not deprecated DAL plugin) — modern API with better macOS integration

---

## Security Architecture

- **Local network only** — no cloud routing, no internet required
- **Optional PIN pairing** — challenge-response after HELLO handshake
- **TLS support** — optional encrypted transport (self-signed cert)
- **USB loopback only** — UsbStreamer rejects non-loopback connections
- **No storage** — video frames are never written to disk
