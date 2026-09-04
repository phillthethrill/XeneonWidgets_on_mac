import Foundation

public struct Alert: Identifiable, Equatable, Sendable {
    public let id: String
    public let level: StateLevel
    public let text: String
    public let box: BoxID
    public let since: Date

    public init(id: String, level: StateLevel, text: String, box: BoxID, since: Date) {
        self.id = id
        self.level = level
        self.text = text
        self.box = box
        self.since = since
    }
}

public struct AlertRules: Equatable, Sendable {
    public var cpuPercent: Double = 95
    public var cpuHoldSeconds: TimeInterval = 30
    public var diskPercent: Double = 95
    public var batteryPercent: Double = 10

    public init() {}
}

public struct AlertInputs: Sendable {
    public var cpuPercent: Double
    public var memoryPressure: MemoryPressureLevel
    public var disks: [(name: String, percent: Double)]
    public var thermal: ThermalLevel
    public var battery: (percent: Double, isCharging: Bool)?
    public var now: Date

    public init(
        cpuPercent: Double,
        memoryPressure: MemoryPressureLevel,
        disks: [(name: String, percent: Double)],
        thermal: ThermalLevel,
        battery: (percent: Double, isCharging: Bool)?,
        now: Date
    ) {
        self.cpuPercent = cpuPercent
        self.memoryPressure = memoryPressure
        self.disks = disks
        self.thermal = thermal
        self.battery = battery
        self.now = now
    }
}

public struct AlertEngine: Sendable {
    private let rules: AlertRules
    private var cpuHoldStart: Date?
    private var active: [String: Alert] = [:]

    public init(rules: AlertRules = AlertRules()) {
        self.rules = rules
    }

    /// Idempotent per tick. Alerts keep their original `since` while the condition persists and disappear when it ends.
    public mutating func evaluate(_ inputs: AlertInputs) -> [Alert] {
        var next: [Alert] = []

        if inputs.cpuPercent >= rules.cpuPercent {
            if cpuHoldStart == nil {
                cpuHoldStart = inputs.now
            }
            if let start = cpuHoldStart, inputs.now.timeIntervalSince(start) >= rules.cpuHoldSeconds {
                let percent = Int(inputs.cpuPercent.rounded())
                let hold = Int(rules.cpuHoldSeconds.rounded())
                next.append(
                    Alert(
                        id: "cpu",
                        level: .crit,
                        text: "CPU · \(percent)% for \(hold) s",
                        box: .cpu,
                        since: active["cpu"]?.since ?? inputs.now
                    )
                )
            }
        } else {
            cpuHoldStart = nil
        }

        switch inputs.memoryPressure {
        case .normal:
            break
        case .warning, .critical:
            next.append(
                Alert(
                    id: "memory",
                    level: inputs.memoryPressure.stateLevel,
                    text: "Memory pressure · \(inputs.memoryPressure.label)",
                    box: .mem,
                    since: active["memory"]?.since ?? inputs.now
                )
            )
        }

        for disk in inputs.disks where disk.percent >= rules.diskPercent {
            let name = disk.name
            let percent = Int(disk.percent.rounded())
            next.append(
                Alert(
                    id: "disk:\(name)",
                    level: .warn,
                    text: "\(name) · \(percent)% full",
                    box: .mem,
                    since: active["disk:\(name)"]?.since ?? inputs.now
                )
            )
        }

        switch inputs.thermal {
        case .nominal, .fair:
            break
        case .serious, .critical:
            next.append(
                Alert(
                    id: "thermal",
                    level: .crit,
                    text: "Thermal · \(inputs.thermal.label)",
                    box: .cpu,
                    since: active["thermal"]?.since ?? inputs.now
                )
            )
        }

        if let battery = inputs.battery, battery.percent <= rules.batteryPercent, !battery.isCharging {
            let percent = Int(battery.percent.rounded())
            next.append(
                Alert(
                    id: "battery",
                    level: .crit,
                    text: "Battery · \(percent)%",
                    box: .battery,
                    since: active["battery"]?.since ?? inputs.now
                )
            )
        }

        next.sort { lhs, rhs in
            if lhs.level != rhs.level {
                return levelRank(lhs.level) < levelRank(rhs.level)
            }
            return lhs.since < rhs.since
        }
        active = Dictionary(uniqueKeysWithValues: next.map { ($0.id, $0) })
        return next
    }

    private func levelRank(_ level: StateLevel) -> Int {
        switch level {
        case .crit: return 0
        case .warn: return 1
        case .ok: return 2
        }
    }
}
