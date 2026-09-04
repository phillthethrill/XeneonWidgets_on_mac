import SwiftUI

enum ButtonKind {
    case primary, secondary, destructive, destructiveTinted
}

struct DashButton: View {
    let title: String
    let kind: ButtonKind
    let width: CGFloat?
    let height: CGFloat
    let action: () -> Void

    @Environment(\.theme) private var theme

    init(_ title: String, kind: ButtonKind = .secondary, width: CGFloat? = nil, height: CGFloat = 56, action: @escaping () -> Void) {
        self.title = title
        self.kind = kind
        self.width = width
        self.height = height
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Typography.button)
                .foregroundStyle(labelColor)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(.plain)
        .frame(width: width, height: height)
        .frame(maxWidth: width == nil ? .infinity : nil)
        .background(fillColor)
        .clipShape(RoundedRectangle(cornerRadius: Metrics.buttonRadius))
        .overlay {
            if kind == .secondary {
                RoundedRectangle(cornerRadius: Metrics.buttonRadius)
                    .stroke(theme.hairline, lineWidth: Metrics.hairline)
            } else if kind == .destructiveTinted {
                RoundedRectangle(cornerRadius: Metrics.buttonRadius)
                    .stroke(theme.crit.opacity(0.50), lineWidth: Metrics.hairline)
            }
        }
    }

    private var fillColor: Color {
        switch kind {
        case .primary: return theme.text
        case .secondary: return theme.surface2
        case .destructive: return theme.crit
        case .destructiveTinted: return theme.crit.opacity(0.18)
        }
    }

    private var labelColor: Color {
        switch kind {
        case .primary: return theme.bg
        case .secondary: return theme.text
        case .destructive: return .white
        case .destructiveTinted: return theme.crit
        }
    }
}
