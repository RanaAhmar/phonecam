# Droid Camera — Streaming Protocol Specification

## Overview

Both USB and WiFi transports use the same binary framing protocol. The only difference is the underlying transport (TCP socket vs ADB-forwarded TCP socket).

- **Port**: `7878` (TCP)
- **Discovery UDP broadcast**: `7879`
- **Encoding**: H.264 (Baseline/Main profile)

---

## Packet Frame Structure

Every packet sent over the wire uses this structure:

```
+------------------+--------+--------+----------+----------+-----------+
| Magic (5 bytes)  | Type   | SeqNum | Timestamp| PayloadLen| Payload  |
|  "DROID"         | 1 byte | 4 bytes| 8 bytes  | 4 bytes   | N bytes  |
+------------------+--------+--------+----------+----------+-----------+
```

Total header size: **22 bytes**

| Field       | Size     | Type       | Description                          |
|-------------|----------|------------|--------------------------------------|
| Magic       | 5 bytes  | ASCII      | Always `44 52 4F 49 44` ("DROID")   |
| Type        | 1 byte   | uint8      | Frame type (see below)               |
| SeqNum      | 4 bytes  | uint32 BE  | Monotonically increasing sequence    |
| Timestamp   | 8 bytes  | int64 BE   | Microseconds since Unix epoch        |
| PayloadLen  | 4 bytes  | uint32 BE  | Length of payload in bytes           |
| Payload     | N bytes  | bytes      | Type-specific payload                |

---

## Frame Types

| Value | Name       | Direction        | Description                          |
|-------|------------|------------------|--------------------------------------|
| 0x01  | HELLO      | Android → Mac    | Initial handshake / capability info  |
| 0x02  | HELLO_ACK  | Mac → Android    | Handshake acknowledgment             |
| 0x03  | SETTINGS   | Mac → Android    | Request resolution/fps change        |
| 0x04  | SETTINGS_ACK | Android → Mac  | Settings applied confirmation        |
| 0x10  | VIDEO      | Android → Mac    | H.264 NAL unit(s)                    |
| 0x20  | PING       | Either direction | Keepalive ping                       |
| 0x21  | PONG       | Either direction | Keepalive pong                       |
| 0xFF  | DISCONNECT | Either direction | Graceful disconnect notification     |

---

## Payload Formats

### HELLO (0x01) — Android → Mac

JSON-encoded UTF-8 string:

```json
{
  "version": 1,
  "device": "Pixel 7 Pro",
  "capabilities": {
    "resolutions": ["720p", "1080p", "4K"],
    "frameRates": [15, 30, 60],
    "codec": "H264"
  },
  "selectedResolution": "1080p",
  "selectedFps": 60
}
```

### HELLO_ACK (0x02) — Mac → Android

JSON-encoded UTF-8 string:

```json
{
  "version": 1,
  "accepted": true,
  "requestedResolution": "1080p",
  "requestedFps": 60
}
```

### SETTINGS (0x03) — Mac → Android

JSON-encoded UTF-8 string:

```json
{
  "resolution": "1080p",
  "fps": 60,
  "bitrate": 8000000
}
```

### VIDEO (0x10) — Android → Mac

Raw H.264 NAL unit bytes. May contain one or more NAL units concatenated with Annex B start codes (`00 00 00 01`).

The first VIDEO frame after connection MUST include SPS and PPS NAL units.

### PING / PONG (0x20 / 0x21)

Empty payload (PayloadLen = 0). Sent every 2 seconds. If no PONG received within 5 seconds, connection is considered lost.

### DISCONNECT (0xFF)

Empty payload. Sent before intentional disconnect.

---

## Connection Sequence

```
Android                              Mac
   |                                  |
   |  [TCP connect to port 7878]      |
   |--------------------------------->|
   |                                  |
   |  HELLO (capabilities)            |
   |--------------------------------->|
   |                                  |
   |          HELLO_ACK (settings)    |
   |<---------------------------------|
   |                                  |
   |  VIDEO frames (continuous)       |
   |--------------------------------->|
   |                                  |
   |  PING (every 2s)                 |
   |<-------------------------------->|
   |                                  |
   |  DISCONNECT (on user action)     |
   |--------------------------------->|
   |                                  |
   |  [TCP close]                     |
   |--------------------------------->|
```

---

## USB Mode

In USB mode, the Mac runs:
```bash
adb forward tcp:7878 tcp:7878
```

This tunnels the Mac's local port `7878` to the Android device's port `7878`. The Android app listens on port `7878` in server mode. The Mac then connects to `localhost:7878` — identical to WiFi mode from the protocol perspective.

---

## WiFi Discovery (UDP)

Android broadcasts a UDP packet on port `7879` every 2 seconds:

```json
{
  "service": "droidcam",
  "version": 1,
  "device": "Pixel 7 Pro",
  "port": 7878,
  "ip": "192.168.1.42"
}
```

Mac listens on UDP port `7879` and populates the device list. mDNS (`_droidcam._tcp`) is used as the primary discovery mechanism; UDP broadcast is the fallback.

---

## Security

- Optional PIN pairing: After HELLO_ACK, if PIN is configured, Mac sends a `CHALLENGE` and Android must respond with the correct PIN hash.
- TLS: Both sides support optional TLS wrapping of the TCP connection (self-signed certificate generated on first launch).
