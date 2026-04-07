import SwiftUI

struct WidgetContainerView: View {
    @ObservedObject var stats: SystemStatsProvider

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 16), count: 4)

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            LazyVGrid(columns: columns, spacing: 16) {
                ClockWidgetView(date: stats.currentDate)
                CPUWidgetView(usage: stats.cpuUsage, thermalState: stats.thermalState)
                RAMWidgetView(usage: stats.ramUsage)
                NetworkWidgetView(inRate: stats.networkIn, outRate: stats.networkOut)
            }
            .padding(24)
        }
    }
}

// MARK: - Shared card chrome

struct WidgetCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
            content.padding(16)
        }
        .frame(maxWidth: .infinity, minHeight: 580)
    }
}
