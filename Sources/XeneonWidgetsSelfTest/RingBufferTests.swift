import XeneonWidgetsCore

func runRingBufferTests() {
    var buffer = RingBuffer<Int>(capacity: 3)
    expectEqual(buffer.capacity, 3, "initial capacity")
    expect(buffer.isEmpty, "new buffer is empty")
    expectNil(buffer.last, "empty last")

    for value in 1...5 {
        buffer.append(value)
    }

    expectEqual(buffer.elements, [3, 4, 5], "drops oldest when full")
    expectEqual(buffer.last, 5, "last is newest")
    expectEqual(buffer.count, 3, "count stays at capacity")
    expectEqual(buffer.suffix(2), [4, 5], "suffix newest 2")
    expectEqual(buffer.suffix(10), [3, 4, 5], "suffix larger than count returns all")

    buffer.resize(capacity: 2)
    expectEqual(buffer.elements, [4, 5], "resize keeps newest")
    expectEqual(buffer.capacity, 2, "resized capacity")

    buffer.resize(capacity: 5)
    expectEqual(buffer.elements, [4, 5], "grow keeps existing newest")
    expectEqual(buffer.capacity, 5, "grown capacity")

    buffer.removeAll()
    expect(buffer.isEmpty, "removeAll empties")
    expectEqual(buffer.count, 0, "removeAll count")
    expectEqual(buffer.elements, [], "removeAll elements")
    expectNil(buffer.last, "removeAll last")
}
