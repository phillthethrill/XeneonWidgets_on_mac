import CoreGraphics
import XeneonWidgetsCore

enum GraphWindow {
    static func samples(_ buffer: RingBuffer<Double>, sampleCount: Int, width: CGFloat) -> [Double] {
        samples(buffer.suffix(sampleCount), sampleCount: sampleCount, width: width)
    }

    static func samples(_ values: [Double], sampleCount: Int, width: CGFloat) -> [Double] {
        let padded = GraphMath.padLeading(Array(values.suffix(sampleCount)), to: sampleCount)
        return GraphMath.bucket(padded, into: max(2, Int(width / 3)))
    }
}
