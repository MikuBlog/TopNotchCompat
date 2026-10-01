import XCTest
@testable import TopNotchCompatCore

final class MenuSpecTests: XCTestCase {
    func testGearMenuMatchesTopNotchStructure() {
        XCTAssertEqual(
            MenuSpec.topNotch,
            [
                MenuEntry.item("Hide Menubar Icon"),
                MenuEntry.separator,
                MenuEntry.disabledItem("Check for Updates..."),
                MenuEntry.item("Visit Website"),
                MenuEntry.separator,
                MenuEntry.item("Quit", keyEquivalent: "q"),
            ]
        )
    }
}
