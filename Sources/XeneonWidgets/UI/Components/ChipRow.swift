import SwiftUI

struct ChipRow: View {
    let titles: [String]
    let selectedIndex: Int
    let height: CGFloat
    let onSelect: (Int) -> Void
    let onLongPress: ((Int) -> Void)?

    init(
        titles: [String],
        selectedIndex: Int,
        height: CGFloat = 56,
        onSelect: @escaping (Int) -> Void,
        onLongPress: ((Int) -> Void)? = nil
    ) {
        self.titles = titles
        self.selectedIndex = selectedIndex
        self.height = height
        self.onSelect = onSelect
        self.onLongPress = onLongPress
    }

    var body: some View {
        HStack(spacing: 8) {
            ForEach(titles.indices, id: \.self) { index in
                Chip(title: titles[index], selected: index == selectedIndex, height: height) {
                    onSelect(index)
                }
                .simultaneousGesture(
                    LongPressGesture(minimumDuration: 0.6)
                        .onEnded { _ in onLongPress?(index) }
                )
            }
        }
    }
}
