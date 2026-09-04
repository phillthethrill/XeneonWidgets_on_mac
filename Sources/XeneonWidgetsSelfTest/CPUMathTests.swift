import XeneonWidgetsCore

func runCPUMathTests() {
    let previous = [
        StatsMath.CPUTicks(user: 100, system: 50, idle: 800, nice: 50),
        StatsMath.CPUTicks(user: 200, system: 100, idle: 700, nice: 0),
    ]
    let current = [
        StatsMath.CPUTicks(user: 120, system: 60, idle: 860, nice: 60),
        StatsMath.CPUTicks(user: 200, system: 100, idle: 700, nice: 0),
    ]
    if let usage = CPUMath.perCoreUsage(current: current, previous: previous) {
        expectEqual(usage.count, 2, "per-core usage count")
        expectClose(usage[0], 40, "core 0 busy % from tick deltas")
        expectClose(usage[1], 0, "core 1 zero total delta is 0")
    } else {
        expect(false, "per-core usage should be available with matching baselines")
    }

    expectNil(
        CPUMath.perCoreUsage(current: current, previous: []),
        "per-core usage is nil when previous is empty"
    )
    expectNil(
        CPUMath.perCoreUsage(
            current: [StatsMath.CPUTicks(user: 1, system: 0, idle: 0, nice: 0)],
            previous: previous
        ),
        "per-core usage is nil when counts differ"
    )

    let groups16 = CPUMath.coreGroups(logicalCount: 16, performanceCount: 12, efficiencyCount: 4)
    expectEqual(groups16.performance, Array(4...15), "E-cores take lowest indices; P is 4…15")
    expectEqual(groups16.efficiency, Array(0...3), "E-cores occupy 0…3")

    let groupsIntel = CPUMath.coreGroups(logicalCount: 8, performanceCount: 8, efficiencyCount: 0)
    expectEqual(groupsIntel.performance, Array(0...7), "Intel: all cores are P")
    expectEqual(groupsIntel.efficiency, [], "Intel: no E-cores")

    expectEqual(CPUMath.coreConfigLabel(performance: 12, efficiency: 4), "12P + 4E", "Apple Silicon label")
    expectEqual(CPUMath.coreConfigLabel(performance: 8, efficiency: 0), "8 cores", "Intel label")

    expectClose(CPUMath.average([40, 0]), 20, "average of two cores")
    expectClose(CPUMath.average([]), 0, "average of empty is 0")
}
