import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let dashboardVisibleKey = "dashboardVisible"

    private var statusItem: NSStatusItem?
    private var widgetWindow: WidgetWindow?
    private var isVisible = true
    private var toggleItem: NSMenuItem?
    private let statsProvider = SystemStatsProvider()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        isVisible = UserDefaults.standard.object(forKey: Self.dashboardVisibleKey) as? Bool ?? true
        setupStatusItem()
        statsProvider.startPolling()
        openWindowIfNeeded()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    func applicationWillTerminate(_ notification: Notification) {
        statsProvider.stopPolling()
        NotificationCenter.default.removeObserver(self)
        widgetWindow?.close()
        widgetWindow = nil
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        updateStatusIcon()

        let menu = NSMenu()
        menu.delegate = self

        let toggle = NSMenuItem(
            title: isVisible ? "Hide Dashboard" : "Show Dashboard",
            action: #selector(toggleDashboard),
            keyEquivalent: "d"
        )
        toggle.target = self
        toggleItem = toggle
        menu.addItem(toggle)
        menu.addItem(NSMenuItem.separator())

        let statusMenuItem = NSMenuItem(title: xeneonStatusTitle, action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        statusMenuItem.tag = 100
        menu.addItem(statusMenuItem)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(
            title: "Quit XeneonWidgets",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))
        statusItem?.menu = menu
    }

    private func updateStatusIcon() {
        if let icon = NSImage(named: "XeneonWidgets") {
            icon.size = NSSize(width: 18, height: 18)
            statusItem?.button?.image = icon
            statusItem?.button?.alphaValue = isVisible ? 1.0 : 0.4
        } else {
            let symbolName = isVisible ? "display.and.arrow.down" : "display"
            statusItem?.button?.image = NSImage(
                systemSymbolName: symbolName,
                accessibilityDescription: "XeneonWidgets"
            )
        }
    }

    private var xeneonStatusTitle: String {
        DisplayManager.xeneonScreen != nil
            ? "Xeneon Edge: Connected"
            : "Xeneon Edge: Not Connected"
    }

    @objc private func toggleDashboard() {
        isVisible.toggle()
        UserDefaults.standard.set(isVisible, forKey: Self.dashboardVisibleKey)
        if isVisible {
            widgetWindow?.orderFront(nil)
        } else {
            widgetWindow?.orderOut(nil)
        }
        toggleItem?.title = isVisible ? "Hide Dashboard" : "Show Dashboard"
        updateStatusIcon()
    }

    private func openWindowIfNeeded() {
        guard let screen = DisplayManager.xeneonScreen else { return }

        if widgetWindow == nil {
            let content = WidgetContainerView(stats: statsProvider)
            widgetWindow = WidgetWindow(screen: screen, contentView: content)
        } else {
            syncWindowFrame(to: screen)
        }

        applyVisibilityPreference()
    }

    private func applyVisibilityPreference() {
        toggleItem?.title = isVisible ? "Hide Dashboard" : "Show Dashboard"
        if isVisible {
            widgetWindow?.orderFront(nil)
        } else {
            widgetWindow?.orderOut(nil)
        }
        updateStatusIcon()
    }

    private func syncWindowFrame(to screen: NSScreen) {
        guard let window = widgetWindow else { return }
        if window.frame != screen.frame {
            window.setFrame(screen.frame, display: true)
        }
    }

    @objc private func screensChanged() {
        if let screen = DisplayManager.xeneonScreen {
            if widgetWindow == nil {
                openWindowIfNeeded()
            } else {
                syncWindowFrame(to: screen)
                applyVisibilityPreference()
            }
        } else {
            widgetWindow?.close()
            widgetWindow = nil
        }

        if let menu = statusItem?.menu,
           let item = menu.item(withTag: 100) {
            item.title = xeneonStatusTitle
        }
    }
}

extension AppDelegate: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        if let item = menu.item(withTag: 100) {
            item.title = xeneonStatusTitle
        }
    }
}