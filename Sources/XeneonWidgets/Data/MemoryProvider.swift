import Combine
import Darwin
import Foundation
import XeneonWidgetsCore

final class MemoryProvider: ObservableObject, SampledProvider {
    @Published private(set) var breakdown: MemoryBreakdown
    @Published private(set) var pressure: MemoryPressureLevel = .normal
    @Published private(set) var swapUsed: UInt64 = 0
    @Published private(set) var swapTotal: UInt64 = 0
    @Published private(set) var usedHistory: RingBuffer<Double>

    var totalLabel: String {
        let gb = Double(breakdown.total) / 1_073_741_824.0
        let decimals = gb.rounded() == gb ? 0 : 1
        return "\(Formatters.gigabytes(breakdown.total, decimals: decimals)) unified"
    }

    private var pressureSource: DispatchSourceMemoryPressure?

    init(historyCapacity: Int) {
        let capacity = max(historyCapacity, 1)
        self.breakdown = MemoryBreakdown(
            app: 0,
            wired: 0,
            compressed: 0,
            cached: 0,
            free: 0,
            total: ProcessInfo.processInfo.physicalMemory
        )
        self.usedHistory = RingBuffer(capacity: capacity)
        if let level = Self.readPressureLevel() {
            self.pressure = level
        }
        startPressureMonitor()
    }

    deinit {
        pressureSource?.cancel()
        pressureSource = nil
    }

    func sample(at _: Date, interval _: SamplingInterval) {
        let snapshot = Self.readBreakdown()
        let swap = Self.readSwap()
        let seeded = Self.readPressureLevel()
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.breakdown = snapshot
            self.swapUsed = swap.used
            self.swapTotal = swap.total
            self.usedHistory.append(snapshot.usedPercent)
            if let seeded {
                self.pressure = seeded
            }
        }
    }

    func historyCapacityChanged(to capacity: Int) {
        let next = max(capacity, 1)
        DispatchQueue.main.async {
            self.usedHistory.resize(capacity: next)
        }
    }

    private func startPressureMonitor() {
        let queue = DispatchQueue(label: "com.local.xeneon.memory-pressure", qos: .utility)
        let source = DispatchSource.makeMemoryPressureSource(
            eventMask: [.normal, .warning, .critical],
            queue: queue
        )
        source.setEventHandler { [weak self] in
            let event = source.data
            let level: MemoryPressureLevel
            if event.contains(.critical) {
                level = .critical
            } else if event.contains(.warning) {
                level = .warning
            } else {
                level = .normal
            }
            DispatchQueue.main.async {
                self?.pressure = level
            }
        }
        source.resume()
        pressureSource = source
    }

    private static func readBreakdown() -> MemoryBreakdown {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size
        )
        let kr = withUnsafeMutablePointer(to: &stats) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        let total = ProcessInfo.processInfo.physicalMemory
        guard kr == KERN_SUCCESS else {
            return MemoryBreakdown(app: 0, wired: 0, compressed: 0, cached: 0, free: 0, total: total)
        }
        return MemoryMath.breakdown(
            internalPages: UInt64(stats.internal_page_count),
            purgeablePages: UInt64(stats.purgeable_count),
            externalPages: UInt64(stats.external_page_count),
            wiredPages: UInt64(stats.wire_count),
            compressorPages: UInt64(stats.compressor_page_count),
            freePages: UInt64(stats.free_count),
            pageSize: UInt64(vm_kernel_page_size),
            totalBytes: total
        )
    }

    private static func readPressureLevel() -> MemoryPressureLevel? {
        var level: Int32 = 0
        var size = MemoryLayout<Int32>.size
        let result = sysctlbyname("kern.memorystatus_vm_pressure_level", &level, &size, nil, 0)
        guard result == 0 else { return nil }
        return MemoryMath.pressureLevel(fromSysctl: level)
    }

    private static func readSwap() -> (used: UInt64, total: UInt64) {
        var usage = xsw_usage()
        var size = MemoryLayout<xsw_usage>.size
        let result = sysctlbyname("vm.swapusage", &usage, &size, nil, 0)
        guard result == 0 else { return (0, 0) }
        return (usage.xsu_used, usage.xsu_total)
    }
}
