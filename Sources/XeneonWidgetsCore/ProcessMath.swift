import Foundation

public enum ProcSort: String, CaseIterable, Codable, Sendable {
    case cpu, mem, pid, name
}

public enum ProcFilter: String, CaseIterable, Sendable {
    case all = "All"
    case apps = "Apps"
    case background = "Background"
    case system = "System"
    case mine = "Mine"
    case highCPU = "High CPU"
}

public struct ProcessSample: Identifiable, Equatable, Sendable {
    public var id: pid_t { pid }
    public var pid: pid_t
    public var parentPID: pid_t
    public var name: String
    public var user: String
    public var uid: uid_t
    public var path: String
    public var cpuPercent: Double
    public var residentBytes: UInt64
    public var threads: Int
    public var openFiles: Int?
    public var startTime: Date?
    public var isApp: Bool
    public var isSystem: Bool

    public init(
        pid: pid_t,
        parentPID: pid_t,
        name: String,
        user: String,
        uid: uid_t,
        path: String,
        cpuPercent: Double,
        residentBytes: UInt64,
        threads: Int,
        openFiles: Int? = nil,
        startTime: Date? = nil,
        isApp: Bool,
        isSystem: Bool
    ) {
        self.pid = pid
        self.parentPID = parentPID
        self.name = name
        self.user = user
        self.uid = uid
        self.path = path
        self.cpuPercent = cpuPercent
        self.residentBytes = residentBytes
        self.threads = threads
        self.openFiles = openFiles
        self.startTime = startTime
        self.isApp = isApp
        self.isSystem = isSystem
    }
}

public enum ProcessMath {
    /// CPU % = Δ(user+system) ns / Δwall ns × 100, clamped 0…(100 × coreCount).
    public static func cpuPercent(deltaCPUNanoseconds: UInt64, deltaWallNanoseconds: UInt64) -> Double {
        guard deltaWallNanoseconds > 0 else { return 0 }
        let raw = Double(deltaCPUNanoseconds) / Double(deltaWallNanoseconds) * 100.0
        let ceiling = 100.0 * Double(ProcessInfo.processInfo.processorCount)
        return min(max(raw, 0), ceiling)
    }

    public static func filter(_ procs: [ProcessSample], by filter: ProcFilter, currentUID: uid_t) -> [ProcessSample] {
        switch filter {
        case .all:
            return procs
        case .apps:
            return procs.filter(\.isApp)
        case .background:
            return procs.filter { !$0.isApp && !$0.isSystem }
        case .system:
            return procs.filter(\.isSystem)
        case .mine:
            return procs.filter { $0.uid == currentUID }
        case .highCPU:
            return procs.filter { $0.cpuPercent >= 10 }
        }
    }

    public static func sort(_ procs: [ProcessSample], by sort: ProcSort) -> [ProcessSample] {
        switch sort {
        case .cpu:
            return procs.sorted { $0.cpuPercent > $1.cpuPercent }
        case .mem:
            return procs.sorted { $0.residentBytes > $1.residentBytes }
        case .pid:
            return procs.sorted { $0.pid < $1.pid }
        case .name:
            return procs.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
    }

    /// True when a live sample has this `pid` and the same `startTime`.
    /// Both `nil` start times match: identity is pid-only when start time is unknown.
    /// A `nil` expected start time does not match a non-nil sample start time (Optional `==`).
    public static func identityMatches(samples: [ProcessSample], pid: pid_t, startTime: Date?) -> Bool {
        guard let match = samples.first(where: { $0.pid == pid }) else { return false }
        return match.startTime == startTime
    }

    public static func memLabel(_ bytes: UInt64) -> String {
        let gb = 1_073_741_824.0
        let value = Double(bytes)
        if value >= gb {
            return String(format: "%.2f GB", value / gb)
        }
        let mb = Int((value / 1_048_576.0).rounded())
        return "\(mb) MB"
    }
}
