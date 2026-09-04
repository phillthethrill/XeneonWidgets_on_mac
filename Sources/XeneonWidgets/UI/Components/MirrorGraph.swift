import SwiftUI
import XeneonWidgetsCore

struct MirrorGraph: View {
    let down: [Double]
    let up: [Double]
    let downScale: Double
    let upScale: Double
    let downLabel: String
    let upLabel: String

    @Environment(\.theme) private var theme

    init(down: [Double], up: [Double], downScale: Double, upScale: Double, downLabel: String, upLabel: String) {
        self.down = down
        self.up = up
        self.downScale = downScale
        self.upScale = upScale
        self.downLabel = downLabel
        self.upLabel = upLabel
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let halfHeight = h / 2 - 6
            ZStack(alignment: .topLeading) {
                canvas(width: w, height: h, halfHeight: halfHeight)
                VStack {
                    Text(downLabel)
                    Spacer()
                    Text(upLabel)
                }
                .font(Typography.mono(12))
                .monoDigits()
                .foregroundStyle(theme.text3)
            }
        }
    }

    @ViewBuilder
    private func canvas(width: CGFloat, height: CGFloat, halfHeight: CGFloat) -> some View {
        let downLine = smoothedPath(values: down, width: width, height: halfHeight, min: 0, max: downScale)
        let upLine = mirroredUpPath(width: width, height: height, halfHeight: halfHeight)
        let stroke = StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)

        ZStack {
            if !downLine.isEmpty {
                areaPath(from: downLine, width: width, height: height, baseline: halfHeight)
                    .fill(downFill)
                downLine.stroke(theme.accent, style: stroke)
            }
            if !upLine.isEmpty {
                areaPath(from: upLine, width: width, height: height, baseline: height - halfHeight)
                    .fill(upFill)
                upLine.stroke(theme.up, style: stroke)
            }
            Path { path in
                path.move(to: CGPoint(x: 0, y: height / 2))
                path.addLine(to: CGPoint(x: width, y: height / 2))
            }
            .stroke(theme.text3.opacity(0.5), lineWidth: 1)
        }
    }

    private func mirroredUpPath(width: CGFloat, height: CGFloat, halfHeight: CGFloat) -> Path {
        let points = GraphMath.points(
            values: up,
            width: Double(width),
            height: Double(halfHeight),
            min: 0,
            max: upScale
        ).map { CGPoint(x: $0.x, y: height - $0.y) }
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        for segment in GraphMath.smoothSegments(points) {
            path.addCurve(to: segment.end, control1: segment.control1, control2: segment.control2)
        }
        return path
    }

    private var downFill: LinearGradient {
        LinearGradient(
            colors: [theme.accent.opacity(0.4), theme.accent.opacity(0.02)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var upFill: LinearGradient {
        LinearGradient(
            colors: [theme.up.opacity(0.4), theme.up.opacity(0.02)],
            startPoint: .bottom,
            endPoint: .top
        )
    }
}
