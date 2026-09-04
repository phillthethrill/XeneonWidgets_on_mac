import Foundation

public struct VolumeInfo: Identifiable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var kind: String
    public var usedBytes: UInt64
    public var totalBytes: UInt64
    public var percent: Double
    public var bsdName: String?

    public init(
        id: String,
        name: String,
        kind: String,
        usedBytes: UInt64,
        totalBytes: UInt64,
        percent: Double,
        bsdName: String?
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.usedBytes = usedBytes
        self.totalBytes = totalBytes
        self.percent = percent
        self.bsdName = bsdName
    }
}

public struct DiskIOSample: Equatable, Sendable {
    public var readBytes: UInt64
    public var writeBytes: UInt64

    public init(readBytes: UInt64, writeBytes: UInt64) {
        self.readBytes = readBytes
        self.writeBytes = writeBytes
    }
}

public enum DiskMath {
    public static func kindLabel(format: String?, isInternal: Bool, isRemovable: Bool, isLocal: Bool) -> String {
        let location: String
        if !isLocal {
            location = "network"
        } else if isInternal && !isRemovable {
            location = "internal"
        } else {
            location = "external"
        }
        let trimmed = format?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let fs = trimmed.isEmpty ? "unknown" : trimmed
        return "\(fs) · \(location)"
    }

    public static func wholeDisk(fromBSDName name: String) -> String {
        guard name.hasPrefix("disk") else { return name }
        let digits = name.dropFirst(4).prefix { $0.isNumber }
        guard !digits.isEmpty else { return name }
        return "disk\(digits)"
    }

    public static func rates(
        current: DiskIOSample,
        previous: DiskIOSample,
        interval: TimeInterval
    ) -> (read: Double, write: Double)? {
        guard interval > 0 else { return nil }
        let read = Double(current.readBytes &- previous.readBytes) / interval
        let write = Double(current.writeBytes &- previous.writeBytes) / interval
        return (read, write)
    }

    public static func capacityLabel(used: UInt64, total: UInt64) -> String {
        "\(Formatters.capacity(used)) / \(Formatters.capacity(total))"
    }
}
