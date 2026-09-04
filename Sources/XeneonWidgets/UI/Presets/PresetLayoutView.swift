import SwiftUI
import XeneonWidgetsCore

struct PresetLayoutView: View {
    let env: DashboardEnvironment
    let preset: Preset
    let box: (BoxPlacement) -> AnyView

    @ObservedObject private var state: DashboardState
    @Environment(\.pageDotsVisible) private var showPageDots

    init(
        env: DashboardEnvironment,
        preset: Preset,
        @ViewBuilder box: @escaping (BoxPlacement) -> AnyView
    ) {
        self.env = env
        self.preset = preset
        self.box = box
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

            HStack(spacing: 16) {
                ForEach(spec.visible, id: \.id) { placement in
                    box(placement)
                        .frame(width: placement.width, height: Metrics.bodyHeight)
                }
            }
        }
        .padding(24)
        .frame(width: Metrics.screenWidth, height: Metrics.screenHeight)
    }
}
