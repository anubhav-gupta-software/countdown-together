import ActivityKit
import Foundation

@MainActor
enum LiveActivityController {
    static func reconcile(_ countdowns: [Countdown]) async -> String? {
        let activities = Activity<CountdownActivityAttributes>.activities
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            for activity in activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            return nil
        }

        let now = Date()
        let wanted = Set(countdowns.filter { shouldRun($0, now: now) }.map(\.id))
        for activity in activities where !wanted.contains(activity.attributes.countdownID) {
            await activity.end(nil, dismissalPolicy: .immediate)
        }

        var warning: String?
        for countdown in countdowns where wanted.contains(countdown.id) {
            if let message = await upsert(countdown) {
                warning = message
            }
        }
        return warning
    }

    static func upsert(_ countdown: Countdown) async -> String? {
        let state = CountdownActivityAttributes.ContentState(countdown: countdown)
        let stale = max(countdown.targetDate.addingTimeInterval(60 * 60), Date().addingTimeInterval(60 * 60))
        let content = ActivityContent(state: state, staleDate: stale)
        if let existing = Activity<CountdownActivityAttributes>.activities.first(where: {
            $0.attributes.countdownID == countdown.id
        }) {
            await existing.update(content)
            return nil
        }
        do {
            _ = try Activity.request(
                attributes: CountdownActivityAttributes(countdownID: countdown.id),
                content: content
            )
            return nil
        } catch {
            return "Couldn't start the Lock Screen countdown. \(error.localizedDescription)"
        }
    }

    static func end(_ id: UUID) async {
        for activity in Activity<CountdownActivityAttributes>.activities where activity.attributes.countdownID == id {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    static func isRunning(_ id: UUID) -> Bool {
        Activity<CountdownActivityAttributes>.activities.contains { $0.attributes.countdownID == id }
    }

    private static func shouldRun(_ countdown: Countdown, now: Date) -> Bool {
        let remaining = countdown.targetDate.timeIntervalSince(now)
        switch countdown.liveActivityMode {
        case .off:
            return false
        case .pinned:
            return remaining > -3_600
        case .automatic:
            return remaining > -3_600 && remaining < 86_400
        }
    }
}
