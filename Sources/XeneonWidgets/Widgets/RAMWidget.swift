import SwiftUI

struct RAMWidgetView: View {
    let usage: Double

    var body: some View {
        WidgetCard {
            VStack(spacing: 23) {
                ArcGauge(value: usage, color: usageColor, icon: "memorychip", label: "RAM usage")
                Text("RAM")
                    .font(.system(size: 35, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("RAM")
    }

    private var usageColor: Color {
        usage < 70 ? .green : usage < 90 ? .yellow : .red
    }
}