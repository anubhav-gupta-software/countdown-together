import SwiftUI

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        let red = Double((hex >> 16) & 0xFF) / 255
        let green = Double((hex >> 8) & 0xFF) / 255
        let blue = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: opacity)
    }
}

extension CountdownTheme {
    var gradientColors: [Color] {
        [Color(hex: gradientHex.top), Color(hex: gradientHex.bottom)]
    }

    var foreground: Color {
        inkIsLight ? Color(hex: 0xF7F3EC) : Color(hex: 0x241910)
    }

    var secondaryForeground: Color {
        foreground.opacity(inkIsLight ? 0.74 : 0.68)
    }
}

struct ThemeBackground: View {
    var theme: CountdownTheme

    var body: some View {
        LinearGradient(
            colors: theme.gradientColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
