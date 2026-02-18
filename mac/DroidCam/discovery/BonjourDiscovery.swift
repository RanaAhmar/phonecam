import Foundation
import Network

/// Bonjour/mDNS discovery for Android devices on the local network.
/// Publishes a _droidcam._tcp service so Android can find this Mac,
/// and browses for Android devices that have registered the same service type.
class BonjourDiscovery: NSObject {

    private let serviceType = "_droidcam._tcp"
    private let serviceDomain = "local."
    private let serviceName = "DroidCamera-Mac"

    // Publishing (so Android can find us)
    private var publishedService: NetService?

    // Browsing (so we can find Android devices)
    private var browser: NetServiceBrowser?
    private var resolvingServices: [NetService] = []

    struct DiscoveredDevice: Identifiable, Hashable {
        let id = UUID()
        let name: String
        let host: String
        let port: Int
    }

    var onDevicesChanged: (([DiscoveredDevice]) -> Void)?
    private var devices: [DiscoveredDevice] = []

    // MARK: - Publishing

    func startPublishing(port: Int) {
        publishedService = NetService(
            domain: serviceDomain,
            type: serviceType,
            name: serviceName,
            port: Int32(port)
        )
        publishedService?.delegate = self
        publishedService?.publish()
    }

    func stopPublishing() {
        publishedService?.stop()
        publishedService = nil
    }

    // MARK: - Browsing

    func startBrowsing() {
        browser = NetServiceBrowser()
        browser?.delegate = self
        browser?.searchForServices(ofType: serviceType, inDomain: serviceDomain)
    }

    func stopBrowsing() {
        browser?.stop()
        browser = nil
        resolvingServices.removeAll()
    }

    func stop() {
        stopPublishing()
        stopBrowsing()
    }
}

// MARK: - NetServiceBrowserDelegate

extension BonjourDiscovery: NetServiceBrowserDelegate {

    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        // Don't add ourselves
        guard service.name != serviceName else { return }
        service.delegate = self
        resolvingServices.append(service)
        service.resolve(withTimeout: 5.0)
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didRemove service: NetService, moreComing: Bool) {
        devices.removeAll { $0.name == service.name }
        onDevicesChanged?(devices)
    }

    func netServiceBrowserDidStopSearch(_ browser: NetServiceBrowser) {}
    func netServiceBrowser(_ browser: NetServiceBrowser, didNotSearch errorDict: [String: NSNumber]) {
        print("[Bonjour] Browse error: \(errorDict)")
    }
}

// MARK: - NetServiceDelegate

extension BonjourDiscovery: NetServiceDelegate {

    func netServiceDidResolveAddress(_ sender: NetService) {
        guard let addresses = sender.addresses, !addresses.isEmpty else { return }

        // Extract IPv4 address
        var host: String?
        for addressData in addresses {
            var storage = sockaddr_storage()
            (addressData as NSData).getBytes(&storage, length: MemoryLayout<sockaddr_storage>.size)
            if Int32(storage.ss_family) == AF_INET {
                var addr = sockaddr_in()
                withUnsafeMutablePointer(to: &addr) { ptr in
                    ptr.withMemoryRebound(to: sockaddr_storage.self, capacity: 1) { $0.pointee = storage }
                }
                var buffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
                inet_ntop(AF_INET, &addr.sin_addr, &buffer, socklen_t(INET_ADDRSTRLEN))
                host = String(cString: buffer)
                break
            }
        }

        guard let resolvedHost = host else { return }

        let device = DiscoveredDevice(
            name: sender.name,
            host: resolvedHost,
            port: sender.port
        )

        if !devices.contains(where: { $0.name == device.name }) {
            devices.append(device)
            onDevicesChanged?(devices)
        }

        resolvingServices.removeAll { $0 === sender }
    }

    func netService(_ sender: NetService, didNotResolve errorDict: [String: NSNumber]) {
        print("[Bonjour] Resolve failed for \(sender.name): \(errorDict)")
        resolvingServices.removeAll { $0 === sender }
    }

    func netServiceDidPublish(_ sender: NetService) {
        print("[Bonjour] Published: \(sender.name)")
    }

    func netService(_ sender: NetService, didNotPublish errorDict: [String: NSNumber]) {
        print("[Bonjour] Publish failed: \(errorDict)")
    }
}
