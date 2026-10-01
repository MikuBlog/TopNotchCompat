import AppKit
import TopNotchCompatCore

protocol PopupViewControllerDelegate: AnyObject {
    func popupViewControllerDidChangeSettings(_ settings: WallpaperSettings)
    func popupViewControllerDidRequestWebsite()
    func popupViewControllerDidRequestHideIcon()
    func popupViewControllerDidRequestQuit()
}

final class PopupViewController: NSViewController {
    private weak var delegate: PopupViewControllerDelegate?
    private var settings: WallpaperSettings
    private var enabledSwitch = NSSwitch()
    private var builtInOnlyButton = NSButton()
    private var roundCornersButton = NSButton()
    private var dynamicButton = NSButton()
    private var loginButton = NSButton()
    private var radiusPopup = NSPopUpButton()
    private var previewView = WallpaperPreviewView()
    private var progressIndicator = NSProgressIndicator()
    private var processingLabel = NSTextField(labelWithString: "Processing wallpaper...")

    init(settings: WallpaperSettings, delegate: PopupViewControllerDelegate) {
        self.settings = settings
        self.delegate = delegate
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        nil
    }

    var currentSettings: WallpaperSettings { settings }

    override func loadView() {
        let outer = PopupBackgroundView(frame: NSRect(x: 0, y: 0, width: 353, height: 508))
        outer.appearance = NSAppearance(named: .darkAqua)
        let root = PopupRootView(frame: NSRect(x: 13, y: 13, width: 327, height: 482))
        outer.addSubview(root)
        view = outer

        configurePromoArea(in: root)
        configureSettingsArea(in: root)
        configureMainArea(in: root)
        configureFooter(in: root)
        updateControls()
    }

    func update(settings: WallpaperSettings) {
        self.settings = settings
        updateControls()
    }

    func setProcessing(_ processing: Bool) {
        progressIndicator.isHidden = !processing
        processingLabel.isHidden = !processing
        if processing {
            progressIndicator.startAnimation(nil)
        } else {
            progressIndicator.stopAnimation(nil)
        }
    }

