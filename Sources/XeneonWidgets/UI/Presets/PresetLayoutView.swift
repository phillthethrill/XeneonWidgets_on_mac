import SwiftUI
import XeneonWidgetsCore

struct PresetLayoutView<Overlay: View>: View {
    let env: DashboardEnvironment
    let preset: Preset
    let box: (BoxPlacement) -> AnyView
    let bodyOverlay: Overlay

    @ObservedObject private var state: DashboardState
    @Environment(\.pageDotsVisible) private var showPageDots

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
                    ForEach(spec.visible, id: \.id) { placement in
                        box(placement)
                            .frame(width: placement.width, height: Metrics.bodyHeight)
                    }
                }
                bodyOverlay
            }
            .frame(width: Metrics.contentWidth, height: Metrics.bodyHeight)
        }
        .padding(24)
        .frame(width: Metrics.screenWidth, height: Metrics.screenHeight)
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
