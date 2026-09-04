import SwiftUI

struct BigNumber: View {
    let value: String
    let unit: String?
    let label: String?
    let size: CGFloat
    let color: Color?

    @Environment(\.theme) private var theme

    init(value: String, unit: String? = nil, label: String? = nil, size: CGFloat = 72, color: Color? = nil) {
        self.value = value
        self.unit = unit
        self.label = label
        self.size = size
        self.color = color
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(Typography.mono(size, .semibold))
                    .monoDigits()
                    .tracking(size >= 56 ? -2 : 0)
                    .foregroundStyle(color ?? theme.text)
                    .contentTransition(.numericText())
                    .animation(Motion.numberTween, value: value)
                if let unit {
                    Text(unit)
                        .font(Typography.mono(size * 0.36, .semibold))
                        .monoDigits()
                        .foregroundStyle(theme.text2)
                }
            }
            if let label {
                Text(label)
                    .font(Typography.small)
                    .foregroundStyle(theme.text3)
                    .tracking(0.3)
            }
        }
    }
}
