import SwiftUI

struct SegBar: View {
    struct Segment: Identifiable {
        let id: String
        let value: Double
        let color: Color
        let opacity: Double
    }

    let segments: [Segment]
    let height: CGFloat

    init(segments: [Segment], height: CGFloat = 14) {
        self.segments = segments
        self.height = height
    }

    var body: some View {
        GeometryReader { geo in
            let total = segments.reduce(0) { $0 + $1.value }
            let gapCount = max(segments.count - 1, 0)
            let usable = geo.size.width - CGFloat(gapCount) * 2
            HStack(spacing: 2) {
                ForEach(segments) { segment in
                    let width = total > 0 ? usable * CGFloat(segment.value / total) : 0
                    segment.color
                        .opacity(segment.opacity)
                        .frame(width: max(width, 0))
                }
            }
        }
        .frame(height: height)
        .clipShape(Capsule())
    }
}
