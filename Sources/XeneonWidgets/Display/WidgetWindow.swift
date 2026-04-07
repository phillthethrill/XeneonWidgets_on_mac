import AppKit
import SwiftUI

final class WidgetWindow: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    init(screen: NSScreen, contentView: some View) {
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenNone]
        self.isOpaque = true
        self.backgroundColor = .black
        self.hasShadow = false
        self.contentViewController = NSHostingController(rootView: contentView)
        self.setFrame(screen.frame, display: true)
    }
}
