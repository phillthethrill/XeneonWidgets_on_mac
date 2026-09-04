import Combine
import Darwin
import Foundation
import IOKit
import XeneonWidgetsCore

struct DiskIO: Equatable {
    var readRate: Double
    var writeRate: Double
    var readHistory: RingBuffer<Double>
    var writeHistory: RingBuffer<Double>
}

final class DiskProvider: ObservableObject, SampledProvider {
    @Published private(set) var volumes: [VolumeInfo] = []
    @Published private(set) var io: [String: DiskIO] = [:]

    var volumeCount: Int { volumes.count }

    private var historyCapacity: Int
    private var lastVolumeEnumeration: Date?
    private var lastIOSampleDate: Date?
    private var previousIO: [String: DiskIOSample] = [:]
    private var probes: [VolumeProbe] = []

    private struct VolumeProbe {
        var id: String
        var isInternal: Bool
        var isLocal: Bool
        var bsdName: String?
    }

    init(historyCapacity: Int) {
        self.historyCapacity = max(historyCapacity, 1)
    }

    func sample(at now: Date, interval: SamplingInterval) {
        var enumerated: [VolumeInfo]?
        if lastVolumeEnumeration == nil || now.timeIntervalSince(lastVolumeEnumeration!) >= 5 {
            let snapshot = Self.enumerateVolumes()
            probes = snapshot.probes
            enumerated = snapshot.volumes
            lastVolumeEnumeration = now
        }

        let driverStats = Self.collectDriverStats()
        let dt: TimeInterval
        if let last = lastIOSampleDate {
            dt = now.timeIntervalSince(last)
        } else {
            dt = interval.rawValue
        }
        lastIOSampleDate = now

        let liveIDs = Set(probes.map(\.id))
        previousIO = previousIO.filter { liveIDs.contains($0.key) }

        var ratesByID: [String: (read: Double, write: Double)] = [:]
        for probe in probes {
            guard probe.isLocal else { continue }
            guard let current = Self.sample(for: probe, stats: driverStats) else { continue }
            if let previous = previousIO[probe.id],
               let rates = DiskMath.rates(current: current, previous: previous, interval: dt) {
                ratesByID[probe.id] = (rates.read / 1_000_000.0, rates.write / 1_000_000.0)
            }
            previousIO[probe.id] = current
        }

        let capacity = historyCapacity
        DispatchQueue.main.async {
            if let enumerated {
                self.volumes = enumerated
            }
            var next = self.io.filter { liveIDs.contains($0.key) }
            for (id, rates) in ratesByID {
                var entry = next[id] ?? DiskIO(
                    readRate: 0,
                    writeRate: 0,
                    readHistory: RingBuffer(capacity: capacity),
                    writeHistory: RingBuffer(capacity: capacity)
                )
                entry.readRate = rates.read
                entry.writeRate = rates.write
                entry.readHistory.append(rates.read)
                entry.writeHistory.append(rates.write)
                next[id] = entry
            }
            self.io = next
        }
    }

    func historyCapacityChanged(to capacity: Int) {
        let next = max(capacity, 1)
        historyCapacity = next
        DispatchQueue.main.async {
            var updated = self.io
            for key in updated.keys {
                guard var entry = updated[key] else { continue }
                entry.readHistory.resize(capacity: next)
                entry.writeHistory.resize(capacity: next)
                updated[key] = entry
            }
            self.io = updated
        }
    }

    private static func sample(for probe: VolumeProbe, stats: DriverStats) -> DiskIOSample? {
        if let bsdName = probe.bsdName {
            let whole = DiskMath.wholeDisk(fromBSDName: bsdName)
            if let match = stats.byBSD[whole] ?? stats.byBSD[bsdName] {
                return match
            }
        }
        return nil
    }

    private static func enumerateVolumes() -> (volumes: [VolumeInfo], probes: [VolumeProbe]) {
        let keys: [URLResourceKey] = [
            .volumeNameKey,
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeAvailableCapacityKey,
            .volumeIsInternalKey,
            .volumeIsRemovableKey,
            .volumeIsLocalKey,
            .volumeLocalizedFormatDescriptionKey,
        ]
        let urls = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: keys,
            options: [.skipHiddenVolumes]
        ) ?? []

        var rows: [(info: VolumeInfo, isInternal: Bool)] = []
        var probes: [VolumeProbe] = []
        rows.reserveCapacity(urls.count)

