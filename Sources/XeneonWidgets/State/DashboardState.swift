import Combine
import Darwin
import Foundation
import XeneonWidgetsCore

enum ConfirmAction: Equatable {
    case terminate(pid_t)
    case forceQuit(pid_t)
}

@MainActor
final class DashboardState: ObservableObject {
    private let settings: SettingsStore
    private let layoutStore: LayoutStore

    @Published var preset: Preset {
        didSet { settings.preset = preset }
    }

    @Published private(set) var layouts: [Preset: LayoutSpec]

    @Published var sampling: SamplingInterval {
        didSet { settings.sampling = sampling }
    }

    @Published var editMode: Bool = false
    @Published var alerts: [Alert] = []
    @Published var selectedPID: pid_t? = nil
    @Published var confirm: ConfirmAction? = nil
    @Published var glance: Bool = false
    @Published var isDisplayConnected: Bool = false
    @Published var lastActivity: Date = Date()

    let theme: Theme = .oled

    @Published private var timeRanges: [BoxID: TimeRange] {
        didSet { settings.timeRanges = timeRanges }
    }

    var idleMinutes: Int {
        get { settings.idleMinutes }
        set { settings.idleMinutes = newValue }
    }

    init(settings: SettingsStore, layoutStore: LayoutStore) {
        self.settings = settings
        self.layoutStore = layoutStore
        preset = settings.preset
        sampling = settings.sampling
        timeRanges = settings.timeRanges

        let stored = layoutStore.load()
        var merged: [Preset: LayoutSpec] = [:]
        for item in Preset.allCases {
            merged[item] = stored[item] ?? LayoutSpec.default(for: item)
        }
        layouts = merged
    }

    func layout(for preset: Preset) -> LayoutSpec {
        layouts[preset] ?? LayoutSpec.default(for: preset)
    }

    func updateLayout(_ spec: LayoutSpec, for preset: Preset) {
        layouts[preset] = spec
        layoutStore.save(layouts)
    }

    func resetLayout(for preset: Preset) {
        layouts[preset] = LayoutSpec.default(for: preset)
        layoutStore.save(layouts)
    }

    func timeRange(for box: BoxID) -> TimeRange {
        timeRanges[box] ?? .fiveMinutes
    }

    func setTimeRange(_ range: TimeRange, for box: BoxID) {
        timeRanges[box] = range
    }

    func nextPreset() {
        preset = preset.next
    }

    func previousPreset() {
        preset = preset.previous
    }

    func noteActivity() {
        lastActivity = Date()
        glance = false
    }
}
