import Combine
import CoreWLAN
import Darwin
import Foundation
import SystemConfiguration
import XeneonWidgetsCore

struct NetInterface: Identifiable, Equatable {
    var id: String { name }
    var name: String
    var kind: InterfaceKind
    var displayName: String
    var ipv4: String?
    var isActive: Bool
}

struct WiFiInfo: Equatable {
    var ssid: String?
    var rssi: Int
    var txRateMbps: Double
}

final class NetworkProvider: ObservableObject, SampledProvider {
    @Published var selection: NetworkSelection {
        didSet {
            lock.lock()
            selectionSnapshot = selection
            selectionChanged = true
            lock.unlock()
        }
    }

    @Published private(set) var interfaces: [NetInterface] = []
    @Published private(set) var downRate: Double = 0
    @Published private(set) var upRate: Double = 0
    @Published private(set) var downPeak: Double = 0
    @Published private(set) var upPeak: Double = 0
    @Published private(set) var downTotal: UInt64 = 0
    @Published private(set) var upTotal: UInt64 = 0
    @Published private(set) var downHistory: RingBuffer<Double>
    @Published private(set) var upHistory: RingBuffer<Double>
    @Published private(set) var wifi: WiFiInfo? = nil
    @Published private(set) var pingMilliseconds: Double? = nil

    var hostName: String

    var activeInterface: NetInterface? {
        Self.resolveActive(interfaces: interfaces, selection: selection)
    }

    var valueLabel: String {
        guard let iface = activeInterface else { return "—" }
        return "\(iface.name) · \(iface.displayName)"
    }

    var metaLabel: String {
        if let ip = activeInterface?.ipv4 {
            return "\(hostName) · \(ip)"
        }
        return hostName
    }

    private let lock = NSLock()
    private var selectionSnapshot: NetworkSelection
    private var selectionChanged = false
    private var previousCounters: InterfaceCounters?
    private var lastDiscovery: Date?
    private var lastSampleTime: Date?
    private var cachedInterfaces: [NetInterface] = []
    private var downHistoryStorage: RingBuffer<Double>
    private var upHistoryStorage: RingBuffer<Double>
    private var runningDownRate: Double = 0
    private var runningUpRate: Double = 0
    private var runningDownPeak: Double = 0
    private var runningUpPeak: Double = 0
    private var runningDownTotal: UInt64 = 0
    private var runningUpTotal: UInt64 = 0
    private let ping: PingService

    init(historyCapacity: Int, selection: NetworkSelection, pingHost: String) {
        self.selection = selection
        self.selectionSnapshot = selection
        self.downHistory = RingBuffer(capacity: historyCapacity)
        self.upHistory = RingBuffer(capacity: historyCapacity)
        self.downHistoryStorage = RingBuffer(capacity: historyCapacity)
        self.upHistoryStorage = RingBuffer(capacity: historyCapacity)
        self.hostName = Host.current().localizedName ?? "Mac"
        let ping = PingService(host: pingHost)
        self.ping = ping
        ping.latencyMilliseconds = { [weak self] value in
            self?.pingMilliseconds = value
        }
        ping.start()
    }

    deinit {
        ping.stop()
    }

