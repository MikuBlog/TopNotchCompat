import AppKit
import TopNotchCompatCore

protocol StatusItemControllerDelegate: AnyObject {
    func statusItemControllerDidChangeSettings(_ settings: WallpaperSettings)
    func statusItemControllerDidRequestWebsite()
    func statusItemControllerDidRequestHideIcon()
    func statusItemControllerDidRequestQuit()
}

final class StatusItemController: NSObject {
    private weak var delegate: StatusItemControllerDelegate?
    private var settings: WallpaperSettings
    private let statusItem: NSStatusItem
    private lazy var panel = makePanel()
    private var eventMonitors = [Any?]()
    private var iconTimer: Timer?
    private var isOpen = false

    init(settings: WallpaperSettings, delegate: StatusItemControllerDelegate) {
        self.settings = settings
        self.delegate = delegate
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()

        statusItem.button?.image = Self.makeStatusIcon()
        statusItem.button?.imagePosition = .imageOnly
        statusItem.button?.target = self
        statusItem.button?.action = #selector(togglePopover)
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])

        if settings.hideMenuBarIcon {
            showIconTemporarily()
        }
    }

    func setSettings(_ settings: WallpaperSettings) {
        self.settings = settings
        if let controller = panel.contentViewController as? PopupViewController {
            controller.update(settings: settings)
        }
    }

    func setProcessing(_ processing: Bool) {
        if let controller = panel.contentViewController as? PopupViewController {
            controller.setProcessing(processing)
        }
    }

    func closePopover() {
        guard isOpen else { return }
        isOpen = false
        panel.orderOut(nil)
        removeEventMonitors()
    }

    func hideIconTemporarily() {
        showIconTemporarily()
    }

    private func showIconTemporarily() {
        iconTimer?.invalidate()
        statusItem.isVisible = true
        iconTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: false) { [weak self] _ in
            self?.statusItem.isVisible = false
        }
    }

    @objc private func togglePopover() {
        if isOpen {
            closePopover()
        } else {
            showPopover()
        }
    }

    private func showPopover() {
        installEventMonitors()
        positionPanel()
        panel.orderFrontRegardless()
        isOpen = true
    }

    private func positionPanel() {
        guard
            let buttonFrame = statusItem.button?.window?.frame,
            let screen = NSScreen.main
        else { return }

        let panelFrame = panel.frame
        let visibleFrame = screen.frame
        var origin = CGPoint(
            x: buttonFrame.midX - panelFrame.width / 2,
            y: buttonFrame.minY - panelFrame.height + 13
        )
        origin.x = min(max(origin.x, visibleFrame.minX + 6), visibleFrame.maxX - panelFrame.width - 6)
        if origin.y < visibleFrame.minY {
            origin.y = buttonFrame.maxY
        }
        panel.setFrameOrigin(origin)
    }

    private func makePanel() -> NSPanel {
        let rect = NSRect(x: 0, y: 0, width: 353, height: 508)
        let panel = NonactivatingPanel(
            contentRect: rect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.contentViewController = PopupViewController(settings: settings, delegate: self)
        panel.orderOut(nil)
        return panel
    }

    private func installEventMonitors() {
        let global = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] _ in
            self?.closePopover()
        }
        let local = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] event in
            if let window = event.window, window !== self?.panel {
                self?.closePopover()
            }
            return event
        }
        eventMonitors = [global, local]
    }

    private func removeEventMonitors() {
        for monitor in eventMonitors {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
        }
        eventMonitors.removeAll()
    }

    private static func makeStatusIcon() -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18))
        image.lockFocus()
        NSColor.black.setStroke()
        NSColor.black.setFill()

        let body = NSBezierPath(
            roundedRect: NSRect(x: 1.5, y: 3, width: 15, height: 12),
            xRadius: 3.5,
            yRadius: 3.5
        )
        body.lineWidth = 1.5
        body.stroke()

        let slot = NSBezierPath(roundedRect: NSRect(x: 7, y: 2.5, width: 4, height: 3), xRadius: 1, yRadius: 1)
        slot.fill()
        image.unlockFocus()
        image.isTemplate = true
        return image
    }
}

extension StatusItemController: PopupViewControllerDelegate {
    func popupViewControllerDidChangeSettings(_ settings: WallpaperSettings) {
        delegate?.statusItemControllerDidChangeSettings(settings)
    }

    func popupViewControllerDidRequestWebsite() {
        delegate?.statusItemControllerDidRequestWebsite()
    }

    func popupViewControllerDidRequestHideIcon() {
        delegate?.statusItemControllerDidRequestHideIcon()
    }

    func popupViewControllerDidRequestQuit() {
        closePopover()
        delegate?.statusItemControllerDidRequestQuit()
    }
}

extension StatusItemController: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        for item in menu.items {
            item.target = self
        }
    }

    @objc private func hideIcon() {
        var settings = currentSettings()
        settings.hideMenuBarIcon = true
        delegate?.statusItemControllerDidChangeSettings(settings)
        hideIconTemporarily()
    }

    @objc private func visitWebsite() {
        delegate?.statusItemControllerDidRequestWebsite()
    }

    @objc private func quit() {
        popupViewControllerDidRequestQuit()
    }

    private func currentSettings() -> WallpaperSettings {
        (panel.contentViewController as? PopupViewController)?.currentSettings ?? settings
    }
}

final class NonactivatingPanel: NSPanel {
    override var canBecomeKey: Bool { false }
}
