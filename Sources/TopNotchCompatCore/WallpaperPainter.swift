import AppKit
import CryptoKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

public enum WallpaperOutputKind: Equatable {
    case dynamic
    case staticImage
}

public enum WallpaperPainterError: Error, Equatable {
    case missingScreen
    case missingWallpaper
    case untrackedGeneratedWallpaper
    case unreadableWallpaper
    case cannotCreateOutput
    case desktopWriteFailed(String)
}

public final class WallpaperPainter {
    private let store: WallpaperStore
    private let workspace: NSWorkspace

    public init(store: WallpaperStore, workspace: NSWorkspace = .shared) {
        self.store = store
        self.workspace = workspace
        store.load()
    }

    public func apply(
        to screens: [NSScreen],
        settings: WallpaperSettings
    ) throws {
        let descriptors = Self.eligibleScreens(screens.map(\.descriptor), builtInOnly: settings.builtInScreenOnly)
        guard !descriptors.isEmpty else { return }

        for screen in screens where descriptors.contains(screen.descriptor) {
            try apply(to: screen, descriptor: screen.descriptor, settings: settings)
        }
    }

    public func restoreActiveScreens() throws {
        for screen in NSScreen.screens {
            guard
                let currentURL = workspace.desktopImageURL(for: screen),
                store.isGeneratedURL(currentURL),
                let record = store.record(forGenerated: currentURL)
            else { continue }

            do {
                try workspace.setDesktopImageURL(
                    record.originalURL,
                    for: screen,
                    options: record.originalDesktopOptions
                )
            } catch {
                throw WallpaperPainterError.desktopWriteFailed("\(error.localizedDescription)")
            }
        }
    }

    private func apply(
        to screen: NSScreen,
        descriptor: ScreenDescriptor,
        settings: WallpaperSettings
    ) throws {
        guard let currentURL = workspace.desktopImageURL(for: screen) else {
            throw WallpaperPainterError.missingWallpaper
        }

        let originalURL: URL
        let originalScaling: ImageScaling
        let originalAllowsClipping: Bool
        let originalFillColorHex: String?

        if store.isGeneratedURL(currentURL) {
            guard let record = store.record(forGenerated: currentURL) else {
                throw WallpaperPainterError.untrackedGeneratedWallpaper
            }
            originalURL = record.originalURL
            originalScaling = record.scaling
            originalAllowsClipping = record.allowsClipping
            originalFillColorHex = record.fillColorHex
        } else {
            let options = workspace.desktopImageOptions(for: screen) ?? [:]
            originalURL = currentURL
            originalScaling = ImageScaling(
                desktopRawValue: options[.imageScaling] as? Int ?? ImageScaling.proportionallyUpOrDown.desktopRawValue
            )
            originalAllowsClipping = options[.allowClipping] as? Bool ?? true
            originalFillColorHex = (options[.fillColor] as? NSColor)?.hexadecimalString
        }

        if let reusable = reusableRecord(
            originalURL: originalURL,
            descriptor: descriptor,
            settings: settings
        ) {
            if workspace.desktopImageURL(for: screen)?.standardizedFileURL != reusable.generatedURL.standardizedFileURL {
                var options = [NSWorkspace.DesktopImageOptionKey: Any]()
                options[.imageScaling] = ImageScaling.axesIndependently.desktopRawValue
                options[.allowClipping] = true
                if settings.roundCorners {
                    options[.fillColor] = NSColor.black
                }
                do {
                    try workspace.setDesktopImageURL(reusable.generatedURL, for: screen, options: options)
                } catch {
                    throw WallpaperPainterError.desktopWriteFailed(error.localizedDescription)
                }
            }
            try store.save(reusable)
            return
        }

        guard let (source, digest) = Self.readableSourceAndDigest(for: originalURL, in: store) else {
            throw WallpaperPainterError.unreadableWallpaper
        }

        let frameCount = CGImageSourceGetCount(source)
        guard frameCount > 0 else { throw WallpaperPainterError.unreadableWallpaper }
        let outputKind = Self.outputKind(frameCount: frameCount, useDynamic: settings.useDynamicWallpapers)
        let filename = Self.generatedFilename(
            originalPath: originalURL.path,
            digest: digest,
            canvasSize: descriptor.pixelSize,
            cornerRadius: settings.cornerRadius,
            rounded: settings.roundCorners,
            barHeight: WallpaperGeometry.paintedBarHeight(
                menuBarHeight: Self.menuBarHeight(for: descriptor),
                backingScaleFactor: descriptor.backingScaleFactor
            ),
            dynamic: outputKind == .dynamic
        )
        let outputURL = store.generatedDirectory.appendingPathComponent(filename)

        if !FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.createDirectory(at: store.generatedDirectory, withIntermediateDirectories: true)
            try Self.writeWallpaper(
                from: source,
                to: outputURL,
                descriptor: descriptor,
                scaling: originalScaling,
                allowsClipping: originalAllowsClipping,
                settings: settings,
                dynamic: outputKind == .dynamic
            )
        }

