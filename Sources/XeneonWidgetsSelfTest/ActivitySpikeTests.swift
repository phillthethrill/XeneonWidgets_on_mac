import Foundation
import XeneonWidgetsCore

func runActivitySpikeTests() {
    expect(
        !ActivitySpike.detected(cpuNow: 40, cpuThen: 20, downRate: 0),
        "20-point CPU rise is not a spike"
    )
    expect(
        ActivitySpike.detected(cpuNow: 50, cpuThen: 20, downRate: 0),
        "30-point CPU rise is a spike"
    )
    expect(
        ActivitySpike.detected(cpuNow: 51, cpuThen: 20, downRate: 0),
        "31-point CPU rise is a spike"
    )
    expect(
        !ActivitySpike.detected(cpuNow: 10, cpuThen: 50, downRate: 0),
        "CPU drop is not a spike"
    )
    expect(
        !ActivitySpike.detected(cpuNow: 10, cpuThen: 10, downRate: 5_000_000),
        "exactly 5 MB/s down is not a spike"
    )
    expect(
        ActivitySpike.detected(cpuNow: 10, cpuThen: 10, downRate: 5_000_001),
        "just over 5 MB/s down is a spike"
    )
    expect(
        ActivitySpike.detected(cpuNow: 50, cpuThen: 20, downRate: 6_000_000),
        "either condition is enough"
    )
}
