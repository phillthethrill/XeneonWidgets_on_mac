import Foundation

public struct MemoryBreakdown: Equatable, Sendable {
    public var app: UInt64
    public var wired: UInt64
    public var compressed: UInt64
    public var cached: UInt64
    public var free: UInt64
    public var total: UInt64

    public var used: UInt64 { app + wired + compressed }

    public var usedPercent: Double {
        guard total > 0 else { return 0 }
        return Double(used) / Double(total) * 100
    }

    public init(app: UInt64, wired: UInt64, compressed: UInt64, cached: UInt64, free: UInt64, total: UInt64) {
        self.app = app
        self.wired = wired
        self.compressed = compressed
        self.cached = cached
        self.free = free
        self.total = total
    }
}

public enum MemoryMath {
    /// Spec formulas: app = internal − purgeable; cached = purgeable + external; wired, compressed, free straight from counts. All in pages → bytes.
    public static func breakdown(
        internalPages: UInt64,
        purgeablePages: UInt64,
        externalPages: UInt64,
        wiredPages: UInt64,
        compressorPages: UInt64,
        freePages: UInt64,
        pageSize: UInt64,
        totalBytes: UInt64
    ) -> MemoryBreakdown {
        let appPages = internalPages > purgeablePages ? internalPages - purgeablePages : 0
        return MemoryBreakdown(
            app: appPages * pageSize,
            wired: wiredPages * pageSize,
            compressed: compressorPages * pageSize,
            cached: (purgeablePages + externalPages) * pageSize,
            free: freePages * pageSize,
            total: totalBytes
        )
    }

    public static func swapLabel(usedBytes: UInt64, totalBytes: UInt64) -> String {
        "swap \(pairLabel(usedBytes: usedBytes, totalBytes: totalBytes))"
    }

    public static func memValueLabel(usedBytes: UInt64, totalBytes: UInt64) -> String {
        pairLabel(usedBytes: usedBytes, totalBytes: totalBytes)
    }

    private static func pairLabel(usedBytes: UInt64, totalBytes: UInt64) -> String {
        let usedGB = Double(usedBytes) / 1_073_741_824.0
        let totalGB = Double(totalBytes) / 1_073_741_824.0
        let usedText = String(format: "%.1f", usedGB)
        let totalDecimals = totalGB.rounded() == totalGB ? 0 : 1
        return "\(usedText) / \(Formatters.gigabytes(totalBytes, decimals: totalDecimals))"
    }
}
