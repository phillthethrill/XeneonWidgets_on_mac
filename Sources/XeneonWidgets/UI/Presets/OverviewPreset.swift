import SwiftUI
import XeneonWidgetsCore

struct OverviewPreset: View {
    let env: DashboardEnvironment

    @ObservedObject private var clock: ClockProvider
    @ObservedObject private var state: DashboardState
    @ObservedObject private var alertMonitor: AlertMonitor

    init(env: DashboardEnvironment) {
        self.env = env
        self._clock = ObservedObject(wrappedValue: env.clock)
        self._state = ObservedObject(wrappedValue: env.state)
        self._alertMonitor = ObservedObject(wrappedValue: env.alertMonitor)
    }

    var body: some View {
        PresetLayoutView(env: env, preset: .overview) { placement in
            AnyView(box(for: placement))
        }
    }

    @ViewBuilder
    private func box(for placement: BoxPlacement) -> some View {
        switch placement.id {
        case .cpu:
            CPUBox(cpu: env.cpu, state: state, mode: .overview, uptime: clock.uptime, glow: glow(for: .cpu))
        case .mem:
            MemBox(memory: env.memory, disks: env.disks, compact: false, glow: glow(for: .mem))
        case .net:
            NetBox(network: env.network, compact: false, glow: glow(for: .net))
        case .proc:
            ProcBox(processes: env.processes, state: state, wide: false, glow: glow(for: .proc)) {
                state.preset = .focusProcesses
                state.noteActivity()
            }
        case .gpu:
            GPUBox(cpu: env.cpu)
        case .battery:
            BatteryBox(power: env.power, glow: glow(for: .battery))
        case .clock:
            ClockBox(clock: env.clock)
        }
    }

    private func glow(for box: BoxID) -> Color? {
        AlertHighlight.glow(
            for: box,
            alerts: state.alerts,
            theme: state.theme,
            highlighted: alertMonitor.highlightedBox,
            pulseOpacity: alertMonitor.highlightOpacity
        )
    }
}
