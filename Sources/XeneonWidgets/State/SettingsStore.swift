import Foundation
import XeneonWidgetsCore

final class SettingsStore {
    private enum Key {
        static let sampling = "dashboard.sampling"
        static let preset = "dashboard.preset"
        static let timeRanges = "dashboard.timeRanges"
        static let idleMinutes = "dashboard.idleMinutes"
        static let glanceEnabled = "dashboard.glanceEnabled"
        static let pingHost = "dashboard.pingHost"
        static let networkSelection = "dashboard.networkSelection"
    }

    private let defaults: UserDefaults

    var sampling: SamplingInterval {
        didSet { defaults.set(sampling.rawValue, forKey: Key.sampling) }
    }

    var preset: Preset {
        didSet { defaults.set(preset.rawValue, forKey: Key.preset) }
    }

    var timeRanges: [BoxID: TimeRange] {
        didSet { persistTimeRanges() }
    }

    var idleMinutes: Int {
        didSet { defaults.set(idleMinutes, forKey: Key.idleMinutes) }
    }

    var glanceEnabled: Bool {
        didSet { defaults.set(glanceEnabled, forKey: Key.glanceEnabled) }
    }

    var pingHost: String {
        didSet { defaults.set(pingHost, forKey: Key.pingHost) }
    }

    var networkSelection: String {
        didSet { defaults.set(networkSelection, forKey: Key.networkSelection) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        if let raw = defaults.object(forKey: Key.sampling) as? Double,
           let interval = SamplingInterval(rawValue: raw) {
            sampling = interval
        } else {
            sampling = .one
        }

        if let raw = defaults.string(forKey: Key.preset),
           let value = Preset(rawValue: raw) {
            preset = value
        } else {
            preset = .overview
        }

        timeRanges = Self.decodeTimeRanges(defaults.data(forKey: Key.timeRanges))

        if let stored = defaults.object(forKey: Key.idleMinutes) as? Int {
            idleMinutes = stored
        } else {
            idleMinutes = 10
        }

        if let stored = defaults.object(forKey: Key.glanceEnabled) as? Bool {
            glanceEnabled = stored
        } else {
            glanceEnabled = true
        }

        pingHost = defaults.string(forKey: Key.pingHost) ?? "1.1.1.1"
        networkSelection = defaults.string(forKey: Key.networkSelection) ?? "auto"
    }

    private func persistTimeRanges() {
        let keyed = Dictionary(uniqueKeysWithValues: timeRanges.map { ($0.key.rawValue, $0.value) })
        if let data = try? JSONEncoder().encode(keyed) {
            defaults.set(data, forKey: Key.timeRanges)
        }
    }

    private static func decodeTimeRanges(_ data: Data?) -> [BoxID: TimeRange] {
        guard let data,
              let keyed = try? JSONDecoder().decode([String: TimeRange].self, from: data) else {
            return [:]
        }
        var result: [BoxID: TimeRange] = [:]
        for (raw, range) in keyed {
            if let box = BoxID(rawValue: raw) {
                result[box] = range
            }
        }
        return result
    }
}
