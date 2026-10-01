import AppKit
import Foundation

public enum CornerRadius: String, Codable, CaseIterable, Equatable {
    case small
    case medium
    case high

    public var points: CGFloat {
        switch self {
        case .small: return 12
        case .medium: return 24
        case .high: return 36
        }
    }
}

public enum ImageScaling: Int, Codable, CaseIterable {
    case proportionallyDown = 0
    case axesIndependently = 1
    case none = 2
    case proportionallyUpOrDown = 3

    public var desktopRawValue: Int { rawValue }

    public init(desktopRawValue: Int) {
        self = ImageScaling(rawValue: desktopRawValue) ?? .proportionallyUpOrDown
    }
}

public struct WallpaperSettings: Codable, Equatable {
    public var isEnabled: Bool
    public var startAtLogin: Bool
    public var builtInScreenOnly: Bool
    public var roundCorners: Bool
    public var cornerRadius: CornerRadius
    public var useDynamicWallpapers: Bool
    public var hideMenuBarIcon: Bool
    public var hasAcceptedStartupNotice: Bool

    public init(
        isEnabled: Bool = true,
        startAtLogin: Bool = false,
        builtInScreenOnly: Bool = false,
        roundCorners: Bool = false,
        cornerRadius: CornerRadius = .medium,
        useDynamicWallpapers: Bool = true,
        hideMenuBarIcon: Bool = false,
        hasAcceptedStartupNotice: Bool = false
    ) {
        self.isEnabled = isEnabled
        self.startAtLogin = startAtLogin
        self.builtInScreenOnly = builtInScreenOnly
        self.roundCorners = roundCorners
        self.cornerRadius = cornerRadius
        self.useDynamicWallpapers = useDynamicWallpapers
        self.hideMenuBarIcon = hideMenuBarIcon
        self.hasAcceptedStartupNotice = hasAcceptedStartupNotice
    }
}

public final class SettingsStore {
    private let defaults: UserDefaults
    private let key = "TopNotchCompat.settings"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var settings: WallpaperSettings {
        get {
            guard
                let data = defaults.data(forKey: key),
                let decoded = try? JSONDecoder().decode(WallpaperSettings.self, from: data)
            else { return WallpaperSettings() }
            return decoded
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue) else { return }
            defaults.set(data, forKey: key)
        }
    }
}

public struct ScreenDescriptor: Equatable {
    public var id: CGDirectDisplayID
    public var frame: CGRect
    public var backingScaleFactor: CGFloat
    public var safeAreaTop: CGFloat
    public var systemMenuBarHeight: CGFloat
    public var isBuiltIn: Bool

    public init(
        id: CGDirectDisplayID,
        frame: CGRect,
        backingScaleFactor: CGFloat,
        safeAreaTop: CGFloat,
        systemMenuBarHeight: CGFloat,
        isBuiltIn: Bool
    ) {
        self.id = id
        self.frame = frame
        self.backingScaleFactor = backingScaleFactor
        self.safeAreaTop = safeAreaTop
        self.systemMenuBarHeight = systemMenuBarHeight
        self.isBuiltIn = isBuiltIn
    }

    public var pixelSize: CGSize {
        CGSize(
            width: (frame.width * backingScaleFactor).rounded(),
            height: (frame.height * backingScaleFactor).rounded()
        )
    }
}

public struct WallpaperRecord: Codable, Equatable {
    public var generatedURL: URL
    public var originalURL: URL
    public var scaling: ImageScaling
    public var allowsClipping: Bool
    public var fillColorHex: String?

    public init(
        generatedURL: URL,
        originalURL: URL,
        scaling: ImageScaling,
        allowsClipping: Bool,
        fillColorHex: String?
    ) {
        self.generatedURL = generatedURL
        self.originalURL = originalURL
        self.scaling = scaling
        self.allowsClipping = allowsClipping
        self.fillColorHex = fillColorHex
    }

    public var originalDesktopOptions: [NSWorkspace.DesktopImageOptionKey: Any] {
        var options = [NSWorkspace.DesktopImageOptionKey: Any]()
        options[.imageScaling] = scaling.desktopRawValue
        options[.allowClipping] = allowsClipping
        if let fillColorHex {
            options[.fillColor] = NSColor(hex: fillColorHex) ?? .black
        }
        return options
    }
}

