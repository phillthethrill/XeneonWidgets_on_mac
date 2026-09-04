import SwiftUI

struct Sparkline: View {
    let values: [Double]
    let color: Color
    let max: Double?
    let min: Double
    let lineWidth: CGFloat

    init(values: [Double], color: Color, max: Double? = nil, min: Double = 0, lineWidth: CGFloat = 1.5) {
        self.values = values
        self.color = color
        self.max = max
        self.min = min
        self.lineWidth = lineWidth
    }

    var body: some View {
        GeometryReader { geo in
            let ceiling = max ?? Swift.max(1, values.max() ?? 1)
            let line = smoothedPath(
                values: values,
                width: geo.size.width,
                height: geo.size.height,
                min: min,
                max: ceiling
            )
            ZStack {
                if !line.isEmpty {
                    areaPath(from: line, width: geo.size.width, height: geo.size.height)
                        .fill(fillGradient)
                    line.stroke(
                        color,
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
                    )
                }
            }
        }
    }

    private var fillGradient: LinearGradient {
        LinearGradient(
            colors: [color.opacity(0.35), color.opacity(0)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
