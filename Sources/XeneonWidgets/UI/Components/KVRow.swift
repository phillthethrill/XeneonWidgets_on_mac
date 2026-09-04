import SwiftUI

struct KVRow: View {
    let key: String
    let value: String
    let valueColor: Color?
    let mono: Bool

    @Environment(\.theme) private var theme

    init(key: String, value: String, valueColor: Color? = nil, mono: Bool = true) {
        self.key = key
        self.value = value
        self.valueColor = valueColor
        self.mono = mono
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(key)
                .font(Typography.small)
                .foregroundStyle(theme.text3)
            Spacer(minLength: 12)
            valueText
                .foregroundStyle(valueColor ?? theme.text2)
        }
        .lineLimit(1)
    }

    @ViewBuilder
    private var valueText: some View {
        if mono {
            Text(value)
                .font(Typography.smallMono)
                .monoDigits()
        } else {
            Text(value)
                .font(Typography.small)
        }
    }
}
