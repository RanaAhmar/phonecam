import Foundation
import IOKit
import IOKit.usb

/// USB receiver — monitors IOKit for Android device connect/detach,
/// runs `adb forward tcp:7878 tcp:7878`, then connects via localhost.
/// Uses the same WifiReceiver internally (identical protocol over ADB tunnel).
class UsbReceiver {

    var onDeviceConnected: (() -> Void)?
    var onDeviceDisconnected: (() -> Void)?
    var onVideoFrame: ((Data, Int64) -> Void)?
    var onStateChanged: ((WifiReceiver.State) -> Void)?

    private var notificationPort: IONotificationPortRef?
    private var addedIterator: io_iterator_t = 0
    private var removedIterator: io_iterator_t = 0
    private var wifiReceiver: WifiReceiver?
    private var adbForwardProcess: Process?
    private var isForwarding = false

    // MARK: - Start/Stop

    func start() {
        setupUSBNotifications()
        // Also check if a device is already connected
        checkExistingDevices()
    }

    func stop() {
        teardownUSBNotifications()
        stopAdbForward()
        wifiReceiver?.disconnect()
        wifiReceiver = nil
    }

    // MARK: - IOKit USB Notifications

    private func setupUSBNotifications() {
        notificationPort = IONotificationPortCreate(kIOMainPortDefault)
        guard let port = notificationPort else { return }

        let runLoopSource = IONotificationPortGetRunLoopSource(port).takeUnretainedValue()
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .defaultMode)

        // Match any USB device (we'll check for ADB-capable devices)
        let matchingDict = IOServiceMatching(kIOUSBDeviceClassName) as NSMutableDictionary

        // Device added
        let addCallback: IOServiceMatchingCallback = { refcon, iterator in
            let receiver = Unmanaged<UsbReceiver>.fromOpaque(refcon!).takeUnretainedValue()
            receiver.handleDeviceAdded(iterator: iterator)
        }

        IOServiceAddMatchingNotification(
            port,
            kIOFirstMatchNotification,
            matchingDict,
            addCallback,
            Unmanaged.passUnretained(self).toOpaque(),
            &addedIterator
        )
        // Drain initial iterator
        handleDeviceAdded(iterator: addedIterator)

        // Device removed
        let removeCallback: IOServiceMatchingCallback = { refcon, iterator in
            let receiver = Unmanaged<UsbReceiver>.fromOpaque(refcon!).takeUnretainedValue()
            receiver.handleDeviceRemoved(iterator: iterator)
        }

        let matchingDict2 = IOServiceMatching(kIOUSBDeviceClassName) as NSMutableDictionary
        IOServiceAddMatchingNotification(
            port,
            kIOTerminatedNotification,
            matchingDict2,
            removeCallback,
            Unmanaged.passUnretained(self).toOpaque(),
            &removedIterator
        )
        handleDeviceRemoved(iterator: removedIterator)
    }

    private func teardownUSBNotifications() {
        if addedIterator != 0 { IOObjectRelease(addedIterator) }
        if removedIterator != 0 { IOObjectRelease(removedIterator) }
        if let port = notificationPort { IONotificationPortDestroy(port) }
    }

    private func handleDeviceAdded(iterator: io_iterator_t) {
        var service: io_object_t = IOIteratorNext(iterator)
        while service != 0 {
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }
        // Any USB device added — try ADB forward
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.tryAdbForward()
        }
    }

    private func handleDeviceRemoved(iterator: io_iterator_t) {
        var service: io_object_t = IOIteratorNext(iterator)
        while service != 0 {
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }
        // Check if ADB device is still available
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.checkAdbDevices()
        }
    }

    private func checkExistingDevices() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            self?.tryAdbForward()
        }
    }

    // MARK: - ADB

    private func tryAdbForward() {
        guard !isForwarding else { return }

        // Check if any ADB devices are connected
        let result = runAdb(args: ["devices"])
        let hasDevice = result.contains("device") && !result.trimmingCharacters(in: .whitespacesAndNewlines)
            .hasSuffix("List of devices attached")

        guard hasDevice else {
            print("[UsbReceiver] No ADB devices found")
            return
        }

        // Set up port forwarding
        let fwdResult = runAdb(args: ["forward", "tcp:\(DroidProtocol.videoPort)", "tcp:\(DroidProtocol.videoPort)"])
        print("[UsbReceiver] ADB forward result: \(fwdResult)")

        isForwarding = true
        onDeviceConnected?()

        // Connect via localhost (ADB tunnel)
        DispatchQueue.main.async { [weak self] in
            self?.connectViaAdb()
        }
    }

    private func connectViaAdb() {
        let receiver = WifiReceiver()
        receiver.onVideoFrame = self.onVideoFrame
        receiver.onStateChanged = { [weak self] state in
            self?.onStateChanged?(state)
            if case .disconnected = state {
                self?.isForwarding = false
                self?.onDeviceDisconnected?()
            }
        }
        self.wifiReceiver = receiver
        receiver.connect(host: "127.0.0.1", port: DroidProtocol.videoPort)
    }

    private func checkAdbDevices() {
        let result = runAdb(args: ["devices"])
        let hasDevice = result.contains("device") && !result.trimmingCharacters(in: .whitespacesAndNewlines)
            .hasSuffix("List of devices attached")

        if !hasDevice && isForwarding {
            print("[UsbReceiver] ADB device disconnected")
            isForwarding = false
            wifiReceiver?.disconnect()
            wifiReceiver = nil
            onDeviceDisconnected?()
        }
    }

    private func stopAdbForward() {
        guard isForwarding else { return }
        _ = runAdb(args: ["forward", "--remove", "tcp:\(DroidProtocol.videoPort)"])
        isForwarding = false
    }

    /// Run an adb command and return stdout.
    @discardableResult
    private func runAdb(args: [String]) -> String {
        let process = Process()
        // Try common ADB locations
        let adbPaths = [
            "/usr/local/bin/adb",
            "/opt/homebrew/bin/adb",
            "/usr/bin/adb",
            (ProcessInfo.processInfo.environment["HOME"] ?? "") + "/Library/Android/sdk/platform-tools/adb"
        ]
        let adbPath = adbPaths.first { FileManager.default.fileExists(atPath: $0) } ?? "/usr/local/bin/adb"
        process.executableURL = URL(fileURLWithPath: adbPath)
        process.arguments = args

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            print("[UsbReceiver] ADB error: \(error)")
            return ""
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }
}
