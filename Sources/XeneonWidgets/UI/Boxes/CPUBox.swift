import SwiftUI
import XeneonWidgetsCore

enum CPUBoxMode {
    case overview, focus
}

struct CPUBox: View {
    @ObservedObject var cpu: CPUProvider
    @ObservedObject var state: DashboardState
    let mode: CPUBoxMode
    let uptime: TimeInterval

    @Environment(\.theme) private var theme
    @State private var showRangePicker = false

    init(cpu: CPUProvider, state: DashboardState, mode: CPUBoxMode, uptime: TimeInterval) {
        self.cpu = cpu
        self.state = state
        self.mode = mode
        self.uptime = uptime
    }

    var body: some View {
        let totalColor = theme.stateColor(cpu.total, .cpu)
        BoxContainer(
            title: "cpu",
            meta: "\(cpu.cpuModel) · \(cpu.coreConfigLabel) · \(Formatters.uptime(uptime))",
            value: Formatters.percent(cpu.total),
            valueColor: totalColor
        ) {
            GeometryReader { geo in
                let innerW = geo.size.width
                let graphW = mode == .overview ? 404 : max(0, innerW - 268 - 24)
                let graphH: CGFloat = mode == .overview ? 240 : 200
                ZStack(alignment: .topLeading) {
                    VStack(alignment: .leading, spacing: Metrics.innerGap) {
                        topRow(graphWidth: graphW, graphHeight: graphH, totalColor: totalColor)
                        coresRow(innerWidth: innerW)
                        if let gpu = cpu.gpu {
                            Hairline()
                            gpuRow(gpu, innerWidth: innerW)
                        } else {
                            Spacer(minLength: 0)
                        }
                    }
                    .frame(width: innerW, height: geo.size.height, alignment: .topLeading)

                    if showRangePicker {
                        Color.clear
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .contentShape(Rectangle())
                            .onTapGesture(perform: closeRangePicker)
                        TimeRangePopover(selected: timeRange, onSelect: selectRange)
                            .frame(width: graphW, height: graphH)
                    }
                }
            }
        }
    }

    private var timeRange: TimeRange {
        state.timeRange(for: .cpu)
    }

    private func topRow(graphWidth: CGFloat, graphHeight: CGFloat, totalColor: Color) -> some View {
        HStack(alignment: .top, spacing: 24) {
            HistoryGraph(
                values: windowed(cpu.totalHistory, width: graphWidth),
                cornerLabel: "\(timeRange.label) · tap for range"
            )
            .frame(width: graphWidth, height: graphHeight)
            .contentShape(Rectangle())
            .onTapGesture(perform: openRangePicker)

            rightColumn(totalColor: totalColor)
                .frame(width: 268, alignment: .leading)
        }
    }

