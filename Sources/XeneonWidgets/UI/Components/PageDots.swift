import SwiftUI

struct PageDots: View {
    let count: Int
    let index: Int

    @Environment(\.theme) private var theme

    init(count: Int, index: Int) {
        self.count = count
        self.index = index
    }

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<count, id: \.self) { i in
                Circle()
                    .fill(i == index ? theme.text : theme.text3)
                    .frame(width: 6, height: 6)
            }
        }
    }
}