    private func configurePromoArea(in parent: NSView) {
        let card = CardView(frame: NSRect(x: 20, y: 20, width: 287, height: 42))
        parent.addSubview(card)

        let label = textLabel("Inspired by TopNotch", color: .secondaryLabelColor, font: .systemFont(ofSize: 12))
        let link = linkButton("GitHub", target: self, action: #selector(openWebsite))
        let chevron = NSImageView(frame: .zero)
        chevron.image = NSImage(systemSymbolName: "chevron.right", accessibilityDescription: nil)
        chevron.contentTintColor = NSColor.systemBlue

        label.sizeToFit()
        link.sizeToFit()
        let labelSize = label.fittingSize
        let linkSize = link.fittingSize
        let chevronSize = chevron.image?.size ?? NSSize(width: 8, height: 11)
        let rowWidth = labelSize.width + 6 + linkSize.width + 5 + chevronSize.width
        let rowX = (card.bounds.width - rowWidth) / 2
        let textY = (card.bounds.height - max(labelSize.height, linkSize.height)) / 2
        label.frame = NSRect(origin: CGPoint(x: rowX, y: textY), size: labelSize)
        link.frame = NSRect(
            origin: CGPoint(x: label.frame.maxX + 6, y: textY),
            size: linkSize
        )
        chevron.frame = NSRect(
            x: link.frame.maxX + 5,
            y: (card.bounds.height - chevronSize.height) / 2,
            width: chevronSize.width,
            height: chevronSize.height
        )

        card.addSubview(label)
        card.addSubview(link)
        card.addSubview(chevron)
    }

    private func configureSettingsArea(in parent: NSView) {
        let card = CardView(frame: NSRect(x: 20, y: 77, width: 287, height: 122))
        parent.addSubview(card)

        loginButton = checkbox("Start at login", target: self, action: #selector(toggleLogin))
        loginButton.frame = NSRect(x: 11, y: 13, width: 105, height: 18)
        card.addSubview(loginButton)

        builtInOnlyButton = checkbox("Enable on MacBook screen only", target: self, action: #selector(toggleBuiltInOnly))
        builtInOnlyButton.frame = NSRect(x: 11, y: 39, width: 256, height: 18)
        card.addSubview(builtInOnlyButton)

        roundCornersButton = checkbox("Round corners", target: self, action: #selector(toggleRoundCorners))
        roundCornersButton.frame = NSRect(x: 11, y: 65, width: 115, height: 18)
        card.addSubview(roundCornersButton)

        let radiusLabel = textLabel("Radius:", color: .labelColor, font: .systemFont(ofSize: 11))
        radiusLabel.frame = NSRect(x: 149, y: 66, width: 44, height: 14)
        card.addSubview(radiusLabel)

        radiusPopup = NSPopUpButton(frame: NSRect(x: 198, y: 61, width: 79, height: 22), pullsDown: false)
        radiusPopup.addItems(withTitles: ["Small", "Medium", "High"])
        radiusPopup.target = self
        radiusPopup.action = #selector(changeRadius)
        radiusPopup.controlSize = .small
        card.addSubview(radiusPopup)

        dynamicButton = checkbox("Use dynamic wallpapers", target: self, action: #selector(toggleDynamic))
        dynamicButton.frame = NSRect(x: 11, y: 91, width: 173, height: 18)
        card.addSubview(dynamicButton)

        let info = NSButton(frame: NSRect(x: 253, y: 88, width: 24, height: 24))
        info.bezelStyle = .regularSquare
        info.isBordered = false
        info.image = NSImage(systemSymbolName: "info.circle", accessibilityDescription: "About dynamic wallpapers")
        info.contentTintColor = .secondaryLabelColor
        info.target = self
        info.action = #selector(showDynamicInfo)
        card.addSubview(info)
    }

    private func configureMainArea(in parent: NSView) {
        let card = CardView(frame: NSRect(x: 20, y: 214, width: 287, height: 218))
        parent.addSubview(card)

        previewView = WallpaperPreviewView(frame: NSRect(x: 0, y: 0, width: 287, height: 89))
        card.addSubview(previewView)

        let description = textLabel(
            "Enable TopNotchCompat to automatically add a black bar to your wallpapers.",
            color: .secondaryLabelColor,
            font: .systemFont(ofSize: 12)
        )
        description.alignment = .center
        description.lineBreakMode = .byWordWrapping
        description.maximumNumberOfLines = 3
        description.frame = NSRect(x: 14, y: 102, width: 259, height: 52)
        card.addSubview(description)

        enabledSwitch = NSSwitch(frame: NSRect(x: 122.5, y: 163, width: 42, height: 25))
        enabledSwitch.target = self
        enabledSwitch.action = #selector(toggleEnabled)
        card.addSubview(enabledSwitch)

        progressIndicator = NSProgressIndicator(frame: NSRect(x: 0, y: 34, width: 16, height: 16))
        progressIndicator.style = .spinning
        progressIndicator.controlSize = .small
        progressIndicator.isDisplayedWhenStopped = false
        card.addSubview(progressIndicator)

        processingLabel = textLabel("Processing wallpaper...", color: .secondaryLabelColor, font: .systemFont(ofSize: 10))
        processingLabel.sizeToFit()
        let processingWidth = processingLabel.fittingSize.width
        let processingGroupX = (287 - processingWidth - 22) / 2
        progressIndicator.setFrameOrigin(NSPoint(x: processingGroupX, y: 34))
        processingLabel.frame = NSRect(x: processingGroupX + 22, y: 35, width: processingWidth, height: 14)
        processingLabel.isHidden = true
        card.addSubview(processingLabel)
    }

    private func configureFooter(in parent: NSView) {
        let appName = linkButton("TopNotchCompat", target: self, action: #selector(openWebsite))
        appName.sizeToFit()
        appName.frame = NSRect(
            x: 20,
            y: 445,
            width: appName.fittingSize.width,
            height: max(19, appName.fittingSize.height)
        )
        parent.addSubview(appName)

        let versionNumber = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let version = textLabel("v\(versionNumber)", color: .tertiaryLabelColor, font: .systemFont(ofSize: 10))
        version.alignment = .center
        version.frame = NSRect(x: (parent.bounds.width - 84) / 2, y: 448, width: 84, height: 13)
        parent.addSubview(version)

        let gear = NSButton(frame: NSRect(x: 281, y: 443, width: 26, height: 27))
        gear.isBordered = false
        gear.bezelStyle = .regularSquare
        gear.image = NSImage(systemSymbolName: "gearshape.fill", accessibilityDescription: "Menu")
        gear.contentTintColor = .secondaryLabelColor
        gear.target = self
        gear.action = #selector(openGearMenu)
        parent.addSubview(gear)
    }

    private func updateControls() {
        enabledSwitch.state = settings.isEnabled ? .on : .off
        loginButton.state = settings.startAtLogin ? .on : .off
        builtInOnlyButton.state = settings.builtInScreenOnly ? .on : .off
        roundCornersButton.state = settings.roundCorners ? .on : .off
        dynamicButton.state = settings.useDynamicWallpapers ? .on : .off
        radiusPopup.selectItem(at: ["small", "medium", "high"].firstIndex(of: settings.cornerRadius.rawValue) ?? 1)
        radiusPopup.isEnabled = settings.roundCorners
        previewView.isEnabled = settings.isEnabled
        previewView.needsDisplay = true
    }

    private func publishChange() {
        delegate?.popupViewControllerDidChangeSettings(settings)
    }

    @objc private func toggleEnabled() {
        settings.isEnabled = enabledSwitch.state == .on
        publishChange()
        updateControls()
    }

    @objc private func toggleLogin() {
        settings.startAtLogin = loginButton.state == .on
        publishChange()
    }

    @objc private func toggleBuiltInOnly() {
        settings.builtInScreenOnly = builtInOnlyButton.state == .on
        publishChange()
    }

    @objc private func toggleRoundCorners() {
        settings.roundCorners = roundCornersButton.state == .on
        radiusPopup.isEnabled = settings.roundCorners
        publishChange()
    }

    @objc private func toggleDynamic() {
        settings.useDynamicWallpapers = dynamicButton.state == .on
        publishChange()
    }

    @objc private func changeRadius() {
        settings.cornerRadius = CornerRadius(rawValue: radiusPopup.titleOfSelectedItem?.lowercased() ?? "") ?? .medium
        publishChange()
    }

    @objc private func openWebsite() {
        delegate?.popupViewControllerDidRequestWebsite()
    }

    @objc private func showDynamicInfo(_ sender: NSButton) {
        let popover = NSPopover()
        popover.behavior = .transient
        popover.contentViewController = NSViewController()
        let label = textLabel(
            "Dynamic wallpapers change depending on macOS appearance and time. Processing them takes longer than static images.",
            color: .labelColor,
            font: .systemFont(ofSize: 12)
        )
        label.lineBreakMode = .byWordWrapping
        label.maximumNumberOfLines = 0
        label.frame = NSRect(x: 16, y: 16, width: 220, height: 90)
        popover.contentViewController?.view = NSView(frame: NSRect(x: 0, y: 0, width: 252, height: 122))
        popover.contentViewController?.view.addSubview(label)
        popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .maxY)
    }

    @objc private func openGearMenu(_ sender: NSButton) {
        let menu = MenuFactory.gearMenu(
            target: self,
            hideAction: #selector(hideIcon),
            websiteAction: #selector(openWebsite),
            quitAction: #selector(quit)
        )
        if let event = NSApp.currentEvent {
            NSMenu.popUpContextMenu(menu, with: event, for: sender)
        }
    }

    @objc private func hideIcon() {
        settings.hideMenuBarIcon = true
        publishChange()
        delegate?.popupViewControllerDidRequestHideIcon()
    }

    @objc private func quit() {
        delegate?.popupViewControllerDidRequestQuit()
    }
}

private func textLabel(_ text: String, color: NSColor, font: NSFont) -> NSTextField {
    let label = NSTextField(labelWithString: text)
    label.textColor = color
    label.font = font
    return label
}

private func linkButton(_ title: String, target: AnyObject?, action: Selector) -> NSButton {
    let button = NSButton(title: title, target: target, action: action)
    button.isBordered = false
    button.font = .systemFont(ofSize: 12, weight: .medium)
    button.contentTintColor = .systemBlue
    button.attributedTitle = NSAttributedString(
        string: title,
        attributes: [
            .font: NSFont.systemFont(ofSize: 12, weight: .medium),
            .foregroundColor: NSColor.systemBlue,
        ]
    )
    return button
}

private func checkbox(_ title: String, target: AnyObject?, action: Selector) -> NSButton {
    let button = NSButton(checkboxWithTitle: title, target: target, action: action)
    button.attributedTitle = NSAttributedString(
        string: title,
        attributes: [
            .font: NSFont.systemFont(ofSize: 13),
            .foregroundColor: NSColor.labelColor,
        ]
    )
    return button
}
