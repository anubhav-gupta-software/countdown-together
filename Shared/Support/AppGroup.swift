import Foundation

/// Identifiers a paid Apple Developer account can turn on later.
/// The default build leaves the matching entitlements unattached so a free
/// personal Apple ID can still install the app. See the README.
enum AppGroup {
    static let identifier = "group.com.countdowntogether.app"
}

enum CloudKitContainer {
    static let identifier = "iCloud.com.countdowntogether.app"
}

enum AppLink {
    static let scheme = "countdowntogether"

    static func joinURL(code: String) -> URL {
        URL(string: "\(scheme)://join/\(code)")!
    }
}
