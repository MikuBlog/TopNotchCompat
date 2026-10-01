import XCTest
@testable import TopNotchCompatCore

final class GeometryTests: XCTestCase {
    func testMenuBarHeightPrefersLargestValidValue() {
        XCTAssertEqual(WallpaperGeometry.menuBarHeight(safeAreaTop: 38, systemMenuBarHeight: 39), 39)
        XCTAssertEqual(WallpaperGeometry.menuBarHeight(safeAreaTop: 0, systemMenuBarHeight: 24), 24)
        XCTAssertEqual(WallpaperGeometry.menuBarHeight(safeAreaTop: 0, systemMenuBarHeight: 0), 24)
    }

    func testPaintedBarOverlapsSystemMenuBarByTwoPhysicalPixels() {
        XCTAssertEqual(WallpaperGeometry.paintedBarHeight(menuBarHeight: 38, backingScaleFactor: 2), 78)
        XCTAssertEqual(WallpaperGeometry.paintedBarHeight(menuBarHeight: 39, backingScaleFactor: 2), 80)
    }

    func testPlacementMatchesDesktopScalingModes() {
        let canvas = CGSize(width: 100, height: 50)
        let image = CGSize(width: 200, height: 50)

        XCTAssertEqual(
            WallpaperGeometry.placement(imageSize: image, canvasSize: canvas, scaling: .proportionallyUpOrDown, allowsClipping: true),
            CGRect(x: -50, y: 0, width: 200, height: 50)
        )
        XCTAssertEqual(
            WallpaperGeometry.placement(imageSize: image, canvasSize: canvas, scaling: .proportionallyUpOrDown, allowsClipping: false),
            CGRect(x: 0, y: 12.5, width: 100, height: 25)
        )
        XCTAssertEqual(
            WallpaperGeometry.placement(imageSize: image, canvasSize: canvas, scaling: .axesIndependently, allowsClipping: true),
            CGRect(x: 0, y: 0, width: 100, height: 50)
        )
        XCTAssertEqual(
            WallpaperGeometry.placement(imageSize: image, canvasSize: canvas, scaling: .none, allowsClipping: false),
            CGRect(x: -50, y: 0, width: 200, height: 50)
        )
    }

    func testRadiusMapping() {
        XCTAssertEqual(CornerRadius.small.points, 12)
        XCTAssertEqual(CornerRadius.medium.points, 24)
        XCTAssertEqual(CornerRadius.high.points, 36)
    }

    func testAppCornerFillPathsUseSmoothWindowArc() {
        let paths = WallpaperPainter.appCornerFillPaths(
            in: CGRect(x: 0, y: 0, width: 100, height: 100),
            menuBarHeight: 40,
            radius: 16
        )

        XCTAssertEqual(paths.count, 2)
        XCTAssertEqual(paths[0].boundingBox, CGRect(x: 0, y: 44, width: 16, height: 16))
        XCTAssertEqual(paths[1].boundingBox, CGRect(x: 84, y: 44, width: 16, height: 16))
        XCTAssertTrue(paths[0].contains(CGPoint(x: 0, y: 60)))
        XCTAssertTrue(paths[0].contains(CGPoint(x: 0, y: 50)))
        XCTAssertFalse(paths[0].contains(CGPoint(x: 10, y: 55)))
        XCTAssertTrue(paths[1].contains(CGPoint(x: 100, y: 60)))
        XCTAssertTrue(paths[1].contains(CGPoint(x: 100, y: 50)))
        XCTAssertFalse(paths[1].contains(CGPoint(x: 90, y: 55)))
    }
}
