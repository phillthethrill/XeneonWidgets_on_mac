import SwiftUI
import XeneonWidgetsCore

struct OverviewPreset: View {
    let env: DashboardEnvironment

    @ObservedObject private var clock: ClockProvider

    init(env: DashboardEnvironment) {
        self.env = env
        self._clock = ObservedObject(wrappedValue: env.clock)
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
            CPUBox(cpu: env.cpu, state: env.state, mode: .overview, uptime: clock.uptime)
        case .mem:
            MemBox(memory: env.memory, disks: env.disks, compact: false)
        case .net:
            NetBox(network: env.network, compact: false)
        case .proc:
            ProcBox(processes: env.processes, state: env.state, wide: false) {
                env.state.preset = .focusProcesses
                env.state.noteActivity()
            }
        case .gpu:
            GPUBox(cpu: env.cpu)
        case .battery:
            BatteryBox(power: env.power)
        case .clock:
            ClockBox(clock: env.clock)
        }
    }
}
