import SwiftUI

/// A crisp circular arc gauge that renders natively at display resolution.
struct ArcGauge: View {
    let value: Double
    let color: Color
    let icon: String
    let label: String

    private let lineWidth: CGFloat = 18
    private let size: CGFloat = 208

    var body: some View {
        ZStack {
            Circle()
                .trim(from: 0, to: 1)
                .stroke(Color.white.opacity(0.12), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-210))
                .frame(width: size, height: size)

            Circle()
                .trim(from: 0, to: min(value / 100.0 * (240.0 / 360.0), 1))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-210))
                .frame(width: size, height: size)
                .animation(.easeInOut(duration: 0.4), value: value)

            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                Text("\(Int(value))%")
                    .font(.system(size: 47, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue("\(Int(value)) percent")
    }
}