import Foundation
import Darwin
import IOKit

final class SystemStatsProvider: ObservableObject {
    @Published var currentDate: Date = Date()
    @Published var cpuUsage: Double = 0
    @Published var thermalState: ProcessInfo.ThermalState = .nominal
    @Published var ramUsage: Double = 0
    @Published var networkIn: Double = 0
    @Published var networkOut: Double = 0

    private let queue = DispatchQueue(label: "com.local.xeneon.stats", qos: .utility)
    private var timers: [DispatchSourceTimer] = []

    // CPU differential state
    private var prevCPUTicks: [(user: Int32, system: Int32, idle: Int32, nice: Int32)] = []

    // Network differential state
    private var prevNetBytes: (inBytes: UInt64, outBytes: UInt64, time: Date) = (0, 0, Date())

    func startPolling() {
        scheduleTimer(interval: 1.0) { [weak self] in self?.updateClock() }
        scheduleTimer(interval: 2.0) { [weak self] in self?.sampleCPU(); self?.sampleThermal() }
        scheduleTimer(interval: 5.0) { [weak self] in self?.sampleRAM() }
        scheduleTimer(interval: 2.0) { [weak self] in self?.sampleNetwork() }
    }

    private func scheduleTimer(interval: Double, handler: @escaping () -> Void) {
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now(), repeating: interval)
        timer.setEventHandler(handler: handler)
        timer.resume()
        timers.append(timer)
    }

    // MARK: - Clock

    private func updateClock() {
        let now = Date()
        DispatchQueue.main.async { self.currentDate = now }
    }

    // MARK: - CPU

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
        var totalUsed: Double = 0
        var totalAll: Double = 0

        for i in 0..<Int(numCPUs) {
            let user   = Int32(info[i * stride + Int(CPU_STATE_USER)])
            let system = Int32(info[i * stride + Int(CPU_STATE_SYSTEM)])
            let idle   = Int32(info[i * stride + Int(CPU_STATE_IDLE)])
            let nice   = Int32(info[i * stride + Int(CPU_STATE_NICE)])

            if prevCPUTicks.count > i {
                let dUser   = Double(UInt32(bitPattern: user)   &- UInt32(bitPattern: prevCPUTicks[i].user))
                let dSystem = Double(UInt32(bitPattern: system) &- UInt32(bitPattern: prevCPUTicks[i].system))
                let dIdle   = Double(UInt32(bitPattern: idle)   &- UInt32(bitPattern: prevCPUTicks[i].idle))
                let dNice   = Double(UInt32(bitPattern: nice)   &- UInt32(bitPattern: prevCPUTicks[i].nice))
                let dTotal  = dUser + dSystem + dIdle + dNice
                totalUsed += dUser + dSystem + dNice
                totalAll  += dTotal
                prevCPUTicks[i] = (user, system, idle, nice)
            } else {
                prevCPUTicks.append((user, system, idle, nice))
            }
        }

        let pct = totalAll > 0 ? (totalUsed / totalAll) * 100.0 : 0
        DispatchQueue.main.async { self.cpuUsage = pct }
    }

    // MARK: - Thermal State

    private func sampleThermal() {
        let state = ProcessInfo.processInfo.thermalState
        DispatchQueue.main.async { self.thermalState = state }
    }

    // MARK: - RAM

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
        let used = UInt64(stats.active_count + stats.wire_count) * pageSize
        let total = ProcessInfo.processInfo.physicalMemory
        let pct = Double(used) / Double(total) * 100.0
        DispatchQueue.main.async { self.ramUsage = pct }
    }

    // MARK: - Network

    private func sampleNetwork() {
        var ifap: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifap) == 0 else { return }
        defer { freeifaddrs(ifap) }

        var totalIn: UInt64 = 0
        var totalOut: UInt64 = 0
        var cursor = ifap

        while let addr = cursor {
            let name = String(cString: addr.pointee.ifa_name)
            if name != "lo0",
               addr.pointee.ifa_addr?.pointee.sa_family == UInt8(AF_LINK),
               let data = addr.pointee.ifa_data {
                let ifdata = data.load(as: if_data.self)
                totalIn  += UInt64(ifdata.ifi_ibytes)
                totalOut += UInt64(ifdata.ifi_obytes)
            }
            cursor = addr.pointee.ifa_next
        }

        let now = Date()
        let dt = now.timeIntervalSince(prevNetBytes.time)
        if dt > 0 && (prevNetBytes.inBytes > 0 || prevNetBytes.outBytes > 0) {
            let inRate  = Double(totalIn  &- prevNetBytes.inBytes)  / dt
            let outRate = Double(totalOut &- prevNetBytes.outBytes) / dt
            DispatchQueue.main.async {
                self.networkIn  = max(0, inRate)
                self.networkOut = max(0, outRate)
            }
        }
        prevNetBytes = (totalIn, totalOut, now)
    }
}
