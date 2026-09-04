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

    private var cancellables = Set<AnyCancellable>()

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

        if let preview = AppLaunch.previewPreset {
            state.preset = preview
        }
    }

    func start() {
        sampler.start()
        clock.start()
    }

    func stop() {
        sampler.stop()
        clock.stop()
    }

    func setSampling(_ interval: SamplingInterval) {
        state.sampling = interval
        sampler.setInterval(interval)
    }
}
