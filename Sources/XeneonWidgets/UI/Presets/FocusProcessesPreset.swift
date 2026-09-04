import SwiftUI
import XeneonWidgetsCore

struct FocusProcessesPreset: View {
    let env: DashboardEnvironment

    @ObservedObject private var state: DashboardState
    @ObservedObject private var processes: ProcessProvider
    @ObservedObject private var alertMonitor: AlertMonitor

    init(env: DashboardEnvironment) {
        self.env = env
        self._state = ObservedObject(wrappedValue: env.state)
        self._processes = ObservedObject(wrappedValue: env.processes)
        self._alertMonitor = ObservedObject(wrappedValue: env.alertMonitor)
    }

    var body: some View {
        PresetLayoutView(env: env, preset: .focusProcesses) { placement in
            AnyView(box(for: placement))
        } bodyOverlay: {
            if let process = selectedProcess {
                ProcessDetailSheet(
                    process: process,
                    icon: processes.icon(for: process),
                    detail: processes.detail,
                    state: state,
                    onTerminate: {
                        _ = processes.terminate(process.pid, startedAt: process.startTime)
                        closeSheet()
                    },
                    onForceQuit: {
                        _ = processes.forceQuit(process.pid, startedAt: process.startTime)
                        closeSheet()
                    },
                    onClose: closeSheet
                )
                .transition(.move(edge: .trailing))
            }
        }
        .animation(Motion.siblingSlide, value: state.selectedPID)
        .onChange(of: state.selectedPID) { _ in
            state.confirm = nil
        }
    }

    @ViewBuilder
    private func box(for placement: BoxPlacement) -> some View {
        switch placement.id {
        case .proc:
            ProcBox(processes: processes, state: state, wide: true, glow: glow(for: .proc))
        case .cpu:
            CPUBox(cpu: env.cpu, state: state, mode: .overview, uptime: env.clock.uptime, glow: glow(for: .cpu))
        case .mem:
            MemBox(memory: env.memory, disks: env.disks, compact: false, glow: glow(for: .mem))
        case .net:
            NetBox(network: env.network, compact: false, glow: glow(for: .net))
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
