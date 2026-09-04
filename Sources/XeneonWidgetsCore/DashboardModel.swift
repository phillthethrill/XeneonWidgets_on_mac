public enum Preset: String, CaseIterable, Codable, Sendable {
    case overview, focusCPU, focusProcesses, ambient

    public var title: String {
        switch self {
        case .overview: return "Overview"
        case .focusCPU: return "Focus CPU"
        case .focusProcesses: return "Focus Processes"
        case .ambient: return "Ambient"
        }
    }

    public var index: Int {
        Self.allCases.firstIndex(of: self) ?? 0
    }

    public var next: Preset {
        let all = Self.allCases
        return all[(index + 1) % all.count]
    }

    public var previous: Preset {
        let all = Self.allCases
        return all[(index + all.count - 1) % all.count]
    }
}

public enum BoxID: String, CaseIterable, Codable, Sendable {
    case cpu, mem, net, proc, gpu, battery, clock

    public var title: String { rawValue }

    public var displayName: String {
        switch self {
        case .cpu: return "CPU"
        case .mem: return "Memory"
        case .net: return "Network"
        case .proc: return "Processes"
        case .gpu: return "GPU"
        case .battery: return "Battery"
        case .clock: return "Clock"
        }
    }
}

public enum TimeRange: Int, CaseIterable, Codable, Sendable {
    case oneMinute = 60
    case fiveMinutes = 300
    case fifteenMinutes = 900
    case oneHour = 3600

    public var label: String {
        switch self {
        case .oneMinute: return "1 min"
        case .fiveMinutes: return "5 min"
        case .fifteenMinutes: return "15 min"
        case .oneHour: return "1 h"
        }
    }

    public func sampleCount(at interval: SamplingInterval) -> Int {
        max(2, Int((Double(rawValue) / interval.rawValue).rounded()))
    }
}

public enum SamplingInterval: Double, CaseIterable, Codable, Sendable {
    case half = 0.5
    case one = 1
    case two = 2
    case five = 5

    public var label: String {
        switch self {
        case .half: return "0.5 s sampling"
        case .one: return "1 s sampling"
        case .two: return "2 s sampling"
        case .five: return "5 s sampling"
        }
    }

    public var menuLabel: String {
        switch self {
        case .half: return "0.5 s"
        case .one: return "1 s"
        case .two: return "2 s"
        case .five: return "5 s"
        }
    }

    public var historyCapacity: Int {
        Int((3600.0 / rawValue).rounded())
    }
}
