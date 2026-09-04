public struct BoxPlacement: Codable, Equatable, Sendable {
    public var id: BoxID
    public var width: Double
    public var hidden: Bool

    public init(id: BoxID, width: Double, hidden: Bool = false) {
        self.id = id
        self.width = width
        self.hidden = hidden
    }
}

public struct LayoutSpec: Codable, Equatable, Sendable {
    public static let contentWidth: Double = 2512
    public static let gap: Double = 16
    public static let minBoxWidth: Double = 320

    public var boxes: [BoxPlacement]

    public init(boxes: [BoxPlacement]) {
        self.boxes = boxes
    }

    public static func `default`(for preset: Preset) -> LayoutSpec {
        switch preset {
        case .overview:
            return LayoutSpec(boxes: [
                BoxPlacement(id: .cpu, width: 740),
                BoxPlacement(id: .mem, width: 600),
                BoxPlacement(id: .net, width: 480),
                BoxPlacement(id: .proc, width: 644),
                BoxPlacement(id: .gpu, width: 480, hidden: true),
                BoxPlacement(id: .battery, width: 480, hidden: true),
                BoxPlacement(id: .clock, width: 480, hidden: true),
            ])
        case .focusCPU:
            return LayoutSpec(boxes: [
                BoxPlacement(id: .cpu, width: 1500),
                BoxPlacement(id: .mem, width: 480),
                BoxPlacement(id: .net, width: 500),
                BoxPlacement(id: .proc, width: 644, hidden: true),
                BoxPlacement(id: .gpu, width: 480, hidden: true),
                BoxPlacement(id: .battery, width: 480, hidden: true),
                BoxPlacement(id: .clock, width: 480, hidden: true),
            ])
        case .focusProcesses:
            return LayoutSpec(boxes: [
                BoxPlacement(id: .proc, width: 2512),
                BoxPlacement(id: .cpu, width: 740, hidden: true),
                BoxPlacement(id: .mem, width: 600, hidden: true),
                BoxPlacement(id: .net, width: 480, hidden: true),
                BoxPlacement(id: .gpu, width: 480, hidden: true),
                BoxPlacement(id: .battery, width: 480, hidden: true),
                BoxPlacement(id: .clock, width: 480, hidden: true),
            ])
        case .ambient:
            return LayoutSpec(boxes: [])
        }
    }

    public var visible: [BoxPlacement] {
        boxes.filter { !$0.hidden }
    }

    public var hiddenIDs: [BoxID] {
        boxes.filter(\.hidden).map(\.id)
    }

    public mutating func hide(_ id: BoxID) {
        if let index = boxes.firstIndex(where: { $0.id == id }) {
            boxes[index].hidden = true
        }
        normalize()
    }

    public mutating func show(_ id: BoxID) {
        if let index = boxes.firstIndex(where: { $0.id == id }) {
            boxes[index].hidden = false
            boxes[index].width = Self.minBoxWidth
        } else {
            boxes.append(BoxPlacement(id: id, width: Self.minBoxWidth))
        }
        normalize()
    }

    public mutating func move(_ id: BoxID, to index: Int) {
        let visibleIDs = visible.map(\.id)
        guard let current = visibleIDs.firstIndex(of: id) else { return }
        var reordered = visibleIDs
        reordered.remove(at: current)
        let clamped = min(max(index, 0), reordered.count)
        reordered.insert(id, at: clamped)

        var remaining = Dictionary(uniqueKeysWithValues: boxes.map { ($0.id, $0) })
        var next: [BoxPlacement] = []
        for visibleID in reordered {
            if var placement = remaining.removeValue(forKey: visibleID) {
                placement.hidden = false
                next.append(placement)
            }
        }
        for original in boxes {
            if let placement = remaining.removeValue(forKey: original.id) {
                next.append(placement)
            }
        }
        boxes = next
    }

    public mutating func resize(_ id: BoxID, width: Double) {
        guard let boxIndex = boxes.firstIndex(where: { $0.id == id && !$0.hidden }) else { return }
        let newWidth = max(width, Self.minBoxWidth)
        let delta = newWidth - boxes[boxIndex].width
        boxes[boxIndex].width = newWidth

        let visibleIDs = visible.map(\.id)
        guard let visibleIndex = visibleIDs.firstIndex(of: id) else { return }
        let neighbourID: BoxID?
        if visibleIndex + 1 < visibleIDs.count {
            neighbourID = visibleIDs[visibleIndex + 1]
        } else if visibleIndex > 0 {
            neighbourID = visibleIDs[visibleIndex - 1]
        } else {
            neighbourID = nil
        }

        if let neighbourID, let neighbourIndex = boxes.firstIndex(where: { $0.id == neighbourID }) {
            boxes[neighbourIndex].width = max(Self.minBoxWidth, boxes[neighbourIndex].width - delta)
        }
        normalize()
    }

    public mutating func normalize() {
        let visibleIndexes = boxes.indices.filter { !boxes[$0].hidden }
        let count = visibleIndexes.count
        guard count > 0 else { return }
        let target = Self.contentWidth - Self.gap * Double(count - 1)
        let current = visibleIndexes.reduce(0.0) { $0 + boxes[$1].width }
        guard current > 0 else { return }
        let scale = target / current
        for index in visibleIndexes {
            boxes[index].width *= scale
        }
    }
}
