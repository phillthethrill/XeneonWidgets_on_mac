import Foundation
import XeneonWidgetsCore

func runAlertEngineTests() {
    let t0 = Date(timeIntervalSince1970: 1_000_000)
    var engine = AlertEngine()

    func inputs(
        cpu: Double = 40,
        memory: MemoryPressureLevel = .normal,
        disks: [(name: String, percent: Double)] = [],
        thermal: ThermalLevel = .nominal,
        battery: (percent: Double, isCharging: Bool)? = nil,
        at time: Date
    ) -> AlertInputs {
        AlertInputs(
            cpuPercent: cpu,
            memoryPressure: memory,
            disks: disks,
            thermal: thermal,
            battery: battery,
            now: time
        )
    }

    expectEqual(engine.evaluate(inputs(cpu: 97, at: t0)).count, 0, "CPU hold not started as alert")
    expectEqual(engine.evaluate(inputs(cpu: 97, at: t0.addingTimeInterval(29))).count, 0, "CPU hold under 30 s")

    let fired = engine.evaluate(inputs(cpu: 97, at: t0.addingTimeInterval(30)))
    expectEqual(fired.count, 1, "CPU fires at 30 s")
    expectEqual(fired.first?.id, "cpu", "CPU id")
    expectEqual(fired.first?.level, .crit, "CPU crit")
    expectEqual(fired.first?.text, "CPU · 97% for 30 s", "CPU text")
    expectEqual(fired.first?.box, .cpu, "CPU box")
    expectEqual(fired.first?.since, t0.addingTimeInterval(30), "CPU since is first fire time")

    let held = engine.evaluate(inputs(cpu: 97, at: t0.addingTimeInterval(45)))
    expectEqual(held.first?.since, t0.addingTimeInterval(30), "CPU since preserved")

    expectEqual(engine.evaluate(inputs(cpu: 40, at: t0.addingTimeInterval(50))).count, 0, "CPU cleared")

    expectEqual(engine.evaluate(inputs(cpu: 97, at: t0.addingTimeInterval(51))).count, 0, "CPU hold restarts")
    expectEqual(engine.evaluate(inputs(cpu: 97, at: t0.addingTimeInterval(80))).count, 0, "CPU hold still restarting")
    let refired = engine.evaluate(inputs(cpu: 97, at: t0.addingTimeInterval(81)))
    expectEqual(refired.count, 1, "CPU refires after new 30 s hold")
    expectEqual(refired.first?.since, t0.addingTimeInterval(81), "CPU since restarts")

    var memoryEngine = AlertEngine()
    let warning = memoryEngine.evaluate(inputs(memory: .warning, at: t0))
    expectEqual(warning.count, 1, "memory warning")
    expectEqual(warning.first?.id, "memory", "memory id")
    expectEqual(warning.first?.level, .warn, "memory warn level")
    expectEqual(warning.first?.text, "Memory pressure · Warning", "memory warning text")
    expectEqual(warning.first?.box, .mem, "memory box")

    let critical = memoryEngine.evaluate(inputs(memory: .critical, at: t0.addingTimeInterval(10)))
    expectEqual(critical.first?.id, "memory", "memory id stable")
    expectEqual(critical.first?.level, .crit, "memory crit replaces warn")
    expectEqual(critical.first?.text, "Memory pressure · Critical", "memory critical text")
    expectEqual(critical.first?.since, t0, "memory since preserved")

    var diskEngine = AlertEngine()
    let disk = diskEngine.evaluate(inputs(disks: [("Macintosh HD", 95.4)], at: t0))
    expectEqual(disk.first?.id, "disk:Macintosh HD", "disk id")
    expectEqual(disk.first?.level, .warn, "disk warn")
    expectEqual(disk.first?.text, "Macintosh HD · 95% full", "disk text")
    expectEqual(disk.first?.box, .mem, "disk box")

    var thermalEngine = AlertEngine()
    let thermal = thermalEngine.evaluate(inputs(thermal: .serious, at: t0))
    expectEqual(thermal.first?.id, "thermal", "thermal id")
    expectEqual(thermal.first?.level, .crit, "thermal crit")
    expectEqual(thermal.first?.text, "Thermal · Serious", "thermal text")
    expectEqual(thermal.first?.box, .cpu, "thermal box")

    var batteryEngine = AlertEngine()
    let low = batteryEngine.evaluate(inputs(battery: (8, false), at: t0))
    expectEqual(low.first?.id, "battery", "battery id")
    expectEqual(low.first?.level, .crit, "battery crit")
    expectEqual(low.first?.text, "Battery · 8%", "battery text")
    expectEqual(low.first?.box, .battery, "battery box")
    expectEqual(batteryEngine.evaluate(inputs(battery: (8, true), at: t0.addingTimeInterval(1))).count, 0, "charging clears battery")

    var orderEngine = AlertEngine()
    let mixed = orderEngine.evaluate(
        inputs(
            memory: .warning,
            disks: [("Macintosh HD", 95)],
            thermal: .serious,
            at: t0
        )
    )
    expectEqual(mixed.map(\.level), [.crit, .warn, .warn], "crit before warn")
    expectEqual(mixed.first?.id, "thermal", "crit first")
}
