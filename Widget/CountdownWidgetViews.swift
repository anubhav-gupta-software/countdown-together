import SwiftUI
import UIKit
import WidgetKit

struct CountdownWidgetView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var renderingMode
    var entry: CountdownEntry

    private var accented: Bool { renderingMode == .accented }

    var body: some View {
        Group {
            if let countdown = entry.countdown {
                countdownBody(countdown)
            } else {
                emptyBody
            }
        }
        .containerBackground(for: .widget) {
            background
        }
    }

    @ViewBuilder
    private func countdownBody(_ countdown: Countdown) -> some View {
        let breakdown = CountdownMath.breakdown(from: entry.date, to: countdown.targetDate)
        let light = !accented && (entry.photo != nil || countdown.theme.inkIsLight)
        switch family {
        case .accessoryInline:
            Text("\(countdown.title) · \(CountdownMath.compact(breakdown))")
                .lineLimit(1)
        case .accessoryCircular:
            circular(breakdown)
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Text(countdown.title)
                    .font(.system(.headline, design: .serif))
                    .lineLimit(1)
                Text("\(breakdown.primaryValue) \(breakdown.primaryUnit)")
                    .font(.system(.caption, design: .rounded))
                    .monospacedDigit()
                Text(CountdownMath.caption(kind: countdown.kind, breakdown: breakdown))
                    .font(.system(.caption2, design: .rounded))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
        case .systemMedium, .systemLarge:
            wide(countdown, breakdown: breakdown, light: light, showsNote: family == .systemLarge)
        default:
            compact(countdown, breakdown: breakdown, light: light)
        }
    }

    private func compact(_ countdown: Countdown, breakdown: CountdownBreakdown, light: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            kind(countdown, light: light)
            Spacer(minLength: 0)
            Text(countdown.title)
                .font(.system(.headline, design: .serif))
                .foregroundStyle(foreground(light))
                .lineLimit(2)
            Text("\(breakdown.primaryValue)")
                .font(.system(size: 42, weight: .light, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(foreground(light))
                .widgetAccentable()
            Text("\(breakdown.primaryUnit) \(CountdownMath.caption(kind: countdown.kind, breakdown: breakdown))")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(secondary(light))
                .lineLimit(1)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func wide(
        _ countdown: Countdown,
        breakdown: CountdownBreakdown,
        light: Bool,
        showsNote: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            kind(countdown, light: light)
            Text(countdown.title)
                .font(.system(size: showsNote ? 34 : 28, weight: .medium, design: .serif))
                .foregroundStyle(foreground(light))
                .lineLimit(2)
            Spacer(minLength: 0)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(breakdown.primaryValue)")
                    .font(.system(size: 48, weight: .light, design: .rounded))
                    .monospacedDigit()
                    .widgetAccentable()
                Text(breakdown.primaryUnit)
                    .font(.system(.title3, design: .serif))
            }
            .foregroundStyle(foreground(light))
            Text(CountdownMath.caption(kind: countdown.kind, breakdown: breakdown))
                .font(.system(.footnote, design: .rounded))
                .foregroundStyle(secondary(light))
            if showsNote && !countdown.note.isEmpty {
                Text(countdown.note)
                    .font(.system(.subheadline, design: .serif))
                    .italic()
                    .foregroundStyle(secondary(light))
                    .lineLimit(2)
            }
            Text(countdown.targetDate.formatted(date: .complete, time: .shortened))
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(secondary(light))
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func circular(_ breakdown: CountdownBreakdown) -> some View {
        VStack(spacing: 0) {
            Text("\(breakdown.primaryValue)")
                .font(.system(.title2, design: .rounded).weight(.semibold))
                .monospacedDigit()
                .widgetAccentable()
                .minimumScaleFactor(0.6)
            Text(shortUnit(breakdown))
                .font(.system(size: 10, weight: .medium, design: .rounded))
        }
    }

    private func kind(_ countdown: Countdown, light: Bool) -> some View {
        HStack(spacing: 5) {
            Image(systemName: countdown.kind.symbol)
            Text(countdown.kind.title.uppercased())
                .tracking(1.1)
        }
        .font(.system(size: 11, weight: .semibold, design: .rounded))
        .foregroundStyle(secondary(light))
    }

    private var emptyBody: some View {
        VStack(alignment: .leading, spacing: 6) {
            if family == .accessoryInline {
                Text("Countdown")
            } else if family == .accessoryCircular {
                Image(systemName: "hourglass")
            } else {
                Image(systemName: "hourglass")
                    .font(.title3)
                Text(entry.usesAppGroup ? "Add a countdown in the app." : "Turn on the App Group to show countdowns here.")
                    .font(.system(.caption, design: .rounded))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(family == .accessoryInline || family == .accessoryCircular ? 0 : 14)
    }

    @ViewBuilder
    private var background: some View {
        switch family {
        case .accessoryCircular, .accessoryRectangular:
            AccessoryWidgetBackground()
        case .accessoryInline:
            Color.clear
        default:
            if accented {
                Color.clear
            } else if let photo = entry.photo {
                ZStack {
                    Image(uiImage: photo)
                        .resizable()
                        .scaledToFill()
                    LinearGradient(
                        colors: [.black.opacity(0.12), .black.opacity(0.72)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
            } else if let theme = entry.countdown?.theme {
                ThemeBackground(theme: theme)
            } else {
                Color(hex: 0x17152E)
            }
        }
    }

    private func foreground(_ light: Bool) -> Color {
        accented ? .primary : (light ? Color(hex: 0xF7F3EC) : Color(hex: 0x241910))
    }

    private func secondary(_ light: Bool) -> Color {
        foreground(light).opacity(0.74)
    }

    private func shortUnit(_ breakdown: CountdownBreakdown) -> String {
        if breakdown.days > 0 { return breakdown.days == 1 ? "day" : "days" }
        if breakdown.hours > 0 { return "hrs" }
        if breakdown.minutes > 0 { return "min" }
        return "sec"
    }
}

#Preview(as: .systemSmall) {
    CountdownHomeWidget()
} timeline: {
    CountdownEntry.placeholder
}

#Preview(as: .accessoryRectangular) {
    CountdownHomeWidget()
} timeline: {
    CountdownEntry.placeholder
}
