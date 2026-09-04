import Foundation

public enum InterfaceKind: String, Equatable, Sendable, CaseIterable {
    case wifi = "Wi-Fi"
    case ethernet = "Ethernet"
    case usb = "USB"
    case other = "Other"
}

public enum NetworkSelection: Equatable, Sendable {
    case auto
    case interface(String)

    public init(rawValue: String) {
        if rawValue == "auto" {
            self = .auto
        } else {
            self = .interface(rawValue)
        }
    }

    public var rawValue: String {
        switch self {
        case .auto:
            return "auto"
        case .interface(let name):
            return name
        }
    }

    /// "Auto" for `.auto`. For `.interface`, the BSD name — the view supplies the kind chip label.
    public var chipLabel: String {
        switch self {
        case .auto:
            return "Auto"
        case .interface(let name):
            return name
        }
    }
}

public struct InterfaceCounters: Equatable, Sendable {
    public var inBytes: UInt64
    public var outBytes: UInt64

    public init(inBytes: UInt64, outBytes: UInt64) {
        self.inBytes = inBytes
        self.outBytes = outBytes
    }

    public static let zero = InterfaceCounters(inBytes: 0, outBytes: 0)
}

public enum NetworkMath {
    /// Sums counters of the selected interfaces (auto → all names with prefix "en" that are active).
    public static func aggregate(
        _ counters: [String: InterfaceCounters],
        selection: NetworkSelection,
        activeNames: Set<String>
    ) -> InterfaceCounters {
        switch selection {
        case .auto:
            var total = InterfaceCounters.zero
            for (name, counters) in counters {
                guard name.hasPrefix("en"), activeNames.contains(name) else { continue }
                total.inBytes += counters.inBytes
                total.outBytes += counters.outBytes
            }
            return total
        case .interface(let name):
            return counters[name] ?? .zero
        }
    }

    public static func rates(
        current: InterfaceCounters,
        previous: InterfaceCounters,
        interval: TimeInterval
    ) -> (down: Double, up: Double)? {
        guard interval > 0, previous != .zero else { return nil }
        let down = max(0, Double(current.inBytes &- previous.inBytes) / interval)
        let up = max(0, Double(current.outBytes &- previous.outBytes) / interval)
        return (down, up)
    }

    public static func kind(
        forSCInterfaceType type: String?,
        bsdName: String,
        localizedName: String = ""
    ) -> InterfaceKind {
        switch type {
        case "IEEE80211":
            return .wifi
        case "Ethernet":
            let haystack = localizedName.isEmpty ? bsdName : "\(localizedName) \(bsdName)"
            if haystack.range(of: "USB", options: .caseInsensitive) != nil {
                return .usb
            }
            return .ethernet
        default:
            return .other
        }
    }

    public static func rateScaleLabel(bytesPerSecond: Double, arrow: String) -> String {
        let megabytes = bytesPerSecond / 1_000_000.0
        let scale = GraphMath.niceScale(peak: megabytes, floor: 1)
        return "\(arrow) \(formatScale(scale)) MB/s"
    }

    private static func formatScale(_ scale: Double) -> String {
        if scale == scale.rounded() {
            return String(format: "%.0f", scale)
        }
        return String(format: "%g", scale)
    }
}
