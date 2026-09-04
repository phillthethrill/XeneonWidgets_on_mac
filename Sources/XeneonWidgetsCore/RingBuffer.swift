public struct RingBuffer<Element>: Equatable where Element: Equatable {
    public private(set) var capacity: Int
    private var storage: [Element?]
    private var head: Int
    private var storedCount: Int

    public init(capacity: Int) {
        precondition(capacity >= 1, "RingBuffer capacity must be ≥ 1")
        self.capacity = capacity
        self.storage = Array(repeating: nil, count: capacity)
        self.head = 0
        self.storedCount = 0
    }

    public var count: Int { storedCount }

    public var isEmpty: Bool { storedCount == 0 }

    public var last: Element? {
        guard storedCount > 0 else { return nil }
        return storage[index(offset: storedCount - 1)]
    }

    public mutating func append(_ element: Element) {
        if storedCount < capacity {
            storage[index(offset: storedCount)] = element
            storedCount += 1
        } else {
            storage[head] = element
            head = (head + 1) % capacity
        }
    }

    public var elements: [Element] {
        (0..<storedCount).compactMap { storage[index(offset: $0)] }
    }

    public func suffix(_ n: Int) -> [Element] {
        guard n > 0 else { return [] }
        let start = max(storedCount - n, 0)
        return (start..<storedCount).compactMap { storage[index(offset: $0)] }
    }

    public mutating func resize(capacity: Int) {
        precondition(capacity >= 1, "RingBuffer capacity must be ≥ 1")
        let kept = Array(elements.suffix(capacity))
        self.capacity = capacity
        storage = Array(repeating: nil, count: capacity)
        head = 0
        storedCount = 0
        for element in kept {
            append(element)
        }
    }

    public mutating func removeAll() {
        storage = Array(repeating: nil, count: capacity)
        head = 0
        storedCount = 0
    }

    public static func == (lhs: RingBuffer<Element>, rhs: RingBuffer<Element>) -> Bool {
        lhs.capacity == rhs.capacity && lhs.elements == rhs.elements
    }

    private func index(offset: Int) -> Int {
        (head + offset) % capacity
    }
}
