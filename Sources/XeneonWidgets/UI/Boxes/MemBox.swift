import SwiftUI
import XeneonWidgetsCore

struct MemBox: View {
    @ObservedObject var memory: MemoryProvider
    @ObservedObject var disks: DiskProvider
    let compact: Bool
    let glow: Color?

    @Environment(\.theme) private var theme

    init(memory: MemoryProvider, disks: DiskProvider, compact: Bool, glow: Color? = nil) {
        self.memory = memory
        self.disks = disks
        self.compact = compact
        self.glow = glow
    }

    var body: some View {
        let breakdown = memory.breakdown
        let usedPercent = breakdown.usedPercent
        let memState = theme.stateColor(usedPercent, .memory)
        let valueColor = memory.pressure != .normal
            ? theme.color(memory.pressure.stateLevel)
            : memState
        let usedLabel = String(Int(usedPercent.rounded()))
        let swap = MemoryMath.swapLabel(usedBytes: memory.swapUsed, totalBytes: memory.swapTotal)

        return BoxContainer(
            title: "mem",
            meta: memory.totalLabel,
            value: MemoryMath.memValueLabel(usedBytes: breakdown.used, totalBytes: breakdown.total),
            valueColor: valueColor,
            glow: glow
        ) {
            VStack(alignment: .leading, spacing: Metrics.innerGap) {
                usedRow(usedLabel: usedLabel, memState: memState, swap: swap)
                SegBar(segments: segments(for: breakdown))
                Legend(items: legendItems(for: breakdown), columns: compact ? 1 : 2)
                Hairline()
                disksHeader
                diskRows
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    private func usedRow(usedLabel: String, memState: Color, swap: String) -> some View {
        HStack(alignment: .bottom, spacing: 20) {
            BigNumber(value: usedLabel, unit: "%", label: "used", size: 56, color: memState)
            VStack(alignment: .leading, spacing: 8) {
                StatePill(label: "Pressure", value: memory.pressure.label, level: memory.pressure.stateLevel)
                Text(swap)
                    .font(Typography.mono(14))
                    .monoDigits()
                    .foregroundStyle(theme.text3)
                    .padding(.leading, 2)
                    .contentTransition(.numericText())
                    .animation(Motion.numberTween, value: swap)
            }
            .padding(.bottom, 4)
        }
    }

    private var disksHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("disks")
                .font(Typography.boxTitle)
                .tracking(2.4)
                .textCase(.lowercase)
                .foregroundStyle(theme.text2)
            Spacer(minLength: 8)
            disksMeta
        }
    }

    @ViewBuilder
    private var disksMeta: some View {
        let count = disks.volumeCount
        if compact {
            Text("\(count) volumes")
                .font(Typography.mono(14))
                .monoDigits()
                .foregroundStyle(theme.text3)
        } else {
            HStack(spacing: 0) {
                Text("\(count) volumes · ")
                Text("R")
                    .foregroundStyle(theme.accent)
                Text(" ")
                Text("W")
                    .foregroundStyle(theme.up)
                Text(" MB/s")
            }
            .font(Typography.mono(14))
            .monoDigits()
            .foregroundStyle(theme.text3)
        }
    }

    private var diskRows: some View {
        VStack(spacing: 4) {
            ForEach(Array(disks.volumes.prefix(4))) { volume in
                diskRow(for: volume)
            }
        }
    }

    private func diskRow(for volume: VolumeInfo) -> some View {
        let io = disks.io[volume.id]
        return DiskRow(
            name: volume.name,
            kind: volume.kind,
            capacityLabel: DiskMath.capacityLabel(used: volume.usedBytes, total: volume.totalBytes),
            percent: volume.percent,
            readHistory: io.map { $0.readHistory.suffix(60) },
            writeHistory: io.map { $0.writeHistory.suffix(60) },
            readLabel: io.map { Self.ioLabel($0.readRate) },
            writeLabel: io.map { Self.ioLabel($0.writeRate) },
            showIO: !compact,
            crit: volume.percent >= 90
        )
    }

    private func segments(for breakdown: MemoryBreakdown) -> [SegBar.Segment] {
        [
            SegBar.Segment(id: "app", value: Double(breakdown.app), color: theme.rampHigh, opacity: 1),
            SegBar.Segment(id: "wired", value: Double(breakdown.wired), color: theme.rampMid, opacity: 1),
            SegBar.Segment(id: "compressed", value: Double(breakdown.compressed), color: theme.up, opacity: 1),
            SegBar.Segment(id: "cached", value: Double(breakdown.cached), color: theme.rampLow, opacity: 1),
            SegBar.Segment(id: "free", value: Double(breakdown.free), color: theme.text3, opacity: 0.25),
        ]
    }

    private func legendItems(
        for breakdown: MemoryBreakdown
    ) -> [(label: String, value: String, color: Color, opacity: Double)] {
        [
            ("App", Formatters.gigabytes(breakdown.app, decimals: 1), theme.rampHigh, 1),
            ("Wired", Formatters.gigabytes(breakdown.wired, decimals: 1), theme.rampMid, 1),
            ("Compressed", Formatters.gigabytes(breakdown.compressed, decimals: 1), theme.up, 1),
            ("Cached files", Formatters.gigabytes(breakdown.cached, decimals: 1), theme.rampLow, 1),
            ("Free", Formatters.gigabytes(breakdown.free, decimals: 1), theme.text3, 0.35),
        ]
    }

    private static func ioLabel(_ megabytesPerSecond: Double) -> String {
        String(format: "%.1f MB/s", megabytesPerSecond)
    }
}
