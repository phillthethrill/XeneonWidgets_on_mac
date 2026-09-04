import CoreGraphics
import XeneonWidgetsCore

func runGraphMathTests() {
    expectEqual(GraphMath.bucket([1, 5, 2, 8, 3, 9], into: 3), [5, 8, 9], "bucket max of equal groups")
    expectEqual(GraphMath.bucket([1, 2], into: 5), [1, 2], "bucket unchanged when shorter than count")
    expectEqual(GraphMath.padLeading([1, 2], to: 4), [0, 0, 1, 2], "padLeading fills on the left")

    let pts = GraphMath.points(values: [0, 50, 100], width: 100, height: 50, min: 0, max: 100)
    expectEqual(pts.count, 3, "three points")
    expectClose(pts[0].x, 0, "first x")
    expectClose(pts[0].y, 50, "first y (min at bottom)")
    expectClose(pts[1].x, 50, "mid x")
    expectClose(pts[1].y, 25, "mid y")
    expectClose(pts[2].x, 100, "last x")
    expectClose(pts[2].y, 0, "last y (max at top)")

    let single = GraphMath.points(values: [50], width: 100, height: 50, min: 0, max: 100)
    expectEqual(single.count, 1, "single value one point")
    expectClose(single[0].x, 100, "single value x = width")

    let a = CGPoint(x: 0, y: 0)
    let b = CGPoint(x: 60, y: 30)
    let segments = GraphMath.smoothSegments([a, b])
    expectEqual(segments.count, 1, "two points → one segment")
    if let seg = segments.first {
        expectClose(seg.control1.x, 10, "c1 on line x")
        expectClose(seg.control1.y, 5, "c1 on line y")
        expectClose(seg.control2.x, 50, "c2 on line x")
        expectClose(seg.control2.y, 25, "c2 on line y")
        expectClose(seg.end.x, 60, "segment end x")
        expectClose(seg.end.y, 30, "segment end y")
    }

    expectEqual(GraphMath.niceScale(peak: 48.2, floor: 1), 50, "niceScale 48.2 → 50")
    expectEqual(GraphMath.niceScale(peak: 0.3, floor: 1), 1, "niceScale below floor")
    expectEqual(GraphMath.niceScale(peak: 120, floor: 1), 200, "niceScale 120 → 200")
}
