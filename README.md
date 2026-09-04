# XeneonWidgets

A macOS menu bar app that renders a btop-class system monitor on the **Corsair Xeneon Edge** (2560 × 720) touch display, treating it as a standard secondary monitor. The shipped theme is OLED Black.

![XeneonWidgets](screenshot.png)

## Features

The dashboard fills the Xeneon Edge with a header strip and four swipeable presets: Overview, Focus CPU, Focus Processes, and Ambient. Live CPU, memory, disk, network, process, GPU, battery, and clock data are sampled in the background and drawn natively in SwiftUI.

### Presets

| Preset | Contents |
|---|---|
| **Overview** | Header plus four boxes: cpu (history, thermal, load, P/E core bars, GPU row when available), mem (breakdown, pressure, swap, disk list), net (mirrored up/down graph, rates, interface chips, ping), and proc (filtered top-7 list). |
| **Focus CPU** | Wide cpu box with a per-core history grid; compact mem (disks without I/O sparklines) and net (no chip row). Processes are hidden by default. |
| **Focus Processes** | Full-width process table (9 rows, memory/CPU sparklines) and a right-hand detail sheet for the selected process. |
| **Ambient** | No header. Large clock, long date, optional next calendar event, and cpu / mem / net-down sparklines. Also the glance/burn-in target. |

Switch presets by swiping left or right on the dashboard, or from the menu bar **Preset** submenu. Page dots appear briefly after a swipe.

### Gestures

- Swipe horizontally (minimum 40 pt) to change preset.
- Tap the CPU history graph to pick a time range: 1 min, 5 min, 15 min, or 1 h. The choice is persisted per box.
- Long-press a box (0.6 s) to enter edit mode.
- Tap a net chip (Auto / Wi-Fi / Ethernet / USB) to switch the selected interface; Auto sums active `en*` interfaces. Long-press a chip to open the interface picker (BSD name, IPv4, selection).
- Tap a process row to select it and open the detail sheet (Focus Processes). On Overview, tap the proc header to jump to that preset.
- Terminate (SIGTERM, 0.5 s hold) and Force Quit (SIGKILL, 1.0 s hold) from the detail sheet. Releasing early cancels.

### Alerts

Default rules: CPU ≥ 95 % for 30 s; memory pressure Warning or Critical; any disk ≥ 95 %; thermal Serious or Critical; battery ≤ 10 % and not charging. Matching alerts appear as header chips (up to three, then `+N`) and an edge glow on the affected box. Alerts clear when the condition ends. Tapping a chip switches to a preset that shows that box and highlights it.

### Edit mode

Long-press any box to tilt the layout, show hide / drag / resize handles, and open a toolbar for hidden boxes, Reset, and Done. Hide, show, reorder, and resize are persisted per preset in `~/Library/Application Support/XeneonWidgets/layouts.json`.

### Glance / burn-in

When glance is enabled (default), idle for the configured minutes (default 10) switches to Ambient, dims the dashboard to 60 % opacity, and drifts the content by ±4 px every 60 s. Touch or an activity spike (CPU jump or download rate) restores the previous preset.

### Sampling

The menu bar **Sampling** submenu sets the poll interval: 0.5 s, 1 s (default), 2 s, or 5 s. The current interval is shown in the header. History buffers are sized for one hour at the chosen interval.

## Preview mode

For development without a Xeneon Edge, open a half-scale (1280 × 360) window on the main screen:

```bash
swift run XeneonWidgets --preview
```

`XENEON_PREVIEW=1` is equivalent to `--preview`. Additional developer hooks (preview path only):

| Variable | Effect |
|---|---|
| `XENEON_PREVIEW_PRESET` | Start on `overview`, `focusCPU`, `focusProcesses`, or `ambient`. |
| `XENEON_PREVIEW_SELECT_PID` | After the first process sample, select that PID, or `first`. |
| `XENEON_PREVIEW_EDIT=1` | Open already in edit mode. |
| `XENEON_PREVIEW_ALERTS=1` | Inject two synthetic header alerts and skip the live alert monitor. |

## Data sources

