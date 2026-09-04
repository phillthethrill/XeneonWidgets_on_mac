import SwiftUI
import XeneonWidgetsCore

struct Theme: Equatable {
    let id: String
    let name: String
    let bg, surface, surface2, hairline, text, text2, text3: Color
    let rampLow, rampMid, rampHigh, accent, up, ok, warn, crit: Color
    let sheet: Color

    func color(_ level: StateLevel) -> Color {
        switch level {
        case .ok: return ok
        case .warn: return warn
        case .crit: return crit
        }
    }

    func stateColor(_ pct: Double, _ threshold: Threshold) -> Color {
        color(threshold.level(pct))
    }

    var ramp: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: rampLow, location: 0),
                .init(color: rampMid, location: 0.5),
                .init(color: rampHigh, location: 1),
            ],
            startPoint: .bottom,
            endPoint: .top
        )
    }

    static let oled = Theme(
        id: "oled",
        name: "OLED Black",
        bg: Color(hex: 0x000000),
        surface: Color(hex: 0xFFFFFF, opacity: 0.04),
        surface2: Color(hex: 0xFFFFFF, opacity: 0.09),
        hairline: Color(hex: 0xFFFFFF, opacity: 0.12),
        text: Color(hex: 0xFFFFFF, opacity: 0.92),
        text2: Color(hex: 0xFFFFFF, opacity: 0.60),
        text3: Color(hex: 0xFFFFFF, opacity: 0.40),
        rampLow: Color(hex: 0x4FD8CF),
        rampMid: Color(hex: 0xF2C24E),
        rampHigh: Color(hex: 0xF0533F),
        accent: Color(hex: 0x7FBDF5),
        up: Color(hex: 0xC89AF0),
        ok: Color(hex: 0x4ED17A),
        warn: Color(hex: 0xF2C24E),
        crit: Color(hex: 0xF0533F),
        sheet: Color(hex: 0x0E1016)
    )
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        let red = Double((hex >> 16) & 0xFF) / 255.0
        let green = Double((hex >> 8) & 0xFF) / 255.0
        let blue = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: opacity)
    }
}

private struct ThemeKey: EnvironmentKey {
    static let defaultValue = Theme.oled
}

extension EnvironmentValues {
    var theme: Theme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}
