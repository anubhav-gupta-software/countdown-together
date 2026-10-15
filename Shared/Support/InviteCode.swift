import Foundation

enum InviteCode {
    /// No 0/O or 1/I, so a code can be read out loud.
    static let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
    static let length = 8

    static func make() -> String {
        var generator = SystemRandomNumberGenerator()
        return make(using: &generator)
    }

    static func make<T: RandomNumberGenerator>(using generator: inout T) -> String {
        String((0..<length).map { _ in alphabet.randomElement(using: &generator)! })
    }

    static func normalize(_ raw: String) -> String {
        String(raw.uppercased().filter { alphabet.contains($0) })
    }

    static func display(_ code: String) -> String {
        guard code.count > 4 else { return code }
        let index = code.index(code.startIndex, offsetBy: 4)
        return "\(code[..<index]) \(code[index...])"
    }
}
