import Foundation

public enum StatsMath {
    public struct CPUTicks: Equatable, Sendable {
        public let user: Int32
        public let system: Int32
        public let idle: Int32
        public let nice: Int32

        public init(user: Int32, system: Int32, idle: Int32, nice: Int32) {
            self.user = user
            self.system = system
            self.idle = idle
            self.nice = nice
        }
    }

    public static func cpuUsagePercent(current: [CPUTicks], previous: [CPUTicks]) -> Double? {
        guard !current.isEmpty, current.count == previous.count else { return nil }

        var totalUsed: Double = 0
        var totalAll: Double = 0

        for (currentTicks, previousTicks) in zip(current, previous) {
            let dUser = Double(
                UInt32(bitPattern: currentTicks.user) &- UInt32(bitPattern: previousTicks.user)
            )
            let dSystem = Double(
                UInt32(bitPattern: currentTicks.system) &- UInt32(bitPattern: previousTicks.system)
            )
            let dIdle = Double(
                UInt32(bitPattern: currentTicks.idle) &- UInt32(bitPattern: previousTicks.idle)
            )
            let dNice = Double(
                UInt32(bitPattern: currentTicks.nice) &- UInt32(bitPattern: previousTicks.nice)
            )
            let dTotal = dUser + dSystem + dIdle + dNice
            totalUsed += dUser + dSystem + dNice
            totalAll += dTotal
        }

        guard totalAll > 0 else { return nil }
        return (totalUsed / totalAll) * 100.0
    }

    public static func ramUsagePercent(
        activePages: UInt64,
        wiredPages: UInt64,
        compressedPages: UInt64,
        pageSize: UInt64,
        totalBytes: UInt64
    ) -> Double {
        guard totalBytes > 0 else { return 0 }
        let usedBytes = (activePages + wiredPages + compressedPages) * pageSize
        return Double(usedBytes) / Double(totalBytes) * 100.0
    }

    public static func isDataInterface(_ name: String) -> Bool {
        name.hasPrefix("en")
    }

    public static func networkRates(
        currentIn: UInt64,
        currentOut: UInt64,
        previousIn: UInt64,
        previousOut: UInt64,
        interval: TimeInterval
    ) -> (download: Double, upload: Double)? {
        guard interval > 0, previousIn > 0 || previousOut > 0 else { return nil }

        let download = max(0, Double(currentIn &- previousIn) / interval)
        let upload = max(0, Double(currentOut &- previousOut) / interval)
        return (download, upload)
    }
}