import Foundation
import Darwin
import IOKit
import XeneonWidgetsCore

final class SystemStatsProvider: ObservableObject {
    @Published var currentDate: Date = Date()
    @Published var cpuUsage: Double = 0
    @Published var thermalState: ProcessInfo.ThermalState = .nominal
    @Published var ramUsage: Double = 0
    @Published var networkIn: Double = 0
    @Published var networkOut: Double = 0

    private let queue = DispatchQueue(label: "com.local.xeneon.stats", qos: .utility)
    private var timers: [DispatchSourceTimer] = []
    private var isPolling = false

    private var prevCPUTicks: [StatsMath.CPUTicks] = []
    private var prevNetBytes: (inBytes: UInt64, outBytes: UInt64, time: Date) = (0, 0, Date())

    func startPolling() {
        guard !isPolling else { return }
        isPolling = true
        scheduleTimer(interval: 1.0) { [weak self] in self?.updateClock() }
        scheduleTimer(interval: 2.0) { [weak self] in self?.sampleCPU(); self?.sampleThermal() }
        scheduleTimer(interval: 5.0) { [weak self] in self?.sampleRAM() }
        scheduleTimer(interval: 2.0) { [weak self] in self?.sampleNetwork() }
    }

    func stopPolling() {
        timers.forEach { $0.cancel() }
        timers.removeAll()
        isPolling = false
    }

    deinit {
        stopPolling()
    }

    private func scheduleTimer(interval: Double, handler: @escaping () -> Void) {
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now(), repeating: interval)
        timer.setEventHandler(handler: handler)
        timer.resume()
        timers.append(timer)
    }

    private func updateClock() {
        let now = Date()
        DispatchQueue.main.async { self.currentDate = now }
    }

    private func sampleCPU() {
        var infoArray: processor_info_array_t?
        var infoCount: mach_msg_type_number_t = 0
        var numCPUs: natural_t = 0

        guard host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &numCPUs,
            &infoArray,
            &infoCount
        ) == KERN_SUCCESS, let info = infoArray else { return }

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

        if let pct = StatsMath.cpuUsagePercent(current: currentTicks, previous: prevCPUTicks) {
            DispatchQueue.main.async { self.cpuUsage = pct }
        }
        prevCPUTicks = currentTicks
    }

    private func sampleThermal() {
        let state = ProcessInfo.processInfo.thermalState
        DispatchQueue.main.async { self.thermalState = state }
    }

    private func sampleRAM() {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size
        )
        let kr = withUnsafeMutablePointer(to: &stats) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard kr == KERN_SUCCESS else { return }

        let pageSize = UInt64(vm_kernel_page_size)
        let pct = StatsMath.ramUsagePercent(
            activePages: UInt64(stats.active_count),
            wiredPages: UInt64(stats.wire_count),
            compressedPages: UInt64(stats.compressor_page_count),
            pageSize: pageSize,
            totalBytes: ProcessInfo.processInfo.physicalMemory
        )
        DispatchQueue.main.async { self.ramUsage = pct }
    }

    private func sampleNetwork() {
        var ifap: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifap) == 0 else { return }
        defer { freeifaddrs(ifap) }

        var totalIn: UInt64 = 0
        var totalOut: UInt64 = 0
        var cursor = ifap

        while let addr = cursor {
            let name = String(cString: addr.pointee.ifa_name)
            if StatsMath.isDataInterface(name),
               addr.pointee.ifa_addr?.pointee.sa_family == UInt8(AF_LINK),
               let data = addr.pointee.ifa_data {
                let ifdata = data.load(as: if_data.self)
                totalIn += UInt64(ifdata.ifi_ibytes)
                totalOut += UInt64(ifdata.ifi_obytes)
            }
            cursor = addr.pointee.ifa_next
        }

        let now = Date()
        let dt = now.timeIntervalSince(prevNetBytes.time)
        if let rates = StatsMath.networkRates(
            currentIn: totalIn,
            currentOut: totalOut,
            previousIn: prevNetBytes.inBytes,
            previousOut: prevNetBytes.outBytes,
            interval: dt
        ) {
            DispatchQueue.main.async {
                self.networkIn = rates.download
                self.networkOut = rates.upload
            }
        }
        prevNetBytes = (totalIn, totalOut, now)
    }
}