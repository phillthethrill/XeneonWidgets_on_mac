import SwiftUI
import XeneonWidgetsCore

struct NetBox: View {
    @ObservedObject var network: NetworkProvider
    var compact: Bool

    @Environment(\.theme) private var theme
    @State private var showInterfacePopover = false

    init(network: NetworkProvider, compact: Bool) {
        self.network = network
        self.compact = compact
    }

    var body: some View {
        BoxContainer(title: "net", meta: network.metaLabel, value: network.valueLabel) {
            VStack(alignment: .leading, spacing: Metrics.innerGap) {
                graph
                    .onTapGesture { showInterfacePopover = false }
                rates
                    .onTapGesture { showInterfacePopover = false }
                if !compact {
                    chipBlock
                }
                footer
                    .onTapGesture { showInterfacePopover = false }
            }
        }
    }

    private var graph: some View {
        let down = windowedMegabytes(network.downHistory)
        let up = windowedMegabytes(network.upHistory)
        let downMax = down.max() ?? 0
        let upMax = up.max() ?? 0
        return MirrorGraph(
            down: down,
            up: up,
            downScale: GraphMath.niceScale(peak: downMax, floor: 1),
            upScale: GraphMath.niceScale(peak: upMax, floor: 1),
            downLabel: NetworkMath.rateScaleLabel(bytesPerSecond: downMax * 1_000_000.0, arrow: "↓"),
            upLabel: NetworkMath.rateScaleLabel(bytesPerSecond: upMax * 1_000_000.0, arrow: "↑")
        )
        .frame(width: 436, height: compact ? 230 : 300)
    }

    private var rates: some View {
        HStack(alignment: .top, spacing: Metrics.innerGap) {
            rateBlock(
                arrow: "↓",
                color: theme.accent,
                rate: network.downRate,
                peak: network.downPeak,
                total: network.downTotal
            )
            rateBlock(
                arrow: "↑",
                color: theme.up,
                rate: network.upRate,
                peak: network.upPeak,
                total: network.upTotal
            )
        }
    }

