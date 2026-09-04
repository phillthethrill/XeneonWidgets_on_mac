import AppKit
import SwiftUI

final class WidgetWindow: NSPanel {
    private let allowsKey: Bool

    override var canBecomeKey: Bool { allowsKey }
    override var canBecomeMain: Bool { allowsKey }

    init(screen: NSScreen, contentView: some View) {
        allowsKey = false
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
        self.hidesOnDeactivate = false
        self.contentViewController = NSHostingController(rootView: contentView)
        self.setFrame(screen.frame, display: true)
    }

    init(previewOn screen: NSScreen, contentView: some View) {
        allowsKey = true
        let contentRect = NSRect(x: 0, y: 0, width: 1280, height: 360)
        super.init(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        self.title = "XeneonWidgets Preview"
        self.level = .statusBar
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        self.isOpaque = true
        self.backgroundColor = .black
        self.hasShadow = true
        self.hidesOnDeactivate = false
        self.isFloatingPanel = true
        let host = NSHostingController(rootView: contentView)
        host.view.frame = contentRect
        self.contentViewController = host
        self.setContentSize(NSSize(width: 1280, height: 360))
        let visible = screen.visibleFrame
        let size = frame.size
        setFrameOrigin(NSPoint(
            x: visible.midX - size.width / 2,
            y: visible.midY - size.height / 2
        ))
    }
}
