import AppKit
import SwiftUI

struct AppIconView: View {
    let image: NSImage?
    let size: CGFloat

    @Environment(\.theme) private var theme

    init(image: NSImage?, size: CGFloat) {
        self.image = image
        self.size = size
    }

    var body: some View {
        let radius = size * 0.24
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFill()
            } else {
                theme.surface2
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: radius))
    }
}
