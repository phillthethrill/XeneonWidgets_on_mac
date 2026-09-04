import SwiftUI
import XeneonWidgetsCore

struct AlertChip: View {
    let text: String
    let age: String
    let level: StateLevel
    let action: () -> Void

    @Environment(\.theme) private var theme
    @State private var pulseDim = false

    init(text: String, age: String, level: StateLevel, action: @escaping () -> Void) {
        self.text = text
        self.age = age
        self.level = level
        self.action = action
    }

    var body: some View {
        let tint = theme.color(level)
        Button(action: action) {
            HStack(spacing: 10) {
                Circle()
                    .fill(tint)
                    .frame(width: 10, height: 10)
                    .shadow(color: tint, radius: 5)
                    .opacity(pulseDim ? 0.35 : 1)
                Text(text)
                    .font(Typography.chip)
                Text(age)
                    .font(Typography.smallMono)
                    .monoDigits()
                    .opacity(0.75)
            }
            .foregroundStyle(tint)
            .padding(.leading, 12)
            .padding(.trailing, 16)
            .frame(height: 40)
            .background(tint.opacity(0.18), in: Capsule())
            .overlay(Capsule().stroke(tint.opacity(0.45), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .onAppear {
            withAnimation(Motion.alertPulse) {
                pulseDim = true
            }
        }
    }
}
