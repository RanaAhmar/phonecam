import Cocoa

/// Settings window — resolution, video adjustments, startup options.
class SettingsWindowController: NSWindowController {

    private var resolutionPopup: NSPopUpButton!
    private var brightnessSlider: NSSlider!
    private var contrastSlider: NSSlider!
    private var launchAtLoginCheckbox: NSButton!

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 320),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Droid Camera Settings"
        window.center()
        self.init(window: window)
        setupUI()
        loadSettings()
    }

    private func setupUI() {
        guard let contentView = window?.contentView else { return }
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 16
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor)
        ])

        // Resolution
        stack.addArrangedSubview(sectionLabel("Video"))
        let resRow = labeledControl("Default Resolution:", control: {
            resolutionPopup = NSPopUpButton()
            resolutionPopup.addItems(withTitles: ["720p", "1080p (Default)", "4K"])
            resolutionPopup.selectItem(at: 1)
            return resolutionPopup
        }())
        stack.addArrangedSubview(resRow)

        // Brightness
        let brightnessRow = labeledControl("Brightness:", control: {
            brightnessSlider = NSSlider(value: 0.5, minValue: 0, maxValue: 1, target: nil, action: nil)
            brightnessSlider.widthAnchor.constraint(equalToConstant: 200).isActive = true
            return brightnessSlider
        }())
        stack.addArrangedSubview(brightnessRow)

        // Contrast
        let contrastRow = labeledControl("Contrast:", control: {
            contrastSlider = NSSlider(value: 0.5, minValue: 0, maxValue: 1, target: nil, action: nil)
            contrastSlider.widthAnchor.constraint(equalToConstant: 200).isActive = true
            return contrastSlider
        }())
        stack.addArrangedSubview(contrastRow)

        // Startup
        stack.addArrangedSubview(sectionLabel("Startup"))
        launchAtLoginCheckbox = NSButton(checkboxWithTitle: "Launch at Login", target: self, action: #selector(toggleLaunchAtLogin))
        stack.addArrangedSubview(launchAtLoginCheckbox)

        // About
        stack.addArrangedSubview(sectionLabel("About"))
        let versionLabel = NSTextField(labelWithString: "Droid Camera v1.0.0")
        versionLabel.textColor = .secondaryLabelColor
        stack.addArrangedSubview(versionLabel)

        // Save button
        let saveButton = NSButton(title: "Save", target: self, action: #selector(saveSettings))
        saveButton.bezelStyle = .rounded
        saveButton.keyEquivalent = "\r"
        stack.addArrangedSubview(saveButton)
    }

    private func sectionLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text.uppercased())
        label.font = NSFont.boldSystemFont(ofSize: 11)
        label.textColor = .secondaryLabelColor
        return label
    }

    private func labeledControl(_ labelText: String, control: NSView) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 8
        let label = NSTextField(labelWithString: labelText)
        label.widthAnchor.constraint(equalToConstant: 130).isActive = true
        row.addArrangedSubview(label)
        row.addArrangedSubview(control)
        return row
    }

    private func loadSettings() {
        let defaults = UserDefaults.standard
        let resIdx = defaults.integer(forKey: "defaultResolutionIndex")
        resolutionPopup.selectItem(at: resIdx)
        brightnessSlider.doubleValue = defaults.double(forKey: "brightness").clamped(to: 0...1)
        contrastSlider.doubleValue = defaults.double(forKey: "contrast").clamped(to: 0...1)
        launchAtLoginCheckbox.state = defaults.bool(forKey: "launchAtLogin") ? .on : .off
    }

    @objc private func saveSettings() {
        let defaults = UserDefaults.standard
        defaults.set(resolutionPopup.indexOfSelectedItem, forKey: "defaultResolutionIndex")
        defaults.set(brightnessSlider.doubleValue, forKey: "brightness")
        defaults.set(contrastSlider.doubleValue, forKey: "contrast")
        defaults.set(launchAtLoginCheckbox.state == .on, forKey: "launchAtLogin")
        window?.close()
    }

    @objc private func toggleLaunchAtLogin() {
        // Launch at login via SMAppService (macOS 13+) or LSSharedFileList (older)
        // Implementation depends on target OS version
    }
}

extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
