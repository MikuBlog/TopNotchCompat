import AppKit

final class PopupRootView: NSView {
    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.setFill()
        bounds.fill()
    }
}

final class PopupBackgroundView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(
            roundedRect: NSRect(x: 13, y: 13, width: 327, height: 482),
            xRadius: 18,
            yRadius: 18
        )
        NSColor(calibratedWhite: 0.06, alpha: 0.94).setFill()
        path.fill()
        NSColor.white.withAlphaComponent(0.11).setStroke()
        path.lineWidth = 1
        path.stroke()
    }
}

final class CardView: NSView {
    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        wantsLayer = true
        layer?.backgroundColor = NSColor.white.withAlphaComponent(0.055).cgColor
        layer?.cornerRadius = 10
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.white.withAlphaComponent(0.08).cgColor
    }
}

final class WallpaperPreviewView: NSView {
    var isEnabled = true

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.saveGState()
        context.addPath(Self.topRoundedPath(in: bounds, radius: 10))
        context.clip()

        let colors = [
            NSColor(calibratedRed: 0.35, green: 0.12, blue: 0.82, alpha: 1).cgColor,
            NSColor(calibratedRed: 0.72, green: 0.28, blue: 0.86, alpha: 1).cgColor,
            NSColor(calibratedRed: 0.94, green: 0.48, blue: 0.75, alpha: 1).cgColor,
        ] as CFArray
        let gradient = CGGradient(
            colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
            colors: colors,
            locations: [0, 0.52, 1]
        )
        if let gradient {
            context.drawLinearGradient(
                gradient,
                start: CGPoint(x: 0, y: bounds.maxY),
                end: CGPoint(x: bounds.maxX, y: bounds.minY),
                options: []
            )
        }

        let topHeight = bounds.height * 0.28
        if isEnabled {
            context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
            context.fill(CGRect(x: 0, y: bounds.maxY - topHeight, width: bounds.width, height: topHeight))
        } else {
            let notchWidth = bounds.width * 0.30
            let notch = CGRect(
                x: (bounds.width - notchWidth) / 2,
                y: bounds.maxY - topHeight,
                width: notchWidth,
                height: topHeight
            )
            context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
            context.fill(notch)
        }

        let cameraCenter = CGPoint(x: bounds.midX - 3, y: bounds.maxY - topHeight / 2)
        context.setFillColor(CGColor(red: 0.06, green: 0.06, blue: 0.06, alpha: 1))
        context.fillEllipse(in: CGRect(x: cameraCenter.x - 3, y: cameraCenter.y - 3, width: 6, height: 6))
        context.setFillColor(CGColor(red: 0.2, green: 0.9, blue: 0.35, alpha: 1))
        context.fillEllipse(in: CGRect(x: cameraCenter.x + 3, y: cameraCenter.y - 1.25, width: 2.5, height: 2.5))
        context.restoreGState()
    }

    private static func topRoundedPath(in rect: CGRect, radius: CGFloat) -> CGPath {
        let radius = min(radius, rect.width / 2, rect.height)
        let path = CGMutablePath()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - radius))
        path.addArc(
            tangent1End: CGPoint(x: rect.minX, y: rect.maxY),
            tangent2End: CGPoint(x: rect.minX + radius, y: rect.maxY),
            radius: radius
        )
        path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.maxY))
        path.addArc(
            tangent1End: CGPoint(x: rect.maxX, y: rect.maxY),
            tangent2End: CGPoint(x: rect.maxX, y: rect.maxY - radius),
            radius: radius
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}
