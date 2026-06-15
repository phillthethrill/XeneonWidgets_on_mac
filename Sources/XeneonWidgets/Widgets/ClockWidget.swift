import SwiftUI

struct ClockWidgetView: View {
    let date: Date

    private static let timeFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    private static let dateFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    var body: some View {
        WidgetCard {
            VStack(spacing: 15) {
                Text(Self.timeFmt.string(from: date))
                    .font(.system(size: 96, weight: .light, design: .monospaced))
                    .foregroundStyle(.white)
                    .accessibilityLabel("Current time")
                    .accessibilityValue(Self.timeFmt.string(from: date))
                Text(Self.dateFmt.string(from: date))
                    .font(.system(size: 30, weight: .regular))
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Current date")
                    .accessibilityValue(Self.dateFmt.string(from: date))
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Clock")
    }
}