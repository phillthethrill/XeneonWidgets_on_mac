import SwiftUI
import XeneonWidgetsCore

struct StatePill: View {
    let label: String
    let value: String
    let level: StateLevel

    @Environment(\.theme) private var theme

    init(label: String, value: String, level: StateLevel) {
        self.label = label
        self.value = value
        self.level = level
    }

    var body: some View {
        let tint = theme.color(level)
        HStack(spacing: 8) {
            Circle()
                .fill(tint)
                .frame(width: 8, height: 8)
                .shadow(color: tint, radius: 4)
            HStack(spacing: 0) {
                Text(label)
                    .foregroundStyle(theme.text2)
                Text(" · ")
                    .foregroundStyle(theme.text2)
                Text(value)
                    .foregroundStyle(tint)
            }
        }
        .font(Typography.pro(14, .medium))
        .padding(.horizontal, 14)
        .frame(height: Metrics.pillHeight)
        .background(theme.surface2, in: Capsule())
    }
}
