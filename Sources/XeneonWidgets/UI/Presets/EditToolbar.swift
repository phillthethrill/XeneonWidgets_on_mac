import SwiftUI
import XeneonWidgetsCore

struct EditToolbar: View {
    let presetTitle: String
    let hidden: [BoxID]
    let onShow: (BoxID) -> Void
    let onReset: () -> Void
    let onDone: () -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 12) {
            Text("Editing · \(presetTitle)")
                .font(Typography.small)
                .foregroundStyle(theme.text3)
                .padding(.horizontal, 8)

            Hairline(vertical: true)
                .frame(height: 40)

            Text("Hidden")
                .font(Typography.small)
                .foregroundStyle(theme.text3)
                .padding(.leading, 8)

            ForEach(hidden, id: \.self) { id in
                Chip(title: "+ \(id.displayName)", selected: false) {
                    onShow(id)
                }
                .frame(width: 140, height: 56)
            }

            Hairline(vertical: true)
                .frame(height: 40)

            DashButton("Reset", kind: .secondary, width: 160, action: onReset)
            DashButton("Done", kind: .primary, width: 160, action: onDone)
        }
        .padding(10)
        .background(theme.sheet, in: RoundedRectangle(cornerRadius: Metrics.sheetRadius))
        .overlay {
            RoundedRectangle(cornerRadius: Metrics.sheetRadius)
                .stroke(theme.hairline, lineWidth: Metrics.hairline)
        }
        .shadow(color: Color.black.opacity(0.5), radius: 70, x: 0, y: 24)
    }
}

struct EditToolbarHost: View {
    let env: DashboardEnvironment

    @ObservedObject private var state: DashboardState

    init(env: DashboardEnvironment) {
        self.env = env
        self._state = ObservedObject(wrappedValue: env.state)
    }

    var body: some View {
        let spec = state.layout(for: state.preset)
        EditToolbar(
            presetTitle: state.preset.title,
            hidden: Self.hiddenChipOrder(spec.hiddenIDs),
            onShow: { id in
                var next = state.layout(for: state.preset)
                next.show(id)
                withAnimation(Motion.siblingSlide) {
                    state.updateLayout(next, for: state.preset)
                }
                state.noteActivity()
            },
            onReset: {
                withAnimation(Motion.siblingSlide) {
                    state.resetLayout(for: state.preset)
                }
                state.noteActivity()
            },
            onDone: {
                state.editMode = false
                state.noteActivity()
            }
        )
        .padding(.bottom, 16)
        .frame(width: Metrics.screenWidth, height: Metrics.screenHeight, alignment: .bottom)
        .zIndex(100)
    }

    /// JSX toolbar order is Battery, GPU, Clock; remaining hidden ids keep layout order.
    private static func hiddenChipOrder(_ ids: [BoxID]) -> [BoxID] {
        let preferred: [BoxID] = [.battery, .gpu, .clock]
        return preferred.filter(ids.contains) + ids.filter { !preferred.contains($0) }
    }
}
