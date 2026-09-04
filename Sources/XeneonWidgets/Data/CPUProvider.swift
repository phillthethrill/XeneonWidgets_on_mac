import Combine
import Darwin
import Foundation
import IOKit
import XeneonWidgetsCore

struct GPUStats: Equatable {
    var utilization: Double
    var memoryUsedBytes: UInt64
    /// GPU-specific total when the registry provides one. `0` when `hasRealTotal` is false.
    /// Part B should render used-only (`4.2 GB`) when `hasRealTotal` is false — do not treat this as system RAM.
    var memoryTotalBytes: UInt64
    var hasRealTotal: Bool
    var source: String
}

final class CPUProvider: ObservableObject, SampledProvider {
    @Published private(set) var total: Double = 0
    @Published private(set) var perCore: [Double] = []
    @Published private(set) var totalHistory: RingBuffer<Double>
    @Published private(set) var coreHistories: [RingBuffer<Double>]
    @Published private(set) var loadAverage: (one: Double, five: Double, fifteen: Double) = (0, 0, 0)
    @Published private(set) var thermal: ThermalLevel = .nominal
    @Published private(set) var gpu: GPUStats? = nil
    @Published private(set) var gpuHistory: RingBuffer<Double>

    let cpuModel: String
    let performanceCoreIndices: [Int]
    let efficiencyCoreIndices: [Int]
    let coreCount: Int

    var coreConfigLabel: String {
        CPUMath.coreConfigLabel(
            performance: performanceCoreIndices.count,
            efficiency: efficiencyCoreIndices.count
        )
    }

    var perCoreFrequencyAvailable: Bool { false }

    private var previousTicks: [StatsMath.CPUTicks] = []
    private var thermalObserver: NSObjectProtocol?

    init(historyCapacity: Int) {
        self.totalHistory = RingBuffer(capacity: historyCapacity)
        self.gpuHistory = RingBuffer(capacity: historyCapacity)

        let logical = sysctlInt("hw.logicalcpu") ?? ProcessInfo.processInfo.processorCount
        let resolvedCount = max(logical, 1)
        self.coreCount = resolvedCount
        self.coreHistories = (0..<resolvedCount).map { _ in RingBuffer(capacity: historyCapacity) }

        let performanceCount = sysctlInt("hw.perflevel0.logicalcpu") ?? resolvedCount
        let efficiencyCount = sysctlInt("hw.perflevel1.logicalcpu") ?? 0
        let groups = CPUMath.coreGroups(
            logicalCount: resolvedCount,
            performanceCount: performanceCount,
            efficiencyCount: efficiencyCount
        )
        self.performanceCoreIndices = groups.performance
        self.efficiencyCoreIndices = groups.efficiency
        self.cpuModel = sysctlString("machdep.cpu.brand_string") ?? "Unknown"

        let initialThermal = ThermalLevel(ProcessInfo.processInfo.thermalState)
        self.thermal = initialThermal
        self.thermalObserver = NotificationCenter.default.addObserver(
            forName: ProcessInfo.thermalStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.thermal = ThermalLevel(ProcessInfo.processInfo.thermalState)
        }
    }

    deinit {
        if let thermalObserver {
            NotificationCenter.default.removeObserver(thermalObserver)
        }
    }

