import Cocoa
import AVFoundation
import CoreMedia

/// Main application window — shows video preview, device list, and controls.
class MainWindowController: NSWindowController {

    // UI components
    private var previewLayer: AVSampleBufferDisplayLayer!
    private var devicePopup: NSPopUpButton!
    private var statusLabel: NSTextField!
    private var startStopButton: NSButton!
    private var connectionModeLabel: NSTextField!
    private var settingsButton: NSButton!

    // Core components
    private let bonjourDiscovery = BonjourDiscovery()
    private let wifiReceiver = WifiReceiver()
    private let usbReceiver = UsbReceiver()
    private let videoDecoder = VideoDecoder()
    private let virtualCamera = VirtualCameraDriver.shared

    private var discoveredDevices: [BonjourDiscovery.DiscoveredDevice] = []
    private var isVirtualCameraRunning = false
    private var currentConnectionMode: ConnectionMode = .none

    enum ConnectionMode { case none, wifi, usb }

    // MARK: - Init

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Droid Camera"
        window.center()
        window.minSize = NSSize(width: 700, height: 450)
        self.init(window: window)
        setupUI()
        setupComponents()
    }

    // MARK: - UI Setup

    private func setupUI() {
        guard let contentView = window?.contentView else { return }
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor(calibratedWhite: 0.1, alpha: 1.0).cgColor

        // Video preview (left side)
        let previewContainer = NSView()
        previewContainer.wantsLayer = true
        previewContainer.layer?.backgroundColor = NSColor.black.cgColor
        previewContainer.layer?.cornerRadius = 8
        previewContainer.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(previewContainer)

        previewLayer = AVSampleBufferDisplayLayer()
        previewLayer.videoGravity = .resizeAspect
        previewLayer.backgroundColor = NSColor.black.cgColor
        previewContainer.layer?.addSublayer(previewLayer)

        // Right panel
        let rightPanel = NSView()
        rightPanel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(rightPanel)

        // App title
        let titleLabel = makeLabel("Droid Camera", size: 20, bold: true, color: .white)
        rightPanel.addSubview(titleLabel)

        // Status
        statusLabel = makeLabel("Not connected", size: 13, bold: false, color: .secondaryLabelColor)
        rightPanel.addSubview(statusLabel)

        // Connection mode
        connectionModeLabel = makeLabel("", size: 12, bold: false, color: .tertiaryLabelColor)
        rightPanel.addSubview(connectionModeLabel)

        // Separator
        let sep1 = NSBox()
        sep1.boxType = .separator
        sep1.translatesAutoresizingMaskIntoConstraints = false
        rightPanel.addSubview(sep1)

        // Device selection
        let deviceLabel = makeLabel("Android Device", size: 12, bold: true, color: .secondaryLabelColor)
        rightPanel.addSubview(deviceLabel)

        devicePopup = NSPopUpButton()
        devicePopup.translatesAutoresizingMaskIntoConstraints = false
        devicePopup.addItem(withTitle: "Searching for devices…")
        devicePopup.target = self
        devicePopup.action = #selector(deviceSelected)
        rightPanel.addSubview(devicePopup)

        // USB connect button
        let usbButton = NSButton(title: "Connect via USB", target: self, action: #selector(connectUsb))
        usbButton.translatesAutoresizingMaskIntoConstraints = false
        usbButton.bezelStyle = .rounded
        rightPanel.addSubview(usbButton)

        // Separator
        let sep2 = NSBox()
        sep2.boxType = .separator
        sep2.translatesAutoresizingMaskIntoConstraints = false
        rightPanel.addSubview(sep2)

        // Virtual camera toggle
        startStopButton = NSButton(title: "Start Virtual Camera", target: self, action: #selector(toggleVirtualCamera))
        startStopButton.translatesAutoresizingMaskIntoConstraints = false
        startStopButton.bezelStyle = .rounded
        startStopButton.keyEquivalent = "\r"
        rightPanel.addSubview(startStopButton)

        let cameraHint = makeLabel("Appears as 'Droid Camera' in OBS, Zoom, etc.", size: 11, bold: false, color: .tertiaryLabelColor)
        rightPanel.addSubview(cameraHint)

        // Settings button
        settingsButton = NSButton(title: "⚙ Settings", target: self, action: #selector(openSettings))
        settingsButton.translatesAutoresizingMaskIntoConstraints = false
        settingsButton.bezelStyle = .rounded
        rightPanel.addSubview(settingsButton)

        // Layout constraints
        NSLayoutConstraint.activate([
            previewContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            previewContainer.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            previewContainer.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16),
            previewContainer.widthAnchor.constraint(equalTo: contentView.widthAnchor, multiplier: 0.62),

            rightPanel.leadingAnchor.constraint(equalTo: previewContainer.trailingAnchor, constant: 16),
            rightPanel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            rightPanel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            rightPanel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16),

            titleLabel.topAnchor.constraint(equalTo: rightPanel.topAnchor, constant: 8),
            titleLabel.leadingAnchor.constraint(equalTo: rightPanel.leadingAnchor),

            statusLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            statusLabel.leadingAnchor.constraint(equalTo: rightPanel.leadingAnchor),

            connectionModeLabel.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 2),
            connectionModeLabel.leadingAnchor.constraint(equalTo: rightPanel.leadingAnchor),

            sep1.topAnchor.constraint(equalTo: connectionModeLabel.bottomAnchor, constant: 16),
            sep1.leadingAnchor.constraint(equalTo: rightPanel.leadingAnchor),
            sep1.trailingAnchor.constraint(equalTo: rightPanel.trailingAnchor),

            deviceLabel.topAnchor.constraint(equalTo: sep1.bottomAnchor, constant: 12),
            deviceLabel.leadingAnchor.constraint(equalTo: rightPanel.leadingAnchor),

            devicePopup.topAnchor.constraint(equalTo: deviceLabel.bottomAnchor, constant: 4),
            devicePopup.leadingAnchor.constraint(equalTo: rightPanel.leadingAnchor),
            devicePopup.trailingAnchor.constraint(equalTo: rightPanel.trailingAnchor),

            usbButton.topAnchor.constraint(equalTo: devicePopup.bottomAnchor, constant: 8),
            usbButton.leadingAnchor.constraint(equalTo: rightPanel.leadingAnchor),
            usbButton.trailingAnchor.constraint(equalTo: rightPanel.trailingAnchor),

            sep2.topAnchor.constraint(equalTo: usbButton.bottomAnchor, constant: 16),
            sep2.leadingAnchor.constraint(equalTo: rightPanel.leadingAnchor),
            sep2.trailingAnchor.constraint(equalTo: rightPanel.trailingAnchor),

            startStopButton.topAnchor.constraint(equalTo: sep2.bottomAnchor, constant: 12),
            startStopButton.leadingAnchor.constraint(equalTo: rightPanel.leadingAnchor),
            startStopButton.trailingAnchor.constraint(equalTo: rightPanel.trailingAnchor),

            cameraHint.topAnchor.constraint(equalTo: startStopButton.bottomAnchor, constant: 4),
            cameraHint.leadingAnchor.constraint(equalTo: rightPanel.leadingAnchor),
            cameraHint.trailingAnchor.constraint(equalTo: rightPanel.trailingAnchor),

            settingsButton.bottomAnchor.constraint(equalTo: rightPanel.bottomAnchor),
            settingsButton.leadingAnchor.constraint(equalTo: rightPanel.leadingAnchor),
            settingsButton.trailingAnchor.constraint(equalTo: rightPanel.trailingAnchor),
        ])

        // Update preview layer frame when window resizes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidResize),
            name: NSWindow.didResizeNotification,
            object: window
        )
    }

    @objc private func windowDidResize() {
        guard let previewContainer = previewLayer.superlayer?.delegate as? NSView else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        previewLayer.frame = previewContainer.bounds
        CATransaction.commit()
    }

    private func makeLabel(_ text: String, size: CGFloat, bold: Bool, color: NSColor) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = bold ? NSFont.boldSystemFont(ofSize: size) : NSFont.systemFont(ofSize: size)
        label.textColor = color
        label.lineBreakMode = .byWordWrapping
        label.maximumNumberOfLines = 0
        return label
    }

    // MARK: - Component Setup

    private func setupComponents() {
        // Video decoder → virtual camera
        videoDecoder.onDecodedFrame = { [weak self] pixelBuffer, presentationTime in
            guard let self = self else { return }
            // Update preview
            DispatchQueue.main.async {
                self.updatePreview(pixelBuffer: pixelBuffer, time: presentationTime)
            }
            // Feed virtual camera
            self.virtualCamera.enqueueFrame(pixelBuffer, presentationTime: presentationTime)
        }

        // WiFi receiver → decoder
        wifiReceiver.onVideoFrame = { [weak self] data, timestampUs in
            self?.videoDecoder.decode(annexBData: data, presentationTimeUs: timestampUs)
        }
        wifiReceiver.onStateChanged = { [weak self] state in
            DispatchQueue.main.async { self?.handleWifiState(state) }
        }

        // USB receiver → decoder
        usbReceiver.onVideoFrame = { [weak self] data, timestampUs in
            self?.videoDecoder.decode(annexBData: data, presentationTimeUs: timestampUs)
        }
        usbReceiver.onStateChanged = { [weak self] state in
            DispatchQueue.main.async { self?.handleUsbState(state) }
        }
        usbReceiver.onDeviceConnected = { [weak self] in
            DispatchQueue.main.async {
                self?.statusLabel.stringValue = "USB device detected"
                self?.connectionModeLabel.stringValue = "Connecting via USB…"
            }
        }
        usbReceiver.onDeviceDisconnected = { [weak self] in
            DispatchQueue.main.async {
                self?.statusLabel.stringValue = "USB device disconnected"
                self?.connectionModeLabel.stringValue = ""
                self?.currentConnectionMode = .none
            }
        }

        // Bonjour discovery
        bonjourDiscovery.onDevicesChanged = { [weak self] devices in
            DispatchQueue.main.async { self?.updateDeviceList(devices) }
        }
        bonjourDiscovery.startPublishing(port: DroidProtocol.videoPort)
        bonjourDiscovery.startBrowsing()

        // Start USB monitoring
        usbReceiver.start()
    }

    private func updatePreview(pixelBuffer: CVPixelBuffer, time: CMTime) {
        var sampleBuffer: CMSampleBuffer?
        var timingInfo = CMSampleTimingInfo(
            duration: CMTime(value: 1, timescale: 60),
            presentationTimeStamp: time,
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
            sampleBufferOut: &sampleBuffer
        )
        if let sb = sampleBuffer {
            previewLayer.enqueue(sb)
        }
    }

    // MARK: - Actions

    @objc private func deviceSelected() {
        let idx = devicePopup.indexOfSelectedItem
        guard idx < discoveredDevices.count else { return }
        let device = discoveredDevices[idx]
        wifiReceiver.connect(host: device.host, port: device.port)
        currentConnectionMode = .wifi
    }

    @objc private func connectUsb() {
        // USB receiver auto-detects; this just triggers a manual check
        statusLabel.stringValue = "Checking for USB device…"
        usbReceiver.start()
    }

    @objc private func toggleVirtualCamera() {
        if isVirtualCameraRunning {
            virtualCamera.stop()
            isVirtualCameraRunning = false
            startStopButton.title = "Start Virtual Camera"
        } else {
            do {
                try virtualCamera.start()
                isVirtualCameraRunning = true
                startStopButton.title = "Stop Virtual Camera"
            } catch {
                let alert = NSAlert()
                alert.messageText = "Failed to start virtual camera"
                alert.informativeText = error.localizedDescription
                alert.runModal()
            }
        }
    }

    @objc private func openSettings() {
        let settings = SettingsWindowController()
        settings.showWindow(nil)
    }

    // MARK: - State Handlers

    private func handleWifiState(_ state: WifiReceiver.State) {
        switch state {
        case .disconnected:
            statusLabel.stringValue = "Disconnected"
            connectionModeLabel.stringValue = ""
        case .connecting:
            statusLabel.stringValue = "Connecting…"
            connectionModeLabel.stringValue = "WiFi"
        case .connected:
            statusLabel.stringValue = "● Streaming"
            statusLabel.textColor = .systemGreen
            connectionModeLabel.stringValue = "WiFi"
        case .error(let msg):
            statusLabel.stringValue = "Error: \(msg)"
            statusLabel.textColor = .systemRed
        }
    }

    private func handleUsbState(_ state: WifiReceiver.State) {
        switch state {
        case .connected:
            statusLabel.stringValue = "● Streaming"
            statusLabel.textColor = .systemGreen
            connectionModeLabel.stringValue = "USB"
        case .disconnected:
            statusLabel.stringValue = "Disconnected"
            statusLabel.textColor = .secondaryLabelColor
            connectionModeLabel.stringValue = ""
        case .connecting:
            statusLabel.stringValue = "Connecting via USB…"
        case .error(let msg):
            statusLabel.stringValue = "USB Error: \(msg)"
            statusLabel.textColor = .systemRed
        }
    }

    private func updateDeviceList(_ devices: [BonjourDiscovery.DiscoveredDevice]) {
        discoveredDevices = devices
        devicePopup.removeAllItems()
        if devices.isEmpty {
            devicePopup.addItem(withTitle: "Searching for devices…")
        } else {
            for device in devices {
                devicePopup.addItem(withTitle: "\(device.name) (\(device.host))")
            }
        }
    }

    override func windowDidLoad() {
        super.windowDidLoad()
    }
}
