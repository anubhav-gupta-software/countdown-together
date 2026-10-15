import Foundation

enum CountdownKind: String, Codable, CaseIterable, Identifiable {
    case trip
    case date
    case event
    case anniversary
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .trip: "Trip"
        case .date: "Date"
        case .event: "Event"
        case .anniversary: "Anniversary"
        case .custom: "Custom"
        }
    }

    var detail: String {
        switch self {
        case .trip: "A place you're going together"
        case .date: "A night you both have planned"
        case .event: "Something on the calendar"
        case .anniversary: "Counts up once the day has passed"
        case .custom: "Anything else you're waiting on"
        }
    }

    var symbol: String {
        switch self {
        case .trip: "airplane"
        case .date: "fork.knife"
        case .event: "ticket"
        case .anniversary: "gift"
        case .custom: "sparkle"
        }
    }

    /// Anniversaries keep counting after the date instead of becoming a memory.
    var countsUpAfter: Bool { self == .anniversary }
}
