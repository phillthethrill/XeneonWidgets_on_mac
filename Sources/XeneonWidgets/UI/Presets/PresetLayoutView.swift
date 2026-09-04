import SwiftUI
import XeneonWidgetsCore

struct PresetLayoutView<Overlay: View>: View {
    let env: DashboardEnvironment
    let preset: Preset
    let box: (BoxPlacement) -> AnyView
    let bodyOverlay: Overlay

    @ObservedObject private var state: DashboardState
    @Environment(\.pageDotsVisible) private var showPageDots

    @State private var draggingID: BoxID?
    @State private var dragTranslation: CGFloat = 0
    @State private var dragStartSpec: LayoutSpec?
    @State private var dragStartOrigins: [BoxID: CGFloat] = [:]
    @State private var resizingID: BoxID?
    @State private var resizeStartSpec: LayoutSpec?
    @State private var resizeStartWidth: Double = 0

    init(
        env: DashboardEnvironment,
        preset: Preset,
        @ViewBuilder box: @escaping (BoxPlacement) -> AnyView,
        @ViewBuilder bodyOverlay: () -> Overlay
    ) {
        self.env = env
        self.preset = preset
        self.box = box
        self.bodyOverlay = bodyOverlay()
        self._state = ObservedObject(wrappedValue: env.state)
    }

    var body: some View {
        let spec = state.layouts[preset] ?? LayoutSpec.default(for: preset)
        VStack(spacing: 16) {
            HeaderBar(
                clock: env.clock,
                power: env.power,
                state: state,
                onAlertTap: { _ in state.noteActivity() },
                showPageDots: showPageDots
            )
            .frame(height: 56)

            ZStack(alignment: .trailing) {
                HStack(spacing: 16) {
                    ForEach(Array(spec.visible.enumerated()), id: \.element.id) { index, placement in
                        editableBox(placement: placement, index: index, spec: spec)
                    }
                }
                bodyOverlay
            }
            .frame(width: Metrics.contentWidth, height: Metrics.bodyHeight)
        }
        .padding(24)
        .frame(width: Metrics.screenWidth, height: Metrics.screenHeight)
    }

    @ViewBuilder
    private func editableBox(placement: BoxPlacement, index: Int, spec: LayoutSpec) -> some View {
        let editing = state.editMode
        let dragging = draggingID == placement.id
        let tilt = index.isMultiple(of: 2) ? -Motion.editTiltDegrees : Motion.editTiltDegrees

        ZStack {
            box(placement)
                .allowsHitTesting(!editing)
                .rotationEffect(.degrees(editing ? tilt : 0))

            if editing {
                EditModeOverlay(
                    index: index,
                    onHide: { hide(placement.id) },
                    onResize: { delta in resize(placement.id, delta: delta) },
                    onResizeEnd: endResize
                )
            }
        }
        .frame(width: placement.width, height: Metrics.bodyHeight)
        .contentShape(Rectangle())
        .shadow(
            color: dragging ? Color.black.opacity(0.5) : .clear,
            radius: 80,
            x: 0,
            y: 30
        )
        .offset(x: dragging ? dragVisualOffset(for: placement.id, spec: spec) : 0)
        .zIndex(dragging ? 10 : 0)
        .simultaneousGesture(enterEditGesture)
        .editBoxDrag(enabled: editing && resizingID == nil, gesture: boxDrag(for: placement, spec: spec))
    }

    private var enterEditGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.6)
            .onEnded { _ in
                guard !state.editMode else { return }
                state.editMode = true
                state.noteActivity()
            }
    }

    private func boxDrag(for placement: BoxPlacement, spec: LayoutSpec) -> some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                guard resizingID == nil else { return }
                if draggingID == nil {
                    draggingID = placement.id
                    dragStartSpec = spec
                    dragStartOrigins = origins(of: spec)
                }
                dragTranslation = value.translation.width
                applyReorder(id: placement.id)
            }
            .onEnded { _ in
                draggingID = nil
                dragTranslation = 0
                dragStartSpec = nil
                dragStartOrigins = [:]
                state.noteActivity()
            }
    }

    private func applyReorder(id: BoxID) {
        guard let startSpec = dragStartSpec,
              let startX = dragStartOrigins[id],
              let startBox = startSpec.visible.first(where: { $0.id == id })
        else { return }

        let center = startX + CGFloat(startBox.width) / 2 + dragTranslation
        var target = 0
        for box in startSpec.visible where box.id != id {
            if let origin = dragStartOrigins[box.id] {
                let mid = origin + CGFloat(box.width) / 2
                if mid < center {
                    target += 1
                }
            }
        }

        let currentIndex = (state.layouts[preset] ?? startSpec).visible.firstIndex(where: { $0.id == id })
        guard currentIndex != target else { return }

        var next = startSpec
        next.move(id, to: target)
        withAnimation(Motion.siblingSlide) {
            state.updateLayout(next, for: preset)
        }
    }

    private func hide(_ id: BoxID) {
        var spec = state.layout(for: preset)
        spec.hide(id)
        withAnimation(Motion.siblingSlide) {
            state.updateLayout(spec, for: preset)
        }
        state.noteActivity()
    }

    private func resize(_ id: BoxID, delta: CGFloat) {
        if resizeStartSpec == nil {
            let spec = state.layout(for: preset)
            resizeStartSpec = spec
            resizeStartWidth = spec.boxes.first(where: { $0.id == id })?.width ?? 0
            resizingID = id
            draggingID = nil
            dragTranslation = 0
            dragStartSpec = nil
            dragStartOrigins = [:]
        }
        guard var spec = resizeStartSpec else { return }
        spec.resize(id, width: resizeStartWidth + Double(delta))
        state.updateLayout(spec, for: preset)
    }

    private func endResize() {
        resizeStartSpec = nil
        resizeStartWidth = 0
        resizingID = nil
        state.noteActivity()
    }

    private func origins(of spec: LayoutSpec) -> [BoxID: CGFloat] {
        var x: CGFloat = 0
        var result: [BoxID: CGFloat] = [:]
        for box in spec.visible {
            result[box.id] = x
            x += CGFloat(box.width) + Metrics.boxGap
        }
        return result
    }

    private func dragVisualOffset(for id: BoxID, spec: LayoutSpec) -> CGFloat {
        let startX = dragStartOrigins[id] ?? 0
        let currentX = origins(of: spec)[id] ?? startX
        return dragTranslation - (currentX - startX)
    }
}

extension PresetLayoutView where Overlay == EmptyView {
    init(
        env: DashboardEnvironment,
        preset: Preset,
        @ViewBuilder box: @escaping (BoxPlacement) -> AnyView
    ) {
        self.init(env: env, preset: preset, box: box, bodyOverlay: { EmptyView() })
    }
}

private extension View {
    @ViewBuilder
    func editBoxDrag<G: Gesture>(enabled: Bool, gesture: G) -> some View {
        if enabled {
            self.gesture(gesture)
        } else {
            self
        }
    }
}
