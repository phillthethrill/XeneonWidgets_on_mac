import Foundation

public enum CPUMath {
    /// Per-core busy % from tick deltas (user+system+nice)/(total). nil when counts differ or previous empty. Cores with zero total delta → 0.
    public static func perCoreUsage(current: [StatsMath.CPUTicks], previous: [StatsMath.CPUTicks]) -> [Double]? {
        guard !previous.isEmpty, current.count == previous.count else { return nil }

        return zip(current, previous).map { currentTicks, previousTicks in
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
            guard dTotal > 0 else { return 0 }
            return ((dUser + dSystem + dNice) / dTotal) * 100.0
        }
    }

    /// Apple Silicon: efficiency cores occupy the LOWEST logical indices. Returns (pIndices, eIndices) for `logicalCount` cores given perflevel counts; when eCount == 0 (Intel) all cores are P.
    public static func coreGroups(logicalCount: Int, performanceCount _: Int, efficiencyCount: Int) -> (performance: [Int], efficiency: [Int]) {
        guard logicalCount > 0 else { return ([], []) }
        if efficiencyCount <= 0 {
            return (Array(0..<logicalCount), [])
        }
        let eCount = min(efficiencyCount, logicalCount)
        return (Array(eCount..<logicalCount), Array(0..<eCount))
    }

    public static func average(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    /// "12P + 4E" ; Intel (e == 0) → "16 cores"
    public static func coreConfigLabel(performance: Int, efficiency: Int) -> String {
        if efficiency == 0 {
            return "\(performance) cores"
        }
        return "\(performance)P + \(efficiency)E"
    }
}
