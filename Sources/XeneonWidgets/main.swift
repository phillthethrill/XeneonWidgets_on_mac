import AppKit
import Foundation

enum AppLaunch {
    static var isPreview: Bool {
        CommandLine.arguments.contains("--preview")
            || ProcessInfo.processInfo.environment["XENEON_PREVIEW"] == "1"
    }
}

let delegate = MainActor.assumeIsolated { AppDelegate() }
NSApplication.shared.delegate = delegate
NSApplication.shared.run()
