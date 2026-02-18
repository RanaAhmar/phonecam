import Foundation
import CoreMediaIO
import CoreMedia
import CoreVideo
import AVFoundation

/// CoreMediaIO virtual camera driver.
/// Creates a virtual camera device named "Droid Camera" that appears in
/// OBS Studio, Zoom, Google Meet, Teams, FaceTime, and any app using
/// standard macOS camera APIs.
///
/// Uses the CMIOExtension API (macOS 12.3+) which is the modern replacement
/// for the deprecated DAL plugin approach. For macOS 11, falls back to
/// the DAL plugin approach via a System Extension.
///
/// IMPORTANT: This extension must be signed with an Apple Developer certificate
/// and the com.apple.developer.system-extension.install entitlement.
class VirtualCameraDriver {

    static let shared = VirtualCameraDriver()

    private var provider: CMIOExtensionProvider?
    private var device: CMIOExtensionDevice?
    private var stream: CMIOExtensionStream?
    private var streamSource: DroidCameraStreamSource?

    private var isRunning = false

    // Camera properties
    let deviceName = "Droid Camera"
    let deviceModelID = "com.droid.webcam.camera"
    let deviceUID = "DroidCamera-Virtual-001"

    // Stream format — 1080p/60fps, 32BGRA
    private let width = 1920
    private let height = 1080
    private let frameRate = 60.0

    private init() {}

    // MARK: - Start/Stop

    func start() throws {
        guard !isRunning else { return }

        let streamSource = DroidCameraStreamSource(
            width: width,
            height: height,
            frameRate: frameRate
        )
        self.streamSource = streamSource

        // Create stream
        let streamFormat = CMIOExtensionStreamFormat(
            formatDescription: try makeFormatDescription(),
            maxFrameDuration: CMTime(value: 1, timescale: CMTimeScale(frameRate)),
            minFrameDuration: CMTime(value: 1, timescale: CMTimeScale(frameRate)),
            validFrameDurations: nil
        )

        stream = CMIOExtensionStream(
            localizedName: "Droid Camera Stream",
            streamID: UUID(),
            direction: .source,
            clockType: .hostTime,
            source: streamSource
        )

        // Create device
        device = CMIOExtensionDevice(
            localizedName: deviceName,
            deviceID: UUID(uuidString: "A1B2C3D4-E5F6-7890-ABCD-EF1234567890")!,
            legacyDeviceID: deviceUID,
            source: DroidCameraDeviceSource()
        )

        if let stream = stream, let device = device {
            try device.addStream(stream)
        }

        // Create provider
        provider = CMIOExtensionProvider(source: DroidCameraProviderSource(), clientQueue: nil)
        if let device = device, let provider = provider {
            try provider.addDevice(device)
        }

        // Start the provider
        CMIOExtensionProvider.startService(provider: provider!)

        isRunning = true
        print("[VirtualCamera] Started — '\(deviceName)' is now available")
    }

    func stop() {
        guard isRunning else { return }
        streamSource?.stopStreaming()
        isRunning = false
        print("[VirtualCamera] Stopped")
    }

    // MARK: - Frame Delivery

    /// Called with each decoded CVPixelBuffer from VideoDecoder.
    func enqueueFrame(_ pixelBuffer: CVPixelBuffer, presentationTime: CMTime) {
        guard isRunning else { return }
        streamSource?.enqueueFrame(pixelBuffer, presentationTime: presentationTime)
    }

    // MARK: - Format Description

    private func makeFormatDescription() throws -> CMVideoFormatDescription {
        var formatDesc: CMVideoFormatDescription?
        let status = CMVideoFormatDescriptionCreate(
            allocator: kCFAllocatorDefault,
            codecType: kCVPixelFormatType_32BGRA,
            width: Int32(width),
            height: Int32(height),
            extensions: nil,
            formatDescriptionOut: &formatDesc
        )
        guard status == noErr, let desc = formatDesc else {
            throw NSError(domain: "VirtualCamera", code: Int(status), userInfo: [
                NSLocalizedDescriptionKey: "Failed to create format description"
            ])
        }
        return desc
    }
}

// MARK: - Stream Source

/// Manages the pixel buffer queue and frame timing for the virtual camera stream.
class DroidCameraStreamSource: NSObject, CMIOExtensionStreamSource {

    private let width: Int
    private let height: Int
    private let frameRate: Double

    private var pixelBufferPool: CVPixelBufferPool?
    private var streaming = false
    private var seqNum: UInt64 = 0

    weak var stream: CMIOExtensionStream?

    init(width: Int, height: Int, frameRate: Double) {
        self.width = width
        self.height = height
        self.frameRate = frameRate
        super.init()
        setupPixelBufferPool()
    }

