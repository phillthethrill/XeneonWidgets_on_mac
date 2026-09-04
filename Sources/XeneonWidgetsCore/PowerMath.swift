import Foundation

public struct BatteryInfo: Equatable, Sendable {
    public var percent: Double
    public var isCharging: Bool
    public var isPresent: Bool
    public var minutesRemaining: Int?
    public var watts: Double?
    public var cycleCount: Int?

    public init(
        percent: Double,
        isCharging: Bool,
        isPresent: Bool,
        minutesRemaining: Int?,
        watts: Double?,
        cycleCount: Int?
    ) {
        self.percent = percent
        self.isCharging = isCharging
        self.isPresent = isPresent
        self.minutesRemaining = minutesRemaining
        self.watts = watts
        self.cycleCount = cycleCount
    }
}

public enum PowerMath {
    public static func watts(amperageMilliamps: Int, voltageMillivolts: Int) -> Double {
        abs(Double(amperageMilliamps) * Double(voltageMillivolts)) / 1_000_000.0
    }

    public static func remainingLabel(minutes: Int?, watts: Double?) -> String {
        switch (minutes, watts) {
        case (nil, nil):
            return ""
        case (let minutes?, nil):
            return Formatters.minutesAsClock(minutes)
        case (nil, let watts?):
            return "— · \(Formatters.watts(watts))"
        case (let minutes?, let watts?):
            return "\(Formatters.minutesAsClock(minutes)) · \(Formatters.watts(watts))"
        }
    }
}
