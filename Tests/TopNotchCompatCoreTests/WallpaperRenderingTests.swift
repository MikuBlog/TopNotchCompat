import AppKit
import ImageIO
import UniformTypeIdentifiers
import XCTest
@testable import TopNotchCompatCore

final class WallpaperRenderingTests: XCTestCase {
    func testRenderKeepsMenuBarRectangular() throws {
        let descriptor = ScreenDescriptor(
            id: 1,
            frame: CGRect(x: 0, y: 0, width: 100, height: 100),
            backingScaleFactor: 1,
            safeAreaTop: 38,
            systemMenuBarHeight: 39,
            isBuiltIn: true
        )
        var settings = WallpaperSettings()
        settings.roundCorners = true
        settings.cornerRadius = .medium
        let rendered = WallpaperPainter.render(
            image: try makeImage(red: 1, green: 0, blue: 0),
            descriptor: descriptor,
            scaling: .axesIndependently,
            allowsClipping: true,
            settings: settings
        )
        let representation = try XCTUnwrap(NSBitmapImageRep(cgImage: rendered))

        XCTAssertEqual(Double(representation.colorAt(x: 50, y: 39)?.redComponent ?? -1), 0, accuracy: 0.02)
        XCTAssertEqual(Double(representation.colorAt(x: 50, y: 59)?.redComponent ?? -1), 1, accuracy: 0.02)
        XCTAssertEqual(Double(representation.colorAt(x: 1, y: 41)?.redComponent ?? -1), 0, accuracy: 0.02)
        XCTAssertEqual(Double(representation.colorAt(x: 98, y: 41)?.redComponent ?? -1), 0, accuracy: 0.02)
        XCTAssertEqual(Double(representation.colorAt(x: 15, y: 41)?.redComponent ?? -1), 1, accuracy: 0.02)
        XCTAssertEqual(Double(representation.colorAt(x: 8, y: 41)?.redComponent ?? -1), 0, accuracy: 0.02)
        XCTAssertEqual(Double(representation.colorAt(x: 0, y: 50)?.redComponent ?? -1), 0, accuracy: 0.02)
        XCTAssertEqual(Double(representation.colorAt(x: 8, y: 50)?.redComponent ?? -1), 1, accuracy: 0.02)
        XCTAssertEqual(Double(representation.colorAt(x: 1, y: 58)?.redComponent ?? -1), 1, accuracy: 0.02)
        XCTAssertEqual(Double(representation.colorAt(x: 84, y: 41)?.redComponent ?? -1), 1, accuracy: 0.02)
        XCTAssertEqual(Double(representation.colorAt(x: 92, y: 41)?.redComponent ?? -1), 0, accuracy: 0.02)
        XCTAssertEqual(Double(representation.colorAt(x: 99, y: 50)?.redComponent ?? -1), 0, accuracy: 0.02)
        XCTAssertEqual(Double(representation.colorAt(x: 92, y: 50)?.redComponent ?? -1), 1, accuracy: 0.02)
        XCTAssertEqual(Double(representation.colorAt(x: 98, y: 58)?.redComponent ?? -1), 1, accuracy: 0.02)
        XCTAssertEqual(Double(representation.colorAt(x: 1, y: 1)?.redComponent ?? -1), 0, accuracy: 0.02)
        XCTAssertEqual(Double(representation.colorAt(x: 98, y: 1)?.redComponent ?? -1), 0, accuracy: 0.02)
        XCTAssertEqual(Double(representation.colorAt(x: 1, y: 39)?.redComponent ?? -1), 0, accuracy: 0.02)
        XCTAssertEqual(Double(representation.colorAt(x: 98, y: 39)?.redComponent ?? -1), 0, accuracy: 0.02)
        let bottomOutsideCorner = try XCTUnwrap(representation.colorAt(x: 1, y: 99))
        XCTAssertEqual(bottomOutsideCorner.alphaComponent, 1, accuracy: 0.02)
        XCTAssertEqual(bottomOutsideCorner.redComponent, 0, accuracy: 0.02)
        XCTAssertEqual(bottomOutsideCorner.greenComponent, 0, accuracy: 0.02)
        XCTAssertEqual(bottomOutsideCorner.blueComponent, 0, accuracy: 0.02)
    }

    func testDynamicWriterPreservesFrameCountAndAddsBlackBar() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("tnc-render-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let sourceURL = directory.appendingPathComponent("source.heic")
        let outputURL = directory.appendingPathComponent("output.heic")
        let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(
            sourceURL as CFURL,
            UTType.heic.identifier as CFString,
            2,
            nil
        ))
        CGImageDestinationAddImage(destination, try makeImage(red: 0, green: 1, blue: 0), nil)
        CGImageDestinationAddImage(destination, try makeImage(red: 0, green: 0, blue: 1), nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination))

        let descriptor = ScreenDescriptor(
            id: 1,
            frame: CGRect(x: 0, y: 0, width: 40, height: 40),
            backingScaleFactor: 1,
            safeAreaTop: 20,
            systemMenuBarHeight: 24,
            isBuiltIn: true
        )
        let source = try XCTUnwrap(CGImageSourceCreateWithURL(sourceURL as CFURL, nil))
        try WallpaperPainter.writeWallpaper(
            from: source,
            to: outputURL,
            descriptor: descriptor,
            scaling: .axesIndependently,
            allowsClipping: true,
            settings: WallpaperSettings(),
            dynamic: true
        )

        let output = try XCTUnwrap(CGImageSourceCreateWithURL(outputURL as CFURL, nil))
        XCTAssertEqual(CGImageSourceGetCount(output), 2)
        let first = try XCTUnwrap(CGImageSourceCreateImageAtIndex(output, 0, nil))
        let representation = try XCTUnwrap(NSBitmapImageRep(cgImage: first))
        XCTAssertEqual(Double(representation.colorAt(x: 20, y: 1)?.redComponent ?? -1), 0, accuracy: 0.02)
        XCTAssertEqual(Double(representation.colorAt(x: 20, y: 39)?.greenComponent ?? -1), 1, accuracy: 0.02)
    }

    private func makeImage(red: CGFloat, green: CGFloat, blue: CGFloat) throws -> CGImage {
        let context = try XCTUnwrap(CGContext(
            data: nil,
            width: 40,
            height: 40,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setFillColor(red: red, green: green, blue: blue, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: 40, height: 40))
        return try XCTUnwrap(context.makeImage())
    }
}
