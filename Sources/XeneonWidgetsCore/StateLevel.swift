import Foundation

public enum StateLevel: Equatable, Sendable {
    case ok, warn, crit
}

public struct Threshold: Equatable, Sendable {
    public let lo: Double
    public let hi: Double

    public init(lo: Double, hi: Double) {
        self.lo = lo
        self.hi = hi
    }

    public func level(_ pct: Double) -> StateLevel {
        if pct < lo { return .ok }
        if pct < hi { return .warn }
        return .crit
    }

    public static let cpu = Threshold(lo: 50, hi: 80)
    public static let memory = Threshold(lo: 70, hi: 90)
    public static let disk = Threshold(lo: 80, hi: 90)
    public static let process = Threshold(lo: 10, hi: 25)
    public static let ping = Threshold(lo: 50, hi: 150)
}

public enum ThermalLevel: Equatable, Sendable {
    case nominal, fair, serious, critical

    public init(_ state: ProcessInfo.ThermalState) {
        switch state {
        case .nominal: self = .nominal
        case .fair: self = .fair
        case .serious: self = .serious
        case .critical: self = .critical
        @unknown default: self = .nominal
        }
    }

    public var stateLevel: StateLevel {
        switch self {
        case .nominal: return .ok
        case .fair: return .warn
        case .serious, .critical: return .crit
        }
    }

    public var label: String {
        switch self {
        case .nominal: return "Nominal"
        case .fair: return "Fair"
        case .serious: return "Serious"
        case .critical: return "Critical"
        }
    }
}

public enum MemoryPressureLevel: Equatable, Sendable {
    case normal, warning, critical

    public var stateLevel: StateLevel {
        switch self {
        case .normal: return .ok
        case .warning: return .warn
        case .critical: return .crit
        }
    }

    public var label: String {
        switch self {
        case .normal: return "Normal"
        case .warning: return "Warning"
        case .critical: return "Critical"
        }
    }
}
