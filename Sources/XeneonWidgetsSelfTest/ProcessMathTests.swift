import Foundation
import XeneonWidgetsCore

func runProcessMathTests() {
    runCPUPercentTests()
    runFilterTests()
    runSortTests()
    runMemLabelTests()
    runSampleIdentityTests()
}

private func runCPUPercentTests() {
    expectClose(
        ProcessMath.cpuPercent(deltaCPUNanoseconds: 500_000_000, deltaWallNanoseconds: 1_000_000_000),
        50,
        "50% when CPU time is half of wall time"
    )
    expectClose(
        ProcessMath.cpuPercent(deltaCPUNanoseconds: 1_000_000_000, deltaWallNanoseconds: 1_000_000_000),
        100,
        "100% when CPU time equals wall time"
    )
    expectClose(
        ProcessMath.cpuPercent(deltaCPUNanoseconds: 0, deltaWallNanoseconds: 1_000_000_000),
        0,
        "0% when no CPU time elapsed"
    )
    expectClose(
        ProcessMath.cpuPercent(deltaCPUNanoseconds: 1_000_000_000, deltaWallNanoseconds: 0),
        0,
        "0% when wall delta is zero"
    )

    let cores = ProcessInfo.processInfo.processorCount
    let oversubscribed = UInt64(cores + 4) * 1_000_000_000
    expectClose(
        ProcessMath.cpuPercent(deltaCPUNanoseconds: oversubscribed, deltaWallNanoseconds: 1_000_000_000),
        Double(100 * cores),
        "clamped to 100 × coreCount"
    )
}

private func runFilterTests() {
    let mine = sample(pid: 10, uid: 501, cpu: 3, isApp: true, isSystem: false, name: "Safari")
    let otherApp = sample(pid: 11, uid: 502, cpu: 12, isApp: true, isSystem: false, name: "Mail")
    let daemon = sample(pid: 12, uid: 501, cpu: 1, isApp: false, isSystem: false, name: "helper")
    let root = sample(pid: 1, uid: 0, cpu: 25, isApp: false, isSystem: true, name: "launchd")
    let all = [mine, otherApp, daemon, root]

    expectEqual(
        ProcessMath.filter(all, by: .all, currentUID: 501).map(\.pid),
        [10, 11, 12, 1],
        "all keeps every process"
    )
    expectEqual(
        ProcessMath.filter(all, by: .apps, currentUID: 501).map(\.pid),
        [10, 11],
        "apps is isApp"
    )
    expectEqual(
        ProcessMath.filter(all, by: .background, currentUID: 501).map(\.pid),
        [12],
        "background is !isApp && !isSystem"
    )
    expectEqual(
        ProcessMath.filter(all, by: .system, currentUID: 501).map(\.pid),
        [1],
        "system is isSystem"
    )
    expectEqual(
        ProcessMath.filter(all, by: .mine, currentUID: 501).map(\.pid),
        [10, 12],
        "mine is uid == currentUID"
    )
    expectEqual(
        ProcessMath.filter(all, by: .highCPU, currentUID: 501).map(\.pid),
        [11, 1],
        "highCPU is cpuPercent >= 10"
    )

    let atThreshold = sample(pid: 99, uid: 501, cpu: 10, isApp: false, isSystem: false, name: "hot")
    expectEqual(
        ProcessMath.filter([atThreshold], by: .highCPU, currentUID: 501).map(\.pid),
        [99],
        "highCPU includes exactly 10%"
    )

    expectEqual(ProcFilter.all.rawValue, "All", "All chip label")
    expectEqual(ProcFilter.apps.rawValue, "Apps", "Apps chip label")
    expectEqual(ProcFilter.background.rawValue, "Background", "Background chip label")
    expectEqual(ProcFilter.system.rawValue, "System", "System chip label")
    expectEqual(ProcFilter.mine.rawValue, "Mine", "Mine chip label")
    expectEqual(ProcFilter.highCPU.rawValue, "High CPU", "High CPU chip label")
}

private func runSortTests() {
    let a = sample(pid: 30, uid: 501, cpu: 5, mem: 100, isApp: true, isSystem: false, name: "zeta")
    let b = sample(pid: 10, uid: 501, cpu: 40, mem: 50, isApp: true, isSystem: false, name: "Alpha")
    let c = sample(pid: 20, uid: 501, cpu: 12, mem: 200, isApp: false, isSystem: false, name: "beta")
    let procs = [a, b, c]

    expectEqual(
        ProcessMath.sort(procs, by: .cpu).map(\.pid),
        [10, 20, 30],
        "cpu sort is descending"
    )
    expectEqual(
        ProcessMath.sort(procs, by: .mem).map(\.pid),
        [20, 30, 10],
        "mem sort is descending"
    )
    expectEqual(
        ProcessMath.sort(procs, by: .pid).map(\.pid),
        [10, 20, 30],
        "pid sort is ascending"
    )
    expectEqual(
        ProcessMath.sort(procs, by: .name).map(\.name),
        ["Alpha", "beta", "zeta"],
        "name sort is case-insensitive ascending"
    )
}

private func runMemLabelTests() {
    let gb = UInt64(1_073_741_824)
    let mb = UInt64(1_048_576)
    expectEqual(ProcessMath.memLabel(UInt64((3.92 * Double(gb)).rounded())), "3.92 GB", "memLabel 3.92 GB")
    expectEqual(ProcessMath.memLabel(512 * mb), "512 MB", "memLabel 512 MB")
    expectEqual(ProcessMath.memLabel(gb), "1.00 GB", "memLabel 1.00 GB at 1 GiB")
    expectEqual(ProcessMath.memLabel(0), "0 MB", "memLabel 0 MB")
}

private func runSampleIdentityTests() {
    let proc = sample(pid: 2210, uid: 501, cpu: 31.6, mem: 4_209_068_749, isApp: true, isSystem: false, name: "Docker")
    expectEqual(proc.id, 2210, "Identifiable id is pid")
}

private func sample(
    pid: pid_t,
    parentPID: pid_t = 1,
    uid: uid_t,
    cpu: Double,
    mem: UInt64 = 0,
    isApp: Bool,
    isSystem: Bool,
    name: String
) -> ProcessSample {
    ProcessSample(
        pid: pid,
        parentPID: parentPID,
        name: name,
        user: "user\(uid)",
        uid: uid,
        path: isApp ? "/Applications/\(name).app/Contents/MacOS/\(name)" : "/usr/bin/\(name)",
        cpuPercent: cpu,
        residentBytes: mem,
        threads: 4,
        openFiles: nil,
        startTime: nil,
        isApp: isApp,
        isSystem: isSystem
    )
}
