import Foundation

struct GradientHex: Equatable {
    var top: UInt32
    var bottom: UInt32
}

enum CountdownTheme: String, Codable, CaseIterable, Identifiable {
    case midnight
    case sunrise
    case ocean
    case rose
    case forest
    case amber
    case lilac
    case paper

    var id: String { rawValue }

    var title: String {
        switch self {
        case .midnight: "Midnight"
        case .sunrise: "Sunrise"
        case .ocean: "Ocean"
        case .rose: "Rose"
        case .forest: "Forest"
        case .amber: "Amber"
        case .lilac: "Lilac"
        case .paper: "Paper"
        }
    }

    var gradientHex: GradientHex {
        switch self {
        case .midnight: GradientHex(top: 0x17152E, bottom: 0x3A3568)
        case .sunrise: GradientHex(top: 0xF8D7B5, bottom: 0xE98B6A)
        case .ocean: GradientHex(top: 0x083544, bottom: 0x1C7380)
        case .rose: GradientHex(top: 0x4A1C32, bottom: 0xC45B78)
        case .forest: GradientHex(top: 0x12241C, bottom: 0x2F6B4F)
        case .amber: GradientHex(top: 0xF6D7A8, bottom: 0xE09A45)
        case .lilac: GradientHex(top: 0x241833, bottom: 0x6E5B8A)
        case .paper: GradientHex(top: 0xF7F1E6, bottom: 0xE4D3BC)
        }
    }

    /// Light type reads on the darker themes. Sunrise, amber, and paper use ink.
    var inkIsLight: Bool {
        switch self {
        case .sunrise, .amber, .paper: false
        default: true
        }
    }
}
