import SwiftUI

struct ChipRow: View {
    let titles: [String]
    let selectedIndex: Int
    let height: CGFloat
    let onSelect: (Int) -> Void
    let onLongPress: ((Int) -> Void)?

    @State private var longPressGate = ChipLongPressGate()

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
                    if longPressGate.consume(index) { return }
                    onSelect(index)
                }
                .simultaneousGesture(
                    LongPressGesture(minimumDuration: 0.6)
                        .onEnded { _ in
                            longPressGate.mark(index)
                            onLongPress?(index)
                        }
                )
            }
        }
    }
}

/// Synchronous flag so a recognised long-press can suppress the Button tap on lift.
/// `@State` would update too late — `LongPressGesture.onEnded` and the button action run in the same turn.
private final class ChipLongPressGate {
    private var index: Int?

    func mark(_ index: Int) {
        self.index = index
    }

    func consume(_ index: Int) -> Bool {
        guard self.index == index else { return false }
        self.index = nil
        return true
    }
}
