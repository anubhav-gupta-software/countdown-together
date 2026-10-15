import Foundation

struct CountdownBreakdown: Equatable {
    var days: Int
    var hours: Int
    var minutes: Int
    var seconds: Int
    var isPast: Bool
    var totalSeconds: Int

    var isFinalDay: Bool { !isPast && totalSeconds < 86_400 }
    var isFinalHour: Bool { !isPast && totalSeconds < 3_600 }

    var primaryValue: Int {
        if days > 0 { return days }
        if hours > 0 { return hours }
        if minutes > 0 { return minutes }
        return seconds
    }

    var primaryUnit: String {
        if days > 0 { return days == 1 ? "day" : "days" }
        if hours > 0 { return hours == 1 ? "hour" : "hours" }
        if minutes > 0 { return minutes == 1 ? "minute" : "minutes" }
        return seconds == 1 ? "second" : "seconds"
    }
}

enum CountdownPhase: Equatable {
    case upcoming
    case finalDay
    case past
    case elapsed
}

enum CountdownMath {
    static func timestamp(_ date: Date = Date()) -> Date {
        Date(timeIntervalSince1970: date.timeIntervalSince1970.rounded(.down))
    }

    static func breakdown(
        from now: Date,
        to target: Date,
        calendar: Calendar = .current
    ) -> CountdownBreakdown {
        let past = target < now
        let earlier = past ? target : now
        let later = past ? now : target
        let parts = calendar.dateComponents([.day, .hour, .minute, .second], from: earlier, to: later)
        let total = Int(later.timeIntervalSince(earlier).rounded(.down))
        return CountdownBreakdown(
            days: max(0, parts.day ?? 0),
            hours: max(0, parts.hour ?? 0),
            minutes: max(0, parts.minute ?? 0),
            seconds: max(0, parts.second ?? 0),
            isPast: past,
            totalSeconds: max(0, total)
        )
    }

    static func phase(kind: CountdownKind, breakdown: CountdownBreakdown) -> CountdownPhase {
        if !breakdown.isPast {
            return breakdown.isFinalDay ? .finalDay : .upcoming
        }
        return kind.countsUpAfter ? .elapsed : .past
    }

    static func caption(kind: CountdownKind, breakdown: CountdownBreakdown) -> String {
        switch phase(kind: kind, breakdown: breakdown) {
        case .upcoming:
            return "to go"
        case .finalDay:
            return "left today"
        case .past:
            return "ago"
        case .elapsed:
            return "together"
        }
    }

    static func compact(_ breakdown: CountdownBreakdown) -> String {
        if breakdown.isPast {
            if breakdown.days > 0 { return "\(breakdown.days)d ago" }
            if breakdown.hours > 0 { return "\(breakdown.hours)h ago" }
            if breakdown.minutes > 0 { return "\(breakdown.minutes)m ago" }
            return "just now"
        }
        if breakdown.days > 0 { return "\(breakdown.days)d" }
        if breakdown.hours > 0 { return "\(breakdown.hours)h" }
        if breakdown.minutes > 0 { return "\(breakdown.minutes)m" }
        return "\(breakdown.seconds)s"
    }

    static func accessibilitySummary(
        title: String,
        kind: CountdownKind,
        breakdown: CountdownBreakdown
    ) -> String {
        let caption = caption(kind: kind, breakdown: breakdown)
        return "\(title), \(kind.title), \(breakdown.primaryValue) \(breakdown.primaryUnit) \(caption)"
    }
}
