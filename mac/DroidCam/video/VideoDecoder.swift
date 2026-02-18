import Foundation
import VideoToolbox
import CoreMedia
import CoreVideo

/// H.264 decoder using VideoToolbox VTDecompressionSession.
/// Receives raw H.264 Annex B NAL units and produces CVPixelBuffers
/// for delivery to the virtual camera driver.
class VideoDecoder {

    var onDecodedFrame: ((CVPixelBuffer, CMTime) -> Void)?

    private var decompressionSession: VTDecompressionSession?
    private var formatDescription: CMVideoFormatDescription?

    // SPS/PPS parameter sets (extracted from stream)
    private var spsData: Data?
    private var ppsData: Data?

    // MARK: - Public API

    /// Feed raw H.264 Annex B data (may contain SPS, PPS, IDR, or P-frames).
    func decode(annexBData: Data, presentationTimeUs: Int64) {
        let nalUnits = splitAnnexB(annexBData)

        for nal in nalUnits {
            guard !nal.isEmpty else { continue }
            let nalType = nal[0] & 0x1F

            switch nalType {
            case 7: // SPS
                spsData = nal
                tryCreateSession()
            case 8: // PPS
                ppsData = nal
                tryCreateSession()
            default:
                decodeNAL(nal, presentationTimeUs: presentationTimeUs)
            }
        }
    }

    func flush() {
        guard let session = decompressionSession else { return }
        VTDecompressionSessionFinishDelayedFrames(session)
        VTDecompressionSessionWaitForAsynchronousFrames(session)
    }

    func invalidate() {
        if let session = decompressionSession {
            VTDecompressionSessionInvalidate(session)
            decompressionSession = nil
        }
        formatDescription = nil
        spsData = nil
        ppsData = nil
    }

    // MARK: - Session Setup

    private func tryCreateSession() {
        guard let sps = spsData, let pps = ppsData else { return }

        // Build CMVideoFormatDescription from SPS + PPS
        let parameterSetPointers: [UnsafePointer<UInt8>] = [
            (sps as NSData).bytes.assumingMemoryBound(to: UInt8.self),
            (pps as NSData).bytes.assumingMemoryBound(to: UInt8.self)
        ]
        let parameterSetSizes: [Int] = [sps.count, pps.count]

        var newFormatDesc: CMVideoFormatDescription?
        let status = CMVideoFormatDescriptionCreateFromH264ParameterSets(
            allocator: kCFAllocatorDefault,
            parameterSetCount: 2,
            parameterSetPointers: parameterSetPointers,
            parameterSetSizes: parameterSetSizes,
            nalUnitHeaderLength: 4,
            formatDescriptionOut: &newFormatDesc
        )

        guard status == noErr, let formatDesc = newFormatDesc else {
            print("[VideoDecoder] Failed to create format description: \(status)")
            return
        }

        // Check if we need to recreate the session
        if let existing = formatDescription,
           CMFormatDescriptionEqual(existing, otherFormatDescription: formatDesc) {
            return // Same format, reuse session
        }

        formatDescription = formatDesc

        // Invalidate old session
        if let old = decompressionSession {
            VTDecompressionSessionInvalidate(old)
            decompressionSession = nil
        }

        createDecompressionSession(formatDesc: formatDesc)
    }

