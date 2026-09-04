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
    private var storedLayouts: [Preset: LayoutSpec]

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

        storedLayouts = layoutStore.load()
        layouts = Self.mergedLayouts(stored: storedLayouts)
    }

    func layout(for preset: Preset) -> LayoutSpec {
        storedLayouts[preset] ?? LayoutSpec.default(for: preset)
    }

    func updateLayout(_ spec: LayoutSpec, for preset: Preset) {
        storedLayouts[preset] = spec
        layouts = Self.mergedLayouts(stored: storedLayouts)
        layoutStore.save(storedLayouts)
    }

    func resetLayout(for preset: Preset) {
        storedLayouts.removeValue(forKey: preset)
        layouts = Self.mergedLayouts(stored: storedLayouts)
        layoutStore.save(storedLayouts)
    }

    private static func mergedLayouts(stored: [Preset: LayoutSpec]) -> [Preset: LayoutSpec] {
        var merged: [Preset: LayoutSpec] = [:]
        for item in Preset.allCases {
            merged[item] = stored[item] ?? LayoutSpec.default(for: item)
        }
        return merged
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
