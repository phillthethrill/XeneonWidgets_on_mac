import SwiftUI
import XeneonWidgetsCore

@MainActor
enum AlertHighlight {
    static func glow(
        for box: BoxID,
        alerts: [XeneonWidgetsCore.Alert],
        theme: Theme,
        highlighted: BoxID?,
        pulseOpacity: Double
    ) -> Color? {
        let base = AlertMonitor.glowColor(for: box, alerts: alerts, theme: theme)
        guard highlighted == box else { return base }
        return (base ?? theme.crit).opacity(pulseOpacity)
    }
}
