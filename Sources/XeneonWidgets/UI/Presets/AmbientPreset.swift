import SwiftUI
import XeneonWidgetsCore

struct AmbientPreset: View {
    let env: DashboardEnvironment

    @ObservedObject private var clock: ClockProvider
    @ObservedObject private var cpu: CPUProvider
    @ObservedObject private var memory: MemoryProvider
    @ObservedObject private var network: NetworkProvider
    @ObservedObject private var state: DashboardState
    @Environment(\.theme) private var theme
    @Environment(\.pageDotsVisible) private var showPageDots

    init(env: DashboardEnvironment) {
        self.env = env
        self._clock = ObservedObject(wrappedValue: env.clock)
        self._cpu = ObservedObject(wrappedValue: env.cpu)
        self._memory = ObservedObject(wrappedValue: env.memory)
        self._network = ObservedObject(wrappedValue: env.network)
        self._state = ObservedObject(wrappedValue: env.state)
    }

    var body: some View {
        ZStack {
            HStack(alignment: .center) {
                clockColumn
                Spacer(minLength: 28)
                sparksColumn
            }
            .padding(.horizontal, 72)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)

            if showPageDots {
                VStack {
                    PageDots(count: Preset.allCases.count, index: state.preset.index)
                        .padding(.top, 24)
                    Spacer()
                }
            }
        }
        .frame(width: Metrics.screenWidth, height: Metrics.screenHeight)
    }

    private var clockColumn: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text(Formatters.clockHM(clock.now))
                    .font(Typography.display)
                    .tracking(-12)
                    .foregroundStyle(theme.text)
                Text(Formatters.clockSeconds(clock.now))
                    .font(Typography.mono(96, .ultraLight))
                    .foregroundStyle(theme.text3)
                    .padding(.leading, 18)
            }
            .monoDigits()
            .lineLimit(1)

            HStack(spacing: 0) {
                Text(Formatters.longDate(clock.now) + " · " + Formatters.isoWeek(clock.now))
                    .foregroundStyle(theme.text2)
                if let event = clock.nextEvent {
                    Text(" · next: \(event.title) · \(Formatters.clockHM(event.start))")
                        .foregroundStyle(theme.text3)
                }
            }
            .font(Typography.pro(33))
            .lineLimit(1)
        }
    }

    private var sparksColumn: some View {
        VStack(alignment: .leading, spacing: 28) {
            ambientRow(
                label: "cpu",
                values: cpu.totalHistory.elements,
                color: theme.stateColor(cpu.total, .cpu),
                value: Formatters.percent(cpu.total),
                max: 100
            )
            ambientRow(
                label: "mem",
                values: memory.usedHistory.elements,
                color: theme.stateColor(memory.breakdown.usedPercent, .memory),
                value: Formatters.percent(memory.breakdown.usedPercent),
                max: 100
            )
            ambientRow(
                label: "net ↓",
                values: network.downHistory.elements,
                color: theme.accent,
                value: "\(Formatters.megabytesPerSecond(network.downRate)) MB/s",
                max: nil
            )
        }
    }

    private func ambientRow(
        label: String,
        values: [Double],
        color: Color,
        value: String,
        max: Double?
    ) -> some View {
        HStack(spacing: 24) {
            Text(label)
                .font(Typography.mono(16))
                .tracking(2.4)
                .foregroundStyle(theme.text3)
                .frame(width: 70, alignment: .leading)
            Sparkline(values: values, color: color, max: max)
                .frame(width: 420, height: 64)
            Text(value)
                .font(Typography.mono(36, .medium))
                .monoDigits()
                .foregroundStyle(theme.text)
                .frame(width: 220, alignment: .trailing)
        }
    }
}
