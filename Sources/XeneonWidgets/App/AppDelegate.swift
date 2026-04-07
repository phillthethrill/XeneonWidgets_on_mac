import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var widgetWindow: WidgetWindow?
    private var isVisible = true
    private var toggleItem: NSMenuItem?
    private let statsProvider = SystemStatsProvider()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
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

    // MARK: - Status Item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        updateStatusIcon()

        let menu = NSMenu()
        menu.delegate = self

        toggleItem = NSMenuItem(
            title: "Hide Dashboard",
            action: #selector(toggleDashboard),
            keyEquivalent: "d"
        )
        toggleItem?.target = self
        menu.addItem(toggleItem!)
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
        if let icon = NSImage(named: "SystemPulse") {
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

    // MARK: - Dashboard Toggle

    @objc private func toggleDashboard() {
        isVisible.toggle()
        if isVisible {
            widgetWindow?.orderFront(nil)
        } else {
            widgetWindow?.orderOut(nil)
        }
        toggleItem?.title = isVisible ? "Hide Dashboard" : "Show Dashboard"
        updateStatusIcon()
    }

    // MARK: - Window Lifecycle

    private func openWindowIfNeeded() {
        guard let screen = DisplayManager.xeneonScreen else { return }
        let content = WidgetContainerView(stats: statsProvider)
        widgetWindow = WidgetWindow(screen: screen, contentView: content)
        widgetWindow?.orderFront(nil)
        isVisible = true
        toggleItem?.title = "Hide Dashboard"
        updateStatusIcon()
    }

    @objc private func screensChanged() {
        if DisplayManager.xeneonScreen == nil {
            widgetWindow?.close()
            widgetWindow = nil
            isVisible = false
        } else if widgetWindow == nil {
            openWindowIfNeeded()
        }
        if let menu = statusItem?.menu,
           let item = menu.item(withTag: 100) {
            item.title = xeneonStatusTitle
        }
    }
}

// MARK: - NSMenuDelegate

extension AppDelegate: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        if let item = menu.item(withTag: 100) {
            item.title = xeneonStatusTitle
        }
    }
}
