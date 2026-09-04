import Combine
import Foundation
import XeneonWidgetsCore

@MainActor
final class DashboardEnvironment {
    let settings: SettingsStore
    let layoutStore: LayoutStore
    let state: DashboardState
    let sampler: Sampler
    let cpu: CPUProvider
    let memory: MemoryProvider
    let disks: DiskProvider
    let network: NetworkProvider
    let processes: ProcessProvider
    let power: PowerProvider
    let clock: ClockProvider
    let alertMonitor: AlertMonitor
    let glance: GlanceController

    private var cancellables = Set<AnyCancellable>()
    private var didApplyPreviewPID = false

    init() {
        let settings = SettingsStore()
        let layoutStore = LayoutStore()
        let capacity = settings.sampling.historyCapacity

        self.settings = settings
        self.layoutStore = layoutStore
        self.state = DashboardState(settings: settings, layoutStore: layoutStore)
        self.sampler = Sampler(interval: settings.sampling)
        self.cpu = CPUProvider(historyCapacity: capacity)
        self.memory = MemoryProvider(historyCapacity: capacity)
        self.disks = DiskProvider(historyCapacity: capacity)
        self.network = NetworkProvider(
            historyCapacity: capacity,
            selection: NetworkSelection(rawValue: settings.networkSelection),
            pingHost: settings.pingHost
        )
        self.processes = ProcessProvider()
        self.power = PowerProvider()
        self.clock = ClockProvider()
        self.alertMonitor = AlertMonitor(
            state: state,
            cpu: cpu,
            memory: memory,
            disks: disks,
            power: power
        )
        self.glance = GlanceController(state: state, cpu: cpu, network: network)

        sampler.add(cpu)
        sampler.add(memory)
        sampler.add(disks)
        sampler.add(network)
        sampler.add(processes)
        sampler.add(power)

        network.$selection
            .dropFirst()
            .removeDuplicates()
            .sink { [settings] selection in
                settings.networkSelection = selection.rawValue
            }
            .store(in: &cancellables)

        if AppLaunch.isPreview, let preview = AppLaunch.previewPreset {
            state.preset = preview
        }

        if AppLaunch.previewAlerts {
            Self.injectPreviewAlerts(into: state)
        }

        if AppLaunch.previewSelectPID != nil {
            processes.$processes
                .receive(on: DispatchQueue.main)
                .sink { [weak self] samples in
                    self?.applyPreviewSelectedPID(samples)
                }
                .store(in: &cancellables)
        }
    }

    private func applyPreviewSelectedPID(_ samples: [ProcessSample]) {
        guard !didApplyPreviewPID, !samples.isEmpty,
              let spec = AppLaunch.previewSelectPID else { return }
        let match: ProcessSample?
        if spec == "first" {
            match = samples.first
        } else if let pid = pid_t(spec) {
            match = samples.first(where: { $0.pid == pid })
        } else {
            match = nil
        }
        guard let match else { return }
        didApplyPreviewPID = true
        state.selectedPID = match.pid
        processes.watchedPID = match.pid
    }

    func start() {
        sampler.start()
        clock.start()
        alertMonitor.start()
        glance.start()
    }

    func stop() {
        glance.stop()
        alertMonitor.stop()
        sampler.stop()
        clock.stop()
    }

    private static func injectPreviewAlerts(into state: DashboardState) {
        let now = Date()
        state.alerts = [
            Alert(
                id: "memory",
                level: .crit,
                text: "Pressure critical",
                box: .mem,
                since: now.addingTimeInterval(-134)
            ),
            Alert(
                id: "disk:Macintosh HD",
                level: .warn,
                text: "Macintosh HD 95%",
                box: .mem,
                since: now.addingTimeInterval(-31)
            ),
        ]
    }

    func setSampling(_ interval: SamplingInterval) {
        state.sampling = interval
        sampler.setInterval(interval)
    }
}
