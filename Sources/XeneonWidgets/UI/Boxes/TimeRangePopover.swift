import SwiftUI
import XeneonWidgetsCore

struct TimeRangePopover: View {
    let selected: TimeRange
    let onSelect: (TimeRange) -> Void

    @Environment(\.theme) private var theme

    init(selected: TimeRange, onSelect: @escaping (TimeRange) -> Void) {
        self.selected = selected
        self.onSelect = onSelect
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Metrics.popoverRadius)
        HStack(spacing: 8) {
            ForEach(TimeRange.allCases, id: \.self) { range in
                Chip(title: range.label, selected: range == selected, height: 56) {
                    onSelect(range)
                }
                .frame(width: 92)
            }
        }
        .padding(8)
        .background(theme.sheet, in: shape)
        .overlay(shape.stroke(theme.hairline, lineWidth: Metrics.hairline))
        .shadow(color: Color.black.opacity(0.45), radius: 60, y: 20)
    }
}