    private func setupPixelBufferPool() {
        let poolAttributes: [String: Any] = [
            kCVPixelBufferPoolMinimumBufferCountKey as String: 6
        ]
        let pixelBufferAttributes: [String: Any] = [
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:] as [String: Any]
        ]
        CVPixelBufferPoolCreate(
            kCFAllocatorDefault,
            poolAttributes as CFDictionary,
            pixelBufferAttributes as CFDictionary,
            &pixelBufferPool
        )
    }

    func enqueueFrame(_ pixelBuffer: CVPixelBuffer, presentationTime: CMTime) {
        guard streaming, let stream = stream else { return }

        var sbuf: CMSampleBuffer?
        var timingInfo = CMSampleTimingInfo(
            duration: CMTime(value: 1, timescale: CMTimeScale(frameRate)),
            presentationTimeStamp: presentationTime,
            decodeTimeStamp: CMTime.invalid
        )

        var formatDesc: CMVideoFormatDescription?
        CMVideoFormatDescriptionCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            formatDescriptionOut: &formatDesc
        )

        guard let desc = formatDesc else { return }

        CMSampleBufferCreateReadyWithImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            formatDescription: desc,
            sampleTiming: &timingInfo,
            sampleBufferOut: &sbuf
        )

        guard let sampleBuffer = sbuf else { return }

        // Attach sequence number
        CMSetAttachment(
            sampleBuffer,
            key: CMIOSampleBufferAttachmentKey_SequenceNumber,
            value: NSNumber(value: seqNum),
            attachmentMode: kCMAttachmentMode_ShouldPropagate
        )
        seqNum += 1

        stream.send(sampleBuffer, discontinuity: [], hostTimeInNanoseconds: UInt64(CACurrentMediaTime() * 1_000_000_000))
    }

    func stopStreaming() {
        streaming = false
    }

    // MARK: - CMIOExtensionStreamSource protocol

    var formats: [CMIOExtensionStreamFormat] {
        let frameDuration = CMTime(value: 1, timescale: CMTimeScale(frameRate))
        guard let formatDesc = try? makeFormatDesc() else { return [] }
        return [CMIOExtensionStreamFormat(
            formatDescription: formatDesc,
            maxFrameDuration: frameDuration,
            minFrameDuration: frameDuration,
            validFrameDurations: nil
        )]
    }

    var activeFormatIndex: Int = 0 {
        didSet {
            if activeFormatIndex >= 1 { activeFormatIndex = 0 }
        }
    }

    var availableProperties: Set<CMIOExtensionProperty> {
        [.streamActiveFormatIndex, .streamFrameDuration]
    }

    func streamProperties(forProperties properties: Set<CMIOExtensionProperty>) throws -> CMIOExtensionStreamProperties {
        let props = CMIOExtensionStreamProperties(dictionary: [:])
        if properties.contains(.streamActiveFormatIndex) {
            props.activeFormatIndex = 0
        }
        if properties.contains(.streamFrameDuration) {
            props.frameDuration = CMTime(value: 1, timescale: CMTimeScale(frameRate))
        }
        return props
    }

    func setStreamProperties(_ streamProperties: CMIOExtensionStreamProperties) throws {
        if let idx = streamProperties.activeFormatIndex {
            activeFormatIndex = idx
        }
    }

    func authorizedToStartStream(for client: CMIOExtensionClient) -> Bool { true }

    func startStream() throws {
        streaming = true
    }

    func stopStream() throws {
        streaming = false
    }

    private func makeFormatDesc() throws -> CMVideoFormatDescription {
        var desc: CMVideoFormatDescription?
        CMVideoFormatDescriptionCreate(
            allocator: kCFAllocatorDefault,
            codecType: kCVPixelFormatType_32BGRA,
            width: Int32(width),
            height: Int32(height),
            extensions: nil,
            formatDescriptionOut: &desc
        )
        guard let d = desc else {
            throw NSError(domain: "VirtualCamera", code: -1, userInfo: nil)
        }
        return d
    }
}

// MARK: - Device Source

class DroidCameraDeviceSource: NSObject, CMIOExtensionDeviceSource {

    var availableProperties: Set<CMIOExtensionProperty> {
        [.deviceTransportType, .deviceLinkedCoreAudioDeviceUID]
    }

    func deviceProperties(forProperties properties: Set<CMIOExtensionProperty>) throws -> CMIOExtensionDeviceProperties {
        let props = CMIOExtensionDeviceProperties(dictionary: [:])
        if properties.contains(.deviceTransportType) {
            props.transportType = Int32(kIOAudioDeviceTransportTypeVirtual)
        }
        return props
    }

    func setDeviceProperties(_ deviceProperties: CMIOExtensionDeviceProperties) throws {}
}

// MARK: - Provider Source

class DroidCameraProviderSource: NSObject, CMIOExtensionProviderSource {

    var availableProperties: Set<CMIOExtensionProperty> { [] }

    func providerProperties(forProperties properties: Set<CMIOExtensionProperty>) throws -> CMIOExtensionProviderProperties {
        CMIOExtensionProviderProperties(dictionary: [:])
    }

    func setProviderProperties(_ providerProperties: CMIOExtensionProviderProperties) throws {}
}
