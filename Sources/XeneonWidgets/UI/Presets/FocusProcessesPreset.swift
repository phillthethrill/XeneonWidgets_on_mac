import SwiftUI
import XeneonWidgetsCore

struct FocusProcessesPreset: View {
    let env: DashboardEnvironment

    @ObservedObject private var state: DashboardState
    @ObservedObject private var processes: ProcessProvider

    init(env: DashboardEnvironment) {
        self.env = env
        self._state = ObservedObject(wrappedValue: env.state)
        self._processes = ObservedObject(wrappedValue: env.processes)
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            PresetLayoutView(env: env, preset: .focusProcesses) { placement in
                AnyView(box(for: placement))
            }
            if let process = selectedProcess {
                ProcessDetailSheet(
                    process: process,
                    icon: processes.icon(for: process),
                    detail: processes.detail,
                    state: state,
                    onTerminate: {
                        _ = processes.terminate(process.pid)
                        closeSheet()
                    },
                    onForceQuit: {
                        _ = processes.forceQuit(process.pid)
                        closeSheet()
                    },
                    onClose: closeSheet
                )
            }
        }
        .onChange(of: state.selectedPID) { _ in
            state.confirm = nil
        }
    }

    @ViewBuilder
    private func box(for placement: BoxPlacement) -> some View {
        switch placement.id {
        case .proc:
            ProcBox(processes: processes, state: state, wide: true)
        case .cpu:
            CPUBox(cpu: env.cpu, state: state, mode: .overview, uptime: env.clock.uptime)
        case .mem:
            MemBox(memory: env.memory, disks: env.disks, compact: false)
        case .net:
            NetBox(network: env.network, compact: false)
        case .gpu:
            GPUBox(cpu: env.cpu)
        case .battery:
            BatteryBox(power: env.power)
        case .clock:
            ClockBox(clock: env.clock)
        }
    }

    private var selectedProcess: ProcessSample? {
        guard let pid = state.selectedPID else { return nil }
        return processes.processes.first(where: { $0.pid == pid })
    }

    private func closeSheet() {
        state.selectedPID = nil
        processes.watchedPID = nil
        state.confirm = nil
    }
}
