import AppKit
import Foundation
import XeneonWidgetsCore

enum AppLaunch {
    static var isPreview: Bool {
        CommandLine.arguments.contains("--preview")
            || ProcessInfo.processInfo.environment["XENEON_PREVIEW"] == "1"
    }

    /// Developer hook: `XENEON_PREVIEW_PRESET=<rawValue>` (overview|focusCPU|focusProcesses|ambient).
    static var previewPreset: Preset? {
        guard let raw = ProcessInfo.processInfo.environment["XENEON_PREVIEW_PRESET"],
              !raw.isEmpty else { return nil }
        return Preset(rawValue: raw)
    }

    /// Developer hook: `XENEON_PREVIEW_EDIT=1` (preview path only) opens already in edit mode.
    static var previewEdit: Bool {
        isPreview && ProcessInfo.processInfo.environment["XENEON_PREVIEW_EDIT"] == "1"
    }

    /// Developer hook: `XENEON_PREVIEW_ALERTS=1` (preview path only).
    /// Injects synthetic header chips and skips the monitor overwrite.
    static var previewAlerts: Bool {
        isPreview && ProcessInfo.processInfo.environment["XENEON_PREVIEW_ALERTS"] == "1"
    }

    /// Developer hook: `XENEON_PREVIEW_SELECT_PID=<pid>` or `first`.
    /// Applied after the first matching process sample arrives (preview path only).
    static var previewSelectPID: String? {
        guard isPreview,
              let raw = ProcessInfo.processInfo.environment["XENEON_PREVIEW_SELECT_PID"],
              !raw.isEmpty else { return nil }
        return raw
    }
}

let delegate = MainActor.assumeIsolated { AppDelegate() }
NSApplication.shared.delegate = delegate
NSApplication.shared.run()
