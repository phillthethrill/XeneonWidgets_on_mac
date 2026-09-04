import Foundation
import XeneonWidgetsCore

func runPowerMathTests() {
    expectClose(
        PowerMath.watts(amperageMilliamps: -1200, voltageMillivolts: 15_300),
        18.36,
        "watts from signed mA × mV"
    )
    expectClose(
        PowerMath.watts(amperageMilliamps: 1200, voltageMillivolts: 15_300),
        18.36,
        "watts uses absolute amperage"
    )

    expectEqual(
        PowerMath.remainingLabel(minutes: 161, watts: 18.36),
        "2:41 · 18.4 W",
        "remainingLabel minutes and watts"
    )
    expectEqual(
        PowerMath.remainingLabel(minutes: nil, watts: 18.36),
        "— · 18.4 W",
        "remainingLabel unknown minutes"
    )
    expectEqual(
        PowerMath.remainingLabel(minutes: 161, watts: nil),
        "2:41",
        "remainingLabel watts missing"
    )
    expectEqual(
        PowerMath.remainingLabel(minutes: nil, watts: nil),
        "",
        "remainingLabel both unknown"
    )
}
