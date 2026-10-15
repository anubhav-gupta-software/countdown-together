import SwiftUI
import WidgetKit

struct CountdownLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CountdownActivityAttributes.self) { context in
            LiveActivityBanner(state: context.state)
                .activityBackgroundTint(context.state.theme.gradientColors.first ?? Color(hex: 0x17152E))
                .activitySystemActionForegroundColor(context.state.theme.foreground)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(context.state.kind.title.uppercased())
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .tracking(1.1)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    remaining(until: context.state.targetDate)
                        .font(.system(.headline, design: .rounded))
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.title)
                        .font(.system(.headline, design: .serif))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } compactLeading: {
                Image(systemName: context.state.kind.symbol)
            } compactTrailing: {
                remaining(until: context.state.targetDate)
                    .font(.system(.caption, design: .rounded))
                    .frame(maxWidth: 68)
            } minimal: {
                Image(systemName: "hourglass")
            }
        }
    }

    @ViewBuilder
    private func remaining(until date: Date) -> some View {
        if date > Date() {
            Text(timerInterval: Date()...date, countsDown: true)
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
        } else {
            Text("Now")
                .monospacedDigit()
        }
    }
}

private struct LiveActivityBanner: View {
    var state: CountdownActivityAttributes.ContentState

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("FINAL DAY")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .tracking(1.2)
                Text(state.title)
                    .font(.system(.title3, design: .serif))
                    .lineLimit(1)
                if !state.note.isEmpty {
                    Text(state.note)
                        .font(.system(.caption, design: .rounded))
                        .lineLimit(1)
                        .opacity(0.8)
                }
            }
            Spacer(minLength: 8)
            if state.targetDate > Date() {
                Text(timerInterval: Date()...state.targetDate, countsDown: true)
                    .font(.system(.title2, design: .rounded))
                    .monospacedDigit()
                    .multilineTextAlignment(.trailing)
                    .frame(minWidth: 92)
            } else {
                Text("Now")
                    .font(.system(.title2, design: .serif))
            }
        }
        .foregroundStyle(state.theme.foreground)
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }
}