    func sample(at now: Date, interval: SamplingInterval) {
        let snapshot = Self.readIfaddrs()

        lock.lock()
        let currentSelection = selectionSnapshot
        let resetPrevious = selectionChanged
        selectionChanged = false
        lock.unlock()

        if lastDiscovery == nil || now.timeIntervalSince(lastDiscovery!) >= 5 {
            cachedInterfaces = Self.discoverInterfaces(snapshot: snapshot)
            lastDiscovery = now
        }

        let counters = Dictionary(uniqueKeysWithValues: snapshot.map { ($0.key, $0.value.counters) })
        let activeNames = Set(snapshot.compactMap { $0.value.isActive ? $0.key : nil })
        let aggregated = NetworkMath.aggregate(counters, selection: currentSelection, activeNames: activeNames)

        let dt: TimeInterval
        if let last = lastSampleTime {
            dt = now.timeIntervalSince(last)
        } else {
            dt = interval.rawValue
        }
        lastSampleTime = now

        if resetPrevious {
            previousCounters = aggregated
        } else if let previous = previousCounters,
                  let rates = NetworkMath.rates(current: aggregated, previous: previous, interval: dt) {
            runningDownRate = rates.down
            runningUpRate = rates.up
            runningDownPeak = max(runningDownPeak, rates.down)
            runningUpPeak = max(runningUpPeak, rates.up)
            runningDownTotal += Self.byteDelta(current: aggregated.inBytes, previous: previous.inBytes)
            runningUpTotal += Self.byteDelta(current: aggregated.outBytes, previous: previous.outBytes)
            downHistoryStorage.append(rates.down)
            upHistoryStorage.append(rates.up)
            previousCounters = aggregated
        } else {
            previousCounters = aggregated
        }

        let wifiInfo = Self.sampleWiFi(interfaces: cachedInterfaces)
        let publishedInterfaces = cachedInterfaces
        let downH = downHistoryStorage
        let upH = upHistoryStorage
        let down = runningDownRate
        let up = runningUpRate
        let downP = runningDownPeak
        let upP = runningUpPeak
        let downT = runningDownTotal
        let upT = runningUpTotal

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.interfaces = publishedInterfaces
            self.downRate = down
            self.upRate = up
            self.downPeak = downP
            self.upPeak = upP
            self.downTotal = downT
            self.upTotal = upT
            self.downHistory = downH
            self.upHistory = upH
            self.wifi = wifiInfo
        }
    }

    func historyCapacityChanged(to capacity: Int) {
        downHistoryStorage.resize(capacity: capacity)
        upHistoryStorage.resize(capacity: capacity)
        let downH = downHistoryStorage
        let upH = upHistoryStorage
        DispatchQueue.main.async { [weak self] in
            self?.downHistory = downH
            self?.upHistory = upH
        }
    }

    /// Same wrap rule as `NetworkMath.rates`: 32-bit `if_data` wrap, else 0 when current < previous.
    private static func byteDelta(current: UInt64, previous: UInt64) -> UInt64 {
        if current >= previous {
            return current - previous
        }
        if current <= UInt64(UInt32.max), previous <= UInt64(UInt32.max) {
            return UInt64(UInt32(truncatingIfNeeded: current) &- UInt32(truncatingIfNeeded: previous))
        }
        return 0
    }

    private static func resolveActive(interfaces: [NetInterface], selection: NetworkSelection) -> NetInterface? {
        switch selection {
        case .auto:
            return interfaces.first(where: { $0.isActive && $0.kind == .wifi })
                ?? interfaces.first(where: { $0.isActive && $0.kind == .ethernet })
                ?? interfaces.first(where: { $0.isActive })
        case .interface(let name):
            return interfaces.first(where: { $0.name == name })
        }
    }

    private static func sampleWiFi(interfaces: [NetInterface]) -> WiFiInfo? {
        guard interfaces.contains(where: { $0.kind == .wifi && $0.isActive }) else { return nil }
        guard let cw = CWWiFiClient.shared().interface() else { return nil }
        return WiFiInfo(ssid: cw.ssid(), rssi: cw.rssiValue(), txRateMbps: cw.transmitRate())
    }

    private struct IfaddrsSnapshot {
        var ipv4: String?
        var isActive: Bool
        var counters: InterfaceCounters
    }

    private static func readIfaddrs() -> [String: IfaddrsSnapshot] {
        var ifap: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifap) == 0, let first = ifap else { return [:] }
        defer { freeifaddrs(ifap) }

        var ipv4s: [String: String] = [:]
        var flagsByName: [String: UInt32] = [:]
        var counters: [String: InterfaceCounters] = [:]

        var cursor: UnsafeMutablePointer<ifaddrs>? = first
        while let addr = cursor {
            let name = String(cString: addr.pointee.ifa_name)
            flagsByName[name] = addr.pointee.ifa_flags

            if let sa = addr.pointee.ifa_addr {
                let family = Int32(sa.pointee.sa_family)
                if family == AF_INET, ipv4s[name] == nil {
                    ipv4s[name] = ipv4String(sa)
                } else if family == AF_LINK, let data = addr.pointee.ifa_data {
                    let ifdata = data.load(as: if_data.self)
                    counters[name] = InterfaceCounters(
                        inBytes: UInt64(ifdata.ifi_ibytes),
                        outBytes: UInt64(ifdata.ifi_obytes)
                    )
                }
            }
            cursor = addr.pointee.ifa_next
        }

        var result: [String: IfaddrsSnapshot] = [:]
        let names = Set(flagsByName.keys).union(counters.keys).union(ipv4s.keys)
        for name in names {
            let flags = flagsByName[name] ?? 0
            let upRunning = flags & UInt32(IFF_UP) != 0 && flags & UInt32(IFF_RUNNING) != 0
            let ip = ipv4s[name]
            result[name] = IfaddrsSnapshot(
                ipv4: ip,
                isActive: ip != nil && upRunning,
                counters: counters[name] ?? .zero
            )
        }
        return result
    }

    private static func ipv4String(_ sa: UnsafeMutablePointer<sockaddr>) -> String? {
        sa.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { sin in
            var addr = sin.pointee.sin_addr
            var buf = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
            guard inet_ntop(AF_INET, &addr, &buf, socklen_t(INET_ADDRSTRLEN)) != nil else {
                return nil
            }
            return String(cString: buf)
        }
    }

    private static func discoverInterfaces(snapshot: [String: IfaddrsSnapshot]) -> [NetInterface] {
        var meta: [String: (type: String?, display: String)] = [:]

        if let list = SCNetworkInterfaceCopyAll() as? [SCNetworkInterface] {
            for iface in list {
                guard let bsd = SCNetworkInterfaceGetBSDName(iface) as String? else { continue }
                let type = SCNetworkInterfaceGetInterfaceType(iface) as String?
                let display = (SCNetworkInterfaceGetLocalizedDisplayName(iface) as String?) ?? bsd
                meta[bsd] = (type, display)
            }
        }

        var names = Set(meta.keys)
        for name in snapshot.keys where name.hasPrefix("en") {
            names.insert(name)
        }

        return names.sorted().map { name in
            let info = snapshot[name]
            let sc = meta[name]
            let display = sc?.display ?? name
            let kind = NetworkMath.kind(
                forSCInterfaceType: sc?.type,
                bsdName: name,
                localizedName: display
            )
            return NetInterface(
                name: name,
                kind: kind,
                displayName: display,
                ipv4: info?.ipv4,
                isActive: info?.isActive ?? false
            )
        }
    }
}