        if workspace.desktopImageURL(for: screen)?.standardizedFileURL != outputURL.standardizedFileURL {
            var options = [NSWorkspace.DesktopImageOptionKey: Any]()
            options[.imageScaling] = ImageScaling.axesIndependently.desktopRawValue
            options[.allowClipping] = true
            if settings.roundCorners {
                options[.fillColor] = NSColor.black
            }

            do {
                try workspace.setDesktopImageURL(outputURL, for: screen, options: options)
            } catch {
                throw WallpaperPainterError.desktopWriteFailed(error.localizedDescription)
            }
        }

        let record = WallpaperRecord(
            generatedURL: outputURL,
            originalURL: originalURL,
            scaling: originalScaling,
            allowsClipping: originalAllowsClipping,
            fillColorHex: originalFillColorHex
        )
        try store.save(record)
    }

    public static func eligibleScreens(
        _ screens: [ScreenDescriptor],
        builtInOnly: Bool
    ) -> [ScreenDescriptor] {
        screens.filter { screen in
            guard screen.safeAreaTop > 0, screen.frame.width > 0, screen.frame.height > 0 else { return false }
            return !builtInOnly || screen.isBuiltIn
        }
    }

    public static func outputKind(frameCount: Int, useDynamic: Bool) -> WallpaperOutputKind {
        frameCount > 1 && useDynamic ? .dynamic : .staticImage
    }

    private func reusableRecord(
        originalURL: URL,
        descriptor: ScreenDescriptor,
        settings: WallpaperSettings
    ) -> WallpaperRecord? {
        let canvasSize = descriptor.pixelSize
        let barHeight = WallpaperGeometry.paintedBarHeight(
            menuBarHeight: Self.menuBarHeight(for: descriptor),
            backingScaleFactor: descriptor.backingScaleFactor
        )
        let signature = [
            "\(Int(canvasSize.width))x\(Int(canvasSize.height))",
            settings.cornerRadius.rawValue,
            "round-\(settings.roundCorners ? "on" : "off")",
            "bar-\(Int(barHeight))",
            "v7",
        ].joined(separator: "-")

        return store.allRecords.first { record in
            record.originalURL.standardizedFileURL == originalURL.standardizedFileURL &&
            record.generatedURL.lastPathComponent.contains(signature) &&
            FileManager.default.fileExists(atPath: record.generatedURL.path)
        }
    }

    public static func generatedFilename(
        originalPath: String,
        digest: String,
        canvasSize: CGSize,
        cornerRadius: CornerRadius,
        rounded: Bool,
        barHeight: CGFloat,
        dynamic: Bool
    ) -> String {
        let stem = URL(fileURLWithPath: originalPath).deletingPathExtension().lastPathComponent
            .map { $0.isLetter || $0.isNumber ? $0 : "-" }
            .prefix(48)
        let prefix = String(stem).trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        let kind = dynamic ? "dynamic" : "static"
        return "\(prefix.isEmpty ? "wallpaper" : prefix)-\(digest.prefix(12))-\(Int(canvasSize.width))x\(Int(canvasSize.height))-\(cornerRadius.rawValue)-round-\(rounded ? "on" : "off")-bar-\(Int(barHeight))-v7-\(kind).\(dynamic ? "heic" : "png")"
    }

    public static func menuBarHeight(for descriptor: ScreenDescriptor) -> CGFloat {
        WallpaperGeometry.menuBarHeight(
            safeAreaTop: descriptor.safeAreaTop,
            systemMenuBarHeight: descriptor.systemMenuBarHeight
        )
    }

    private static func digest(forFileAt url: URL) -> String {
        guard let data = try? Data(contentsOf: url) else { return UUID().uuidString }
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private static func readableSourceAndDigest(
        for originalURL: URL,
        in store: WallpaperStore
    ) -> (CGImageSource, String)? {
        var digest = digest(forFileAt: originalURL)
        if let source = CGImageSourceCreateWithURL(originalURL as CFURL, nil),
           CGImageSourceGetCount(source) > 0,
           digest.count == 64 {
            return (source, digest)
        }

        // ponytail: Desktop TCC can deny a re-signed ad-hoc app direct access; migrate from v5 until the app has a stable signing identity.
        guard
            let prior = store.allRecords.last(where: {
                $0.originalURL.standardizedFileURL == originalURL.standardizedFileURL &&
                $0.generatedURL.lastPathComponent.contains("-v5-") &&
                FileManager.default.fileExists(atPath: $0.generatedURL.path)
            }),
            let source = CGImageSourceCreateWithURL(prior.generatedURL as CFURL, nil),
            CGImageSourceGetCount(source) > 0
        else { return nil }

        let components = prior.generatedURL.lastPathComponent.split(separator: "-")
        if digest.count != 64, let existing = components.first(where: { $0.count == 12 }) {
            digest = String(existing)
        }
        return (source, digest)
    }

    static func writeWallpaper(
        from source: CGImageSource,
        to outputURL: URL,
        descriptor: ScreenDescriptor,
        scaling: ImageScaling,
        allowsClipping: Bool,
        settings: WallpaperSettings,
        dynamic: Bool
    ) throws {
        let frameIndices = dynamic ? Array(0..<CGImageSourceGetCount(source)) : [0]
        guard CGImageSourceCreateImageAtIndex(source, 0, nil) != nil else {
            throw WallpaperPainterError.unreadableWallpaper
        }

        let typeIdentifier = dynamic
            ? UTType.heic.identifier as CFString
            : UTType.png.identifier as CFString
        guard let destination = CGImageDestinationCreateWithURL(
            outputURL as CFURL,
            typeIdentifier,
            frameIndices.count,
            nil
        ) else { throw WallpaperPainterError.cannotCreateOutput }

        for index in frameIndices {
            guard let image = CGImageSourceCreateImageAtIndex(source, index, nil) else {
                throw WallpaperPainterError.unreadableWallpaper
            }
            let rendered = render(
                image: image,
                descriptor: descriptor,
                scaling: scaling,
                allowsClipping: allowsClipping,
                settings: settings
            )
            let metadata = CGImageSourceCopyMetadataAtIndex(source, index, nil)
            if let metadata {
                CGImageDestinationAddImageAndMetadata(destination, rendered, metadata, nil)
            } else {
                CGImageDestinationAddImage(destination, rendered, nil)
            }
        }

        guard CGImageDestinationFinalize(destination) else {
            throw WallpaperPainterError.cannotCreateOutput
        }
    }

    static func render(
        image: CGImage,
        descriptor: ScreenDescriptor,
        scaling: ImageScaling,
        allowsClipping: Bool,
        settings: WallpaperSettings
    ) -> CGImage {
        let canvasSize = descriptor.pixelSize
        let width = Int(canvasSize.width)
        let height = Int(canvasSize.height)
        let bitsPerComponent = 8
        let bytesPerRow = 0
        let colorSpace = image.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)!
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            return image
        }

        let canvasRect = CGRect(origin: .zero, size: canvasSize)
        let blackColor = CGColor(red: 0, green: 0, blue: 0, alpha: 1)

        let imageSize = CGSize(width: image.width, height: image.height)
        let placement = WallpaperGeometry.placement(
            imageSize: imageSize,
            canvasSize: canvasSize,
            scaling: scaling,
            allowsClipping: allowsClipping
        )
        context.draw(image, in: placement)

        let barHeight = WallpaperGeometry.paintedBarHeight(
            menuBarHeight: menuBarHeight(for: descriptor),
            backingScaleFactor: descriptor.backingScaleFactor
        )
        let barRect = CGRect(x: 0, y: CGFloat(height) - barHeight, width: canvasSize.width, height: barHeight)
        context.setFillColor(blackColor)
        context.fill(barRect)

        if settings.roundCorners {
            let radius = settings.cornerRadius.points * descriptor.backingScaleFactor
            let appRadius = WallpaperGeometry.appWindowCornerRadius * descriptor.backingScaleFactor
            for path in Self.appCornerFillPaths(
                in: canvasRect,
                menuBarHeight: barHeight,
                radius: appRadius
            ) {
                context.addPath(path)
                context.fillPath()
            }
            context.saveGState()
            context.addPath(CGPath(rect: canvasRect, transform: nil))
            context.addPath(Self.bottomRoundedPath(in: canvasRect, radius: radius))
            context.clip(using: .evenOdd)
            context.setFillColor(blackColor)
            context.fill(canvasRect)
            context.restoreGState()
        }

        return context.makeImage() ?? image
    }

    private static func bottomRoundedPath(in rect: CGRect, radius: CGFloat) -> CGPath {
        let radius = min(radius, rect.width / 2, rect.height / 2)
        let path = CGMutablePath()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + radius))
        path.addArc(
            tangent1End: CGPoint(x: rect.maxX, y: rect.minY),
            tangent2End: CGPoint(x: rect.maxX - radius, y: rect.minY),
            radius: radius
        )
        path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.minY))
        path.addArc(
            tangent1End: CGPoint(x: rect.minX, y: rect.minY),
            tangent2End: CGPoint(x: rect.minX, y: rect.minY + radius),
            radius: radius
        )
        path.closeSubpath()
        return path
    }

    static func appCornerFillPaths(
        in rect: CGRect,
        menuBarHeight: CGFloat,
        radius: CGFloat
    ) -> [CGPath] {
        let appTop = rect.maxY - menuBarHeight
        let radius = min(radius, rect.width / 2, max(0, appTop - rect.minY))
        guard radius > 0 else { return [] }

        let left = CGMutablePath()
        left.move(to: CGPoint(x: rect.minX, y: appTop))
        left.addLine(to: CGPoint(x: rect.minX + radius, y: appTop))
        left.addArc(
            center: CGPoint(x: rect.minX + radius, y: appTop - radius),
            radius: radius,
            startAngle: .pi / 2,
            endAngle: .pi,
            clockwise: false
        )
        left.closeSubpath()

        let right = CGMutablePath()
        right.move(to: CGPoint(x: rect.maxX, y: appTop))
        right.addLine(to: CGPoint(x: rect.maxX - radius, y: appTop))
        right.addArc(
            center: CGPoint(x: rect.maxX - radius, y: appTop - radius),
            radius: radius,
            startAngle: .pi / 2,
            endAngle: 0,
            clockwise: true
        )
        right.closeSubpath()

        return [left, right]
    }

}

extension NSScreen {
    public var descriptor: ScreenDescriptor {
        let number = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
        let id = number?.uint32Value ?? CGDirectDisplayID(0)
        return ScreenDescriptor(
            id: id,
            frame: frame,
            backingScaleFactor: backingScaleFactor,
            safeAreaTop: safeAreaInsets.top,
            systemMenuBarHeight: NSMenu().menuBarHeight,
            isBuiltIn: id == 0 ? false : CGDisplayIsBuiltin(id) == 1
        )
    }
}
