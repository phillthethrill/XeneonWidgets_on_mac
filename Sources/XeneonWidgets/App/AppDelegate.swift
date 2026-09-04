import AppKit
import SwiftUI
import XeneonWidgetsCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let dashboardVisibleKey = "dashboardVisible"

    private var statusItem: NSStatusItem?
    private var widgetWindow: WidgetWindow?
    private var isVisible = true
    private var isPreviewWindow = false
    private var toggleItem: NSMenuItem?
    private let env = DashboardEnvironment()

    func applicationDidFinishLaunching(_ notification: Notification) {
        if AppLaunch.isPreview {
            NSApp.setActivationPolicy(.regular)
        } else {
            NSApp.setActivationPolicy(.accessory)
        }
        isVisible = UserDefaults.standard.object(forKey: Self.dashboardVisibleKey) as? Bool ?? true
        if AppLaunch.isPreview {
            env.state.preset = AppLaunch.previewPreset ?? .overview
        }
        setupStatusItem()
        env.start()
        syncDisplayConnected()
        openWindowIfNeeded()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    func applicationWillTerminate(_ notification: Notification) {
        env.stop()
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

        let presetItem = NSMenuItem(title: "Preset", action: nil, keyEquivalent: "")
        presetItem.submenu = makePresetMenu()
        menu.addItem(presetItem)

        let samplingItem = NSMenuItem(title: "Sampling", action: nil, keyEquivalent: "")
        samplingItem.submenu = makeSamplingMenu()
        menu.addItem(samplingItem)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(
            title: "Quit XeneonWidgets",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))
        statusItem?.menu = menu
    }

    private func makePresetMenu() -> NSMenu {
        let menu = NSMenu(title: "Preset")
        for (index, preset) in Preset.allCases.enumerated() {
            let item = NSMenuItem(
                title: preset.title,
                action: #selector(selectPreset(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.tag = 200 + index
            item.representedObject = preset.rawValue
            menu.addItem(item)
        }
        return menu
    }

    private func makeSamplingMenu() -> NSMenu {
        let menu = NSMenu(title: "Sampling")
        for (index, interval) in SamplingInterval.allCases.enumerated() {
            let item = NSMenuItem(
                title: interval.menuLabel,
                action: #selector(selectSampling(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.tag = 300 + index
            item.representedObject = interval.rawValue
            menu.addItem(item)
        }
        return menu
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

    @objc private func selectPreset(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let preset = Preset(rawValue: raw) else { return }
        env.state.preset = preset
        env.state.noteActivity()
    }

    @objc private func selectSampling(_ sender: NSMenuItem) {
        let intervals = SamplingInterval.allCases
        let index = sender.tag - 300
        guard intervals.indices.contains(index) else { return }
        env.setSampling(intervals[index])
    }

    private func openWindowIfNeeded() {
        // --preview / XENEON_PREVIEW=1 always opens the scaled main-screen
        // window so development screenshots work even when a Xeneon is plugged in.
        if AppLaunch.isPreview, let screen = NSScreen.main ?? NSScreen.screens.first {
            openPreviewWindow(on: screen)
            return
        }

        if let screen = DisplayManager.xeneonScreen {
            openXeneonWindow(on: screen)
        }
    }

    private func openXeneonWindow(on screen: NSScreen) {
        if widgetWindow == nil || isPreviewWindow {
            widgetWindow?.close()
            widgetWindow = WidgetWindow(screen: screen, contentView: DashboardRootView(env: env))
            isPreviewWindow = false
        } else {
            syncWindowFrame(to: screen)
        }
        applyVisibilityPreference()
    }

    private func openPreviewWindow(on screen: NSScreen) {
        if widgetWindow == nil || !isPreviewWindow {
            widgetWindow?.close()
            widgetWindow = WidgetWindow(previewOn: screen, contentView: PreviewScaledRoot(env: env))
            isPreviewWindow = true
        }
        applyVisibilityPreference()
        NSApp.activate(ignoringOtherApps: true)
        widgetWindow?.makeKeyAndOrderFront(nil)
        widgetWindow?.orderFrontRegardless()
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

    private func syncDisplayConnected() {
        env.state.isDisplayConnected = DisplayManager.xeneonScreen != nil
    }

    @objc private func screensChanged() {
        syncDisplayConnected()
        if AppLaunch.isPreview, let screen = NSScreen.main ?? NSScreen.screens.first {
            openPreviewWindow(on: screen)
        } else if let screen = DisplayManager.xeneonScreen {
            openXeneonWindow(on: screen)
        } else {
            widgetWindow?.close()
            widgetWindow = nil
            isPreviewWindow = false
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
        updateRadioMenus(menu)
    }

    private func updateRadioMenus(_ menu: NSMenu) {
        if let presetMenu = menu.item(withTitle: "Preset")?.submenu {
            for (index, preset) in Preset.allCases.enumerated() {
                presetMenu.item(withTag: 200 + index)?.state = env.state.preset == preset ? .on : .off
            }
        }
        if let samplingMenu = menu.item(withTitle: "Sampling")?.submenu {
            for (index, interval) in SamplingInterval.allCases.enumerated() {
                samplingMenu.item(withTag: 300 + index)?.state = env.state.sampling == interval ? .on : .off
            }
        }
    }
}
