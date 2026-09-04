import Combine
import Foundation
import XeneonWidgetsCore

@MainActor
final class GlanceController: ObservableObject {
    @Published private(set) var driftOffset: CGSize = .zero

    private let state: DashboardState
    private let cpu: CPUProvider
    private let network: NetworkProvider
    private var idleTimer: Timer?
    private var driftTimer: Timer?
    private var previousPreset: Preset?
    private var cpuTenSecondsAgo: Double = 0
    private var glanceCancellable: AnyCancellable?

    init(state: DashboardState, cpu: CPUProvider, network: NetworkProvider) {
        self.state = state
        self.cpu = cpu
        self.network = network
        cpuTenSecondsAgo = cpu.total
    }

    func start() {
        stop()
        cpuTenSecondsAgo = cpu.total
        let idle = Timer(timeInterval: 10, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
        RunLoop.main.add(idle, forMode: .common)
        idleTimer = idle
        glanceCancellable = state.$glance
            .removeDuplicates()
            .sink { [weak self] isGlance in
                self?.handleGlanceFlag(isGlance)
            }
        if state.glance {
            startDrift()
        }
    }

    func stop() {
        idleTimer?.invalidate()
        idleTimer = nil
        driftTimer?.invalidate()
        driftTimer = nil
        glanceCancellable?.cancel()
        glanceCancellable = nil
        driftOffset = .zero
    }

    private func tick() {
        let cpuNow = cpu.total
        if state.glance {
            if !state.glanceEnabled
                || ActivitySpike.detected(cpuNow: cpuNow, cpuThen: cpuTenSecondsAgo, downRate: network.downRate) {
                exitGlance()
            }
        } else {
            if state.glanceEnabled && state.idleMinutes > 0 {
                let idle = Date().timeIntervalSince(state.lastActivity)
                if idle >= Double(state.idleMinutes) * 60 {
                    enterGlance()
                }
            }
        }
        cpuTenSecondsAgo = cpuNow
    }

    private func enterGlance() {
        guard !state.glance else { return }
        previousPreset = state.preset
        cpuTenSecondsAgo = cpu.total
        state.glance = true
        state.preset = .ambient
    }

    private func exitGlance() {
        guard state.glance else { return }
        state.glance = false
    }

    private func handleGlanceFlag(_ isGlance: Bool) {
        if isGlance {
            startDrift()
        } else {
            restorePresetIfNeeded()
            stopDrift()
        }
    }

    private func restorePresetIfNeeded() {
        if state.preset == .ambient, let previousPreset {
            state.preset = previousPreset
        }
        previousPreset = nil
    }

    private func startDrift() {
        guard driftTimer == nil else { return }
        let drift = Timer(timeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.nudgeDrift()
            }
        }
        RunLoop.main.add(drift, forMode: .common)
        driftTimer = drift
    }

    private func stopDrift() {
        driftTimer?.invalidate()
        driftTimer = nil
        driftOffset = .zero
    }

    private func nudgeDrift() {
        driftOffset = CGSize(
            width: CGFloat.random(in: -4...4),
            height: CGFloat.random(in: -4...4)
        )
    }
}
