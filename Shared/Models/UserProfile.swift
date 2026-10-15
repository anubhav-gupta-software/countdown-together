import Foundation

enum SyncMode: String, Codable, CaseIterable, Identifiable {
    case local
    case http
    case cloudKit

    var id: String { rawValue }

    var title: String {
        switch self {
        case .local: "This iPhone"
        case .http: "Sync server"
        case .cloudKit: "iCloud"
        }
    }

    var detail: String {
        switch self {
        case .local:
            "Countdowns stay on this phone. Send a countdown file when you want someone else to have a copy."
        case .http:
            "Invite codes work between phones through a small server you run yourself. No account required."
        case .cloudKit:
            "Syncs through iCloud. Needs a paid Apple Developer account and the iCloud capability."
        }
    }
}

struct UserProfile: Codable, Equatable {
    var displayName: String
    var syncMode: SyncMode
    var httpBaseURL: String
    var widgetPinnedID: UUID?
    var notificationsEnabled: Bool
    var didCompleteOnboarding: Bool

    static let empty = UserProfile(
        displayName: "",
        syncMode: .local,
        httpBaseURL: "",
        widgetPinnedID: nil,
        notificationsEnabled: true,
        didCompleteOnboarding: false
    )
}
