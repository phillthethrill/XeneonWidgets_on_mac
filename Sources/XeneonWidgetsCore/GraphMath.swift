import CoreGraphics
import Foundation

public enum GraphMath {
    /// Downsample by taking the max of each of `count` equal buckets. Returns `values` unchanged when values.count <= count. count ≥ 1.
    public static func bucket(_ values: [Double], into count: Int) -> [Double] {
        precondition(count >= 1, "bucket count must be ≥ 1")
        guard values.count > count else { return values }

        var result: [Double] = []
        result.reserveCapacity(count)
        let n = values.count
        for i in 0..<count {
            let start = i * n / count
            let end = (i + 1) * n / count
            result.append(values[start..<end].max() ?? 0)
        }
        return result
    }

    /// Left-pad with `fill` to exactly `count` (used so a young ring buffer still spans the full graph width).
    public static func padLeading(_ values: [Double], to count: Int, fill: Double = 0) -> [Double] {
        if values.count >= count {
            return Array(values.suffix(count))
        }
        return Array(repeating: fill, count: count - values.count) + values
    }

    /// x from 0…width evenly (single value → x = width), y = height - (v-min)/(max-min)*height, clamped to 0…height.
    public static func points(values: [Double], width: Double, height: Double, min: Double, max: Double) -> [CGPoint] {
        guard !values.isEmpty else { return [] }
        let range = max - min

        func yValue(_ v: Double) -> Double {
            let t: Double
            if range == 0 {
                t = 0
            } else {
                t = (v - min) / range
            }
            let raw = height - t * height
            return Swift.min(height, Swift.max(0, raw))
        }

        if values.count == 1 {
            return [CGPoint(x: width, y: yValue(values[0]))]
        }

        let lastIndex = Double(values.count - 1)
        return values.enumerated().map { index, value in
            CGPoint(x: width * Double(index) / lastIndex, y: yValue(value))
        }
    }

    /// Catmull-Rom → cubic Bézier control points (same maths as components.jsx `smooth`): for each segment p1→p2, c1 = p1 + (p2 - p0)/6, c2 = p2 - (p3 - p1)/6.
    public static func smoothSegments(_ points: [CGPoint]) -> [(control1: CGPoint, control2: CGPoint, end: CGPoint)] {
        guard points.count >= 2 else { return [] }
        var segments: [(control1: CGPoint, control2: CGPoint, end: CGPoint)] = []
        segments.reserveCapacity(points.count - 1)
        for i in 0..<(points.count - 1) {
            let p0 = i > 0 ? points[i - 1] : points[i]
            let p1 = points[i]
            let p2 = points[i + 1]
            let p3 = i + 2 < points.count ? points[i + 2] : p2
            let control1 = CGPoint(
                x: p1.x + (p2.x - p0.x) / 6,
                y: p1.y + (p2.y - p0.y) / 6
            )
            let control2 = CGPoint(
                x: p2.x - (p3.x - p1.x) / 6,
                y: p2.y - (p3.y - p1.y) / 6
            )
            segments.append((control1, control2, p2))
        }
        return segments
    }

    /// Smallest value of the form {1,2,5}×10^n that is ≥ max(peak, floor). niceScale(peak: 48.2, floor: 1) == 50.
    public static func niceScale(peak: Double, floor: Double) -> Double {
        let target = max(peak, floor)
        guard target > 0 else { return floor }
        let exponent = Darwin.floor(log10(target))
        let base = pow(10.0, exponent)
        let mantissa = target / base
        let nice: Double
        if mantissa <= 1 {
            nice = 1
        } else if mantissa <= 2 {
            nice = 2
        } else if mantissa <= 5 {
            nice = 5
        } else {
            nice = 10
        }
        return nice * base
    }
}
