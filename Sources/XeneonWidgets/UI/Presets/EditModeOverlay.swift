import SwiftUI

struct EditModeOverlay: View {
    let index: Int
    let onHide: () -> Void
    let onResize: (CGFloat) -> Void
    let onResizeEnd: () -> Void

    @Environment(\.theme) private var theme

    private var tilt: Double {
        index.isMultiple(of: 2) ? -Motion.editTiltDegrees : Motion.editTiltDegrees
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Metrics.boxRadius + 4)
                .stroke(theme.accent, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                .padding(-4)
                .allowsHitTesting(false)

            VStack {
                HStack {
                    gripHandle
                    Spacer()
                    hideHandle
                }
                Spacer()
                HStack {
                    Spacer()
                    resizeHandle
                }
            }
        }
        .rotationEffect(.degrees(tilt))
    }

    private var hideHandle: some View {
        Button(action: onHide) {
            Text("×")
                .font(.system(size: 24))
                .foregroundStyle(theme.text)
                .frame(width: 56, height: 56)
        }
        .buttonStyle(.plain)
        .background(theme.surface2, in: Circle())
        .overlay {
            Circle().stroke(theme.hairline, lineWidth: Metrics.hairline)
        }
        .padding(12)
    }

    private var gripHandle: some View {
        ZStack {
            Circle()
                .fill(theme.surface2)
            Circle()
                .stroke(theme.hairline, lineWidth: Metrics.hairline)
            gripDots
                .foregroundStyle(theme.text2)
        }
        .frame(width: 56, height: 56)
        .padding(12)
        .allowsHitTesting(false)
    }

    private var gripDots: some View {
        VStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { _ in
                HStack(spacing: 6) {
                    Circle().frame(width: 3.6, height: 3.6)
                    Circle().frame(width: 3.6, height: 3.6)
                }
            }
        }
    }

    private var resizeHandle: some View {
        ZStack(alignment: .bottomTrailing) {
            Color.clear
                .frame(width: 56, height: 56)
            ResizeLShape()
                .stroke(theme.text3, style: StrokeStyle(lineWidth: 3, lineCap: .square, lineJoin: .round))
                .frame(width: 28, height: 28)
                .padding(12)
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    onResize(value.translation.width)
                }
                .onEnded { _ in
                    onResizeEnd()
                }
        )
    }
}

private struct ResizeLShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let radius: CGFloat = 8
        path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - radius, y: rect.maxY),
            control: CGPoint(x: rect.maxX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        return path
    }
}
