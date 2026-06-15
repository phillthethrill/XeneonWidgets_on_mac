import AppKit
import XeneonWidgetsCore

struct DisplayManager {
    private static let preferredDisplayKey = "preferredDisplayName"

    static var preferredDisplayName: String? {
        get { UserDefaults.standard.string(forKey: preferredDisplayKey) }
        set {
            if let newValue {
                UserDefaults.standard.set(newValue, forKey: preferredDisplayKey)
            } else {
                UserDefaults.standard.removeObject(forKey: preferredDisplayKey)
            }
        }
    }

    static var candidateDisplays: [DisplayCandidate] {
        NSScreen.screens.map { screen in
            DisplayCandidate(
                localizedName: screen.localizedName,
                width: screen.frame.size.width,
                height: screen.frame.size.height
            )
        }
    }

    /// Returns the Xeneon Edge NSScreen, or nil if not connected.
    static var xeneonScreen: NSScreen? {
        guard let match = DisplayMatching.bestMatch(
            among: candidateDisplays,
            preferredName: preferredDisplayName
        ) else {
            return nil
        }

        return NSScreen.screens.first { screen in
            screen.localizedName == match.localizedName
                && screen.frame.size.width == match.width
                && screen.frame.size.height == match.height
        }
    }
}