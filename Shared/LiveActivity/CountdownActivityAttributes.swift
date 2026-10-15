import ActivityKit
import Foundation

struct CountdownActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var title: String
        var targetDate: Date
        var themeRaw: String
        var kindRaw: String
        var note: String
    }

    var countdownID: UUID
}

extension CountdownActivityAttributes.ContentState {
    init(countdown: Countdown) {
        self.init(
            title: countdown.title,
            targetDate: countdown.targetDate,
            themeRaw: countdown.theme.rawValue,
            kindRaw: countdown.kind.rawValue,
            note: countdown.note
        )
    }

    var theme: CountdownTheme {
        CountdownTheme(rawValue: themeRaw) ?? .midnight
    }

    var kind: CountdownKind {
        CountdownKind(rawValue: kindRaw) ?? .custom
    }
}
