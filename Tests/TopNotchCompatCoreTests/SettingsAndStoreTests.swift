import XCTest
@testable import TopNotchCompatCore

final class SettingsAndStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "TopNotchCompatTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testSettingsRoundTrip() {
        let store = SettingsStore(defaults: defaults)
        var settings = WallpaperSettings()
        settings.isEnabled = false
        settings.startAtLogin = true
        settings.builtInScreenOnly = true
        settings.roundCorners = true
        settings.cornerRadius = .high
        settings.useDynamicWallpapers = false
        settings.hideMenuBarIcon = true
        store.settings = settings

        XCTAssertEqual(store.settings, settings)
    }

    func testWallpaperStoreMapsGeneratedFileToOriginalAndPreventsDuplicates() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("generated-\(UUID().uuidString)", isDirectory: true)
        let store = WallpaperStore(defaults: defaults, generatedDirectory: directory)
        let generated = directory.appendingPathComponent("generated.heic")
        let original = directory.appendingPathComponent("original.png")
        let record = WallpaperRecord(
            generatedURL: generated,
            originalURL: original,
            scaling: .proportionallyUpOrDown,
            allowsClipping: true,
            fillColorHex: "#656AAA"
        )

        try store.save(record)
        XCTAssertEqual(store.record(forGenerated: generated), record)
        XCTAssertTrue(store.isGeneratedURL(generated))

        try store.save(record)
        XCTAssertEqual(store.allRecords.count, 1)
    }

    func testGeneratedFilenameIncludesIdentityAndBehavior() {
        let name = WallpaperPainter.generatedFilename(
            originalPath: "/tmp/a b.png",
            digest: "abc123",
            canvasSize: CGSize(width: 100, height: 50),
            cornerRadius: .medium,
            rounded: true,
            barHeight: 24,
            dynamic: true
        )
        XCTAssertTrue(name.hasPrefix("a-b-abc123-100x50-medium-round-on-bar-24-v7-dynamic"))
        XCTAssertTrue(name.hasSuffix(".heic"))
    }
}
