import Foundation

/// Implements the Droid Camera binary streaming protocol on the Mac side.
/// Mirrors the Android Protocol.kt implementation.
///
/// Packet format: [DROID(5)] [Type(1)] [SeqNum(4)] [Timestamp(8)] [PayloadLen(4)] [Payload(N)]
/// Header size: 22 bytes
enum DroidProtocol {

    static let magic: [UInt8] = [0x44, 0x52, 0x4F, 0x49, 0x44] // "DROID"
    static let headerSize = 22
    static let videoPort = 7878
    static let discoveryPort = 7879

    // Frame types
    static let typeHello: UInt8       = 0x01
    static let typeHelloAck: UInt8    = 0x02
    static let typeSettings: UInt8    = 0x03
    static let typeSettingsAck: UInt8 = 0x04
    static let typeVideo: UInt8       = 0x10
    static let typePing: UInt8        = 0x20
    static let typePong: UInt8        = 0x21
    static let typeDisconnect: UInt8  = 0xFF

    struct Header {
        let type: UInt8
        let seqNum: UInt32
        let timestampUs: Int64
        let payloadLen: UInt32
    }

    /// Parse a 22-byte header. Returns nil if magic bytes don't match.
    static func parseHeader(_ data: Data) -> Header? {
        guard data.count >= headerSize else { return nil }

        let magicBytes = Array(data[0..<5])
        guard magicBytes == magic else { return nil }

        let type = data[5]
        let seqNum = data.readUInt32BE(at: 6)
        let timestamp = data.readInt64BE(at: 10)
        let payloadLen = data.readUInt32BE(at: 18)

        return Header(type: type, seqNum: seqNum, timestampUs: timestamp, payloadLen: payloadLen)
    }

    /// Build a complete protocol packet.
    static func buildPacket(
        type: UInt8,
        seqNum: UInt32,
        timestampUs: Int64,
        payload: Data = Data()
    ) -> Data {
        var data = Data(capacity: headerSize + payload.count)
        data.append(contentsOf: magic)
        data.append(type)
        data.appendUInt32BE(seqNum)
        data.appendInt64BE(timestampUs)
        data.appendUInt32BE(UInt32(payload.count))
        data.append(payload)
        return data
    }

    static func currentTimestampUs() -> Int64 {
        Int64(Date().timeIntervalSince1970 * 1_000_000)
    }
}

// MARK: - Data extensions for big-endian read/write

extension Data {
    func readUInt32BE(at offset: Int) -> UInt32 {
        var value: UInt32 = 0
        _ = Swift.withUnsafeMutableBytes(of: &value) { ptr in
            self.copyBytes(to: ptr, from: offset..<(offset + 4))
        }
        return UInt32(bigEndian: value)
    }

    func readInt64BE(at offset: Int) -> Int64 {
        var value: Int64 = 0
        _ = Swift.withUnsafeMutableBytes(of: &value) { ptr in
            self.copyBytes(to: ptr, from: offset..<(offset + 8))
        }
        return Int64(bigEndian: value)
    }

    mutating func appendUInt32BE(_ value: UInt32) {
        var v = value.bigEndian
        Swift.withUnsafeBytes(of: &v) { append(contentsOf: $0) }
    }

    mutating func appendInt64BE(_ value: Int64) {
        var v = value.bigEndian
        Swift.withUnsafeBytes(of: &v) { append(contentsOf: $0) }
    }
}
