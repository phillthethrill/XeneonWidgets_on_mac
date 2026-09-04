import SwiftUI

struct GlanceModifier: ViewModifier {
    @ObservedObject var state: DashboardState
    @ObservedObject var glance: GlanceController

    func body(content: Content) -> some View {
        content
            .opacity(state.glance ? 0.6 : 1)
            .offset(glance.driftOffset)
            .animation(.easeInOut(duration: 1), value: state.glance)
            .animation(.easeInOut(duration: 1), value: glance.driftOffset)
    }
}

extension View {
    func glanceEffect(_ env: DashboardEnvironment) -> some View {
        modifier(GlanceModifier(state: env.state, glance: env.glance))
    }
}
