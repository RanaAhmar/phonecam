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
                    │  PhoneCam Protocol│
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

## Component Details

### Android App

| Component | File | Responsibility |
|-----------|------|----------------|
| CameraManager | `camera/CameraManager.kt` | Camera2 capture and MediaCodec H.264 encoding |
| StreamingService | `streaming/StreamingService.kt` | Foreground service coordinating camera and transport |
| WifiStreamer | `network/WifiStreamer.kt` | TCP server, protocol handshake, frame delivery |
| UsbStreamer | `network/UsbStreamer.kt` | Same as WiFi but loopback-only via ADB tunnel |
| MdnsDiscovery | `discovery/MdnsDiscovery.kt` | NsdManager for mDNS registration and discovery |
| HomeFragment | `ui/HomeFragment.kt` | Device list and connect buttons |
| CameraFragment | `ui/CameraFragment.kt` | Live preview and controls |
| SettingsFragment | `ui/SettingsFragment.kt` | Resolution, FPS, and bitrate settings |

### Mac App

| Component | File | Responsibility |
|-----------|------|----------------|
| AppDelegate | `AppDelegate.swift` | App lifecycle and menu bar setup |
| MenuBarController | `MenuBarController.swift` | Status item and quick actions |
| BonjourDiscovery | `discovery/BonjourDiscovery.swift` | NetServiceBrowser and NetService publishing |
| DroidProtocol | `network/DroidProtocol.swift` | Binary packet framing and parsing |
| WifiReceiver | `network/WifiReceiver.swift` | TCP client, protocol handshake, frame reception |
| UsbReceiver | `network/UsbReceiver.swift` | IOKit USB monitoring and ADB port forwarding |
| VideoDecoder | `video/VideoDecoder.swift` | VTDecompressionSession H.264 to CVPixelBuffer |
| VirtualCameraDriver | `video/VirtualCameraDriver.swift` | CMIOExtension virtual camera device |
| MainWindowController | `MainWindowController.swift` | Main UI, preview, and device selection |
| SettingsWindowController | `SettingsWindowController.swift` | Settings UI |

## Streaming Protocol

See [../protocol/PROTOCOL.md](../protocol/PROTOCOL.md) for the full binary protocol specification.

The protocol uses a 22-byte header with a `DROID` magic sequence, type, sequence number, timestamp, and payload length, followed by H.264 Annex B video frames. A JSON handshake (HELLO/HELLO_ACK) is used on connection and keepalive PING/PONG packets are exchanged every 2 seconds. The same protocol runs over both USB and WiFi transports.

## USB Mode Architecture

```
Android (port 7878)  ──────────────────────────────────────────┐
     ↑                                                          │
     │ TCP server                                               │
     │                                                          │
  USB cable                                                     │
     │                                                          │
     ↓                                                          │
Mac: adb forward tcp:7878 tcp:7878                              │
     │                                                          │
     ↓                                                          │
Mac localhost:7878 ──── WifiReceiver (same code) ──────────────┘
```

The USB transport reuses the same protocol and receiver code as WiFi. ADB port forwarding creates a transparent tunnel. The Mac connects to `localhost:7878` which ADB forwards to the Android device's port `7878`.

## Performance Design Decisions

1. **Hardware H.264 encoding** on Android (MediaCodec) offloads CPU and enables 60fps at 1080p
2. **Hardware H.264 decoding** on Mac (VideoToolbox) keeps CPU overhead minimal
3. **TCP with `tcpNoDelay`** disables Nagle's algorithm for lowest latency
4. **Zero-copy pixel buffers** use `CVPixelBuffer` with `IOSurface` backing for GPU-accelerated display
5. **Annex B to AVCC conversion** in the decoder is required by VideoToolbox and is done in-place without extra copies
6. **CMIOExtension** (not the deprecated DAL plugin) is the modern API with better macOS integration

## Security Architecture

All communication is on the local network only — no cloud routing and no internet required. An optional PIN pairing using challenge-response after the HELLO handshake is available, as is optional TLS with a self-signed certificate. The USB streamer rejects non-loopback connections, and video frames are never written to disk.
