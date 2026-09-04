import SwiftUI
import XeneonWidgetsCore

private struct PageDotsVisibleKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var pageDotsVisible: Bool {
        get { self[PageDotsVisibleKey.self] }
        set { self[PageDotsVisibleKey.self] = newValue }
    }
}

struct DashboardRootView: View {
    let env: DashboardEnvironment

    @ObservedObject private var state: DashboardState
    @State private var dragOffset: CGFloat = 0
    @State private var showPageDots = false
    @State private var didNoteActivity = false
    @State private var dotsHideWork: DispatchWorkItem?
    @State private var swipeIsHorizontal: Bool?

    init(env: DashboardEnvironment) {
        self.env = env
        self._state = ObservedObject(wrappedValue: env.state)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            state.theme.bg
            HStack(spacing: 0) {
                OverviewPreset(env: env)
                    .frame(width: Metrics.screenWidth, height: Metrics.screenHeight)
                FocusCPUPreset(env: env)
                    .frame(width: Metrics.screenWidth, height: Metrics.screenHeight)
                FocusProcessesPreset(env: env)
                    .frame(width: Metrics.screenWidth, height: Metrics.screenHeight)
                AmbientPreset(env: env)
                    .frame(width: Metrics.screenWidth, height: Metrics.screenHeight)
            }
            .frame(width: Metrics.screenWidth, height: Metrics.screenHeight, alignment: .leading)
            .offset(x: pagerOffset)
            if state.editMode { EditToolbarHost(env: env) }
        }
        .frame(width: Metrics.screenWidth, height: Metrics.screenHeight, alignment: .topLeading)
        .clipped()
        .contentShape(Rectangle())
        .environment(\.theme, state.theme)
        .environment(\.pageDotsVisible, showPageDots)
        .simultaneousGesture(swipeGesture)
        .simultaneousGesture(activityGesture)
    }

    private var pagerOffset: CGFloat {
        -CGFloat(state.preset.index) * Metrics.screenWidth + dragOffset
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 40)
            .onChanged { value in
                guard !state.editMode else { return }
                noteActivityOnce()
                if swipeIsHorizontal == nil {
                    swipeIsHorizontal = abs(value.translation.height) <= abs(value.translation.width)
                }
                guard swipeIsHorizontal == true else {
                    dragOffset = 0
                    return
                }
                dragOffset = clampedDrag(value.translation.width)
            }
            .onEnded { value in
                guard !state.editMode else {
                    dragOffset = 0
                    swipeIsHorizontal = nil
                    return
                }
                finishActivity()
                let horizontal = swipeIsHorizontal ?? (abs(value.translation.height) <= abs(value.translation.width))
                swipeIsHorizontal = nil
                guard horizontal else {
                    withAnimation(Motion.presetSwipe) { dragOffset = 0 }
                    return
                }
                settleSwipe(translation: value.translation.width, predicted: value.predictedEndTranslation.width)
            }
    }

    private var activityGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { _ in
                noteActivityOnce()
            }
            .onEnded { _ in
                finishActivity()
            }
    }

    private func clampedDrag(_ raw: CGFloat) -> CGFloat {
        let index = state.preset.index
        let last = Preset.allCases.count - 1
        if index == 0 && raw > 0 { return 0 }
        if index == last && raw < 0 { return 0 }
        return raw
    }

    private func settleSwipe(translation: CGFloat, predicted: CGFloat) {
        let threshold: CGFloat = 80
        let index = state.preset.index
        let last = Preset.allCases.count - 1
        let goNext = (translation < -threshold || predicted < -threshold) && index < last
        let goPrev = (translation > threshold || predicted > threshold) && index > 0

        withAnimation(Motion.presetSwipe) {
            if goNext {
                state.preset = Preset.allCases[index + 1]
                revealPageDots()
            } else if goPrev {
                state.preset = Preset.allCases[index - 1]
                revealPageDots()
            }
            dragOffset = 0
        }
    }

    private func revealPageDots() {
        showPageDots = true
        dotsHideWork?.cancel()
        let work = DispatchWorkItem {
            showPageDots = false
        }
        dotsHideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: work)
    }

    private func noteActivityOnce() {
        guard !didNoteActivity else { return }
        didNoteActivity = true
        state.noteActivity()
    }

    private func finishActivity() {
        didNoteActivity = false
        state.noteActivity()
    }
}

struct PreviewScaledRoot: View {
    let env: DashboardEnvironment

    var body: some View {
        DashboardRootView(env: env)
            .frame(width: Metrics.screenWidth, height: Metrics.screenHeight)
            .scaleEffect(0.5, anchor: .topLeading)
            .frame(width: 1280, height: 360, alignment: .topLeading)
            .clipped()
    }
}
