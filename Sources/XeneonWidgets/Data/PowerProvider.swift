import Foundation
import IOKit
import IOKit.ps
import XeneonWidgetsCore

final class PowerProvider: ObservableObject, SampledProvider {
    @Published private(set) var battery: BatteryInfo? = nil

    func sample(at _: Date, interval _: SamplingInterval) {
        let snapshot = Self.readBattery()
        DispatchQueue.main.async { [weak self] in
            self?.battery = snapshot
        }
    }

    func historyCapacityChanged(to _: Int) {}

    private static func readBattery() -> BatteryInfo? {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else {
            return nil
        }
        guard let list = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() else {
            return nil
        }

        for source in list as NSArray {
            guard let unmanaged = IOPSGetPowerSourceDescription(blob, source as CFTypeRef) else {
                continue
            }
            guard let desc = unmanaged.takeUnretainedValue() as? [String: Any] else {
                continue
            }
            let type = desc[kIOPSTypeKey] as? String
            guard type == kIOPSInternalBatteryType else { continue }
            let isPresent = boolValue(desc, kIOPSIsPresentKey) ?? true
            guard isPresent else { continue }
            guard let current = intValue(desc, kIOPSCurrentCapacityKey) else { continue }
            let maxCapacity = intValue(desc, kIOPSMaxCapacityKey) ?? 100
            guard maxCapacity > 0 else { continue }

            let isCharging = boolValue(desc, kIOPSIsChargingKey) ?? false
            let timeKey = isCharging ? kIOPSTimeToFullChargeKey : kIOPSTimeToEmptyKey
            let rawMinutes = intValue(desc, timeKey)
            let minutesRemaining: Int?
            if let rawMinutes, rawMinutes >= 0 {
                minutesRemaining = rawMinutes
            } else {
                minutesRemaining = nil
            }

            let smart = readSmartBattery()
            return BatteryInfo(
                percent: Double(current) / Double(maxCapacity) * 100.0,
                isCharging: isCharging,
                isPresent: isPresent,
                minutesRemaining: minutesRemaining,
                watts: smart.watts,
                cycleCount: smart.cycleCount
            )
        }
        return nil
    }

    private static func readSmartBattery() -> (watts: Double?, cycleCount: Int?) {
        guard let matching = IOServiceMatching("AppleSmartBattery") else {
            return (nil, nil)
        }
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else {
            return (nil, nil)
        }
        defer { IOObjectRelease(iterator) }

        let service = IOIteratorNext(iterator)
        guard service != IO_OBJECT_NULL else { return (nil, nil) }
        defer { IOObjectRelease(service) }

        let amperage = registryInt(service, "Amperage")
        let voltage = registryInt(service, "Voltage")
        let cycleCount = registryInt(service, "CycleCount")
        let watts: Double?
        if let amperage, let voltage {
            watts = PowerMath.watts(amperageMilliamps: amperage, voltageMillivolts: voltage)
        } else {
            watts = nil
        }
        return (watts, cycleCount)
    }

    private static func registryInt(_ service: io_service_t, _ key: String) -> Int? {
        guard let unmanaged = IORegistryEntryCreateCFProperty(
            service,
            key as CFString,
            kCFAllocatorDefault,
            0
        ) else {
            return nil
        }
        let value = unmanaged.takeRetainedValue()
        return (value as? NSNumber)?.intValue
    }

    private static func intValue(_ dict: [String: Any], _ key: String) -> Int? {
        let any = dict[key]
        if let n = any as? Int { return n }
        if let n = any as? NSNumber { return n.intValue }
        return nil
    }

    private static func boolValue(_ dict: [String: Any], _ key: String) -> Bool? {
        let any = dict[key]
        if let b = any as? Bool { return b }
        if let n = any as? NSNumber { return n.boolValue }
        return nil
    }
}
