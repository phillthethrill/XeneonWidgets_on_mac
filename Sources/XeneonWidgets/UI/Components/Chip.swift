import SwiftUI

struct Chip: View {
    let title: String
    let selected: Bool
    let height: CGFloat
    let action: () -> Void

    @Environment(\.theme) private var theme

    init(title: String, selected: Bool, height: CGFloat = 56, action: @escaping () -> Void) {
        self.title = title
        self.selected = selected
        self.height = height
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Typography.chip)
                .foregroundStyle(selected ? theme.bg : theme.text2)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(.plain)
        .frame(height: height)
        .background(selected ? theme.text : theme.surface2)
        .clipShape(RoundedRectangle(cornerRadius: Metrics.chipRadius))
        .overlay {
            if !selected {
                RoundedRectangle(cornerRadius: Metrics.chipRadius)
                    .stroke(theme.hairline, lineWidth: Metrics.hairline)
            }
        }
    }
}
