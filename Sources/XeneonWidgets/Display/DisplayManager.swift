import AppKit

struct DisplayManager {
    /// Returns the Xeneon Edge NSScreen, or nil if not connected.
    static var xeneonScreen: NSScreen? {
        NSScreen.screens.first { screen in
            if screen.localizedName.localizedCaseInsensitiveContains("xeneon") {
                return true
            }
            let sz = screen.frame.size
            // Actual device: 2560x720. Spec also mentions 1280x800 (alternate firmware/mode).
            return (sz.width == 2560 && sz.height == 720)
                || (sz.width == 1280 && sz.height == 800)
        }
    }
}
