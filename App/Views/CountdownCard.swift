import SwiftUI
import UIKit

struct CountdownReadout: View {
    var countdown: Countdown
    var now: Date
    var lightText: Bool
    var prominent: Bool = true

    private var breakdown: CountdownBreakdown {
        CountdownMath.breakdown(from: now, to: countdown.targetDate)
    }

    private var foreground: Color { lightText ? Color.ivory : Color(hex: 0x241910) }
    private var secondary: Color { foreground.opacity(0.72) }

    var body: some View {
        VStack(alignment: .leading, spacing: prominent ? 14 : 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(breakdown.primaryValue)")
                    .font(.system(size: prominent ? 72 : 36, weight: .light, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .contentTransition(.numericText())
                Text(breakdown.primaryUnit)
                    .font(.system(prominent ? .title3 : .subheadline, design: .serif))
            }
            .foregroundStyle(foreground)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(
                CountdownMath.accessibilitySummary(
                    title: countdown.title,
                    kind: countdown.kind,
                    breakdown: breakdown
                )
            )

            if prominent && (breakdown.isFinalDay || breakdown.days > 0) {
                HStack(spacing: 16) {
                    unit("Days", breakdown.days)
                    unit("Hours", breakdown.hours)
                    unit("Min", breakdown.minutes)
                    if breakdown.isFinalDay {
                        unit("Sec", breakdown.seconds)
                    }
                }
            }

            Text(CountdownMath.caption(kind: countdown.kind, breakdown: breakdown))
                .font(.system(.footnote, design: .rounded))
                .foregroundStyle(secondary)
        }
    }

    private func unit(_ label: String, _ value: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(value)")
                .font(.system(.headline, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(foreground)
            Text(label)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct CountdownCard: View {
    var countdown: Countdown
    var together: String?
    var image: UIImage?
    var style: Style

    enum Style {
        case hero
        case row
    }

    private var lightText: Bool {
        image != nil || countdown.theme.inkIsLight
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { timeline in
            content(now: timeline.date)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private func content(now: Date) -> some View {
        ZStack(alignment: style == .hero ? .bottomLeading : .leading) {
            background
            if style == .hero {
                heroText(now: now)
                    .padding(22)
            } else {
                rowText(now: now)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 16)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: style == .hero ? 430 : 132)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    @ViewBuilder
    private var background: some View {
        if let image {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
            LinearGradient(
                colors: [.black.opacity(0.05), .black.opacity(0.72)],
                startPoint: .top,
                endPoint: .bottom
            )
        } else {
            ThemeBackground(theme: countdown.theme)
        }
    }

    private func heroText(now: Date) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            kindRow
            Spacer()
            if let together {
                Text(together)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(secondary)
                    .padding(.bottom, 4)
            }
            Text(countdown.title)
                .font(.system(size: 40, weight: .medium, design: .serif))
                .foregroundStyle(foreground)
                .lineLimit(2)
            CountdownReadout(countdown: countdown, now: now, lightText: lightText)
                .padding(.top, 8)
        }
    }

    private func rowText(now: Date) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                kindRow
                Text(countdown.title)
                    .font(.system(.title3, design: .serif))
                    .foregroundStyle(foreground)
                    .lineLimit(1)
                if let together {
                    Text(together)
                        .font(.system(.footnote, design: .rounded))
                        .foregroundStyle(secondary)
                }
            }
            Spacer(minLength: 8)
            CountdownReadout(countdown: countdown, now: now, lightText: lightText, prominent: false)
        }
    }

    private var kindRow: some View {
        HStack(spacing: 6) {
            Image(systemName: countdown.kind.symbol)
            Text(countdown.kind.title.uppercased())
                .tracking(1.2)
        }
        .font(.system(size: 11, weight: .semibold, design: .rounded))
        .foregroundStyle(secondary)
    }

    private var foreground: Color {
        lightText ? Color.ivory : Color(hex: 0x241910)
    }

    private var secondary: Color {
        foreground.opacity(0.74)
    }

    private var accessibilityText: String {
        let breakdown = CountdownMath.breakdown(from: Date(), to: countdown.targetDate)
        return CountdownMath.accessibilitySummary(
            title: countdown.title,
            kind: countdown.kind,
            breakdown: breakdown
        )
    }
}
