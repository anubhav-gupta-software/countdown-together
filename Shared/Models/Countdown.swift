import Foundation

enum LiveActivityMode: String, Codable, CaseIterable, Identifiable {
    case automatic
    case pinned
    case off

    var id: String { rawValue }

    var title: String {
        switch self {
        case .automatic: "Final day"
        case .pinned: "Keep on Lock Screen"
        case .off: "Off"
        }
    }

    var detail: String {
        switch self {
        case .automatic: "Shows a Live Activity during the last 24 hours"
        case .pinned: "Stays on the Lock Screen until you turn it off"
        case .off: "Don't start a Live Activity"
        }
    }
}

struct Countdown: Codable, Identifiable, Equatable, Hashable {
    var id: UUID
    var title: String
    var targetDate: Date
    var kind: CountdownKind
    var theme: CountdownTheme
    var note: String
    var inviteCode: String
    var ownerName: String
    var partnerName: String?
    var createdAt: Date
    var updatedAt: Date
    var photoFilename: String?
    var liveActivityMode: LiveActivityMode

    func togetherLine(myName: String) -> String? {
        let mine = myName.trimmingCharacters(in: .whitespacesAndNewlines)
        let partner = partnerName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if mine.isEmpty || mine.caseInsensitiveCompare(ownerName) == .orderedSame {
            return partner.isEmpty ? nil : "with \(partner)"
        }
        let owner = ownerName.trimmingCharacters(in: .whitespacesAndNewlines)
        return owner.isEmpty ? nil : "with \(owner)"
    }

    func fractionElapsed(at now: Date) -> Double {
        let total = targetDate.timeIntervalSince(createdAt)
        guard total > 1 else { return targetDate <= now ? 1 : 0 }
        let elapsed = now.timeIntervalSince(createdAt)
        return min(1, max(0, elapsed / total))
    }
}
