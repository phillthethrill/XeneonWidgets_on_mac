import Foundation

public enum Formatters {
    public static func percent(_ value: Double) -> String {
        "\(Int(value.rounded()))%"
    }

    public static func percent1(_ value: Double) -> String {
        String(format: "%.1f%%", value)
    }

    public static func gigabytes(_ bytes: UInt64, decimals: Int = 1) -> String {
        let gb = Double(bytes) / 1_073_741_824.0
        return String(format: "%.\(decimals)f GB", gb)
    }

    /// Used-only when the registry has no GPU-specific total. Never treat `0` as a denominator.
    public static func gpuMemory(usedBytes: UInt64, totalBytes: UInt64, hasRealTotal: Bool) -> String {
        let used = gigabytes(usedBytes, decimals: 1)
        guard hasRealTotal else { return used }
        let usedShort = used.replacingOccurrences(of: " GB", with: "")
        return "\(usedShort) / \(gigabytes(totalBytes, decimals: 0))"
    }

    public static func capacity(_ bytes: UInt64) -> String {
        let gb = Double(bytes) / 1_073_741_824.0
        if gb < 1024 {
            return "\(Int(gb.rounded())) GB"
        }
        return String(format: "%.2f TB", gb / 1024.0)
    }

    public static func megabytesPerSecond(_ bytesPerSecond: Double) -> String {
        String(format: "%.1f", bytesPerSecond / 1_000_000.0)
    }

    public static func totalBytes(_ bytes: UInt64) -> String {
        let value = Double(bytes)
        let tb = 1_099_511_627_776.0
        let gb = 1_073_741_824.0
        let mb = 1_048_576.0
        if value >= tb {
            return String(format: "%.1f TB", value / tb)
        }
        if value >= gb {
            return String(format: "%.1f GB", value / gb)
        }
        if value >= mb {
            return "\(Int((value / mb).rounded())) MB"
        }
        if value >= 1024 {
            return "\(Int((value / 1024.0).rounded())) KB"
        }
        return "\(bytes) B"
    }

    public static func uptime(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let days = total / 86_400
        let hours = (total % 86_400) / 3_600
        let minutes = (total % 3_600) / 60
        if days > 0 {
            return "up \(days)d \(hours)h \(minutes)m"
        }
        if hours > 0 {
            return "up \(hours)h \(minutes)m"
        }
        return "up \(minutes)m"
    }

    public static func age(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let hours = total / 3_600
        let minutes = (total % 3_600) / 60
        let secs = total % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        if minutes > 0 {
            if secs == 0 {
                return "\(minutes)m"
            }
            return "\(minutes)m \(secs)s"
        }
        return "\(secs)s"
    }

    public static func clockHM(_ date: Date, calendar: Calendar = .current) -> String {
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        return String(format: "%02d:%02d", hour, minute)
    }

    public static func clockSeconds(_ date: Date, calendar: Calendar = .current) -> String {
        String(format: "%02d", calendar.component(.second, from: date))
    }

    public static func shortDate(_ date: Date, calendar: Calendar = .current) -> String {
        dateString(date, calendar: calendar, format: "EEE d MMM")
    }

    public static func longDate(_ date: Date, calendar: Calendar = .current) -> String {
        dateString(date, calendar: calendar, format: "EEEE, d MMMM")
    }

    public static func isoWeek(_ date: Date) -> String {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return String(format: "W%d", calendar.component(.weekOfYear, from: date))
    }

    public static func minutesAsClock(_ minutes: Int) -> String {
        String(format: "%d:%02d", minutes / 60, minutes % 60)
    }

    public static func watts(_ w: Double) -> String {
        String(format: "%.1f W", w)
    }

    public static func loadAverage(_ v: Double) -> String {
        String(format: "%.2f", v)
    }

    private static func dateString(_ date: Date, calendar: Calendar, format: String) -> String {
        let locale = calendar.locale ?? .current
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = locale
        formatter.dateFormat = format
        return formatter.string(from: date)
    }
}
