import Foundation

public final class WallpaperStore {
    private let defaults: UserDefaults
    private let storageKey = "TopNotchCompat.wallpaperRecords"
    public let generatedDirectory: URL

    public init(
        defaults: UserDefaults = .standard,
        generatedDirectory: URL? = nil
    ) {
        self.defaults = defaults
        if let generatedDirectory {
            self.generatedDirectory = generatedDirectory
        } else {
            let support = FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first?.appendingPathComponent("TopNotchCompat", isDirectory: true)
            self.generatedDirectory = support ?? FileManager.default.temporaryDirectory
                .appendingPathComponent("TopNotchCompat", isDirectory: true)
        }
    }

    public private(set) var allRecords: [WallpaperRecord] = [] {
        didSet { persist() }
    }

    public func load() {
        guard
            let data = defaults.data(forKey: storageKey),
            let records = try? JSONDecoder().decode([WallpaperRecord].self, from: data)
        else { return }
        allRecords = records
    }

    public func save(_ record: WallpaperRecord) throws {
        try FileManager.default.createDirectory(at: generatedDirectory, withIntermediateDirectories: true)
        var records = allRecords.filter { $0.generatedURL != record.generatedURL }
        records.append(record)
        allRecords = records
    }

    public func record(forGenerated url: URL) -> WallpaperRecord? {
        allRecords.first { $0.generatedURL.standardizedFileURL == url.standardizedFileURL }
    }

    public func isGeneratedURL(_ url: URL) -> Bool {
        url.standardizedFileURL.path.hasPrefix(generatedDirectory.standardizedFileURL.path)
    }

    public func removeRecordsForMissingFiles() {
        allRecords = allRecords.filter { FileManager.default.fileExists(atPath: $0.generatedURL.path) }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(allRecords) else { return }
        defaults.set(data, forKey: storageKey)
    }
}
