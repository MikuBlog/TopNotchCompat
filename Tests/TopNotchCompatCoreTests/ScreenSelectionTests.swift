import XCTest
@testable import TopNotchCompatCore

final class ScreenSelectionTests: XCTestCase {
    func testBuiltInOnlyFiltersToBuiltInNotchedScreens() {
        let builtIn = ScreenDescriptor(
            id: 1,
            frame: CGRect(x: 0, y: 0, width: 1800, height: 1169),
            backingScaleFactor: 2,
            safeAreaTop: 38,
            systemMenuBarHeight: 39,
            isBuiltIn: true
        )
        let external = ScreenDescriptor(
            id: 2,
            frame: CGRect(x: 1800, y: 0, width: 1920, height: 1080),
            backingScaleFactor: 1,
            safeAreaTop: 0,
            systemMenuBarHeight: 24,
            isBuiltIn: false
        )

        XCTAssertEqual(WallpaperPainter.eligibleScreens([builtIn, external], builtInOnly: true), [builtIn])
        XCTAssertEqual(WallpaperPainter.eligibleScreens([builtIn, external], builtInOnly: false), [builtIn])
    }

    func testImageSourceClassification() {
        XCTAssertEqual(WallpaperPainter.outputKind(frameCount: 1, useDynamic: true), .staticImage)
        XCTAssertEqual(WallpaperPainter.outputKind(frameCount: 3, useDynamic: true), .dynamic)
        XCTAssertEqual(WallpaperPainter.outputKind(frameCount: 3, useDynamic: false), .staticImage)
    }
}