public enum MenuSpec {
    public static let topNotch: [MenuEntry] = [
        MenuEntry.item("Hide Menubar Icon"),
        MenuEntry.separator,
        MenuEntry.disabledItem("Check for Updates..."),
        MenuEntry.item("Visit Website"),
        MenuEntry.separator,
        MenuEntry.item("Quit", keyEquivalent: "q"),
    ]
}

public struct MenuEntry: Equatable {
    public var title: String
    public var keyEquivalent: String
    public var isEnabled: Bool
    public var isSeparator: Bool

    public static func item(_ title: String, keyEquivalent: String = "") -> MenuEntry {
        MenuEntry(title: title, keyEquivalent: keyEquivalent, isEnabled: true, isSeparator: false)
    }

    public static func disabledItem(_ title: String) -> MenuEntry {
        MenuEntry(title: title, keyEquivalent: "", isEnabled: false, isSeparator: false)
    }

    public static var separator: MenuEntry {
        MenuEntry(title: "", keyEquivalent: "", isEnabled: false, isSeparator: true)
    }

    private init(title: String, keyEquivalent: String, isEnabled: Bool, isSeparator: Bool) {
        self.title = title
        self.keyEquivalent = keyEquivalent
        self.isEnabled = isEnabled
        self.isSeparator = isSeparator
    }
}

public enum WallpaperGeometry {
    /// Measured from a standard full-screen macOS 27 window at 2×.
    public static let appWindowCornerRadius: CGFloat = 15.5

    public static func menuBarHeight(safeAreaTop: CGFloat, systemMenuBarHeight: CGFloat) -> CGFloat {
        max(24, safeAreaTop, systemMenuBarHeight)
    }

    public static func paintedBarHeight(menuBarHeight: CGFloat, backingScaleFactor: CGFloat) -> CGFloat {
        guard backingScaleFactor > 0 else { return menuBarHeight.rounded() + 2 }
        return (menuBarHeight * backingScaleFactor).rounded() + 2
    }

    public static func placement(
        imageSize: CGSize,
        canvasSize: CGSize,
        scaling: ImageScaling,
        allowsClipping: Bool
    ) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0, canvasSize.width > 0, canvasSize.height > 0 else {
            return .zero
        }

        switch scaling {
        case .axesIndependently:
            return CGRect(origin: .zero, size: canvasSize)
        case .none:
            return CGRect(
                x: (canvasSize.width - imageSize.width) / 2,
                y: (canvasSize.height - imageSize.height) / 2,
                width: imageSize.width,
                height: imageSize.height
            )
        case .proportionallyDown, .proportionallyUpOrDown:
            let scale = max(canvasSize.width / imageSize.width, canvasSize.height / imageSize.height)
            let containedScale = min(canvasSize.width / imageSize.width, canvasSize.height / imageSize.height)
            let selectedScale: CGFloat
            if scaling == .proportionallyDown && max(imageSize.width, imageSize.height) <= max(canvasSize.width, canvasSize.height) {
                selectedScale = 1
            } else {
                selectedScale = allowsClipping ? scale : containedScale
            }
            let size = CGSize(width: imageSize.width * selectedScale, height: imageSize.height * selectedScale)
            return CGRect(
                x: (canvasSize.width - size.width) / 2,
                y: (canvasSize.height - size.height) / 2,
                width: size.width,
                height: size.height
            )
        }
    }
}

extension NSColor {
    public convenience init?(hex: String) {
        let value = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        guard value.count == 6, let rgb = UInt64(value, radix: 16) else { return nil }
        self.init(
            calibratedRed: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
    }

    public var hexadecimalString: String? {
        guard let color = usingColorSpace(.sRGB) else { return nil }
        func component(_ channel: CGFloat) -> Int { Int((channel * 255).rounded().clamped(to: 0...255)) }
        return String(format: "#%02X%02X%02X", component(color.redComponent), component(color.greenComponent), component(color.blueComponent))
    }
}

extension Comparable {
    fileprivate func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
