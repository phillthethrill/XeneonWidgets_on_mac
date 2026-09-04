import SwiftUI
import XeneonWidgetsCore

enum GraphStyle {
    case ramp
    case solid(Color)
}

struct HistoryGraph: View {
    let values: [Double]
    let min: Double
    let max: Double
    let style: GraphStyle
    let showGrid: Bool
    let thresholds: [Double]
    let lineWidth: CGFloat
    let fillOpacity: Double
    let cornerLabel: String?

    @Environment(\.theme) private var theme

    init(
        values: [Double],
        min: Double = 0,
        max: Double = 100,
        style: GraphStyle = .ramp,
        showGrid: Bool = true,
        thresholds: [Double] = [50, 80],
        lineWidth: CGFloat = 2,
        fillOpacity: Double = 0.28,
        cornerLabel: String? = nil
    ) {
        self.values = values
        self.min = min
        self.max = max
        self.style = style
        self.showGrid = showGrid
        self.thresholds = thresholds
        self.lineWidth = lineWidth
        self.fillOpacity = fillOpacity
        self.cornerLabel = cornerLabel
    }

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack(alignment: .topTrailing) {
                canvas(width: size.width, height: size.height)
                if let cornerLabel {
                    Text(cornerLabel)
                        .font(Typography.mono(12))
                        .monoDigits()
                        .foregroundStyle(theme.text3)
                }
            }
        }
    }

    @ViewBuilder
    private func canvas(width: CGFloat, height: CGFloat) -> some View {
        let line = smoothedPath(values: values, width: width, height: height, min: min, max: max)
        ZStack {
            if showGrid {
                ForEach(Array(thresholds.enumerated()), id: \.offset) { _, threshold in
                    thresholdLine(threshold, width: width, height: height)
                }
            }
            if !line.isEmpty {
                areaPath(from: line, width: width, height: height)
                    .fill(fillGradient)
                strokeView(line)
            }
        }
    }

    @ViewBuilder
    private func strokeView(_ line: Path) -> some View {
        let stroke = StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
        switch style {
        case .ramp:
            line.stroke(theme.ramp, style: stroke)
        case .solid(let color):
            line.stroke(color, style: stroke)
        }
    }

    private var fillGradient: LinearGradient {
        let bottom: Color
        let top: Color
        switch style {
        case .ramp:
            bottom = theme.rampLow
            top = theme.rampHigh
        case .solid(let color):
            bottom = color
            top = color
        }
        return LinearGradient(
            stops: [
                .init(color: bottom.opacity(0.02), location: 0),
                .init(color: top.opacity(fillOpacity), location: 1),
            ],
            startPoint: .bottom,
            endPoint: .top
        )
    }

    private func thresholdLine(_ threshold: Double, width: CGFloat, height: CGFloat) -> some View {
        let range = max - min
        let t = range == 0 ? 0 : (threshold - min) / range
        let y = height - CGFloat(t) * height
        return Path { path in
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: width, y: y))
        }
        .stroke(theme.hairline, style: StrokeStyle(lineWidth: 1, dash: [3, 5]))
    }
}

func smoothedPath(values: [Double], width: CGFloat, height: CGFloat, min: Double, max: Double) -> Path {
    let points = GraphMath.points(
        values: values,
        width: Double(width),
        height: Double(height),
        min: min,
        max: max
    )
    var path = Path()
    guard let first = points.first else { return path }
    path.move(to: first)
    for segment in GraphMath.smoothSegments(points) {
        path.addCurve(to: segment.end, control1: segment.control1, control2: segment.control2)
    }
    return path
}

func areaPath(from line: Path, width: CGFloat, height: CGFloat, baseline: CGFloat? = nil) -> Path {
    guard !line.isEmpty else { return Path() }
    var path = line
    let y = baseline ?? height
    path.addLine(to: CGPoint(x: width, y: y))
    path.addLine(to: CGPoint(x: 0, y: y))
    path.closeSubpath()
    return path
}
