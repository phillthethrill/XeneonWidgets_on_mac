import SwiftUI
import XeneonWidgetsCore

struct HeaderBar: View {
    @ObservedObject var clock: ClockProvider
    @ObservedObject var power: PowerProvider
    @ObservedObject var state: DashboardState
    let onAlertTap: (XeneonWidgetsCore.Alert) -> Void
    let showPageDots: Bool

    @Environment(\.theme) private var theme
    @EnvironmentObject private var alertMonitor: AlertMonitor

    init(
        clock: ClockProvider,
        power: PowerProvider,
        state: DashboardState,
        onAlertTap: @escaping (XeneonWidgetsCore.Alert) -> Void,
        showPageDots: Bool
    ) {
        self.clock = clock
        self.power = power
        self.state = state
        self.onAlertTap = onAlertTap
        self.showPageDots = showPageDots
    }

    var body: some View {
        HStack(alignment: .center, spacing: 24) {
            leftCluster
                .fixedSize(horizontal: true, vertical: false)
            centerCluster
                .frame(maxWidth: .infinity)
            if let battery = power.battery {
                BatteryPill(
                    percent: battery.percent,
                    isCharging: battery.isCharging,
                    detail: PowerMath.remainingLabel(minutes: battery.minutesRemaining, watts: battery.watts)
                )
            }
            clockCluster
                .fixedSize(horizontal: true, vertical: false)
        }
        .frame(height: Metrics.headerHeight)
        .frame(maxWidth: .infinity)
    }

    private var leftCluster: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(state.isDisplayConnected ? theme.ok : theme.text3)
                .frame(width: 8, height: 8)
                .shadow(color: state.isDisplayConnected ? theme.ok : .clear, radius: 4)
            Text(clock.hostName)
                .font(Typography.pro(15, .semibold))
                .foregroundStyle(theme.text2)
            Text(clock.osVersion)
                .font(Typography.small)
                .foregroundStyle(theme.text3)
            separator
            Text(Formatters.uptime(clock.uptime))
                .font(Typography.small)
                .foregroundStyle(theme.text3)
            separator
            Text(state.isDisplayConnected ? "Xeneon Connected" : "Xeneon Not Connected")
                .font(Typography.small)
                .foregroundStyle(theme.text3)
            separator
            Text(state.sampling.label)
                .font(Typography.smallMono)
                .monoDigits()
                .foregroundStyle(theme.text3)
        }
        .lineLimit(1)
    }

    private var centerCluster: some View {
        let alerts = state.alerts
        let visible = Array(alerts.prefix(3))
        let extra = alerts.count - visible.count
        return VStack(spacing: 4) {
            if !visible.isEmpty {
                HStack(spacing: 10) {
                    ForEach(visible) { alert in
                        AlertChip(
                            text: alert.text,
                            age: Formatters.age(clock.now.timeIntervalSince(alert.since)),
                            level: alert.level,
                            action: {
                                onAlertTap(alert)
                                alertMonitor.handleChipTap(alert)
                            }
                        )
                    }
                    if extra > 0 {
                        overflowChip(extra)
                    }
                }
            }
            if showPageDots {
                PageDots(count: Preset.allCases.count, index: state.preset.index)
            }
        }
    }

    private var clockCluster: some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text(Formatters.clockHM(clock.now))
                    .font(Typography.clock)
                    .foregroundStyle(theme.text)
                Text(":" + Formatters.clockSeconds(clock.now))
                    .font(Typography.clockSeconds)
                    .foregroundStyle(theme.text3)
            }
            .monoDigits()
            .tracking(-1)
            HStack(spacing: 0) {
                Text(Formatters.shortDate(clock.now))
                    .foregroundStyle(theme.text2)
                Text(" · ")
                    .foregroundStyle(theme.text3)
                Text(Formatters.isoWeek(clock.now))
                    .foregroundStyle(theme.text3)
            }
            .font(Typography.pro(16))
        }
        .lineLimit(1)
    }

    private var separator: some View {
        Text("·")
            .font(Typography.small)
            .foregroundStyle(theme.text3)
    }

    private func overflowChip(_ extra: Int) -> some View {
        Text("+\(extra)")
            .font(Typography.chip)
            .foregroundStyle(theme.text2)
            .padding(.horizontal, 16)
            .frame(height: 40)
            .background(theme.surface2, in: Capsule())
    }
}