    private func rightColumn(totalColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            BigNumber(
                value: "\(Int(cpu.total.rounded()))",
                unit: "%",
                label: "total · \(cpu.coreCount) cores",
                color: totalColor
            )
            StatePill(label: "Thermal", value: cpu.thermal.label, level: cpu.thermal.stateLevel)
            VStack(alignment: .leading, spacing: 4) {
                KVRow(key: "load 1 · 5 · 15", value: loadLabel)
                if cpu.perCoreFrequencyAvailable {
                    KVRow(key: "freq", value: "n/a · Apple Silicon", valueColor: theme.text3)
                }
            }
        }
    }

    private var loadLabel: String {
        [
            Formatters.loadAverage(cpu.loadAverage.one),
            Formatters.loadAverage(cpu.loadAverage.five),
            Formatters.loadAverage(cpu.loadAverage.fifteen),
        ].joined(separator: "  ")
    }

    @ViewBuilder
    private func coresRow(innerWidth: CGFloat) -> some View {
        switch mode {
        case .overview:
            overviewCores
        case .focus:
            focusCoreGrid(innerWidth: innerWidth)
        }
    }

    private var overviewCores: some View {
        let pCount = cpu.performanceCoreIndices.count
        let pTitle = cpu.efficiencyCoreIndices.isEmpty
            ? "\(pCount) cores"
            : "\(pCount) P-cores"
        return HStack(alignment: .top, spacing: 24) {
            CoreBars(title: pTitle, values: values(at: cpu.performanceCoreIndices))
            if !cpu.efficiencyCoreIndices.isEmpty {
                Hairline(vertical: true)
                CoreBars(title: "\(cpu.efficiencyCoreIndices.count) E-cores", values: values(at: cpu.efficiencyCoreIndices))
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func focusCoreGrid(innerWidth: CGFloat) -> some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 8)
        let cellWidth = (innerWidth - 7 * 12) / 8
        let graphWidth = max(1, cellWidth - 20)
        return LazyVGrid(columns: columns, spacing: 12) {
            ForEach(coreItems) { item in
                coreCell(item, graphWidth: graphWidth)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func coreCell(_ item: CoreItem, graphWidth: CGFloat) -> some View {
        let value = coreValue(at: item.logicalIndex)
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(item.isEfficiency ? "\(item.label) · eff" : item.label)
                    .foregroundStyle(theme.text3)
                Spacer(minLength: 4)
                Text(Formatters.percent(value))
                    .foregroundStyle(theme.stateColor(value, .cpu))
                    .contentTransition(.numericText())
                    .animation(Motion.numberTween, value: value)
            }
            .font(Typography.micro)
            .monoDigits()
            HistoryGraph(
                values: windowed(coreHistory(at: item.logicalIndex), width: graphWidth),
                style: .ramp,
                showGrid: false,
                lineWidth: 1.5
            )
            .frame(height: 56)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(theme.surface2)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(item.isEfficiency ? theme.accent : Color.clear)
                .frame(width: 3)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func gpuRow(_ gpu: GPUStats, innerWidth: CGFloat) -> some View {
        let graphW = min(320, max(160, innerWidth - 470))
        return HStack(alignment: .center, spacing: 20) {
            Text("gpu")
                .font(Typography.boxTitle)
                .tracking(2.4)
                .textCase(.lowercase)
                .foregroundStyle(theme.text2)
            HistoryGraph(
                values: windowed(cpu.gpuHistory, width: graphW),
                showGrid: false
            )
            .frame(width: graphW, height: 56)
            BigNumber(
                value: "\(Int(gpu.utilization.rounded()))",
                unit: "%",
                label: "GPU",
                size: 34
            )
            Spacer(minLength: 0)
            VStack(alignment: .leading, spacing: 4) {
                KVRow(key: "gpu memory", value: gpuMemoryLabel(gpu))
                KVRow(key: "source", value: gpu.source, valueColor: theme.text3)
            }
            .frame(width: 200)
        }
    }

    private func gpuMemoryLabel(_ gpu: GPUStats) -> String {
        let used = Formatters.gigabytes(gpu.memoryUsedBytes, decimals: 1)
            .replacingOccurrences(of: " GB", with: "")
        let total = Formatters.gigabytes(gpu.memoryTotalBytes, decimals: 0)
        return "\(used) / \(total)"
    }

    private func windowed(_ buffer: RingBuffer<Double>, width: CGFloat) -> [Double] {
        let range = timeRange
        let sampleCount = range.sampleCount(at: state.sampling)
        let values = buffer.suffix(sampleCount)
        let padded = GraphMath.padLeading(values, to: sampleCount)
        return GraphMath.bucket(padded, into: max(2, Int(width / 3)))
    }

    private func values(at indices: [Int]) -> [Double] {
        indices.map { coreValue(at: $0) }
    }

    private func coreValue(at index: Int) -> Double {
        cpu.perCore.indices.contains(index) ? cpu.perCore[index] : 0
    }

    private func coreHistory(at index: Int) -> RingBuffer<Double> {
        if cpu.coreHistories.indices.contains(index) {
            return cpu.coreHistories[index]
        }
        return RingBuffer(capacity: 2)
    }

    private var coreItems: [CoreItem] {
        let p = cpu.performanceCoreIndices.enumerated().map { offset, index in
            CoreItem(logicalIndex: index, label: "P\(offset)", isEfficiency: false)
        }
        let e = cpu.efficiencyCoreIndices.enumerated().map { offset, index in
            CoreItem(logicalIndex: index, label: "E\(offset)", isEfficiency: true)
        }
        return p + e
    }

    private func openRangePicker() {
        state.noteActivity()
        showRangePicker = true
    }

    private func closeRangePicker() {
        state.noteActivity()
        showRangePicker = false
    }

    private func selectRange(_ range: TimeRange) {
        state.noteActivity()
        state.setTimeRange(range, for: .cpu)
        showRangePicker = false
    }
}

private struct CoreItem: Identifiable {
    var id: Int { logicalIndex }
    let logicalIndex: Int
    let label: String
    let isEfficiency: Bool
}
