import Foundation

public enum ActivitySpike: Sendable {
    public static let cpuJumpPoints: Double = 30
    public static let downRateBytesPerSecond: Double = 5_000_000

    /// CPU jump of ≥ 30 points versus the sample from 10 s ago, or download > 5 MB/s.
    public static func detected(cpuNow: Double, cpuThen: Double, downRate: Double) -> Bool {
        (cpuNow - cpuThen) >= cpuJumpPoints || downRate > downRateBytesPerSecond
    }
}
