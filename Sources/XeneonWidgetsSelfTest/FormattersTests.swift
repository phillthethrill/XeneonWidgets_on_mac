import Foundation
import XeneonWidgetsCore

func runFormattersTests() {
    runStateLevelTests()

    expectEqual(Formatters.percent(34.4), "34%", "percent rounds")
    expectEqual(Formatters.percent1(31.62), "31.6%", "percent1 one decimal")
    expectEqual(Formatters.gigabytes(12_884_901_888), "12.0 GB", "gigabytes default decimals")
    expectEqual(Formatters.gigabytes(12_884_901_888, decimals: 2), "12.00 GB", "gigabytes two decimals")
    expectEqual(
        Formatters.gpuMemory(usedBytes: 12_884_901_888, totalBytes: 36 * 1_073_741_824, hasRealTotal: true),
        "12.0 / 36 GB",
        "gpuMemory used / total when registry has a real total"
    )
    expectEqual(
        Formatters.gpuMemory(usedBytes: 12_884_901_888, totalBytes: 0, hasRealTotal: false),
        "12.0 GB",
        "gpuMemory used-only when total is unknown"
    )

    let gb = UInt64(1_073_741_824)
    expectEqual(Formatters.capacity(612 * gb), "612 GB", "capacity under 1000 GB")
    expectEqual(Formatters.capacity(999 * gb), "999 GB", "999 GB stays in GB")
    expectEqual(Formatters.capacity(1000 * gb), "1000 GB", "1000 GB stays in GB; TB only at ≥ 1024 GB")
    expectEqual(Formatters.capacity(1024 * gb), "1.00 TB", "1024 GB is 1.00 TB")
    let onePointEightSixTB = UInt64((1.86 * 1024 * 1024 * 1024 * 1024).rounded())
    expectEqual(Formatters.capacity(onePointEightSixTB), "1.86 TB", "capacity in TB")

    expectEqual(Formatters.megabytesPerSecond(12_400_000), "12.4", "MB/s number only")

    let mb = UInt64(1_048_576)
    expectEqual(Formatters.totalBytes(812 * mb), "812 MB", "totalBytes MB")
    expectEqual(Formatters.totalBytes(UInt64((3.1 * Double(gb)).rounded())), "3.1 GB", "totalBytes GB")
    let tb = UInt64(1_099_511_627_776)
    expectEqual(Formatters.totalBytes(UInt64((1.2 * Double(tb)).rounded())), "1.2 TB", "totalBytes TB")

    // 3d 14h 22m is 310_920 s (comment's 311_940 is 3d 14h 39m)
    expectEqual(Formatters.uptime(310_920), "up 3d 14h 22m", "uptime days")
    expectEqual(Formatters.uptime(14 * 3600 + 22 * 60), "up 14h 22m", "uptime under one day")
    expectEqual(Formatters.uptime(22 * 60), "up 22m", "uptime under one hour")

    expectEqual(Formatters.age(134), "2m 14s", "age minutes and seconds")
    expectEqual(Formatters.age(2460), "41m", "age whole minutes")
    expectEqual(Formatters.age(7800), "2h 10m", "age hours")
    expectEqual(Formatters.age(42), "42s", "age seconds")

    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
    calendar.locale = Locale(identifier: "en_GB")
    let date = DateComponents(
        calendar: calendar,
        year: 2025,
        month: 9,
        day: 4,
        hour: 14,
        minute: 32,
        second: 7
    ).date!
    expectEqual(Formatters.clockHM(date, calendar: calendar), "14:32", "clockHM")
    expectEqual(Formatters.clockSeconds(date, calendar: calendar), "07", "clockSeconds")
    expectEqual(Formatters.shortDate(date, calendar: calendar), "Thu 4 Sep", "shortDate")
    expectEqual(Formatters.longDate(date, calendar: calendar), "Thursday, 4 September", "longDate")
    expectEqual(Formatters.isoWeek(date), "W36", "isoWeek")

    expectEqual(Formatters.minutesAsClock(161), "2:41", "minutesAsClock")
    expectEqual(Formatters.watts(18.43), "18.4 W", "watts")
    expectEqual(Formatters.loadAverage(3.2149), "3.21", "loadAverage")
}

private func runStateLevelTests() {
    expectEqual(Threshold.cpu.level(49), .ok, "cpu below lo")
    expectEqual(Threshold.cpu.level(50), .warn, "cpu at lo")
    expectEqual(Threshold.cpu.level(79), .warn, "cpu below hi")
    expectEqual(Threshold.cpu.level(80), .crit, "cpu at hi")
    expectEqual(Threshold.memory.lo, 70, "memory lo")
    expectEqual(Threshold.memory.hi, 90, "memory hi")
    expectEqual(Threshold.disk.lo, 80, "disk lo")
    expectEqual(Threshold.disk.hi, 90, "disk hi")
    expectEqual(Threshold.process.lo, 10, "process lo")
    expectEqual(Threshold.process.hi, 25, "process hi")
    expectEqual(Threshold.ping.lo, 50, "ping lo")
    expectEqual(Threshold.ping.hi, 150, "ping hi")

    expectEqual(ThermalLevel(.nominal).stateLevel, .ok, "thermal nominal")
    expectEqual(ThermalLevel(.fair).stateLevel, .warn, "thermal fair")
    expectEqual(ThermalLevel(.serious).stateLevel, .crit, "thermal serious")
    expectEqual(ThermalLevel(.critical).stateLevel, .crit, "thermal critical")
    expectEqual(ThermalLevel.nominal.label, "Nominal", "thermal nominal label")
    expectEqual(ThermalLevel.fair.label, "Fair", "thermal fair label")
    expectEqual(ThermalLevel.serious.label, "Serious", "thermal serious label")
    expectEqual(ThermalLevel.critical.label, "Critical", "thermal critical label")

    expectEqual(MemoryPressureLevel.normal.stateLevel, .ok, "pressure normal")
    expectEqual(MemoryPressureLevel.warning.stateLevel, .warn, "pressure warning")
    expectEqual(MemoryPressureLevel.critical.stateLevel, .crit, "pressure critical")
    expectEqual(MemoryPressureLevel.normal.label, "Normal", "pressure normal label")
    expectEqual(MemoryPressureLevel.warning.label, "Warning", "pressure warning label")
    expectEqual(MemoryPressureLevel.critical.label, "Critical", "pressure critical label")
}
