import SwiftUI

struct ForceQuitConfirmCard: View {
    let processName: String
    let action: ConfirmAction
    let onCancel: () -> Void
    let onConfirm: () -> Void

    @Environment(\.theme) private var theme

    init(
        processName: String,
        action: ConfirmAction,
        onCancel: @escaping () -> Void,
        onConfirm: @escaping () -> Void
    ) {
        self.processName = processName
        self.action = action
        self.onCancel = onCancel
        self.onConfirm = onConfirm
    }

    private var isForceQuit: Bool {
        if case .forceQuit = action { return true }
        return false
    }

    private var title: String {
        isForceQuit ? "Force quit \(processName)?" : "Terminate \(processName)?"
    }

    private var bodyText: String {
        if isForceQuit {
            return "This cannot be undone. Unsaved state in \(processName) will be lost."
        }
        return "The process is asked to quit and may save its state first."
    }

    private var holdTitle: String {
        isForceQuit ? "Hold to Force Quit" : "Hold to Terminate"
    }

    private var holdSeconds: Double {
        isForceQuit ? 1.0 : 0.5
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(Typography.pro(20, .semibold))
                .foregroundStyle(theme.text)
            Text(bodyText)
                .font(Typography.small)
                .foregroundStyle(theme.text2)
                .fixedSize(horizontal: false, vertical: true)
            buttons
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.crit.opacity(0.12), in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(theme.crit.opacity(0.40), lineWidth: Metrics.hairline)
        )
    }

    private var buttons: some View {
        GeometryReader { geo in
            let gap: CGFloat = 12
            let unit = max(0, geo.size.width - gap) / 2.4
            HStack(spacing: gap) {
                DashButton("Cancel", kind: .secondary, width: unit, action: onCancel)
                HoldToConfirmButton(
                    title: holdTitle,
                    holdSeconds: holdSeconds,
                    action: onConfirm
                )
                .frame(width: unit * 1.4)
            }
        }
        .frame(height: 56)
    }
}
