import SwiftUI

struct CPUWidgetView: View {
    let usage: Double
    let thermalState: ProcessInfo.ThermalState

    var body: some View {
        WidgetCard {
            VStack(spacing: 23) {
                ArcGauge(value: usage, color: usageColor, icon: "cpu", label: "CPU")
                Text("CPU")
                    .font(.system(size: 35, weight: .medium))
                    .foregroundStyle(.secondary)
                HStack(spacing: 12) {
                    Circle()
                        .fill(thermalColor)
                        .frame(width: 16, height: 16)
                    Text(thermalLabel)
                        .font(.system(size: 26))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var usageColor: Color {
        usage < 50 ? .green : usage < 80 ? .yellow : .red
    }

    private var thermalColor: Color {
        switch thermalState {
        case .nominal:  return .green
        case .fair:     return .yellow
        case .serious:  return .orange
        case .critical: return .red
        @unknown default: return .gray
        }
    }

    private var thermalLabel: String {
        switch thermalState {
        case .nominal:  return "Nominal"
        case .fair:     return "Fair"
        case .serious:  return "Serious"
        case .critical: return "Critical"
        @unknown default: return "Unknown"
        }
    }
}
