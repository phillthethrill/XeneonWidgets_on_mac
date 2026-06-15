# XeneonWidgets

A minimal macOS menu bar app that renders a live system stats dashboard on the **Corsair Xeneon Edge** touch display, treating it as a standard secondary monitor.

![XeneonWidgets](screenshot.png)

## Features

- **Clock** — time and date, updated every second
- **CPU** — usage percentage with colour-coded arc gauge + thermal pressure indicator
- **RAM** — memory usage with colour-coded arc gauge (includes compressed memory)
- **Network** — live download and upload speeds across active Ethernet/Wi-Fi interfaces

All widgets render natively at full resolution — no blurry scaled bitmaps.

## How it works

macOS recognises the Xeneon Edge as a standard external display over USB-C. XeneonWidgets opens a borderless, non-activating window that fills the display exactly. No proprietary SDK, no HID protocol, no iCUE required.

## Requirements

- macOS 13 Ventura or later
- Xcode Command Line Tools (`xcode-select --install`)
- Corsair Xeneon Edge connected via USB-C

> **Note:** Full Xcode.app is not required — the project builds entirely with Swift Package Manager and the command line tools.

## Install

### 1. Clone the repo

```bash
git clone https://github.com/phillthethrill/XeneonWidgets_on_mac.git
cd XeneonWidgets_on_mac
```

### 2. Build

```bash
bash build.sh
```

This compiles the app, assembles the `.app` bundle, and clears the Gatekeeper quarantine flag automatically.

### 3. Run

```bash
open XeneonWidgets.app
```

A **XeneonWidgets icon** appears in your menu bar. Connect your Xeneon Edge and the dashboard opens on it automatically.

### 4. Launch at login (optional)

Open **System Settings → General → Login Items** and add `XeneonWidgets.app`.

## Usage

Click the menu bar icon to access:

| Action | Result |
|---|---|
| **Hide / Show Dashboard** | Toggles the widget window on/off (preference is preserved across reconnects) |
| **Xeneon Edge: Connected/Not Connected** | Live connection status |
| **Quit XeneonWidgets** | Exits the app |

The dashboard reopens automatically when the Xeneon Edge is reconnected and respects your last hide/show preference.

## Project structure

```
Sources/
├── XeneonWidgetsCore/          # Testable display matching and stats math
│   ├── DisplayMatching.swift
│   └── StatsMath.swift
└── XeneonWidgets/
    ├── App/
    │   └── AppDelegate.swift       # Menu bar, screen lifecycle
    ├── Display/
    │   ├── DisplayManager.swift    # Detects the Xeneon Edge via NSScreen
    │   └── WidgetWindow.swift      # Borderless NSPanel on the target display
    ├── Widgets/
    │   ├── ArcGauge.swift          # Crisp native arc gauge component
    │   ├── WidgetContainer.swift   # 4-column grid layout
    │   ├── ClockWidget.swift
    │   ├── CPUWidget.swift
    │   ├── RAMWidget.swift
    │   └── NetworkWidget.swift
    └── Data/
        └── SystemStatsProvider.swift  # IOKit/sysctl polling
Sources/XeneonWidgetsSelfTest/    # Core logic self-tests (no XCTest required)
```

## Technical notes

- **No App Sandbox** — `host_processor_info`, `vm_statistics64`, and `getifaddrs` are all blocked by the sandbox; this app does not need to be on the Mac App Store
- **CPU temperature** — Apple Silicon locks SMC reads behind a private entitlement (`com.apple.private.smckit`). The CPU widget shows **thermal pressure state** (Nominal / Fair / Serious / Critical) via `NSProcessInfo.thermalState`, which is the same signal the OS uses to trigger throttling
- **Display detection** — matches screens whose name contains `"xeneon"`; name plus matching resolution (`2560×720` or `1280×800`) is preferred. Resolution-only matching is intentionally disabled to avoid false positives on other ultrawide monitors
- **Network stats** — summed across active `en*` interfaces only (Ethernet/Wi-Fi), excluding loopback and virtual tunnels

## Development

```bash
swift run XeneonWidgetsSelfTest   # run core logic tests
swift build         # debug build
bash build.sh       # release .app bundle
```

## License

MIT