    private func rateBlock(
        arrow: String,
        color: Color,
        rate: Double,
        peak: Double,
        total: UInt64
    ) -> some View {
        let rateText = Formatters.megabytesPerSecond(rate)
        let peakText = Formatters.megabytesPerSecond(peak)
        let totalText = Formatters.totalBytes(total)
        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(arrow)
                    .font(Typography.mono(30, .semibold))
                    .foregroundStyle(color)
                Text(rateText)
                    .font(Typography.numMd)
                    .monoDigits()
                    .tracking(-1)
                    .foregroundStyle(theme.text)
                    .contentTransition(.numericText())
                    .animation(Motion.numberTween, value: rateText)
                Text("MB/s")
                    .font(Typography.mono(14))
                    .foregroundStyle(theme.text3)
            }
            Text("peak \(peakText) · total \(totalText)")
                .font(Typography.micro)
                .monoDigits()
                .foregroundStyle(theme.text3)
                .contentTransition(.numericText())
                .animation(Motion.numberTween, value: peakText + totalText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var chipBlock: some View {
        ZStack(alignment: .bottom) {
            chipRow
            if showInterfacePopover {
                InterfacePopover(
                    interfaces: network.interfaces,
                    selected: network.selection,
                    onSelect: { selection in
                        network.selection = selection
                        showInterfacePopover = false
                    }
                )
                .padding(.bottom, 64)
            }
        }
        .zIndex(1)
    }

    private var chipRow: some View {
        HStack(spacing: 8) {
            ForEach(KindChip.allCases, id: \.self) { chip in
                ChipRow(
                    titles: [chip.title],
                    selectedIndex: selectedChip == chip ? 0 : -1,
                    height: 56,
                    onSelect: { _ in select(chip) },
                    onLongPress: { _ in showInterfacePopover = true }
                )
                .opacity(isAvailable(chip) ? 1 : 0.4)
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 0) {
            ForEach(Array(footerSegments.enumerated()), id: \.offset) { index, segment in
                if index > 0 {
                    Text(" · ")
                        .foregroundStyle(theme.text3)
                }
                footerSegment(segment)
            }
        }
        .font(Typography.mono(14))
        .monoDigits()
        .foregroundStyle(theme.text3)
    }

    @ViewBuilder
    private func footerSegment(_ segment: FooterSegment) -> some View {
        switch segment {
        case .text(let value):
            Text(value)
        case .ping(let milliseconds):
            HStack(spacing: 0) {
                Text("ping \(Self.pingHost) ")
                Text("\(Self.pingLabel(milliseconds)) ms")
                    .foregroundStyle(theme.color(Threshold.ping.level(milliseconds)))
                    .animation(Motion.colorFade, value: Threshold.ping.level(milliseconds))
            }
        }
    }

    private var footerSegments: [FooterSegment] {
        var segments: [FooterSegment] = []
        if let wifi = network.wifi {
            segments.append(.text(rssiLabel(wifi.rssi)))
            segments.append(.text(linkRateLabel(wifi.txRateMbps)))
        } else if let kind = network.activeInterface?.kind {
            segments.append(.text("link \(kind.rawValue)"))
        }
        if let ping = network.pingMilliseconds {
            segments.append(.ping(ping))
        }
        return segments
    }

    private var windowCount: Int {
        let capacity = network.downHistory.capacity
        if let interval = SamplingInterval.allCases.first(where: { $0.historyCapacity == capacity }) {
            return TimeRange.fiveMinutes.sampleCount(at: interval)
        }
        return max(2, capacity / 12)
    }

    private func windowedMegabytes(_ history: RingBuffer<Double>) -> [Double] {
        let megabytes = history.suffix(windowCount).map { $0 / 1_000_000.0 }
        let padded = GraphMath.padLeading(megabytes, to: windowCount)
        return GraphMath.bucket(padded, into: max(2, 436 / 3))
    }

    private var selectedChip: KindChip? {
        switch network.selection {
        case .auto:
            return .auto
        case .interface(let name):
            guard let kind = network.interfaces.first(where: { $0.name == name })?.kind else {
                return nil
            }
            return KindChip.matching(kind)
        }
    }

    private func isAvailable(_ chip: KindChip) -> Bool {
        guard let kind = chip.kind else { return true }
        return network.interfaces.contains(where: { $0.kind == kind && $0.isActive })
    }

    private func select(_ chip: KindChip) {
        showInterfacePopover = false
        switch chip {
        case .auto:
            network.selection = .auto
        case .wifi, .ethernet, .usb:
            guard let kind = chip.kind,
                  let iface = network.interfaces.first(where: { $0.kind == kind && $0.isActive }) else {
                return
            }
            network.selection = .interface(iface.name)
        }
    }

    private func rssiLabel(_ rssi: Int) -> String {
        if rssi < 0 {
            return "RSSI −\(abs(rssi)) dBm"
        }
        return "RSSI \(rssi) dBm"
    }

    private func linkRateLabel(_ mbps: Double) -> String {
        "link \(String(format: "%.0f", mbps.rounded())) Mb/s"
    }

    private static func pingLabel(_ milliseconds: Double) -> String {
        String(format: "%.0f", milliseconds.rounded())
    }

    /// Provider exposes machine `hostName`, not the ping target. Default matches SettingsStore.
    private static let pingHost = "1.1.1.1"
}

private enum KindChip: Int, CaseIterable {
    case auto
    case wifi
    case ethernet
    case usb

    var title: String {
        switch self {
        case .auto: return "Auto"
        case .wifi: return InterfaceKind.wifi.rawValue
        case .ethernet: return InterfaceKind.ethernet.rawValue
        case .usb: return InterfaceKind.usb.rawValue
        }
    }

    var kind: InterfaceKind? {
        switch self {
        case .auto: return nil
        case .wifi: return .wifi
        case .ethernet: return .ethernet
        case .usb: return .usb
        }
    }

    static func matching(_ kind: InterfaceKind) -> KindChip? {
        switch kind {
        case .wifi: return .wifi
        case .ethernet: return .ethernet
        case .usb: return .usb
        case .other: return nil
        }
    }
}

private enum FooterSegment {
    case text(String)
    case ping(Double)
}
