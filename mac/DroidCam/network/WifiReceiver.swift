import Foundation
import Network

/// WiFi TCP client that connects to the Android streaming server.
/// Handles the Droid Camera protocol handshake and receives H.264 video frames.
class WifiReceiver {

    enum State {
        case disconnected, connecting, connected, error(String)
    }

    var onStateChanged: ((State) -> Void)?
    var onVideoFrame: ((Data, Int64) -> Void)?
    var onSettingsReceived: ((String, Int, Int) -> Void)? // resolution, fps, bitrate

    private var connection: NWConnection?
    private var seqNum: UInt32 = 0
    private var pingTimer: Timer?
    private var reconnectTimer: Timer?
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 10

    private var targetHost: String = ""
    private var targetPort: Int = DroidProtocol.videoPort

    // Partial read buffer
    private var readBuffer = Data()

    func connect(host: String, port: Int = DroidProtocol.videoPort) {
        self.targetHost = host
        self.targetPort = port
        reconnectAttempts = 0
        doConnect(host: host, port: port)
    }

    private func doConnect(host: String, port: Int) {
        onStateChanged?(.connecting)

        let endpoint = NWEndpoint.hostPort(
            host: NWEndpoint.Host(host),
            port: NWEndpoint.Port(integerLiteral: UInt16(port))
        )
        let params = NWParameters.tcp
        params.allowLocalEndpointReuse = true

        connection = NWConnection(to: endpoint, using: params)
        connection?.stateUpdateHandler = { [weak self] state in
            self?.handleConnectionState(state)
        }
        connection?.start(queue: .global(qos: .userInteractive))
    }

    private func handleConnectionState(_ state: NWConnection.State) {
        switch state {
        case .ready:
            reconnectAttempts = 0
            sendHello()
        case .failed(let error):
            onStateChanged?(.error(error.localizedDescription))
            scheduleReconnect()
        case .cancelled:
            onStateChanged?(.disconnected)
        default:
            break
        }
    }

    private func sendHello() {
        let deviceName = Host.current().localizedName ?? "Mac"
        let helloJson = """
        {"version":1,"device":"\(deviceName)","requestedResolution":"1080p","requestedFps":60}
        """
        let payload = helloJson.data(using: .utf8) ?? Data()
        let packet = DroidProtocol.buildPacket(
            type: DroidProtocol.typeHello,
            seqNum: nextSeq(),
            timestampUs: DroidProtocol.currentTimestampUs(),
            payload: payload
        )
        send(packet) { [weak self] in
            self?.startReceiving()
        }
    }

    private func startReceiving() {
        startPingTimer()
        receiveNextPacket()
    }

    private func receiveNextPacket() {
        // Read header first
        receive(exactly: DroidProtocol.headerSize) { [weak self] headerData in
            guard let self = self, let headerData = headerData else { return }
            guard let header = DroidProtocol.parseHeader(headerData) else {
                print("[WiFiReceiver] Invalid header magic")
                self.disconnect()
                return
            }

            let payloadLen = Int(header.payloadLen)
            if payloadLen == 0 {
                self.handlePacket(header: header, payload: Data())
                self.receiveNextPacket()
            } else {
                self.receive(exactly: payloadLen) { [weak self] payloadData in
                    guard let self = self, let payloadData = payloadData else { return }
                    self.handlePacket(header: header, payload: payloadData)
                    self.receiveNextPacket()
                }
            }
        }
    }

    private func handlePacket(header: DroidProtocol.Header, payload: Data) {
        switch header.type {
        case DroidProtocol.typeHelloAck:
            print("[WiFiReceiver] HELLO_ACK received — streaming started")
            onStateChanged?(.connected)

        case DroidProtocol.typeVideo:
            onVideoFrame?(payload, header.timestampUs)

        case DroidProtocol.typePing:
            // Send PONG
            let pong = DroidProtocol.buildPacket(
                type: DroidProtocol.typePong,
                seqNum: nextSeq(),
                timestampUs: DroidProtocol.currentTimestampUs()
            )
            send(pong, completion: nil)

        case DroidProtocol.typeSettingsAck:
            print("[WiFiReceiver] Settings applied by Android")

        case DroidProtocol.typeDisconnect:
            print("[WiFiReceiver] Android sent DISCONNECT")
            disconnect()

        default:
            print("[WiFiReceiver] Unknown packet type: \(header.type)")
        }
    }

    func requestSettings(resolution: String, fps: Int, bitrate: Int) {
        let json = """
        {"resolution":"\(resolution)","fps":\(fps),"bitrate":\(bitrate)}
        """
        let payload = json.data(using: .utf8) ?? Data()
        let packet = DroidProtocol.buildPacket(
            type: DroidProtocol.typeSettings,
            seqNum: nextSeq(),
            timestampUs: DroidProtocol.currentTimestampUs(),
            payload: payload
        )
        send(packet, completion: nil)
    }

    func disconnect() {
        pingTimer?.invalidate()
        pingTimer = nil
        let packet = DroidProtocol.buildPacket(
            type: DroidProtocol.typeDisconnect,
            seqNum: nextSeq(),
            timestampUs: DroidProtocol.currentTimestampUs()
        )
        send(packet) { [weak self] in
            self?.connection?.cancel()
            self?.connection = nil
            self?.onStateChanged?(.disconnected)
        }
    }

    // MARK: - Helpers

    private func send(_ data: Data, completion: (() -> Void)?) {
        connection?.send(content: data, completion: .contentProcessed { error in
            if let error = error {
                print("[WiFiReceiver] Send error: \(error)")
            }
            completion?()
        })
    }

    private func receive(exactly count: Int, completion: @escaping (Data?) -> Void) {
        connection?.receive(minimumIncompleteLength: count, maximumLength: count) { data, _, isComplete, error in
            if let error = error {
                print("[WiFiReceiver] Receive error: \(error)")
                completion(nil)
                return
            }
            if isComplete && (data == nil || data!.count < count) {
                completion(nil)
                return
            }
            completion(data)
        }
    }

    private func startPingTimer() {
        pingTimer?.invalidate()
        DispatchQueue.main.async { [weak self] in
            self?.pingTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                let ping = DroidProtocol.buildPacket(
                    type: DroidProtocol.typePing,
                    seqNum: self.nextSeq(),
                    timestampUs: DroidProtocol.currentTimestampUs()
                )
                self.send(ping, completion: nil)
            }
        }
    }

    private func scheduleReconnect() {
        guard reconnectAttempts < maxReconnectAttempts else {
            onStateChanged?(.error("Max reconnection attempts reached"))
            return
        }
        reconnectAttempts += 1
        let delay = min(Double(reconnectAttempts) * 2.0, 30.0) // exponential backoff, max 30s
        print("[WiFiReceiver] Reconnecting in \(delay)s (attempt \(reconnectAttempts))")
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self = self else { return }
            self.doConnect(host: self.targetHost, port: self.targetPort)
        }
    }

    private func nextSeq() -> UInt32 {
        seqNum &+= 1
        return seqNum
    }
}
