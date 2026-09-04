import SwiftUI
import XeneonWidgetsCore

struct GPUBox: View {
    @ObservedObject var cpu: CPUProvider
    @Environment(\.theme) private var theme

    var body: some View {
        let gpu = cpu.gpu
        BoxContainer(
            title: "gpu",
            meta: gpu?.source,
            value: gpu.map { Formatters.percent($0.utilization) },
            valueColor: gpu.map { theme.stateColor($0.utilization, .cpu) }
        ) {
            if let gpu {
                HistoryGraph(values: cpu.gpuHistory.elements, showGrid: false)
                    .frame(maxWidth: .infinity)
                    .frame(height: 80)
                KVRow(key: "gpu memory", value: memoryLabel(gpu))
                KVRow(key: "source", value: gpu.source, valueColor: theme.text3)
                Spacer(minLength: 0)
            } else {
                Text("unavailable")
                    .font(Typography.small)
                    .foregroundStyle(theme.text3)
                Spacer(minLength: 0)
            }
        }
    }

    private func memoryLabel(_ gpu: GPUStats) -> String {
        let used = Formatters.gigabytes(gpu.memoryUsedBytes, decimals: 1)
            .replacingOccurrences(of: " GB", with: "")
        let total = Formatters.gigabytes(gpu.memoryTotalBytes, decimals: 0)
        return "\(used) / \(total)"
    }
}

struct BatteryBox: View {
    @ObservedObject var power: PowerProvider
    var glow: Color?
    @Environment(\.theme) private var theme

    var body: some View {
        let battery = power.battery
        BoxContainer(
            title: "battery",
            value: battery.map { Formatters.percent($0.percent) },
            glow: glow
        ) {
            if let battery {
                BatteryPill(
                    percent: battery.percent,
                    isCharging: battery.isCharging,
                    detail: PowerMath.remainingLabel(minutes: battery.minutesRemaining, watts: battery.watts)
                )
                KVRow(
                    key: "cycles",
                    value: battery.cycleCount.map { "\($0)" } ?? "—"
                )
                KVRow(key: "status", value: battery.isCharging ? "charging" : "discharging")
                Spacer(minLength: 0)
            } else {
                Text("unavailable")
                    .font(Typography.small)
                    .foregroundStyle(theme.text3)
                Spacer(minLength: 0)
            }
        }
    }
}

struct ClockBox: View {
    @ObservedObject var clock: ClockProvider
    @Environment(\.theme) private var theme

    var body: some View {
        BoxContainer(
            title: "clock",
            value: Formatters.clockHM(clock.now) + ":" + Formatters.clockSeconds(clock.now)
        ) {
            Text(Formatters.longDate(clock.now))
                .font(Typography.pro(22))
                .foregroundStyle(theme.text)
            Text(Formatters.isoWeek(clock.now))
                .font(Typography.small)
                .foregroundStyle(theme.text3)
            Spacer(minLength: 0)
        }
        .monoDigits()
    }
}
