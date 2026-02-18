import Cocoa

/// Menu bar status item with connection status indicator and quick actions.
class MenuBarController: NSObject {

    private var statusItem: NSStatusItem!
    private var menu: NSMenu!

    // Callbacks
    var onShowMainWindow: (() -> Void)?
    var onDisconnect: (() -> Void)?

    private var connectionStatusItem: NSMenuItem!

    override init() {
        super.init()
        setupStatusItem()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "camera.fill", accessibilityDescription: "Droid Camera")
            button.image?.isTemplate = true
        }

        menu = NSMenu()

        // App title (non-clickable header)
        let titleItem = NSMenuItem(title: "Droid Camera", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)

        // Connection status
        connectionStatusItem = NSMenuItem(title: "● Not connected", action: nil, keyEquivalent: "")
        connectionStatusItem.isEnabled = false
        menu.addItem(connectionStatusItem)

        menu.addItem(NSMenuItem.separator())

        // Open main window
        let openItem = NSMenuItem(title: "Open Droid Camera…", action: #selector(openMainWindow), keyEquivalent: "o")
        openItem.target = self
        menu.addItem(openItem)

        // Disconnect
        let disconnectItem = NSMenuItem(title: "Disconnect", action: #selector(disconnect), keyEquivalent: "d")
        disconnectItem.target = self
        menu.addItem(disconnectItem)

        menu.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(title: "Quit Droid Camera", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    func updateStatus(mode: ConnectionMode, host: String?) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            switch mode {
            case .none:
                self.connectionStatusItem.title = "● Not connected"
                self.connectionStatusItem.attributedTitle = self.statusAttributedString("● Not connected", color: .secondaryLabelColor)
                self.statusItem.button?.image = NSImage(systemSymbolName: "camera.fill", accessibilityDescription: nil)
            case .wifi:
                let label = "● WiFi — \(host ?? "connected")"
                self.connectionStatusItem.attributedTitle = self.statusAttributedString(label, color: .systemGreen)
                self.statusItem.button?.image = NSImage(systemSymbolName: "camera.fill", accessibilityDescription: nil)
            case .usb:
                let label = "● USB — connected"
                self.connectionStatusItem.attributedTitle = self.statusAttributedString(label, color: .systemGreen)
                self.statusItem.button?.image = NSImage(systemSymbolName: "camera.fill", accessibilityDescription: nil)
            }
        }
    }

    private func statusAttributedString(_ text: String, color: NSColor) -> NSAttributedString {
        NSAttributedString(string: text, attributes: [.foregroundColor: color])
    }

    @objc private func openMainWindow() {
        onShowMainWindow?()
    }

    @objc private func disconnect() {
        onDisconnect?()
    }

    func cleanup() {
        NSStatusBar.system.removeStatusItem(statusItem)
    }

    enum ConnectionMode {
        case none, wifi, usb
    }
}
