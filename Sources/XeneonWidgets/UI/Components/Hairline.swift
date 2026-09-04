import SwiftUI

struct Hairline: View {
    let vertical: Bool

    @Environment(\.theme) private var theme

    init(vertical: Bool = false) {
        self.vertical = vertical
    }

    var body: some View {
        Rectangle()
            .fill(theme.hairline)
            .frame(
                width: vertical ? Metrics.hairline : nil,
                height: vertical ? nil : Metrics.hairline
            )
            .frame(
                maxWidth: vertical ? Metrics.hairline : .infinity,
                maxHeight: vertical ? .infinity : Metrics.hairline
            )
    }
}
