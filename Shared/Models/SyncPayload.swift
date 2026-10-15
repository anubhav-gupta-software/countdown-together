import Foundation

struct SharedDatabase: Codable, Equatable {
    var version: Int
    var countdowns: [Countdown]
    var profile: UserProfile

    static let empty = SharedDatabase(version: 1, countdowns: [], profile: .empty)
}

struct SyncPayload: Codable, Equatable {
    var version: Int
    var countdown: Countdown
    /// JPEG bytes, base64. Omitted when the countdown has no photo.
    var photoBase64: String?

    init(countdown: Countdown, photoBase64: String?) {
        self.version = 1
        var copy = countdown
        copy.photoFilename = nil
        self.countdown = copy
        self.photoBase64 = photoBase64
    }
}
