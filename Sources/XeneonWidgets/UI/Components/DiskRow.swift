import SwiftUI
import XeneonWidgetsCore

struct DiskRow: View {
    let name: String
    let kind: String
    let capacityLabel: String
    let percent: Double
    let readHistory: [Double]?
    let writeHistory: [Double]?
    let readLabel: String?
    let writeLabel: String?
    let showIO: Bool
    let crit: Bool

    @Environment(\.theme) private var theme

    init(
        name: String,
        kind: String,
        capacityLabel: String,
        percent: Double,
        readHistory: [Double]?,
        writeHistory: [Double]?,
        readLabel: String?,
        writeLabel: String?,
        showIO: Bool,
        crit: Bool
    ) {
        self.name = name
        self.kind = kind
        self.capacityLabel = capacityLabel
        self.percent = percent
        self.readHistory = readHistory
        self.writeHistory = writeHistory
        self.readLabel = readLabel
        self.writeLabel = writeLabel
        self.showIO = showIO
        self.crit = crit
    }

    var body: some View {
        HStack(spacing: 16) {
            nameAndBar
                .frame(maxWidth: .infinity, alignment: .leading)
            if showIO {
                sparks
                    .frame(width: 150)
                rates
                    .frame(width: 84, alignment: .leading)
            } else {
                Spacer()
                    .frame(width: 120)
            }
        }
        .frame(height: 56)
    }

    private var nameAndBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                HStack(spacing: 8) {
                    Text(name)
                        .font(Typography.pro(16, .medium))
                        .foregroundStyle(theme.text)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Text(kind)
                        .font(Typography.pro(13))
                        .foregroundStyle(theme.text3)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Text(capacityLabel)
                    .font(Typography.mono(13))
                    .monoDigits()
                    .foregroundStyle(crit ? theme.crit : theme.text2)
                    .lineLimit(1)
                    .layoutPriority(1)
            }
            GeometryReader { geo in
                let width = geo.size.width * CGFloat(min(max(percent, 0), 100) / 100)
                ZStack(alignment: .leading) {
                    Capsule().fill(theme.surface2)
                    Capsule()
                        .fill(theme.stateColor(percent, .disk))
                        .frame(width: width)
                }
            }
            .frame(height: 6)
        }
    }

    private var sparks: some View {
        HStack(spacing: 8) {
            Sparkline(values: readHistory ?? [], color: theme.accent, max: 50)
                .frame(width: 70, height: 22)
            Sparkline(values: writeHistory ?? [], color: theme.up, max: 50)
                .frame(width: 70, height: 22)
        }
    }

    private var rates: some View {
        VStack(alignment: .leading, spacing: 0) {
            rateLine(prefix: "R", color: theme.accent, label: readLabel)
            rateLine(prefix: "W", color: theme.up, label: writeLabel)
        }
        .font(Typography.mono(12))
        .monoDigits()
    }

    private func rateLine(prefix: String, color: Color, label: String?) -> some View {
        HStack(spacing: 4) {
            Text(prefix).foregroundStyle(color)
            Text(label ?? "").foregroundStyle(theme.text3)
        }
    }
}
