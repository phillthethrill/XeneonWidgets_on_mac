import Combine
import Foundation
import SwiftUI
import XeneonWidgetsCore

@MainActor
final class AlertMonitor: ObservableObject {
    @Published private(set) var highlightedBox: BoxID?
    @Published private(set) var highlightOpacity: Double = 1

    private let state: DashboardState
    private let cpu: CPUProvider
    private let memory: MemoryProvider
    private let disks: DiskProvider
    private let power: PowerProvider
    private var engine = AlertEngine()
    private var cancellable: AnyCancellable?
    private var highlightClearWork: DispatchWorkItem?

    init(
        state: DashboardState,
        cpu: CPUProvider,
        memory: MemoryProvider,
        disks: DiskProvider,
        power: PowerProvider
    ) {
        self.state = state
        self.cpu = cpu
        self.memory = memory
        self.disks = disks
        self.power = power
    }

    func start() {
        cancellable = Publishers.Merge4(
            cpu.objectWillChange,
            memory.objectWillChange,
            disks.objectWillChange,
            power.objectWillChange
        )
        .throttle(for: .seconds(1), scheduler: DispatchQueue.main, latest: true)
        .sink { [weak self] _ in
            self?.evaluate()
        }
        evaluate()
    }

    func stop() {
        cancellable?.cancel()
        cancellable = nil
        highlightClearWork?.cancel()
        highlightClearWork = nil
    }

    func handleChipTap(_ alert: XeneonWidgetsCore.Alert) {
        if !Self.preset(state.preset, contains: alert.box, layouts: state.layouts) {
            state.preset = Self.presetContaining(alert.box, layouts: state.layouts)
        }
        flash(alert.box)
    }

    static func glowColor(for box: BoxID, alerts: [XeneonWidgetsCore.Alert], theme: Theme) -> Color? {
        let matching = alerts.filter { $0.box == box }
        guard let top = matching.min(by: { levelRank($0.level) < levelRank($1.level) }) else {
            return nil
        }
        return theme.color(top.level)
    }

    private func evaluate() {
        if AppLaunch.previewAlerts { return }
        let battery = power.battery.map { ($0.percent, $0.isCharging) }
        let inputs = AlertInputs(
            cpuPercent: cpu.total,
            memoryPressure: memory.pressure,
            disks: disks.volumes.map { ($0.name, $0.percent) },
            thermal: cpu.thermal,
            battery: battery,
            now: Date()
        )
        let next = engine.evaluate(inputs)
        if next != state.alerts {
            state.alerts = next
        }
    }

    private func flash(_ box: BoxID) {
        highlightClearWork?.cancel()
        highlightedBox = box
        highlightOpacity = 0.35
        withAnimation(.easeInOut(duration: 0.6)) {
            highlightOpacity = 1
        }
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.highlightedBox == box else { return }
            self.highlightedBox = nil
            self.highlightOpacity = 1
        }
        highlightClearWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: work)
    }

    private static func preset(_ preset: Preset, contains box: BoxID, layouts: [Preset: LayoutSpec]) -> Bool {
        let spec = layouts[preset] ?? LayoutSpec.default(for: preset)
        return spec.visible.contains { $0.id == box }
    }

    private static func presetContaining(_ box: BoxID, layouts: [Preset: LayoutSpec]) -> Preset {
        let order: [Preset] = [.overview, .focusCPU, .focusProcesses]
        return order.first { preset($0, contains: box, layouts: layouts) } ?? .overview
    }

    private static func levelRank(_ level: StateLevel) -> Int {
        switch level {
        case .crit: return 0
        case .warn: return 1
        case .ok: return 2
        }
    }
}