    func sample(at _: Date, interval _: SamplingInterval) {
        let ticks = readCPUTicks()
        let perCoreValues: [Double]?
        let totalValue: Double?
        if let ticks {
            perCoreValues = CPUMath.perCoreUsage(current: ticks, previous: previousTicks)
            if let perCoreValues {
                totalValue = StatsMath.cpuUsagePercent(current: ticks, previous: previousTicks)
                    ?? CPUMath.average(perCoreValues)
            } else {
                totalValue = nil
            }
            previousTicks = ticks
        } else {
            perCoreValues = nil
            totalValue = nil
        }

        let load = readLoadAverage()
        let thermalLevel = ThermalLevel(ProcessInfo.processInfo.thermalState)
        let gpuStats = readGPU()

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if let perCoreValues, let totalValue {
                self.total = totalValue
                self.perCore = perCoreValues
                self.totalHistory.append(totalValue)
                self.appendCoreSamples(perCoreValues)
            }
            if let load {
                self.loadAverage = load
            }
            self.thermal = thermalLevel
            self.gpu = gpuStats
            if let gpuStats {
                self.gpuHistory.append(gpuStats.utilization)
            }
        }
    }

    func historyCapacityChanged(to capacity: Int) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.totalHistory.resize(capacity: capacity)
            self.gpuHistory.resize(capacity: capacity)
            var histories = self.coreHistories
            for index in histories.indices {
                histories[index].resize(capacity: capacity)
            }
            self.coreHistories = histories
        }
    }

    private func appendCoreSamples(_ values: [Double]) {
        let capacity = totalHistory.capacity
        if coreHistories.count != values.count {
            coreHistories = values.map { value in
                var buffer = RingBuffer<Double>(capacity: capacity)
                buffer.append(value)
                return buffer
            }
            return
        }
        var histories = coreHistories
        for index in values.indices {
            histories[index].append(values[index])
        }
        coreHistories = histories
    }

    private func readCPUTicks() -> [StatsMath.CPUTicks]? {
        var infoArray: processor_info_array_t?
        var infoCount: mach_msg_type_number_t = 0
        var numCPUs: natural_t = 0

        guard host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &numCPUs,
            &infoArray,
            &infoCount
        ) == KERN_SUCCESS, let info = infoArray else { return nil }

        defer {
            vm_deallocate(
                mach_task_self_,
                vm_address_t(bitPattern: info),
                vm_size_t(infoCount) * vm_size_t(MemoryLayout<integer_t>.size)
            )
        }

        let stride = Int(CPU_STATE_MAX)
        var currentTicks: [StatsMath.CPUTicks] = []
        currentTicks.reserveCapacity(Int(numCPUs))

        for i in 0..<Int(numCPUs) {
            currentTicks.append(
                StatsMath.CPUTicks(
                    user: Int32(info[i * stride + Int(CPU_STATE_USER)]),
                    system: Int32(info[i * stride + Int(CPU_STATE_SYSTEM)]),
                    idle: Int32(info[i * stride + Int(CPU_STATE_IDLE)]),
                    nice: Int32(info[i * stride + Int(CPU_STATE_NICE)])
                )
            )
        }
        return currentTicks
    }

    private func readLoadAverage() -> (one: Double, five: Double, fifteen: Double)? {
        var loads = [Double](repeating: 0, count: 3)
        guard getloadavg(&loads, 3) == 3 else { return nil }
        return (loads[0], loads[1], loads[2])
    }

    private func readGPU() -> GPUStats? {
        guard let matching = IOServiceMatching("IOAccelerator") else { return nil }
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else {
            return nil
        }
        defer { IOObjectRelease(iterator) }

        while true {
            let service = IOIteratorNext(iterator)
            guard service != 0 else { break }
            defer { IOObjectRelease(service) }
            if let stats = gpuStats(from: service) {
                return stats
            }
        }
        return nil
    }

    private func gpuStats(from service: io_service_t) -> GPUStats? {
        guard let raw = IORegistryEntryCreateCFProperty(
            service,
            "PerformanceStatistics" as CFString,
            kCFAllocatorDefault,
            0
        ) else { return nil }
        let value = raw.takeRetainedValue()
        guard let stats = value as? [String: Any],
              let utilization = stats["Device Utilization %"] as? NSNumber else {
            return nil
        }
        let memoryUsed: UInt64
        if let memory = stats["In use system memory"] as? NSNumber {
            memoryUsed = memory.uint64Value
        } else {
            memoryUsed = 0
        }
        let total = gpuMemoryTotal(from: stats, used: memoryUsed)
        return GPUStats(
            utilization: utilization.doubleValue,
            memoryUsedBytes: memoryUsed,
            memoryTotalBytes: total ?? 0,
            hasRealTotal: total != nil,
            source: "IOKit perf stats"
        )
    }

    /// Registry GPU total only — never `physicalMemory`. Used + free is accepted as a real total.
    private func gpuMemoryTotal(from stats: [String: Any], used: UInt64) -> UInt64? {
        if let total = uint64(from: stats["vramTotalBytes"]) ?? uint64(from: stats["VRAM,total"]) {
            return total
        }
        if let free = uint64(from: stats["vramFreeBytes"]) {
            return used + free
        }
        return nil
    }

    private func uint64(from value: Any?) -> UInt64? {
        switch value {
        case let number as NSNumber:
            return number.uint64Value
        case let value as UInt64:
            return value
        case let value as Int64:
            return value >= 0 ? UInt64(value) : nil
        case let value as Int:
            return value >= 0 ? UInt64(value) : nil
        default:
            return nil
        }
    }
}

private func sysctlInt(_ name: String) -> Int? {
    var value: Int32 = 0
    var size = MemoryLayout<Int32>.size
    guard sysctlbyname(name, &value, &size, nil, 0) == 0 else { return nil }
    return Int(value)
}

private func sysctlString(_ name: String) -> String? {
    var size = 0
    guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return nil }
    var buffer = [CChar](repeating: 0, count: size)
    guard sysctlbyname(name, &buffer, &size, nil, 0) == 0 else { return nil }
    return String(cString: buffer)
}
