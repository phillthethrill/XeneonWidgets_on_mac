import SwiftUI

struct Legend: View {
    let items: [(label: String, value: String, color: Color, opacity: Double)]
    let columns: Int

    @Environment(\.theme) private var theme

    init(items: [(label: String, value: String, color: Color, opacity: Double)], columns: Int = 2) {
        self.items = items
        self.columns = columns
    }

    var body: some View {
        let grid = Array(repeating: GridItem(.flexible(), spacing: 20), count: max(columns, 1))
        LazyVGrid(columns: grid, alignment: .leading, spacing: 8) {
            ForEach(items.indices, id: \.self) { index in
                let item = items[index]
                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(item.color.opacity(item.opacity))
                        .frame(width: 10, height: 10)
                    Text(item.label)
                        .font(Typography.small)
                        .foregroundStyle(theme.text3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(item.value)
                        .font(Typography.smallMono)
                        .monoDigits()
                        .foregroundStyle(theme.text2)
                }
            }
        }
    }
}