| Data | API |
|---|---|
| CPU total / per core | `host_processor_info(PROCESSOR_CPU_LOAD_INFO)` deltas; P/E groups via `sysctl hw.perflevel*.logicalcpu` |
| Load average | `getloadavg` |
| Thermal | `ProcessInfo.thermalState` / `ProcessInfo.thermalStateDidChangeNotification` |
| GPU | IOKit `IOAccelerator` → `PerformanceStatistics` (`Device Utilization %`, `In use system memory`) |
| Memory | `host_statistics64(HOST_VM_INFO64)`; pressure via `DispatchSource.makeMemoryPressureSource` and `sysctl kern.memorystatus_vm_pressure_level`; swap `sysctl vm.swapusage` |
| Disks | `FileManager.mountedVolumeURLs` plus volume capacity keys; I/O from IOKit `IOBlockStorageDriver` Statistics |
| Network | `getifaddrs` (`if_data` bytes) per interface; SystemConfiguration for kind/name; CoreWLAN for RSSI / link / SSID; ICMP echo over an unprivileged `SOCK_DGRAM` / `IPPROTO_ICMP` socket to 1.1.1.1 |
| Processes | `proc_listpids`, `proc_pidinfo(PROC_PIDTASKINFO` / `PROC_PIDTBSDINFO)`, `proc_pidpath`; icons via `NSWorkspace` / `NSRunningApplication` |
| Battery | `IOPSCopyPowerSourcesInfo`; watts and cycle count from `AppleSmartBattery` (Amperage × Voltage) |
| Uptime / host / OS | `ProcessInfo`, `Host.current()` |
| Calendar next event | EventKit (optional; prompted on first launch) |

## Fallbacks

- Per-core frequency is not exposed on Apple Silicon; the freq row is omitted.
- SMC temperature is not read; the thermal pressure pill is the signal. No extra temperature pill is shown.
- Missing GPU `PerformanceStatistics` hides the GPU row and lets the core bars grow.
- No active Wi-Fi interface: the net footer shows link type only (no RSSI / rate).
- Calendar access denied or not granted: the Ambient “next:” segment is omitted.
- Intel Macs: all cores are shown as a single P-core group (no E-core bars) and typically have no GPU row.
- Desktop Macs with no internal battery: the battery pill is omitted.

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
| **Preset ▸** | Overview, Focus CPU, Focus Processes, Ambient |
| **Sampling ▸** | 0.5 s, 1 s, 2 s, 5 s |
| **Quit XeneonWidgets** | Exits the app |

The dashboard reopens automatically when the Xeneon Edge is reconnected and respects your last hide/show preference.

## Project structure

```
Resources/                      # Info.plist copied into the .app bundle
docs/design/handoff-btop/       # Design spec, feature inventory, reference art
docs/superpowers/plans/         # Implementation plan
Sources/
├── XeneonWidgetsCore/          # Testable models, maths, layout, alerts
├── XeneonWidgetsSelfTest/      # Core logic self-tests (no XCTest)
└── XeneonWidgets/
    ├── App/                    # Menu bar, DashboardEnvironment, launch hooks
    ├── Data/                   # CPU, memory, disk, net, process, power, clock, ping
    ├── Display/                # NSScreen matching, WidgetWindow
    ├── State/                  # DashboardState, SettingsStore, LayoutStore
    ├── Theme/                  # OLED tokens, type, metrics, motion
    └── UI/
        ├── Components/         # Graphs, chips, bars, rows, hold-to-confirm
        ├── Boxes/              # cpu, mem, net, proc, header, sheets, pickers
        └── Presets/            # Overview, Focus CPU, Focus Processes, Ambient,
                                # edit/glance/alert controllers
```

Run tests with:

```bash
swift run XeneonWidgetsSelfTest
```

## Technical notes

- **OLED Black only.** Other themes, portrait layouts, and a Mac Settings window are specified in the design docs but not shipped.
- **No App Sandbox.** `host_processor_info`, `host_statistics64`, `getifaddrs`, and the ICMP socket are blocked by the sandbox; this app is not intended for the Mac App Store.
- **Calendar.** Ambient “next event” uses EventKit. macOS prompts on first launch (`NSCalendarsFullAccessUsageDescription` in `Resources/Info.plist`). Deny the prompt and the segment is hidden.
- **Ping host** is 1.1.1.1. There is no in-app control to change it.
- **Display detection** matches screens whose name contains `"xeneon"`; name plus matching resolution (`2560×720` or `1280×800`) is preferred. Resolution-only matching is disabled to avoid false positives on other ultrawide monitors.
- **Persisted settings** (UserDefaults): last preset, sampling interval, per-box time ranges, glance enabled, idle minutes, network selection, ping host. Layouts are a JSON file via `LayoutStore`, not UserDefaults.

## Development

```bash
swift run XeneonWidgetsSelfTest   # run core logic tests
swift run XeneonWidgets --preview # half-scale window on the main display
swift build                       # debug build
bash build.sh                     # release .app bundle
```

## Design docs

- Spec and artboards: [`docs/design/handoff-btop/`](docs/design/handoff-btop/) (`README.md`, `FEATURES.md`, screenshots, HTML reference).
- Implementation plan: [`docs/superpowers/plans/2026-09-04-btop-dashboard.md`](docs/superpowers/plans/2026-09-04-btop-dashboard.md).

## License

MIT
