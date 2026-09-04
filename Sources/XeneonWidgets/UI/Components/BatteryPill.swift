import SwiftUI
import XeneonWidgetsCore

struct BatteryPill: View {
    let percent: Double
    let isCharging: Bool
    let detail: String

    @Environment(\.theme) private var theme

    init(percent: Double, isCharging: Bool, detail: String) {
        self.percent = percent
        self.isCharging = isCharging
        self.detail = detail
    }

    var body: some View {
        HStack(spacing: 12) {
            glyph
            Text(Formatters.percent(percent))
                .font(Typography.mono(18, .semibold))
                .monoDigits()
                .foregroundStyle(theme.text)
            if isCharging {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(theme.ok)
            }
            Text(detail)
                .font(Typography.mono(14))
                .monoDigits()
                .foregroundStyle(theme.text3)
                .lineLimit(1)
        }
        .padding(.horizontal, 16)
        .frame(height: Metrics.batteryPillHeight)
        .background(theme.surface, in: Capsule())
        .overlay(Capsule().stroke(theme.hairline, lineWidth: Metrics.hairline))
    }

    private var glyph: some View {
        let fill = isCharging ? theme.ok : (percent < 20 ? theme.crit : theme.text)
        let inner = max(0, min(percent, 100)) / 100
        return ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 4)
                .stroke(theme.text2, lineWidth: 1.5)
                .frame(width: 30, height: 14)
            RoundedRectangle(cornerRadius: 1)
                .fill(theme.text2)
                .frame(width: 3, height: 6)
                .offset(x: 29)
            RoundedRectangle(cornerRadius: 2)
                .fill(fill)
                .frame(width: 26 * CGFloat(inner), height: 10)
                .offset(x: 2)
        }
        .frame(width: 33, height: 14)
    }
}
