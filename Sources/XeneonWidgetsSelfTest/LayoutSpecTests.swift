import Foundation
import XeneonWidgetsCore

func runLayoutSpecTests() {
    let overview = LayoutSpec.default(for: .overview)
    expectEqual(overview.visible.map(\.id), [.cpu, .mem, .net, .proc], "overview visible order")
    expectClose(sumWithGaps(overview.visible), LayoutSpec.contentWidth, "overview fills content width")
    expectEqual(overview.visible.map(\.width), [740, 600, 480, 644], "overview widths")
    expectEqual(overview.hiddenIDs, [.gpu, .battery, .clock], "overview hidden")

    let focusCPU = LayoutSpec.default(for: .focusCPU)
    expectEqual(focusCPU.visible.map(\.id), [.cpu, .mem, .net], "focusCPU visible")
    expectClose(sumWithGaps(focusCPU.visible), LayoutSpec.contentWidth, "focusCPU fills content width")
    expectEqual(focusCPU.visible.map(\.width), [1500, 480, 500], "focusCPU widths")

    let focusProc = LayoutSpec.default(for: .focusProcesses)
    expectEqual(focusProc.visible.map(\.id), [.proc], "focusProcesses only proc")
    expectClose(focusProc.visible[0].width, 2512, "focusProcesses full width")
    expect(focusProc.hiddenIDs.contains(.cpu), "focusProcesses hides others")

    let ambient = LayoutSpec.default(for: .ambient)
    expectEqual(ambient.boxes, [], "ambient empty")
    expectEqual(ambient.visible, [], "ambient visible empty")

    var afterHide = overview
    afterHide.hide(.proc)
    expectEqual(afterHide.visible.count, 3, "hide proc leaves 3")
    expect(!afterHide.visible.contains(where: { $0.id == .proc }), "proc hidden")
    expectClose(sumWithGaps(afterHide.visible), LayoutSpec.contentWidth, "hide renormalizes")

    var afterShow = overview
    afterShow.show(.gpu)
    expectEqual(afterShow.visible.count, 5, "show gpu → 5 visible")
    expect(afterShow.visible.contains(where: { $0.id == .gpu }), "gpu visible")
    expectClose(sumWithGaps(afterShow.visible), LayoutSpec.contentWidth, "show renormalizes")

    var afterMove = overview
    afterMove.move(.mem, to: 0)
    expectEqual(afterMove.visible.map(\.id), [.mem, .cpu, .net, .proc], "move mem to front")

    var afterResize = overview
    afterResize.resize(.cpu, width: 900)
    expectClose(width(of: .cpu, in: afterResize), 900, "cpu resized to 900")
    expectClose(width(of: .mem, in: afterResize), 440, "mem shrinks by 160")
    expectClose(sumWithGaps(afterResize.visible), LayoutSpec.contentWidth, "resize stays normalized")

    var clamped = overview
    clamped.resize(.cpu, width: 100)
    expect(width(of: .cpu, in: clamped) >= LayoutSpec.minBoxWidth, "resize never below min")
    expect(clamped.visible.allSatisfy { $0.width >= LayoutSpec.minBoxWidth }, "neighbours stay ≥ min")

    var grown = LayoutSpec.default(for: .overview)
    grown.resize(.cpu, width: 1500)
    expect(grown.visible.allSatisfy { $0.width >= LayoutSpec.minBoxWidth }, "resize keeps min")
    expectClose(sumWithGaps(grown.visible), LayoutSpec.contentWidth, "still fills width")

    do {
        let data = try JSONEncoder().encode(overview)
        let decoded = try JSONDecoder().decode(LayoutSpec.self, from: data)
        expectEqual(decoded, overview, "Codable round-trip")
    } catch {
        expect(false, "Codable round-trip threw \(error)")
    }
}

private func sumWithGaps(_ boxes: [BoxPlacement]) -> Double {
    guard !boxes.isEmpty else { return 0 }
    return boxes.reduce(0) { $0 + $1.width } + LayoutSpec.gap * Double(boxes.count - 1)
}

private func width(of id: BoxID, in spec: LayoutSpec) -> Double {
    spec.boxes.first(where: { $0.id == id })?.width ?? -1
}
