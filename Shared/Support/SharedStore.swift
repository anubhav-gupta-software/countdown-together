import Foundation

struct SharedStore {
    var directoryOverride: URL?

    /// True only when the App Group entitlement is actually signed into this build.
    var usesAppGroup: Bool {
        directoryOverride == nil && Self.appGroupDirectory() != nil
    }

    func directory() -> URL {
        if let directoryOverride {
            return directoryOverride
        }
        if let group = Self.appGroupDirectory() {
            return group
        }
        return Self.fallbackDirectory()
    }

    func load() -> SharedDatabase {
        let url = fileURL()
        guard let data = try? Data(contentsOf: url) else { return .empty }
        return (try? SyncCoding.decoder.decode(SharedDatabase.self, from: data)) ?? .empty
    }

    func save(_ database: SharedDatabase) throws {
        let folder = directory()
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let data = try SyncCoding.encoder.encode(database)
        try data.write(to: fileURL(), options: .atomic)
    }

    func fileURL() -> URL {
        directory().appendingPathComponent("database.json")
    }

    func photosDirectory() -> URL {
        directory().appendingPathComponent("photos", isDirectory: true)
    }

    func photoURL(named filename: String) -> URL {
        photosDirectory().appendingPathComponent(filename)
    }

    func countdownForWidget(at now: Date = Date()) -> Countdown? {
        let database = load()
        if let pinned = database.profile.widgetPinnedID,
           let match = database.countdowns.first(where: { $0.id == pinned }) {
            return match
        }
        let upcoming = database.countdowns
            .filter { $0.targetDate >= now }
            .sorted { $0.targetDate < $1.targetDate }
        if let next = upcoming.first {
            return next
        }
        return database.countdowns.sorted { $0.targetDate > $1.targetDate }.first
    }

    private static func appGroupDirectory() -> URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppGroup.identifier)
    }

    private static func fallbackDirectory() -> URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("CountdownTogether", isDirectory: true)
    }
}
