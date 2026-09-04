import SwiftUI
import XeneonWidgetsCore

struct InterfacePopover: View {
    let interfaces: [NetInterface]
    let selected: NetworkSelection
    let onSelect: (NetworkSelection) -> Void

    @Environment(\.theme) private var theme

    init(
        interfaces: [NetInterface],
        selected: NetworkSelection,
        onSelect: @escaping (NetworkSelection) -> Void
    ) {
        self.interfaces = interfaces
        self.selected = selected
        self.onSelect = onSelect
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            row(
                title: "Auto",
                subtitle: "sum en*",
                isSelected: selected == .auto
            ) {
                onSelect(.auto)
            }
            ForEach(interfaces) { iface in
                row(
                    title: iface.kind.rawValue,
                    subtitle: subtitle(for: iface),
                    isSelected: selected == .interface(iface.name)
                ) {
                    onSelect(.interface(iface.name))
                }
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.sheet, in: RoundedRectangle(cornerRadius: Metrics.popoverRadius))
        .overlay(
            RoundedRectangle(cornerRadius: Metrics.popoverRadius)
                .stroke(theme.hairline, lineWidth: Metrics.hairline)
        )
        .shadow(color: Color.black.opacity(0.45), radius: 60, x: 0, y: 20)
    }

    private func subtitle(for iface: NetInterface) -> String {
        "\(iface.name) · \(iface.ipv4 ?? "no link")"
    }

    private func row(
        title: String,
        subtitle: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(title)
                    .font(Typography.body)
                    .foregroundStyle(theme.text)
                    .lineLimit(1)
                Spacer(minLength: 8)
                HStack(spacing: 6) {
                    Text(subtitle)
                        .font(Typography.mono(14))
                        .monoDigits()
                        .foregroundStyle(theme.text3)
                        .lineLimit(1)
                    if isSelected {
                        Text("✓")
                            .font(Typography.mono(14))
                            .foregroundStyle(theme.text)
                    }
                }
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: 56, maxHeight: 56, alignment: .leading)
            .background(isSelected ? theme.surface2 : Color.clear, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}
