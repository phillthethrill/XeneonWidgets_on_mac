import SwiftUI

struct NetworkWidgetView: View {
    let inRate: Double
    let outRate: Double

    var body: some View {
        WidgetCard {
            VStack(spacing: 31) {
                Image(systemName: "network")
                    .font(.system(size: 78))
                    .foregroundStyle(.white)
                HStack(spacing: 62) {
                    VStack(spacing: 8) {
                        Label(formatted(inRate), systemImage: "arrow.down")
                            .font(.system(size: 35, weight: .medium))
                            .foregroundStyle(.cyan)
                        Text("Download")
                            .font(.system(size: 27))
                            .foregroundStyle(.secondary)
                    }
                    VStack(spacing: 8) {
                        Label(formatted(outRate), systemImage: "arrow.up")
                            .font(.system(size: 35, weight: .medium))
                            .foregroundStyle(.orange)
                        Text("Upload")
                            .font(.system(size: 27))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func formatted(_ bps: Double) -> String {
        if bps > 1_000_000 { return String(format: "%.1f MB/s", bps / 1_000_000) }
        if bps > 1_000     { return String(format: "%.0f KB/s", bps / 1_000) }
        return String(format: "%.0f B/s", bps)
    }
}