        for url in urls {
            let values: URLResourceValues
            do {
                values = try url.resourceValues(forKeys: Set(keys))
            } catch {
                continue
            }
            let total = UInt64(max(values.volumeTotalCapacity ?? 0, 0))
            guard total > 0 else { continue }

            let available: UInt64
            if let important = values.volumeAvailableCapacityForImportantUsage {
                available = UInt64(max(important, 0))
            } else {
                available = UInt64(max(values.volumeAvailableCapacity ?? 0, 0))
            }
            let used = total > available ? total - available : 0
            let percent = Double(used) / Double(total) * 100
            let isInternal = values.volumeIsInternal ?? false
            let isRemovable = values.volumeIsRemovable ?? false
            let isLocal = values.volumeIsLocal ?? true
            let name = values.volumeName ?? url.lastPathComponent
            let id = url.path
            let bsd = bsdName(forMountPath: id)
            let info = VolumeInfo(
                id: id,
                name: name,
                kind: DiskMath.kindLabel(
                    format: values.volumeLocalizedFormatDescription,
                    isInternal: isInternal,
                    isRemovable: isRemovable,
                    isLocal: isLocal
                ),
                usedBytes: used,
                totalBytes: total,
                percent: percent,
                bsdName: bsd
            )
            rows.append((info, isInternal))
            probes.append(VolumeProbe(id: id, isInternal: isInternal, isLocal: isLocal, bsdName: bsd))
        }

        rows.sort { lhs, rhs in
            if lhs.isInternal != rhs.isInternal {
                return lhs.isInternal && !rhs.isInternal
            }
            return lhs.info.name.localizedStandardCompare(rhs.info.name) == .orderedAscending
        }
        let volumes = rows.map(\.info)
        let order = Dictionary(uniqueKeysWithValues: volumes.enumerated().map { ($0.element.id, $0.offset) })
        probes.sort { (order[$0.id] ?? .max) < (order[$1.id] ?? .max) }
        return (volumes, probes)
    }

    private static func bsdName(forMountPath path: String) -> String? {
        var fs = statfs()
        let ok = path.withCString { statfs($0, &fs) == 0 }
        guard ok else { return nil }
        let device = withUnsafeBytes(of: fs.f_mntfromname) { raw -> String? in
            guard let base = raw.baseAddress?.assumingMemoryBound(to: CChar.self) else { return nil }
            return String(cString: base)
        }
        guard var name = device, !name.isEmpty else { return nil }
        if name.hasPrefix("/dev/") {
            name = String(name.dropFirst(5))
        }
        return name.hasPrefix("disk") ? name : nil
    }

    private struct DriverStats {
        var byBSD: [String: DiskIOSample]
    }

    private static func collectDriverStats() -> DriverStats {
        var byBSD: [String: DiskIOSample] = [:]

        var iterator: io_iterator_t = 0
        let matching = IOServiceMatching("IOBlockStorageDriver")
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else {
            return DriverStats(byBSD: byBSD)
        }
        defer { _ = IOObjectRelease(iterator) }

        while true {
            let service = IOIteratorNext(iterator)
            if service == 0 { break }
            defer { _ = IOObjectRelease(service) }

            guard let sample = statistics(for: service) else { continue }
            if let bsd = childMediaBSDName(for: service) {
                byBSD[bsd] = sample
                let whole = DiskMath.wholeDisk(fromBSDName: bsd)
                if whole != bsd {
                    byBSD[whole] = sample
                }
            }
        }
        return DriverStats(byBSD: byBSD)
    }

    private static func statistics(for service: io_object_t) -> DiskIOSample? {
        var unmanaged: Unmanaged<CFMutableDictionary>?
        let kr = IORegistryEntryCreateCFProperties(service, &unmanaged, kCFAllocatorDefault, 0)
        guard kr == KERN_SUCCESS, let unmanaged else { return nil }
        guard let dict = unmanaged.takeRetainedValue() as? [String: Any],
              let stats = dict["Statistics"] as? [String: Any] else {
            return nil
        }
        return DiskIOSample(
            readBytes: uint64(from: stats["Bytes (Read)"]),
            writeBytes: uint64(from: stats["Bytes (Write)"])
        )
    }

    private static func childMediaBSDName(for service: io_object_t) -> String? {
        var iterator: io_iterator_t = 0
        guard IORegistryEntryGetChildIterator(service, kIOServicePlane, &iterator) == KERN_SUCCESS else {
            return nil
        }
        defer { _ = IOObjectRelease(iterator) }

        while true {
            let child = IOIteratorNext(iterator)
            if child == 0 { break }
            defer { _ = IOObjectRelease(child) }
            if IOObjectConformsTo(child, "IOMedia") != 0,
               let name = stringProperty("BSD Name", service: child) {
                return name
            }
        }
        return nil
    }

    private static func stringProperty(_ key: String, service: io_object_t) -> String? {
        guard let unmanaged = IORegistryEntryCreateCFProperty(
            service,
            key as CFString,
            kCFAllocatorDefault,
            0
        ) else {
            return nil
        }
        return unmanaged.takeRetainedValue() as? String
    }

    private static func uint64(from value: Any?) -> UInt64 {
        switch value {
        case let number as NSNumber:
            return number.uint64Value
        case let value as UInt64:
            return value
        case let value as Int64:
            return UInt64(max(value, 0))
        case let value as Int:
            return UInt64(max(value, 0))
        default:
            return 0
        }
    }
}
