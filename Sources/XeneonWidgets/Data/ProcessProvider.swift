import AppKit
import Combine
import Darwin
import Foundation
import UniformTypeIdentifiers
import XeneonWidgetsCore

struct ProcessDetail: Equatable {
    var cpuHistory: RingBuffer<Double>
    var memHistory: RingBuffer<Double>
}

final class ProcessProvider: ObservableObject, SampledProvider {
    @Published private(set) var processes: [ProcessSample] = []
    @Published private(set) var processCount: Int = 0
    @Published private(set) var threadCount: Int = 0
    @Published private(set) var detail: ProcessDetail? = nil

    var currentUID: uid_t { getuid() }

    var watchedPID: pid_t? {
        get {
            stateLock.lock()
            defer { stateLock.unlock() }
            return _watchedPID
        }
        set {
            stateLock.lock()
            let changed = _watchedPID != newValue
            _watchedPID = newValue
            stateLock.unlock()
            if changed {
                if Thread.isMainThread {
                    detail = nil
                } else {
                    DispatchQueue.main.async { [weak self] in
                        self?.detail = nil
                    }
                }
            }
        }
    }

    private let stateLock = NSLock()
    private var _watchedPID: pid_t?
    private var iconCache: [pid_t: NSImage] = [:]
    private var runningAppPIDs: Set<pid_t> = []
    private var runningAppNames: [pid_t: String] = [:]

    private var lastSample: Date?
    private var previousCPU: [pid_t: PreviousCPU] = [:]
    private var userCache: [uid_t: String] = [:]
    private var lastWatchedPID: pid_t?
    private var detailCPU = RingBuffer<Double>(capacity: 60)
    private var detailMem = RingBuffer<Double>(capacity: 60)

    private let timebase: mach_timebase_info_data_t = {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        return info
    }()

