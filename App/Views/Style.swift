import SwiftUI

extension Color {
    static let ink = Color(hex: 0x100E0C)
    static let ivory = Color(hex: 0xF6F1E8)
    static let clay = Color(hex: 0xE07A5F)
    static let mist = Color(hex: 0xA39E94)
}

enum Greeting {
    static func line(at date: Date = Date()) -> String {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<22: return "Good evening"
        default: return "Good night"
        }
    }
}

struct SectionLabel: View {
    var text: String

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .tracking(1.3)
            .foregroundStyle(Color.mist)
    }
}

struct TogetherMark: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.clay.opacity(0.95))
                .frame(width: 64, height: 64)
                .offset(x: -16)
            Circle()
                .fill(Color.ivory.opacity(0.92))
                .frame(width: 64, height: 64)
                .offset(x: 16)
            Circle()
                .trim(from: 0.08, to: 0.62)
                .stroke(Color.ivory.opacity(0.85), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .frame(width: 108, height: 108)
                .rotationEffect(.degrees(-20))
        }
        .frame(width: 120, height: 96)
        .accessibilityHidden(true)
    }
}

struct PrimaryButton: View {
    var title: String
    var systemImage: String?
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
            }
            .font(.system(.headline, design: .rounded))
            .foregroundStyle(Color.ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.ivory, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct QuietButton: View {
    var title: String
    var systemImage: String?
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
            }
            .font(.system(.subheadline, design: .rounded).weight(.semibold))
            .foregroundStyle(Color.ivory)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.white.opacity(0.06), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct InkPanel: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

extension View {
    func inkPanel() -> some View {
        modifier(InkPanel())
    }
}
