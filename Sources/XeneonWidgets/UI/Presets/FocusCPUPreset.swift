import SwiftUI
import XeneonWidgetsCore

struct FocusCPUPreset: View {
    let env: DashboardEnvironment

    @ObservedObject private var clock: ClockProvider

    init(env: DashboardEnvironment) {
        self.env = env
        self._clock = ObservedObject(wrappedValue: env.clock)
    }

    var body: some View {
        PresetLayoutView(env: env, preset: .focusCPU) { placement in
            AnyView(box(for: placement))
        }
    }

    @ViewBuilder
    private func box(for placement: BoxPlacement) -> some View {
        switch placement.id {
        case .cpu:
            CPUBox(cpu: env.cpu, state: env.state, mode: .focus, uptime: clock.uptime)
        case .mem:
            MemBox(memory: env.memory, disks: env.disks, compact: true)
        case .net:
            NetBox(network: env.network, compact: true)
        case .proc:
            ProcBox(processes: env.processes, state: env.state, wide: false)
        case .gpu:
            GPUBox(cpu: env.cpu)
        case .battery:
            BatteryBox(power: env.power)
        case .clock:
            ClockBox(clock: env.clock)
        }
    }
}
