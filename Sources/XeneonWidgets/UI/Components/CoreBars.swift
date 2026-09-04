import SwiftUI
import XeneonWidgetsCore

struct CoreBars: View {
    let title: String
    let values: [Double]
    let barWidth: CGFloat
    let barHeight: CGFloat
    let gap: CGFloat

    @Environment(\.theme) private var theme

    init(title: String, values: [Double], barWidth: CGFloat = 32, barHeight: CGFloat = 96, gap: CGFloat = 8) {
        self.title = title
        self.values = values
        self.barWidth = barWidth
        self.barHeight = barHeight
        self.gap = gap
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(title)
                    .font(Typography.microSans)
                    .foregroundStyle(theme.text3)
                    .tracking(0.3)
                Spacer(minLength: 8)
                Text("avg \(Formatters.percent(average))")
                    .font(Typography.mono(14))
                    .monoDigits()
                    .foregroundStyle(theme.text2)
            }
            HStack(alignment: .bottom, spacing: gap) {
                ForEach(values.indices, id: \.self) { index in
                    bar(values[index])
                }
            }
        }
    }

    private var average: Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    private func bar(_ value: Double) -> some View {
        let clamped = min(max(value, 0), 100)
        let fillHeight = barHeight * CGFloat(clamped / 100)
        return VStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 6)
                .fill(theme.surface2)
                .frame(width: barWidth, height: barHeight)
                .overlay {
                    theme.ramp
                        .frame(width: barWidth, height: barHeight)
                        .mask(alignment: .bottom) {
                            Rectangle().frame(height: fillHeight)
                        }
                }
                .clipShape(RoundedRectangle(cornerRadius: 6))
            Text("\(Int(value.rounded()))")
                .font(Typography.mono(12))
                .monoDigits()
                .foregroundStyle(theme.text3)
        }
        .frame(width: barWidth)
    }
}
