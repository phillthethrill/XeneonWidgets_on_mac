import SwiftUI

struct BoxContainer<Content: View>: View {
    let title: String
    let meta: String?
    let value: String?
    let valueColor: Color?
    let glow: Color?
    let padding: CGFloat
    let gap: CGFloat
    let content: Content

    @Environment(\.theme) private var theme

    init(
        title: String,
        meta: String? = nil,
        value: String? = nil,
        valueColor: Color? = nil,
        glow: Color? = nil,
        padding: CGFloat = Metrics.boxPadding,
        gap: CGFloat = Metrics.innerGap,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.meta = meta
        self.value = value
        self.valueColor = valueColor
        self.glow = glow
        self.padding = padding
        self.gap = gap
        self.content = content()
    }

    var body: some View {
        let radius = Metrics.boxRadius
        let shape = RoundedRectangle(cornerRadius: radius)
        VStack(alignment: .leading, spacing: gap) {
            header
            content
        }
        .padding(padding)
        .background(theme.surface, in: shape)
        .overlay(shape.stroke(glow ?? theme.hairline, lineWidth: Metrics.hairline))
        .clipShape(shape)
        .modifier(BoxGlow(color: glow))
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 14) {
                Text(title)
                    .font(Typography.boxTitle)
                    .tracking(2.4)
                    .textCase(.lowercase)
                    .foregroundStyle(theme.text2)
                if let meta {
                    Text(meta)
                        .font(Typography.small)
                        .foregroundStyle(theme.text3)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let value {
                Text(value)
                    .font(Typography.boxValue)
                    .monoDigits()
                    .foregroundStyle(valueColor ?? theme.text)
                    .lineLimit(1)
            }
        }
        .frame(minHeight: 28)
    }
}

private struct BoxGlow: ViewModifier {
    let color: Color?

    func body(content: Content) -> some View {
        if let color {
            content
                .shadow(color: color, radius: 0.5)
                .shadow(color: color, radius: 17)
        } else {
            content
        }
    }
}