    init() {
        if Thread.isMainThread {
            refreshRunningApps()
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.refreshRunningApps()
            }
        }
    }

    func sample(at now: Date, interval: SamplingInterval) {
        let minGap = max(interval.rawValue, 1.0)
        if let lastSample, now.timeIntervalSince(lastSample) < minGap {
            return
        }
        lastSample = now

        scheduleRunningAppRefresh()

        stateLock.lock()
        let appPIDs = runningAppPIDs
        let appNames = runningAppNames
        stateLock.unlock()

        let pids = listPIDs()
        var samples: [ProcessSample] = []
        samples.reserveCapacity(pids.count)
        var threads = 0
        var nextCPU: [pid_t: PreviousCPU] = [:]
        nextCPU.reserveCapacity(pids.count)

        let watched = watchedPID
        if watched != lastWatchedPID {
            detailCPU = RingBuffer(capacity: 60)
            detailMem = RingBuffer(capacity: 60)
            lastWatchedPID = watched
        }

        let wallNow = DispatchTime.now().uptimeNanoseconds

        for pid in pids {
            guard let snapshot = readProcess(
                pid: pid,
                watched: watched,
                wallNow: wallNow,
                appPIDs: appPIDs,
                appNames: appNames
            ) else { continue }
            nextCPU[pid] = snapshot.previous
            threads += snapshot.sample.threads
            samples.append(snapshot.sample)
        }

        previousCPU = nextCPU

        var publishedDetail: ProcessDetail?
        if let watched, let match = samples.first(where: { $0.pid == watched }) {
            detailCPU.append(match.cpuPercent)
            detailMem.append(Double(match.residentBytes) / 1_073_741_824.0)
            publishedDetail = ProcessDetail(cpuHistory: detailCPU, memHistory: detailMem)
        }

        let live = Set(samples.map(\.pid))
        stateLock.lock()
        iconCache = iconCache.filter { live.contains($0.key) }
        stateLock.unlock()

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.processes = samples
            self.processCount = samples.count
            self.threadCount = threads
            if self.watchedPID == watched {
                self.detail = publishedDetail
            }
        }
    }

    func historyCapacityChanged(to capacity: Int) {
        guard capacity >= 1 else { return }
        // Detail graphs stay at 60 samples (last 60 s at the 1 Hz process cap).
    }

    func icon(for proc: ProcessSample) -> NSImage {
        stateLock.lock()
        if let cached = iconCache[proc.pid] {
            stateLock.unlock()
            return cached
        }
        stateLock.unlock()

        let image: NSImage
        if let appIcon = NSRunningApplication(processIdentifier: proc.pid)?.icon {
            image = appIcon
        } else if !proc.path.isEmpty {
            image = NSWorkspace.shared.icon(forFile: proc.path)
        } else {
            image = NSWorkspace.shared.icon(for: .unixExecutable)
        }

        stateLock.lock()
        iconCache[proc.pid] = image
        stateLock.unlock()
        return image
    }

    func terminate(_ pid: pid_t) -> Bool {
        kill(pid, SIGTERM) == 0
    }

    func forceQuit(_ pid: pid_t) -> Bool {
        kill(pid, SIGKILL) == 0
    }

    private struct PreviousCPU {
        var startTime: UInt64
        var totalTicks: UInt64
        var wallTime: UInt64
    }

    private struct Snapshot {
        var sample: ProcessSample
        var previous: PreviousCPU
    }

    private func readProcess(
        pid: pid_t,
        watched: pid_t?,
        wallNow: UInt64,
        appPIDs: Set<pid_t>,
        appNames: [pid_t: String]
    ) -> Snapshot? {
        var task = proc_taskinfo()
        let taskSize = Int32(MemoryLayout<proc_taskinfo>.size)
        let taskGot = withUnsafeMutablePointer(to: &task) { ptr in
            proc_pidinfo(pid, PROC_PIDTASKINFO, 0, ptr, taskSize)
        }
        guard taskGot == taskSize else { return nil }

        var bsd = proc_bsdinfo()
        let bsdSize = Int32(MemoryLayout<proc_bsdinfo>.size)
        let bsdGot = withUnsafeMutablePointer(to: &bsd) { ptr in
            proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, ptr, bsdSize)
        }
        guard bsdGot == bsdSize else { return nil }

        let cpuTicks = task.pti_total_user &+ task.pti_total_system
        let cpuNanos = machTicksToNanoseconds(cpuTicks)
        let startTimeTicks = bsd.pbi_start_tvsec
        var cpu = 0.0
        if let previous = previousCPU[pid], previous.startTime == startTimeTicks, wallNow > previous.wallTime {
            let deltaCPU = cpuNanos >= previous.totalTicks ? cpuNanos - previous.totalTicks : 0
            let deltaWall = wallNow - previous.wallTime
            cpu = ProcessMath.cpuPercent(deltaCPUNanoseconds: deltaCPU, deltaWallNanoseconds: deltaWall)
        }

        let path = processPath(pid: pid)
        let isApp = appPIDs.contains(pid) || path.contains(".app/")
        let uid = bsd.pbi_uid
        let isSystem =
            uid == 0
            || path.hasPrefix("/System/")
            || path.hasPrefix("/usr/libexec/")
            || path.hasPrefix("/sbin/")
            || path.hasPrefix("/usr/sbin/")

        var startTime: Date?
        if bsd.pbi_start_tvsec > 0 {
            startTime = Date(
                timeIntervalSince1970: TimeInterval(bsd.pbi_start_tvsec)
                    + TimeInterval(bsd.pbi_start_tvusec) / 1_000_000.0
            )
        }

        let openFiles = watched == pid ? openFileCount(for: pid) : nil
        let name: String
        if let localized = appNames[pid], !localized.isEmpty {
            name = localized
        } else if !path.isEmpty {
            name = URL(fileURLWithPath: path).lastPathComponent
        } else {
            let longName = cString(bsd.pbi_name)
            name = longName.isEmpty ? cString(bsd.pbi_comm) : longName
        }

        let sample = ProcessSample(
            pid: pid,
            parentPID: pid_t(bsd.pbi_ppid),
            name: name,
            user: username(for: uid),
            uid: uid,
            path: path,
            cpuPercent: cpu,
            residentBytes: task.pti_resident_size,
            threads: Int(task.pti_threadnum),
            openFiles: openFiles,
            startTime: startTime,
            isApp: isApp,
            isSystem: isSystem
        )
        return Snapshot(
            sample: sample,
            previous: PreviousCPU(startTime: startTimeTicks, totalTicks: cpuNanos, wallTime: wallNow)
        )
    }

    private func listPIDs() -> [pid_t] {
        let bytes = proc_listpids(UInt32(PROC_ALL_PIDS), 0, nil, 0)
        guard bytes > 0 else { return [] }
        let hinted = Int(bytes) / MemoryLayout<pid_t>.size
        let capacity = hinted * 2 + 64
        var pids = [pid_t](repeating: 0, count: capacity)
        let bufferBytes = Int32(clamping: capacity * MemoryLayout<pid_t>.size)
        let filled = pids.withUnsafeMutableBufferPointer { buf in
            proc_listpids(UInt32(PROC_ALL_PIDS), 0, buf.baseAddress, bufferBytes)
        }
        guard filled > 0 else { return [] }
        let count = min(Int(filled), Int(bufferBytes)) / MemoryLayout<pid_t>.size
        return pids.prefix(count).filter { $0 > 0 }
    }

    private func processPath(pid: pid_t) -> String {
        // Darwin does not import PROC_PIDPATHINFO_MAXSIZE (4 * MAXPATHLEN).
        var buffer = [CChar](repeating: 0, count: 4 * Int(MAXPATHLEN))
        let length = proc_pidpath(pid, &buffer, UInt32(buffer.count))
        guard length > 0 else { return "" }
        return String(cString: buffer)
    }

    private func openFileCount(for pid: pid_t) -> Int? {
        let needed = proc_pidinfo(pid, PROC_PIDLISTFDS, 0, nil, 0)
        guard needed >= 0 else { return nil }
        if needed == 0 { return 0 }
        let fdSize = MemoryLayout<proc_fdinfo>.size
        guard fdSize > 0 else { return nil }
        let capacity = Int(needed) / fdSize
        var fds = [proc_fdinfo](repeating: proc_fdinfo(), count: capacity)
        let got = fds.withUnsafeMutableBufferPointer { buf in
            proc_pidinfo(pid, PROC_PIDLISTFDS, 0, buf.baseAddress, needed)
        }
        guard got >= 0 else { return nil }
        return min(Int(got) / fdSize, capacity)
    }

    private func username(for uid: uid_t) -> String {
        if let cached = userCache[uid] { return cached }
        let name: String
        if let pw = getpwuid(uid) {
            name = String(cString: pw.pointee.pw_name)
        } else {
            name = String(uid)
        }
        userCache[uid] = name
        return name
    }

    private func machTicksToNanoseconds(_ ticks: UInt64) -> UInt64 {
        let numer = UInt64(timebase.numer)
        let denom = UInt64(timebase.denom)
        guard denom > 0 else { return ticks }
        let product = ticks.multipliedFullWidth(by: numer)
        return denom.dividingFullWidth(product).quotient
    }

    private func scheduleRunningAppRefresh() {
        DispatchQueue.main.async { [weak self] in
            self?.refreshRunningApps()
        }
    }

    private func refreshRunningApps() {
        let apps = NSWorkspace.shared.runningApplications
        var pids = Set<pid_t>()
        var names: [pid_t: String] = [:]
        pids.reserveCapacity(apps.count)
        names.reserveCapacity(apps.count)
        for app in apps {
            let pid = app.processIdentifier
            pids.insert(pid)
            if let localized = app.localizedName, !localized.isEmpty {
                names[pid] = localized
            }
        }
        stateLock.lock()
        runningAppPIDs = pids
        runningAppNames = names
        stateLock.unlock()
    }

    private func cString<T>(_ tuple: T) -> String {
        withUnsafeBytes(of: tuple) { raw in
            let chars = raw.bindMemory(to: CChar.self)
            let length = chars.prefix { $0 != 0 }.count
            return String(decoding: chars.prefix(length).map { UInt8(bitPattern: $0) }, as: UTF8.self)
        }
    }
}
