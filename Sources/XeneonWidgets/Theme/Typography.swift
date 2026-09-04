import SwiftUI

enum Typography {
    static func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    static func pro(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    static let display = mono(300, .thin)
    static let clock = mono(44, .semibold)
    static let clockSeconds = mono(44, .regular)
    static let big = mono(72, .semibold)
    static let bigUnit = mono(26, .semibold)
    static let numLg = mono(56, .semibold)
    static let numMd = mono(36, .semibold)
    static let numSm = mono(34, .semibold)
    static let boxValue = mono(22, .medium)
    static let boxTitle = mono(16, .regular)
    static let body = pro(17, .medium)
    static let bodyMono = mono(17, .regular)
    static let small = pro(15, .regular)
    static let smallMono = mono(15, .regular)
    static let micro = mono(13, .regular)
    static let microSans = pro(13, .regular)
    static let colHead = pro(12, .regular)
    static let chip = pro(15, .semibold)
    static let button = pro(18, .semibold)
}

extension View {
    func monoDigits() -> some View {
        monospacedDigit()
    }
}