    private func createDecompressionSession(formatDesc: CMVideoFormatDescription) {
        // Output pixel buffer attributes — use 32BGRA for CoreMediaIO compatibility
        let pixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:] as [String: Any]
        ]

        var outputCallback = VTDecompressionOutputCallbackRecord(
            decompressionOutputCallback: { refcon, _, status, _, imageBuffer, presentationTimeStamp, _ in
                guard status == noErr, let pixelBuffer = imageBuffer else { return }
                let decoder = Unmanaged<VideoDecoder>.fromOpaque(refcon!).takeUnretainedValue()
                decoder.onDecodedFrame?(pixelBuffer, presentationTimeStamp)
            },
            decompressionOutputRefCon: Unmanaged.passUnretained(self).toOpaque()
        )

        let decoderSpec: [String: Any] = [
            kVTVideoDecoderSpecification_EnableHardwareAcceleratedVideoDecoder as String: true
        ]

        let status = VTDecompressionSessionCreate(
            allocator: kCFAllocatorDefault,
            formatDescription: formatDesc,
            decoderSpecification: decoderSpec as CFDictionary,
            imageBufferAttributes: pixelBufferAttributes as CFDictionary,
            outputCallback: &outputCallback,
            decompressionSessionOut: &decompressionSession
        )

        if status != noErr {
            print("[VideoDecoder] Failed to create decompression session: \(status)")
        } else {
            // Enable low-latency decoding
            VTSessionSetProperty(decompressionSession!, key: kVTDecompressionPropertyKey_RealTime, value: kCFBooleanTrue)
            print("[VideoDecoder] Decompression session created successfully")
        }
    }

    // MARK: - Decoding

    private func decodeNAL(_ nal: Data, presentationTimeUs: Int64) {
        guard let session = decompressionSession,
              let formatDesc = formatDescription else { return }

        // Convert Annex B to AVCC (4-byte length prefix instead of start codes)
        var avccData = Data(capacity: nal.count + 4)
        var length = UInt32(nal.count).bigEndian
        withUnsafeBytes(of: &length) { avccData.append(contentsOf: $0) }
        avccData.append(nal)

        // Create CMBlockBuffer
        var blockBuffer: CMBlockBuffer?
        let blockStatus = avccData.withUnsafeBytes { ptr in
            CMBlockBufferCreateWithMemoryBlock(
                allocator: kCFAllocatorDefault,
                memoryBlock: UnsafeMutableRawPointer(mutating: ptr.baseAddress!),
                blockLength: avccData.count,
                blockAllocator: kCFAllocatorNull,
                customBlockSource: nil,
                offsetToData: 0,
                dataLength: avccData.count,
                flags: 0,
                blockBufferOut: &blockBuffer
            )
        }

        guard blockStatus == noErr, let block = blockBuffer else { return }

        // Create CMSampleBuffer
        let pts = CMTime(value: presentationTimeUs, timescale: 1_000_000)
        var sampleBuffer: CMSampleBuffer?
        var timingInfo = CMSampleTimingInfo(
            duration: CMTime.invalid,
            presentationTimeStamp: pts,
            decodeTimeStamp: CMTime.invalid
        )

        let sampleStatus = CMSampleBufferCreateReady(
            allocator: kCFAllocatorDefault,
            dataBuffer: block,
            formatDescription: formatDesc,
            sampleCount: 1,
            sampleTimingEntryCount: 1,
            sampleTimingArray: &timingInfo,
            sampleSizeEntryCount: 0,
            sampleSizeArray: nil,
            sampleBufferOut: &sampleBuffer
        )

        guard sampleStatus == noErr, let sample = sampleBuffer else { return }

        // Decode
        let flags: VTDecodeFrameFlags = [._EnableAsynchronousDecompression, ._EnableTemporalProcessing]
        VTDecompressionSessionDecodeFrame(session, sampleBuffer: sample, flags: flags, frameRefcon: nil, infoFlagsOut: nil)
    }

    // MARK: - Annex B Parsing

    /// Split Annex B stream into individual NAL units (strips start codes).
    private func splitAnnexB(_ data: Data) -> [Data] {
        var nals: [Data] = []
        var start = 0
        let bytes = Array(data)
        let count = bytes.count

        var i = 0
        while i < count - 3 {
            // Look for start code: 00 00 01 or 00 00 00 01
            let is3byte = bytes[i] == 0 && bytes[i+1] == 0 && bytes[i+2] == 1
            let is4byte = i + 3 < count && bytes[i] == 0 && bytes[i+1] == 0 && bytes[i+2] == 0 && bytes[i+3] == 1

            if is4byte || is3byte {
                if i > start {
                    nals.append(Data(bytes[start..<i]))
                }
                start = i + (is4byte ? 4 : 3)
                i = start
            } else {
                i += 1
            }
        }

        if start < count {
            nals.append(Data(bytes[start..<count]))
        }

        return nals.filter { !$0.isEmpty }
    }
}
