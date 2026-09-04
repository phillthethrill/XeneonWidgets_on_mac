import Foundation
import XeneonWidgetsCore

func runMemoryMathTests() {
    let pageSize: UInt64 = 4_096
    let breakdown = MemoryMath.breakdown(
        internalPages: 1_000,
        purgeablePages: 200,
        externalPages: 100,
        wiredPages: 50,
        compressorPages: 25,
        freePages: 400,
        pageSize: pageSize,
        totalBytes: 10_000_000
    )
    expectEqual(breakdown.app, 800 * pageSize, "app is internal minus purgeable")
    expectEqual(breakdown.wired, 50 * pageSize, "wired pages to bytes")
    expectEqual(breakdown.compressed, 25 * pageSize, "compressor pages to bytes")
    expectEqual(breakdown.cached, 300 * pageSize, "cached is purgeable plus external")
    expectEqual(breakdown.free, 400 * pageSize, "free pages to bytes")
    expectEqual(breakdown.total, 10_000_000, "total is the supplied physical memory")
    expectEqual(breakdown.used, breakdown.app + breakdown.wired + breakdown.compressed, "used is app + wired + compressed")
    expectClose(breakdown.usedPercent, 35.84, tol: 0.001, "usedPercent is used/total*100")

    let saturated = MemoryMath.breakdown(
        internalPages: 50,
        purgeablePages: 80,
        externalPages: 10,
        wiredPages: 0,
        compressorPages: 0,
        freePages: 0,
        pageSize: pageSize,
        totalBytes: 0
    )
    expectEqual(saturated.app, 0, "app saturates when purgeable exceeds internal")
    expectEqual(saturated.cached, 90 * pageSize, "cached still sums purgeable and external")
    expectEqual(saturated.usedPercent, 0, "usedPercent is 0 when total is 0")

    expectEqual(
        MemoryMath.swapLabel(usedBytes: 1_288_490_189, totalBytes: 4_294_967_296),
        "swap 1.2 / 4 GB",
        "swapLabel uses one decimal for used and integral total"
    )

    let used19_2 = UInt64((19.2 * 1_073_741_824.0).rounded())
    let total36 = 36 * UInt64(1_073_741_824)
    expectEqual(
        MemoryMath.memValueLabel(usedBytes: used19_2, totalBytes: total36),
        "19.2 / 36 GB",
        "memValueLabel matches the overview hero"
    )

    expectEqual(MemoryMath.pressureLevel(fromSysctl: 1), .normal, "sysctl 1 is normal")
    expectEqual(MemoryMath.pressureLevel(fromSysctl: 2), .warning, "sysctl 2 is warning")
    expectEqual(MemoryMath.pressureLevel(fromSysctl: 4), .critical, "sysctl 4 is critical")
    expectNil(MemoryMath.pressureLevel(fromSysctl: 0), "unknown sysctl keeps last (nil)")
    expectNil(MemoryMath.pressureLevel(fromSysctl: 3), "unmapped sysctl keeps last (nil)")
}
