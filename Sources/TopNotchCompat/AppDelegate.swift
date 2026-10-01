import AppKit
import ServiceManagement
import TopNotchCompatCore

@main
final class AppDelegate: NSObject, NSApplicationDelegate {
    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        application.run()
    }

    private let settingsStore = SettingsStore()
    private lazy var wallpaperStore = WallpaperStore()
    private lazy var painter = WallpaperPainter(store: wallpaperStore)
    private var statusController: StatusItemController?
    private var refreshTimer: Timer?
    private var applyTask: Task<Void, Never>?
    private var lastWallpaperURLs = Set<String>()
    private var isProcessing = false {
        didSet { statusController?.setProcessing(isProcessing) }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        wallpaperStore.load()
        wallpaperStore.removeRecordsForMissingFiles()
        statusController = StatusItemController(
            settings: settingsStore.settings,
            delegate: self
        )

        if settingsStore.settings.hasAcceptedStartupNotice {
            startApplication()
        } else {
            presentWelcome()
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        applyTask?.cancel()
        refreshTimer?.invalidate()

        if settingsStore.settings.isEnabled {
            do {
                try painter.restoreActiveScreens()
            } catch {
                let alert = NSAlert()
                alert.messageText = "Could not restore wallpaper"
                alert.informativeText = "TopNotchCompat could not restore the active desktop. Your original wallpaper remains stored in its settings."
                alert.addButton(withTitle: "Quit Anyway")
                alert.addButton(withTitle: "Cancel")
                if alert.runModal() == .alertFirstButtonReturn {
                    return .terminateNow
                }
                return .terminateCancel
            }
        }
        return .terminateNow
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func startApplication() {
        statusController?.setSettings(settingsStore.settings)
        statusController?.closePopover()
        configureLoginItem(settingsStore.settings.startAtLogin, reportErrors: false)
        observeSystemChanges()

        if settingsStore.settings.isEnabled {
            scheduleApply(reason: .startup)
        }
    }

    private func presentWelcome() {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "Hey, let's hide your notch!"
        var informativeText = """
        TopNotchCompat creates a copy of your current wallpaper with a black menu-bar strip. \
        Your original file is never modified, and quitting restores the active desktop.
        """
        if !NSRunningApplication.runningApplications(withBundleIdentifier: "pl.maketheweb.TopNotch").isEmpty {
            informativeText += "\n\nQuit the original TopNotch before enabling this app to avoid conflicts."
        }
        alert.informativeText = informativeText
        alert.addButton(withTitle: "Start")
        alert.addButton(withTitle: "Quit")
        NSApp.activate(ignoringOtherApps: true)

        if alert.runModal() == .alertFirstButtonReturn {
            var settings = settingsStore.settings
            settings.hasAcceptedStartupNotice = true
            settingsStore.settings = settings
            startApplication()
        } else {
            NSApp.terminate(self)
        }
    }

    private func observeSystemChanges() {
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(spaceDidChange),
            name: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )

        refreshTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            self?.refreshIfNeeded()
        }
    }

    @objc private func spaceDidChange() {
        statusController?.closePopover()
        if settingsStore.settings.isEnabled {
            scheduleApply(reason: .spaceChange)
        }
    }

    @objc private func screenParametersDidChange() {
        statusController?.closePopover()
        if settingsStore.settings.isEnabled {
            scheduleApply(reason: .screenChange)
        }
    }

    private func refreshIfNeeded() {
        guard settingsStore.settings.isEnabled, !isProcessing, applyTask == nil else { return }
        let currentURLs = Set(
            NSScreen.screens
                .compactMap { NSWorkspace.shared.desktopImageURL(for: $0)?.standardizedFileURL.path }
        )
        guard currentURLs != lastWallpaperURLs else { return }
        scheduleApply(reason: .wallpaperPoll)
    }

    private func scheduleApply(reason: ApplyReason) {
        guard !isProcessing else { return }
        isProcessing = true
        let settings = settingsStore.settings

        applyTask = Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            do {
                try self.painter.apply(to: NSScreen.screens, settings: settings)
                await MainActor.run {
                    self.isProcessing = false
                    self.applyTask = nil
                    self.lastWallpaperURLs = Set(
                        NSScreen.screens
                            .compactMap { NSWorkspace.shared.desktopImageURL(for: $0)?.standardizedFileURL.path }
                    )
                }
            } catch {
                await MainActor.run {
                    self.isProcessing = false
                    self.applyTask = nil
                    self.showWallpaperError(error, reason: reason)
                }
            }
        }
    }

    private func restore() {
        guard !isProcessing else { return }
        isProcessing = true

        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            do {
                try self.painter.restoreActiveScreens()
            } catch {
                await MainActor.run { self.showWallpaperError(error, reason: .manualRestore) }
            }
            await MainActor.run { self.isProcessing = false }
        }
    }

    private func showWallpaperError(_ error: Error, reason: ApplyReason) {
        let alert = NSAlert()
        alert.messageText = "Could not update wallpaper"
        alert.informativeText = error.localizedDescription
        alert.runModal()
    }

    private func configureLoginItem(_ enabled: Bool, reportErrors: Bool) {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            if reportErrors {
                let alert = NSAlert(error: error)
                alert.runModal()
            }
        }
    }
}

extension AppDelegate: StatusItemControllerDelegate {
    func statusItemControllerDidChangeSettings(_ settings: WallpaperSettings) {
        settingsStore.settings = settings
        statusController?.setSettings(settings)
        configureLoginItem(settings.startAtLogin, reportErrors: true)

        if settings.isEnabled {
            scheduleApply(reason: .settingsChange)
        } else {
            restore()
        }
    }

    func statusItemControllerDidRequestWebsite() {
        NSWorkspace.shared.open(URL(string: "https://topnotch.app")!)
    }

    func statusItemControllerDidRequestHideIcon() {
        statusController?.hideIconTemporarily()
    }

    func statusItemControllerDidRequestQuit() {
        NSApp.terminate(self)
    }
}

private enum ApplyReason {
    case startup
    case settingsChange
    case spaceChange
    case screenChange
    case wallpaperPoll
    case manualRestore
}
