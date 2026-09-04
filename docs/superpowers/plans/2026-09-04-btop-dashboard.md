# btop Dashboard Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the four-card XeneonWidgets dashboard with the btop-class system monitor specified in the design handoff (Row 1 presets + Row 2 states/interactions, OLED Black theme), rendered natively in SwiftUI on the Corsair Xeneon Edge (2560 × 720, touch).

**Architecture:** Pure, testable logic (ring buffers, graph maths, formatters, thresholds, layout model, alert engine, provider maths) lives in `XeneonWidgetsCore` and is covered by the existing no-XCTest `XeneonWidgetsSelfTest` executable. The app target gets a `Theme`/`Typography`/`Metrics` token layer injected via `@Environment(\.theme)`, one `@Published` provider per data domain driven by a shared `Sampler`, a `DashboardState` object for UI state + persistence, a component library that takes plain values, five boxes composed from components, and preset views that render a persisted `LayoutSpec`. Work is organised in **waves**: tasks inside a wave touch disjoint files and are executed in parallel git worktrees, then merged.

**Tech Stack:** Swift 5.9+ / SwiftPM, SwiftUI + AppKit (NSPanel), Darwin/Mach (`host_processor_info`, `host_statistics64`, `proc_pidinfo`, `getifaddrs`, `sysctl`), IOKit (GPU perf stats, block-storage stats, power sources), CoreWLAN, SystemConfiguration, EventKit (optional). macOS 13+. No third-party dependencies.

**Spec:** `docs/design/handoff-btop/README.md` (binding; sections referenced below as **Spec §…**), `docs/design/handoff-btop/FEATURES.md` (§1–8, §9.2 in scope), `docs/design/handoff-btop/screenshots/0N-*.png` (pixel reference), `docs/design/handoff-btop/html_reference/btop/*.jsx` (component maths; `components.jsx` = graph geometry/gradient, `boxes.jsx` = the five boxes + header, `presets.jsx` = presets/sheet/edit mode/pickers, `data.jsx` = sample data shapes).

## Global Constraints

- Platform: macOS 13+, SwiftPM only (no Xcode project). `swift build` and `swift run XeneonWidgetsSelfTest` must pass with **zero warnings in new code** after every task.
- Screen geometry: 2560 × 720; outer padding 24; header strip 56; box gap 16; body height **608**; content width **2512** (Spec §Screen geometry).
- Theme: ship **OLED Black only**, but through a `Theme` struct with the token names `bg, surface, surface2, hairline, text, text2, text3, rampLow, rampMid, rampHigh, accent, up, ok, warn, crit` so more themes can be added. Values per Spec §Colour (sRGB hex approximations are acceptable).
- Every changing number uses SF Mono (`Font.Design.monospaced`) with `.monospacedDigit()`.
- Type scale, spacing, radii, motion exactly per Spec §Type, §Spacing & radii, §Motion. Minimum tap target 56 × 56.
- Thresholds via `Threshold` constants: CPU/GPU/core 50/80 · Memory 70/90 (pressure overrides) · Disk 80/90 (alert 95) · Process CPU 10/25 · Ping 50/150 ms · Thermal Nominal ok / Fair warn / Serious+Critical crit.
- Every box header follows the btop pattern: title (boxTitle, text2, lowercase) + optional meta (15 Pro text3, truncating) left; live value (boxValue 22 Mono Medium, text or state colour) right.
- Fallbacks are designed, never faked: hide rows when data is unavailable (per-core frequency, GPU, Wi-Fi, calendar, battery on desktops). No mock data in shipped code paths.
- Providers publish on the main queue; sampling happens on a background queue owned by `Sampler`. Ring buffers are sized for 1 h at the current sampling interval.
- Only the alert dot may pulse (1.6 s ease-in-out, opacity 1 → 0.35). Edit-mode tilt is static ±0.5°.
- The only destructive action is Terminate/Force Quit, behind hold-to-confirm (0.5 s / 1.0 s).
- Tests: the self-test executable is the test suite. Each Core file gets a `run<Name>Tests()` function in its own file under `Sources/XeneonWidgetsSelfTest/`; `main.swift` only calls them. **Parallel-wave tasks never edit `main.swift`, `Package.swift`, or another task's files.**
- Commit style: `feat(<area>): …`, `test(<area>): …`, `refactor: …`, `chore: …`. Small, frequent commits.
- Design references are in-repo; read `docs/design/handoff-btop/README.md` sections named in each task and open the matching screenshot before building UI.

---

## File Structure

```
Package.swift                                   (Task 2: linker settings)
Resources/Info.plist                            (Task 8: usage descriptions)
Sources/XeneonWidgetsCore/
  DisplayMatching.swift, StatsMath.swift        (existing, untouched)
  RingBuffer.swift                              (Task 1)
  GraphMath.swift                               (Task 1)
  StateLevel.swift                              (Task 1)  Threshold, StateLevel, ThermalLevel, MemoryPressureLevel
  Formatters.swift                              (Task 1)
  DashboardModel.swift                          (Task 1)  Preset, BoxID, TimeRange, SamplingInterval
  LayoutSpec.swift                              (Task 1)
  AlertEngine.swift                             (Task 1)
  CPUMath.swift                                 (Task 3)
  MemoryMath.swift                              (Task 4)
  DiskMath.swift                                (Task 4)
  NetworkMath.swift                             (Task 5)
  ProcessMath.swift                             (Task 6)
  PowerMath.swift                               (Task 7)
Sources/XeneonWidgetsSelfTest/
  main.swift                                    (Task 1 rewrites; nobody else touches)
  TestHarness.swift                             (Task 1)  expect/expectEqual/failures
  CoreTests.swift                               (Task 1)  existing DisplayMatching + StatsMath tests moved here
  RingBufferTests.swift, GraphMathTests.swift, FormattersTests.swift,
  DashboardModelTests.swift, LayoutSpecTests.swift, AlertEngineTests.swift   (Task 1)
  CPUMathTests.swift (T3) MemoryMathTests.swift + DiskMathTests.swift (T4)
  NetworkMathTests.swift (T5) ProcessMathTests.swift (T6) PowerMathTests.swift (T7)   (stubs created by Task 1)
Sources/XeneonWidgets/
  main.swift                                    (existing)
  App/AppDelegate.swift                         (Task 14 rewires)
  App/DashboardEnvironment.swift                (Task 14)  owns providers, sampler, state, alert monitor
  Display/DisplayManager.swift, Display/WidgetWindow.swift   (existing; Task 14 adds preview mode)
  Theme/Theme.swift, Theme/Typography.swift, Theme/Metrics.swift, Theme/Motion.swift   (Task 2)
  State/DashboardState.swift, State/SettingsStore.swift, State/LayoutStore.swift        (Task 2)
  Data/Sampler.swift                            (Task 2)  Sampler + SampledProvider protocol
  Data/CPUProvider.swift                        (Task 3)  + GPU
  Data/MemoryProvider.swift, Data/DiskProvider.swift          (Task 4)
  Data/NetworkProvider.swift, Data/PingService.swift          (Task 5)
  Data/ProcessProvider.swift                    (Task 6)
  Data/PowerProvider.swift, Data/ClockProvider.swift          (Task 7)
  UI/Components/*.swift                         (Task 8)
  UI/Boxes/HeaderBar.swift                      (Task 9)
  UI/Boxes/CPUBox.swift, UI/Boxes/TimeRangePopover.swift       (Task 10)
  UI/Boxes/MemBox.swift                         (Task 11)
  UI/Boxes/NetBox.swift, UI/Boxes/InterfacePopover.swift       (Task 12)
  UI/Boxes/ProcBox.swift, UI/Boxes/ProcessDetailSheet.swift, UI/Boxes/ForceQuitConfirmCard.swift   (Task 13)
  UI/Presets/DashboardRootView.swift, PresetLayoutView.swift, OverviewPreset.swift,
     FocusCPUPreset.swift, FocusProcessesPreset.swift, AmbientPreset.swift, SimpleBoxes.swift   (Task 14)
  UI/Presets/EditModeOverlay.swift, UI/Presets/EditToolbar.swift    (Task 15)
  UI/Presets/AlertMonitor.swift, UI/Presets/GlanceController.swift  (Task 16)
  Widgets/*.swift, Data/SystemStatsProvider.swift   (DELETED in Task 14)
README.md, build.sh                             (Task 17)
```

## Waves (execution order)

| Wave | Tasks | Mode |
|---|---|---|
| A | 1 → 2 | sequential (foundation) |
| B | 3, 4, 5, 6, 7, 8 | parallel worktrees, disjoint files |
| C | 9, 10, 11, 12, 13 | parallel worktrees, disjoint files |
| D | 14 | sequential (integration) |
| E | 15, 16 | parallel worktrees |
| F | 17 | sequential (docs) |

---

### Task 1: Core foundation — ring buffer, graph maths, tokens model, layout spec, alert engine, test harness split

**Files:**
- Create: `Sources/XeneonWidgetsCore/RingBuffer.swift`, `GraphMath.swift`, `StateLevel.swift`, `Formatters.swift`, `DashboardModel.swift`, `LayoutSpec.swift`, `AlertEngine.swift`
- Create: `Sources/XeneonWidgetsSelfTest/TestHarness.swift`, `CoreTests.swift`, `RingBufferTests.swift`, `GraphMathTests.swift`, `FormattersTests.swift`, `DashboardModelTests.swift`, `LayoutSpecTests.swift`, `AlertEngineTests.swift`
- Create (stubs, one empty `func run…Tests() {}` each, so later parallel tasks never touch `main.swift`): `CPUMathTests.swift`, `MemoryMathTests.swift`, `DiskMathTests.swift`, `NetworkMathTests.swift`, `ProcessMathTests.swift`, `PowerMathTests.swift`
- Modify: `Sources/XeneonWidgetsSelfTest/main.swift` → only calls every `run…Tests()` then prints/exits as today.

**Interfaces — Produces (exact, `public`):**

```swift
// RingBuffer.swift
public struct RingBuffer<Element>: Equatable where Element: Equatable {
    public init(capacity: Int)                       // capacity ≥ 1
    public private(set) var capacity: Int
    public var count: Int { get }
    public var isEmpty: Bool { get }
    public var last: Element? { get }
    public mutating func append(_ element: Element)  // drops oldest when full
    public var elements: [Element] { get }           // oldest → newest, count ≤ capacity
    public func suffix(_ n: Int) -> [Element]        // newest n (or fewer)
    public mutating func resize(capacity: Int)       // keeps the newest `capacity` elements
    public mutating func removeAll()
}

// GraphMath.swift
public enum GraphMath {
    /// Downsample by taking the max of each of `count` equal buckets. Returns `values` unchanged when values.count <= count. count ≥ 1.
    public static func bucket(_ values: [Double], into count: Int) -> [Double]
    /// Left-pad with `fill` to exactly `count` (used so a young ring buffer still spans the full graph width).
    public static func padLeading(_ values: [Double], to count: Int, fill: Double = 0) -> [Double]
    /// x from 0…width evenly (single value → x = width), y = height - (v-min)/(max-min)*height, clamped to 0…height.
    public static func points(values: [Double], width: Double, height: Double, min: Double, max: Double) -> [CGPoint]
    /// Catmull-Rom → cubic Bézier control points (same maths as components.jsx `smooth`): for each segment p1→p2, c1 = p1 + (p2 - p0)/6, c2 = p2 - (p3 - p1)/6.
    public static func smoothSegments(_ points: [CGPoint]) -> [(control1: CGPoint, control2: CGPoint, end: CGPoint)]
    /// Smallest value of the form {1,2,5}×10^n that is ≥ max(peak, floor). niceScale(peak: 48.2, floor: 1) == 50.
    public static func niceScale(peak: Double, floor: Double) -> Double
}

// StateLevel.swift
public enum StateLevel: Equatable, Sendable { case ok, warn, crit }
public struct Threshold: Equatable, Sendable {
    public let lo: Double; public let hi: Double
    public init(lo: Double, hi: Double)
    public func level(_ pct: Double) -> StateLevel   // pct < lo → ok, pct < hi → warn, else crit
    public static let cpu = Threshold(lo: 50, hi: 80)
    public static let memory = Threshold(lo: 70, hi: 90)
    public static let disk = Threshold(lo: 80, hi: 90)
    public static let process = Threshold(lo: 10, hi: 25)
    public static let ping = Threshold(lo: 50, hi: 150)
}
public enum ThermalLevel: Equatable, Sendable {
    case nominal, fair, serious, critical
    public init(_ state: ProcessInfo.ThermalState)
    public var stateLevel: StateLevel   // nominal ok, fair warn, serious/critical crit
    public var label: String            // "Nominal" "Fair" "Serious" "Critical"
}
public enum MemoryPressureLevel: Equatable, Sendable {
    case normal, warning, critical
    public var stateLevel: StateLevel   // ok / warn / crit
    public var label: String            // "Normal" "Warning" "Critical"
}

// Formatters.swift  (all pure; exact outputs are the acceptance tests)
public enum Formatters {
    public static func percent(_ value: Double) -> String              // 34.4 → "34%"
    public static func percent1(_ value: Double) -> String             // 31.62 → "31.6%"
    public static func gigabytes(_ bytes: UInt64, decimals: Int = 1) -> String   // 12_884_901_888 → "12.0 GB" ; decimals 2 → "12.00 GB"
    public static func capacity(_ bytes: UInt64) -> String            // < 1000 GB → "612 GB", else "1.86 TB"
    public static func megabytesPerSecond(_ bytesPerSecond: Double) -> String   // 12_400_000 → "12.4"   (number only, unit rendered by view)
    public static func totalBytes(_ bytes: UInt64) -> String          // adaptive: "812 MB", "3.1 GB", "1.2 TB"
    public static func uptime(_ seconds: TimeInterval) -> String      // 311_940 → "up 3d 14h 22m"; < 1 d → "up 14h 22m"; < 1 h → "up 22m"
    public static func age(_ seconds: TimeInterval) -> String         // 134 → "2m 14s"; 2460 → "41m"; 7800 → "2h 10m"; 42 → "42s"
    public static func clockHM(_ date: Date, calendar: Calendar = .current) -> String   // "14:32"
    public static func clockSeconds(_ date: Date, calendar: Calendar = .current) -> String   // "07"
    public static func shortDate(_ date: Date, calendar: Calendar = .current) -> String      // "Thu 4 Sep"
    public static func longDate(_ date: Date, calendar: Calendar = .current) -> String       // "Thursday, 4 September"
    public static func isoWeek(_ date: Date) -> String                 // "W36"
    public static func minutesAsClock(_ minutes: Int) -> String        // 161 → "2:41"
    public static func watts(_ w: Double) -> String                    // 18.43 → "18.4 W"
    public static func loadAverage(_ v: Double) -> String              // 3.2149 → "3.21"
}

// DashboardModel.swift
public enum Preset: String, CaseIterable, Codable, Sendable {
    case overview, focusCPU, focusProcesses, ambient
    public var title: String           // "Overview" "Focus CPU" "Focus Processes" "Ambient"
    public var next: Preset            // wraps
    public var previous: Preset        // wraps
    public var index: Int
}
public enum BoxID: String, CaseIterable, Codable, Sendable {
    case cpu, mem, net, proc, gpu, battery, clock
    public var title: String           // lowercase btop title: "cpu" "mem" "net" "proc" "gpu" "battery" "clock"
    public var displayName: String     // "CPU" "Memory" "Network" "Processes" "GPU" "Battery" "Clock"
}
public enum TimeRange: Int, CaseIterable, Codable, Sendable {
    case oneMinute = 60, fiveMinutes = 300, fifteenMinutes = 900, oneHour = 3600
    public var label: String           // "1 min" "5 min" "15 min" "1 h"
    public func sampleCount(at interval: SamplingInterval) -> Int   // seconds / interval, rounded, ≥ 2
}
public enum SamplingInterval: Double, CaseIterable, Codable, Sendable {
    case half = 0.5, one = 1, two = 2, five = 5
    public var label: String           // "0.5 s sampling" "1 s sampling" "2 s sampling" "5 s sampling"
    public var menuLabel: String       // "0.5 s" "1 s" "2 s" "5 s"
    public var historyCapacity: Int    // samples for 1 h: 7200, 3600, 1800, 720
}

// LayoutSpec.swift
public struct BoxPlacement: Codable, Equatable, Sendable {
    public var id: BoxID; public var width: Double; public var hidden: Bool
    public init(id: BoxID, width: Double, hidden: Bool = false)
}
public struct LayoutSpec: Codable, Equatable, Sendable {
    public static let contentWidth: Double = 2512
    public static let gap: Double = 16
    public static let minBoxWidth: Double = 320
    public var boxes: [BoxPlacement]                       // order = left→right
    public init(boxes: [BoxPlacement])
    public static func `default`(for preset: Preset) -> LayoutSpec
    // overview: cpu 740, mem 600, net 480, proc 644 (+ gpu, battery, clock hidden, width 480)
    // focusCPU: cpu 1500, mem 480, net 500, proc hidden(644) (+ gpu, battery, clock hidden)
    // focusProcesses: proc 2512, all others hidden
    // ambient: boxes empty
    public var visible: [BoxPlacement]                     // !hidden, in order
    public var hiddenIDs: [BoxID]
    public mutating func hide(_ id: BoxID)                 // then normalize()
    public mutating func show(_ id: BoxID)                 // appends at end if absent, unhides, width = minBoxWidth, then normalize()
    public mutating func move(_ id: BoxID, to index: Int)  // index within visible order
    public mutating func resize(_ id: BoxID, width: Double) // clamps ≥ minBoxWidth, takes/gives the delta to the right-hand neighbour (or left if none), then normalize()
    public mutating func normalize()                        // scales visible widths so Σwidth + gap·(n−1) == contentWidth (no-op when n == 0)
}

// AlertEngine.swift
public struct Alert: Identifiable, Equatable, Sendable {
    public let id: String        // "cpu" | "memory" | "disk:<volume name>" | "thermal" | "battery"
    public let level: StateLevel // .warn or .crit
    public let text: String
    public let box: BoxID
    public let since: Date
}
public struct AlertRules: Equatable, Sendable {
    public var cpuPercent: Double = 95, cpuHoldSeconds: TimeInterval = 30
    public var diskPercent: Double = 95, batteryPercent: Double = 10
    public init()
}
public struct AlertInputs: Sendable {
    public var cpuPercent: Double
    public var memoryPressure: MemoryPressureLevel
    public var disks: [(name: String, percent: Double)]
    public var thermal: ThermalLevel
    public var battery: (percent: Double, isCharging: Bool)?
    public var now: Date
    public init(cpuPercent:memoryPressure:disks:thermal:battery:now:)
}
public struct AlertEngine: Sendable {
    public init(rules: AlertRules = AlertRules())
    /// Idempotent per tick. Alerts keep their original `since` while the condition persists and disappear when it ends.
    public mutating func evaluate(_ inputs: AlertInputs) -> [Alert]
    // Rules & texts:
    //  cpu: cpuPercent ≥ rules.cpuPercent continuously for ≥ cpuHoldSeconds → crit, "CPU · 97% for 30 s" (rounded current %), box .cpu
    //  memory: .warning → warn "Memory pressure · Warning"; .critical → crit "Memory pressure · Critical", box .mem
    //  disk: percent ≥ diskPercent → warn "<name> · 95% full" (rounded %), box .mem, id "disk:<name>"
    //  thermal: serious/critical → crit "Thermal · Serious"/"Thermal · Critical", box .cpu
    //  battery: percent ≤ batteryPercent && !isCharging → crit "Battery · 8%", box .battery
    // Output order: crit before warn, then by since ascending.
}
```

- [ ] **Step 1: Move the harness.** Create `TestHarness.swift` holding `var failures = 0`, `expect`, `expectEqual`, `expectNil`, `expectNotNil` (same bodies as today's `main.swift`), plus `func expectClose(_ a: Double, _ b: Double, tol: Double = 0.001, _ message: String)`. Move today's display-matching and stats tests into `CoreTests.swift` as `func runCoreTests()`. Rewrite `main.swift` to call `runCoreTests()`, `runRingBufferTests()`, `runGraphMathTests()`, `runFormattersTests()`, `runDashboardModelTests()`, `runLayoutSpecTests()`, `runAlertEngineTests()`, `runCPUMathTests()`, `runMemoryMathTests()`, `runDiskMathTests()`, `runNetworkMathTests()`, `runProcessMathTests()`, `runPowerMathTests()` and keep the pass/fail exit. Create the six stub files with empty functions. Run `swift run XeneonWidgetsSelfTest` → "All core logic tests passed." Commit `refactor(test): split self-test harness into per-area files`.
- [ ] **Step 2: RingBuffer (TDD).** Tests: capacity 3, append 1…5 → elements [3,4,5], last 5, count 3; suffix(2) → [4,5]; suffix(10) → all; resize to 2 → [4,5]; resize to 5 keeps [4,5] and capacity 5; removeAll → empty. Implement with a fixed-size array + head index (no `Array.removeFirst`). Commit.
- [ ] **Step 3: GraphMath (TDD).** Tests: `bucket([1,5,2,8,3,9], into: 3) == [5,8,9]`; `bucket([1,2], into: 5) == [1,2]`; `padLeading([1,2], to: 4) == [0,0,1,2]`; `points(values:[0,50,100], width: 100, height: 50, min:0, max:100)` → (0,50),(50,25),(100,0); single value → one point at x = 100; `smoothSegments` for 2 points returns 1 segment whose control points lie on the line; `niceScale(peak: 48.2, floor: 1) == 50`, `niceScale(peak: 0.3, floor: 1) == 1`, `niceScale(peak: 120, floor: 1) == 200`. Commit.
- [ ] **Step 4: StateLevel & Formatters (TDD).** Test every example in the interface comments above (use a fixed `Calendar(identifier: .iso8601)`/`.gregorian` with `TimeZone(identifier: "Europe/Berlin")` and `Locale(identifier: "en_GB")` for date tests; Formatters accept a `calendar:` and internally set the locale from `calendar.locale ?? .current`). Commit.
- [ ] **Step 5: DashboardModel (TDD).** Tests: `Preset.ambient.next == .overview`, `.overview.previous == .ambient`; `TimeRange.oneHour.sampleCount(at: .one) == 3600`, `.oneMinute.sampleCount(at: .five) == 12`; `SamplingInterval.half.historyCapacity == 7200`; labels. Commit.
- [ ] **Step 6: LayoutSpec (TDD).** Tests: defaults sum to 2512 with gaps for overview (740+600+480+644 + 3·16 = 2512) and focusCPU (1500+480+500 + 2·16 = 2512); `hide(.proc)` on overview → 3 visible, widths scaled, sum + gaps == 2512; `show(.gpu)` → 5 visible, includes gpu, normalized; `move(.mem, to: 0)` → visible order mem, cpu, net, proc; `resize(.cpu, width: 900)` → cpu 900, mem shrinks by 160, still normalized; `resize` never goes below 320; Codable round-trip equality. Commit.
- [ ] **Step 7: AlertEngine (TDD).** Tests with a fixed `t0` date: CPU 97 % at t0 → no alert; at t0+29 s → none; at t0+30 s → crit alert with `since == t0+30`… (define: `since` = the time the alert first *fires*), text "CPU · 97% for 30 s"; CPU drops to 40 → cleared; CPU back to 97 restarts the hold. Memory warning → warn alert, critical → crit replaces it (same id "memory", `since` preserved). Disk "Macintosh HD" 95.4 % → warn "Macintosh HD · 95% full". Thermal serious → crit. Battery 8 % discharging → crit; charging → none. Ordering: crit first. Commit `feat(core): alert engine`.
- [ ] **Step 8:** `swift build && swift run XeneonWidgetsSelfTest` clean (no warnings). Final commit if anything is pending.

---

### Task 2: App foundation — theme tokens, typography, metrics, motion, DashboardState, persistence, Sampler

**Files:**
- Create: `Sources/XeneonWidgets/Theme/Theme.swift`, `Theme/Typography.swift`, `Theme/Metrics.swift`, `Theme/Motion.swift`
- Create: `Sources/XeneonWidgets/State/DashboardState.swift`, `State/SettingsStore.swift`, `State/LayoutStore.swift`
- Create: `Sources/XeneonWidgets/Data/Sampler.swift`
- Modify: `Package.swift` — add to the `XeneonWidgets` executable target `linkerSettings: [.linkedFramework("IOKit"), .linkedFramework("CoreWLAN"), .linkedFramework("SystemConfiguration"), .linkedFramework("EventKit")]`.

**Interfaces — Consumes:** Task 1 Core types. **Produces (exact):**

```swift
// Theme.swift
struct Theme: Equatable {
    let id: String, name: String
    let bg, surface, surface2, hairline, text, text2, text3: Color
    let rampLow, rampMid, rampHigh, accent, up, ok, warn, crit: Color
    let sheet: Color                                  // #0e1016 opaque (popover/sheet/toolbar fill)
    func color(_ level: StateLevel) -> Color          // ok/warn/crit
    func stateColor(_ pct: Double, _ threshold: Threshold) -> Color
    var ramp: LinearGradient                          // bottom→top rampLow → rampMid (0.5) → rampHigh
    static let oled: Theme
    // OLED values (Spec §Colour): bg #000000; surface white 4 %; surface2 white 9 %; hairline white 12 %;
    // text white 92 %; text2 60 %; text3 40 %; rampLow #4FD8CF; rampMid #F2C24E; rampHigh #F0533F;
    // accent #7FBDF5; up #C89AF0; ok #4ED17A; warn #F2C24E; crit #F0533F; sheet #0e1016
}
extension Color { init(hex: UInt32, opacity: Double = 1) }   // sRGB
private struct ThemeKey: EnvironmentKey { static let defaultValue = Theme.oled }
extension EnvironmentValues { var theme: Theme { get set } }

// Typography.swift  (Spec §Type)
enum Typography {
    static func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font   // .system(size:, weight:, design: .monospaced)
    static func pro(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font    // .system(size:, weight:, design: .default)
    static let display   = mono(300, .ultraLight)      // ambient clock  (tracking −12 applied by view)
    static let clock     = mono(44, .semibold)
    static let clockSeconds = mono(44, .regular)
    static let big       = mono(72, .semibold)         // tracking −2 applied by view; unit at 36 % = 26 pt
    static let bigUnit   = mono(26, .semibold)
    static let numLg     = mono(56, .semibold)
    static let numMd     = mono(36, .semibold)
    static let numSm     = mono(34, .semibold)
    static let boxValue  = mono(22, .medium)
    static let boxTitle  = mono(16, .regular)          // tracking +2.4, lowercase
    static let body      = pro(17, .medium)
    static let bodyMono  = mono(17, .regular)
    static let small     = pro(15, .regular)
    static let smallMono = mono(15, .regular)
    static let micro     = mono(13, .regular)
    static let microSans = pro(13, .regular)
    static let colHead   = pro(12, .regular)           // tracking +1.2, uppercase
    static let chip      = pro(15, .semibold)
    static let button    = pro(18, .semibold)
}
extension View { func monoDigits() -> some View }      // .monospacedDigit()

// Metrics.swift  (Spec §Spacing & radii, §Screen geometry)
enum Metrics {
    static let screenWidth: CGFloat = 2560, screenHeight: CGFloat = 720
    static let outerPadding: CGFloat = 24, boxGap: CGFloat = 16, boxPadding: CGFloat = 22
    static let innerGap: CGFloat = 16, procInnerGap: CGFloat = 12
    static let headerHeight: CGFloat = 56, bodyHeight: CGFloat = 608, contentWidth: CGFloat = 2512
    static let boxRadius: CGFloat = 20, popoverRadius: CGFloat = 18, sheetRadius: CGFloat = 24
    static let chipRadius: CGFloat = 14, buttonRadius: CGFloat = 16
    static let pillHeight: CGFloat = 32, batteryPillHeight: CGFloat = 40
    static let minTap: CGFloat = 56, hairline: CGFloat = 1
}

// Motion.swift  (Spec §Motion)
enum Motion {
    static let numberTween: Animation = .easeOut(duration: 0.24)
    static let colorFade: Animation = .easeInOut(duration: 0.4)
    static let presetSwipe: Animation = .spring(response: 0.32, dampingFraction: 0.8)
    static let siblingSlide: Animation = .spring(response: 0.32, dampingFraction: 0.8)
    static let alertPulse: Animation = .easeInOut(duration: 1.6).repeatForever(autoreverses: true)
    static let editTiltDegrees: Double = 0.5
}

// SettingsStore.swift (UserDefaults; keys prefixed "dashboard.")
final class SettingsStore {
    init(defaults: UserDefaults = .standard)
    var sampling: SamplingInterval            // default .one
    var preset: Preset                        // default .overview
    var timeRanges: [BoxID: TimeRange]        // default [:] (view falls back to .fiveMinutes)
    var idleMinutes: Int                      // default 10   (glance/ambient after N idle minutes)
    var glanceEnabled: Bool                   // default true
    var pingHost: String                      // default "1.1.1.1"
    var networkSelection: String              // default "auto"  ("auto" or interface name)
}
// LayoutStore.swift  (~/Library/Application Support/XeneonWidgets/layouts.json)
final class LayoutStore {
    init(directory: URL? = nil)               // nil → Application Support/XeneonWidgets (created on demand)
    func load() -> [Preset: LayoutSpec]       // missing/corrupt file → [:]
    func save(_ layouts: [Preset: LayoutSpec])
}

// DashboardState.swift
enum ConfirmAction: Equatable { case terminate(pid_t), forceQuit(pid_t) }
@MainActor final class DashboardState: ObservableObject {
    init(settings: SettingsStore, layoutStore: LayoutStore)
    @Published var preset: Preset                       // persisted via settings
    @Published private(set) var layouts: [Preset: LayoutSpec]   // merged: stored overrides ?? LayoutSpec.default
    @Published var sampling: SamplingInterval           // persisted
    @Published var editMode: Bool = false
    @Published var alerts: [Alert] = []
    @Published var selectedPID: pid_t? = nil
    @Published var confirm: ConfirmAction? = nil
    @Published var glance: Bool = false
    @Published var isDisplayConnected: Bool = false
    @Published var lastActivity: Date = Date()
    let theme: Theme = .oled
    var idleMinutes: Int { get set }                    // settings passthrough
    func layout(for preset: Preset) -> LayoutSpec
    func updateLayout(_ spec: LayoutSpec, for preset: Preset)   // saves
    func resetLayout(for preset: Preset)                          // back to default, saves
    func timeRange(for box: BoxID) -> TimeRange         // default .fiveMinutes
    func setTimeRange(_ range: TimeRange, for box: BoxID)         // persisted
    func nextPreset() / func previousPreset()
    func noteActivity()                                  // lastActivity = now; glance = false
}

// Sampler.swift
protocol SampledProvider: AnyObject {
    /// Called on the sampler's background queue every tick.
    func sample(at now: Date, interval: SamplingInterval)
    /// Called (background queue) when the interval changes; providers resize their ring buffers to `interval.historyCapacity`.
    func historyCapacityChanged(to capacity: Int)
}
final class Sampler {
    init(interval: SamplingInterval)
    let queue: DispatchQueue                             // "com.local.xeneon.sampler", .utility
    private(set) var interval: SamplingInterval
    func add(_ provider: SampledProvider)
    func start(); func stop()
    func setInterval(_ interval: SamplingInterval)      // reschedules timer, notifies providers
}
```

- [ ] **Step 1:** Theme + Color(hex:) + environment key; Typography; Metrics; Motion. Build. Commit `feat(theme): OLED token layer`.
- [ ] **Step 2:** SettingsStore, LayoutStore (Codable JSON via `JSONEncoder` with `.prettyPrinted`; `[Preset: LayoutSpec]` encodes as an array of `{preset, spec}` pairs or a `[String: LayoutSpec]` keyed by rawValue — pick the string-keyed dictionary). Build. Commit.
- [ ] **Step 3:** DashboardState with persistence wiring (`preset`/`sampling`/`timeRanges` written through to SettingsStore via `didSet`). Commit.
- [ ] **Step 4:** Sampler (DispatchSourceTimer on `queue`, `repeating: interval.rawValue`, leeway 50 ms; `setInterval` cancels/recreates and calls `historyCapacityChanged` on each provider). Package.swift linker settings. `swift build` clean. Commit `feat(data): shared Sampler and provider protocol`.
- [ ] **Step 5 (tests):** In `Sources/XeneonWidgetsSelfTest/` nothing new is needed for the app target (not linkable). Instead add a `LayoutStore` round-trip smoke test by temporarily running the app? **No** — keep it simple: LayoutStore is exercised by Task 14/15. Confirm `swift run XeneonWidgetsSelfTest` still passes.

---

### Task 3: CPUProvider + GPU (Wave B)

**Files:** Create `Sources/XeneonWidgetsCore/CPUMath.swift`, `Sources/XeneonWidgets/Data/CPUProvider.swift`; fill `Sources/XeneonWidgetsSelfTest/CPUMathTests.swift`.

**Spec:** §01 Overview → cpu box "Sources" line; §02 Focus CPU (per-core histories); §Fallbacks; FEATURES §12 rows CPU/Load/Thermal/GPU.

**Interfaces — Consumes:** `RingBuffer`, `SampledProvider`, `SamplingInterval`, `ThermalLevel`, `StatsMath.CPUTicks`. **Produces:**

```swift
// CPUMath.swift
public enum CPUMath {
    /// Per-core busy % from tick deltas (user+system+nice)/(total). nil when counts differ or previous empty. Cores with zero total delta → 0.
    public static func perCoreUsage(current: [StatsMath.CPUTicks], previous: [StatsMath.CPUTicks]) -> [Double]?
    /// Apple Silicon: efficiency cores occupy the LOWEST logical indices. Returns (pIndices, eIndices) for `logicalCount` cores given perflevel counts; when eCount == 0 (Intel) all cores are P.
    public static func coreGroups(logicalCount: Int, performanceCount: Int, efficiencyCount: Int) -> (performance: [Int], efficiency: [Int])
    public static func average(_ values: [Double]) -> Double          // 0 for empty
    /// "12P + 4E" ; Intel (e == 0) → "16 cores"
    public static func coreConfigLabel(performance: Int, efficiency: Int) -> String
}

// CPUProvider.swift
struct GPUStats: Equatable { var utilization: Double; var memoryUsedBytes: UInt64; var memoryTotalBytes: UInt64; var source: String /* "IOKit perf stats" */ }
final class CPUProvider: ObservableObject, SampledProvider {
    init(historyCapacity: Int)
    @Published private(set) var total: Double = 0                   // %
    @Published private(set) var perCore: [Double] = []
    @Published private(set) var totalHistory: RingBuffer<Double>
    @Published private(set) var coreHistories: [RingBuffer<Double>]
    @Published private(set) var loadAverage: (one: Double, five: Double, fifteen: Double) = (0,0,0)
    @Published private(set) var thermal: ThermalLevel = .nominal
    @Published private(set) var gpu: GPUStats? = nil                 // nil → hide GPU row
    @Published private(set) var gpuHistory: RingBuffer<Double>
    let cpuModel: String              // sysctl machdep.cpu.brand_string, e.g. "Apple M3 Max"
    let performanceCoreIndices: [Int], efficiencyCoreIndices: [Int]   // via sysctl hw.perflevel0.logicalcpu (P) / hw.perflevel1.logicalcpu (E)
    let coreCount: Int
    var coreConfigLabel: String       // "12P + 4E"
    var perCoreFrequencyAvailable: Bool { false }   // Apple Silicon: always false → view hides the freq row
}
```
GPU: `IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOAccelerator"))`, first service whose `PerformanceStatistics` (CFDictionary) has `"Device Utilization %"`; memory used from `"In use system memory"` (bytes); total = `ProcessInfo.processInfo.physicalMemory` (unified memory). If none → `gpu = nil`. Thermal: observe `ProcessInfo.thermalStateDidChangeNotification` **and** re-read every sample. Load via `getloadavg`. Publish on main via `DispatchQueue.main.async` in one batch per tick.
- [ ] Tests (TDD): perCoreUsage two cores → [40, 0] for the given deltas; nil on mismatch; coreGroups(16, 12, 4) → P = 4…15, E = 0…3; coreGroups(8, 8, 0) → all P; label "12P + 4E" / "8 cores"; average.
- [ ] Implement, build, run self-tests, commit `feat(data): CPUProvider with per-core groups and GPU stats`.

---

### Task 4: MemoryProvider + DiskProvider (Wave B)

**Files:** Create `Sources/XeneonWidgetsCore/MemoryMath.swift`, `DiskMath.swift`, `Sources/XeneonWidgets/Data/MemoryProvider.swift`, `Data/DiskProvider.swift`; fill `MemoryMathTests.swift`, `DiskMathTests.swift`.

**Spec:** §01 Overview → mem box (items 1–5 + Sources), §Fallbacks, FEATURES §3, §12.

**Produces:**
```swift
// MemoryMath.swift
public struct MemoryBreakdown: Equatable, Sendable {
    public var app, wired, compressed, cached, free, total: UInt64   // bytes
    public var used: UInt64 { app + wired + compressed }
    public var usedPercent: Double                                     // used/total*100
    public init(app:wired:compressed:cached:free:total:)
}
public enum MemoryMath {
    /// Spec formulas: app = internal − purgeable; cached = purgeable + external; wired, compressed, free straight from counts. All in pages → bytes.
    public static func breakdown(internalPages: UInt64, purgeablePages: UInt64, externalPages: UInt64, wiredPages: UInt64, compressorPages: UInt64, freePages: UInt64, pageSize: UInt64, totalBytes: UInt64) -> MemoryBreakdown
    public static func swapLabel(usedBytes: UInt64, totalBytes: UInt64) -> String   // "swap 1.2 / 4 GB" (used 1 decimal, total 0 decimals when integral)
    public static func memValueLabel(usedBytes: UInt64, totalBytes: UInt64) -> String   // "19.2 / 36 GB"
}
// DiskMath.swift
public struct VolumeInfo: Identifiable, Equatable, Sendable {
    public var id: String          // mount path
    public var name: String        // "Macintosh HD"
    public var kind: String        // "APFS · internal" | "APFS · external" | "SMB · network" | "<fs> · <location>"
    public var usedBytes: UInt64, totalBytes: UInt64
    public var percent: Double
    public var bsdName: String?    // "disk3s1"
}
public struct DiskIOSample: Equatable, Sendable { public var readBytes: UInt64, writeBytes: UInt64 }
public enum DiskMath {
    public static func kindLabel(format: String?, isInternal: Bool, isRemovable: Bool, isLocal: Bool) -> String   // "APFS · internal" / "APFS · external" / "SMB · network" (non-local → "network")
    public static func wholeDisk(fromBSDName: String) -> String       // "disk3s1" → "disk3"; "disk0" → "disk0"
    public static func rates(current: DiskIOSample, previous: DiskIOSample, interval: TimeInterval) -> (read: Double, write: Double)?   // bytes/s, nil if interval ≤ 0
    public static func capacityLabel(used: UInt64, total: UInt64) -> String   // "612 GB / 926 GB" via Formatters.capacity
}
// MemoryProvider.swift
final class MemoryProvider: ObservableObject, SampledProvider {
    init(historyCapacity: Int)
    @Published private(set) var breakdown: MemoryBreakdown
    @Published private(set) var pressure: MemoryPressureLevel = .normal   // DispatchSource.makeMemoryPressureSource(eventMask: [.normal, .warning, .critical])
    @Published private(set) var swapUsed: UInt64 = 0, swapTotal: UInt64 = 0   // sysctl vm.swapusage (xsw_usage)
    @Published private(set) var usedHistory: RingBuffer<Double>       // usedPercent
    var totalLabel: String   // "36 GB unified"
}
// DiskProvider.swift
struct DiskIO: Equatable { var readRate: Double; var writeRate: Double; var readHistory: RingBuffer<Double>; var writeHistory: RingBuffer<Double> }   // MB/s values in histories
final class DiskProvider: ObservableObject, SampledProvider {
    init(historyCapacity: Int)
    @Published private(set) var volumes: [VolumeInfo] = []            // FileManager.mountedVolumeURLs(includingResourceValuesForKeys:options: [.skipHiddenVolumes]); exclude volumes with totalBytes == 0; sort: internal first, then by name
    @Published private(set) var io: [String: DiskIO] = [:]            // key = VolumeInfo.id; missing key → view shows no sparklines / "—"
    var volumeCount: Int
}
```
I/O: enumerate `IOBlockStorageDriver` services, read `Statistics` → `"Bytes (Read)"`, `"Bytes (Write)"`; find the driver's child `IOMedia` `BSD Name` (whole disk, e.g. "disk0"). Map each volume: `statfs` → `f_mntfromname` "/dev/disk3s1" → try whole disk "disk3"; if no driver stats exist for it (APFS synthesized container), fall back to the internal physical drive stats (the first IOBlockStorageDriver with non-zero stats, when the volume `isInternal`). Network volumes → no `io` entry. Volumes are re-enumerated every 5 s (not every tick); I/O every tick.
- [ ] Tests: breakdown formulas with round numbers; `swapLabel(1_288_490_189, 4_294_967_296) == "swap 1.2 / 4 GB"`; `memValueLabel == "19.2 / 36 GB"`; kindLabel cases; wholeDisk; rates; capacityLabel "612 GB / 926 GB" and "1.86 TB / 2.00 TB".
- [ ] Implement, build, tests, commit.

---

### Task 5: NetworkProvider + ping (Wave B)

**Files:** Create `Sources/XeneonWidgetsCore/NetworkMath.swift`, `Sources/XeneonWidgets/Data/NetworkProvider.swift`, `Data/PingService.swift`; fill `NetworkMathTests.swift`.

**Spec:** §01 Overview → net box (items 1–4 + Sources); §08 interface popover row content; §Fallbacks (No Wi-Fi); FEATURES §4, §12.

**Produces:**
```swift
// NetworkMath.swift
public enum InterfaceKind: String, Equatable, Sendable, CaseIterable { case wifi = "Wi-Fi", ethernet = "Ethernet", usb = "USB", other = "Other" }
public enum NetworkSelection: Equatable, Sendable {
    case auto, interface(String)
    public init(rawValue: String)     // "auto" or name
    public var rawValue: String
    public var chipLabel: String      // "Auto" | kind label supplied by view
}
public struct InterfaceCounters: Equatable, Sendable { public var inBytes: UInt64, outBytes: UInt64 }
public enum NetworkMath {
    /// Sums counters of the selected interfaces (auto → all names with prefix "en" that are active).
    public static func aggregate(_ counters: [String: InterfaceCounters], selection: NetworkSelection, activeNames: Set<String>) -> InterfaceCounters
    public static func rates(current: InterfaceCounters, previous: InterfaceCounters, interval: TimeInterval) -> (down: Double, up: Double)?  // bytes/s; nil if interval ≤ 0 or previous == zero
    public static func kind(forSCInterfaceType type: String?, bsdName: String) -> InterfaceKind   // "IEEE80211" → wifi; "Ethernet" → ethernet (bsdName-based USB detection: SC type "Ethernet" with hardware "USB" in localized name → usb); else other
    public static func rateScaleLabel(bytesPerSecond: Double, arrow: String) -> String  // "↓ 60 MB/s" using niceScale of MB
}
// NetworkProvider.swift
struct NetInterface: Identifiable, Equatable {
    var id: String { name }
    var name: String            // "en0"
    var kind: InterfaceKind
    var displayName: String     // SCNetworkInterface localized display name, e.g. "Wi-Fi"
    var ipv4: String?
    var isActive: Bool          // has IPv4 and IFF_UP|IFF_RUNNING
}
struct WiFiInfo: Equatable { var ssid: String?; var rssi: Int; var txRateMbps: Double }
final class NetworkProvider: ObservableObject, SampledProvider {
    init(historyCapacity: Int, selection: NetworkSelection, pingHost: String)
    @Published private(set) var interfaces: [NetInterface] = []
    @Published var selection: NetworkSelection                     // setting it resets peaks/histories? NO — keep totals/peaks; only rates switch
    @Published private(set) var downRate: Double = 0, upRate: Double = 0        // bytes/s
    @Published private(set) var downPeak: Double = 0, upPeak: Double = 0
    @Published private(set) var downTotal: UInt64 = 0, upTotal: UInt64 = 0       // since app start
    @Published private(set) var downHistory: RingBuffer<Double>, upHistory: RingBuffer<Double>   // bytes/s
    @Published private(set) var wifi: WiFiInfo? = nil               // CoreWLAN CWWiFiClient.shared().interface(); nil when no Wi-Fi interface is active
    @Published private(set) var pingMilliseconds: Double? = nil     // nil until first reply / on failure
    var activeInterface: NetInterface?                              // resolved selection (auto → the active interface carrying the default route: first active wifi/ethernet)
    var hostName: String                                            // Host.current().localizedName ?? "Mac"
    var valueLabel: String                                          // "en0 · Wi-Fi"
    var metaLabel: String                                           // "Tolaria · 192.168.1.42"
}
// PingService.swift — ICMP echo via SOCK_DGRAM/IPPROTO_ICMP (unprivileged on macOS), 1 request every 2 s, 1 s timeout; result on main. Fallback: if socket creation fails → `latency == nil` forever (view hides the ping segment).
final class PingService { init(host: String); var latencyMilliseconds: ((Double?) -> Void)?; func start(); func stop(); func setHost(_ host: String) }
```
Interface discovery every 5 s: `SCNetworkInterfaceCopyAll()` for kind/displayName by BSD name; `getifaddrs` for AF_INET address + flags + AF_LINK `if_data` counters.
- [ ] Tests: aggregate auto sums only active `en*`; selection specific picks one; rates warm-up nil; kind mapping; `rateScaleLabel(48_200_000, "↓") == "↓ 50 MB/s"`.
- [ ] Implement, build, tests, commit.

---

### Task 6: ProcessProvider (Wave B)

**Files:** Create `Sources/XeneonWidgetsCore/ProcessMath.swift`, `Sources/XeneonWidgets/Data/ProcessProvider.swift`; fill `ProcessMathTests.swift`.

**Spec:** §01 Overview → proc box (chips, columns, sources); §03 Focus Processes + DetailSheet stat tiles; §07 kill semantics; FEATURES §5, §12.

**Produces:**
```swift
// ProcessMath.swift
public enum ProcSort: String, CaseIterable, Codable, Sendable { case cpu, mem, pid, name }
public enum ProcFilter: String, CaseIterable, Sendable { case all = "All", apps = "Apps", background = "Background", system = "System", mine = "Mine", highCPU = "High CPU" }
public struct ProcessSample: Identifiable, Equatable, Sendable {
    public var id: pid_t { pid }
    public var pid: pid_t, parentPID: pid_t
    public var name: String, user: String, uid: uid_t
    public var path: String
    public var cpuPercent: Double, residentBytes: UInt64, threads: Int
    public var openFiles: Int?                 // PROC_PIDLISTFDS count (detail only)
    public var startTime: Date?
    public var isApp: Bool                     // path contains ".app/" or NSRunningApplication exists
    public var isSystem: Bool                  // uid == 0 || path hasPrefix "/System/" || "/usr/libexec/" || "/sbin/" || "/usr/sbin/"
    public init(...)
}
public enum ProcessMath {
    /// CPU % = Δ(user+system) ns / Δwall ns × 100, clamped 0…(100 × coreCount).
    public static func cpuPercent(deltaCPUNanoseconds: UInt64, deltaWallNanoseconds: UInt64) -> Double
    public static func filter(_ procs: [ProcessSample], by filter: ProcFilter, currentUID: uid_t) -> [ProcessSample]
    // apps: isApp; background: !isApp && !isSystem; system: isSystem; mine: uid == currentUID; highCPU: cpuPercent >= 10
    public static func sort(_ procs: [ProcessSample], by sort: ProcSort) -> [ProcessSample]   // cpu/mem descending, pid ascending, name case-insensitive ascending
    public static func memLabel(_ bytes: UInt64) -> String    // "3.92 GB" (2 decimals), < 1 GB → "512 MB"
}
// ProcessProvider.swift
struct ProcessDetail: Equatable { var cpuHistory: RingBuffer<Double>; var memHistory: RingBuffer<Double> /* GB */ }   // 60 samples
final class ProcessProvider: ObservableObject, SampledProvider {
    init()
    @Published private(set) var processes: [ProcessSample] = []     // ALL processes, unsorted
    @Published private(set) var processCount: Int = 0, threadCount: Int = 0
    @Published private(set) var detail: ProcessDetail? = nil        // for `watchedPID`
    var watchedPID: pid_t?                                          // set from main; provider fills detail 60-sample histories
    func icon(for proc: ProcessSample) -> NSImage                   // cached by pid; NSRunningApplication(processIdentifier:)?.icon ?? NSWorkspace.shared.icon(forFile: path) ?? generic
    func terminate(_ pid: pid_t) -> Bool                            // kill(pid, SIGTERM) == 0
    func forceQuit(_ pid: pid_t) -> Bool                            // kill(pid, SIGKILL) == 0
    var currentUID: uid_t
}
```
Sampling: `proc_listpids(PROC_ALL_PIDS)`, per pid `proc_pidinfo(PROC_PIDTASKINFO)` (pti_total_user/system are Mach absolute time on Apple Silicon → convert via `mach_timebase_info`), `PROC_PIDTBSDINFO` (pbi_comm/pbi_name, pbi_uid, pbi_ppid, pbi_start_tvsec), `proc_pidpath`; user via `getpwuid` cached per uid. Name: `NSRunningApplication.localizedName` when available else last path component else pbi_name. Sample at most once per second even at 0.5 s intervals.
- [ ] Tests: cpuPercent; each filter; each sort; memLabel "3.92 GB"/"512 MB".
- [ ] Implement, build, tests, commit.

---

### Task 7: PowerProvider + ClockProvider (Wave B)

**Files:** Create `Sources/XeneonWidgetsCore/PowerMath.swift`, `Sources/XeneonWidgets/Data/PowerProvider.swift`, `Data/ClockProvider.swift`; fill `PowerMathTests.swift`; Modify `Resources/Info.plist` (add `NSCalendarsFullAccessUsageDescription` "Shows your next calendar event in the ambient dashboard.").

**Spec:** §HeaderBar (BatteryPill, clock, date, sources); §04 Ambient (next event); §Fallbacks; FEATURES §1, §12, §13.

**Produces:**
```swift
// PowerMath.swift
public struct BatteryInfo: Equatable, Sendable {
    public var percent: Double, isCharging: Bool, isPresent: Bool
    public var minutesRemaining: Int?         // nil when calculating/unknown
    public var watts: Double?                 // |Amperage × Voltage| / 1e6 from AppleSmartBattery (mA × mV)
    public var cycleCount: Int?
}
public enum PowerMath {
    public static func watts(amperageMilliamps: Int, voltageMillivolts: Int) -> Double   // abs(mA×mV)/1e6, e.g. (−1200, 15_300) → 18.36
    public static func remainingLabel(minutes: Int?, watts: Double?) -> String   // "2:41 · 18.4 W" ; minutes nil → "— · 18.4 W" ; watts nil → "2:41"; both nil → ""
}
// PowerProvider.swift
final class PowerProvider: ObservableObject, SampledProvider {
    @Published private(set) var battery: BatteryInfo? = nil   // nil on desktops → header hides the pill
    // IOPSCopyPowerSourcesInfo/IOPSCopyPowerSourcesList/IOPSGetPowerSourceDescription: kIOPSCurrentCapacityKey, kIOPSIsChargingKey, kIOPSTimeToEmptyKey/kIOPSTimeToFullChargeKey (−1 → nil)
    // IORegistry AppleSmartBattery: "Amperage" (Int, signed), "Voltage", "CycleCount"
}
// ClockProvider.swift (1 Hz on main via Timer, independent of Sampler)
struct CalendarEvent: Equatable { var title: String; var start: Date }
final class ClockProvider: ObservableObject {
    init(); func start(); func stop()
    @Published private(set) var now: Date
    @Published private(set) var uptime: TimeInterval          // ProcessInfo.processInfo.systemUptime
    @Published private(set) var nextEvent: CalendarEvent? = nil   // EventKit: requestFullAccessToEvents (macOS 14+) / requestAccess(to: .event) (13); refreshed every 60 s; nil if denied/none in next 24 h
    let hostName: String          // Host.current().localizedName ?? "Mac"
    let osVersion: String         // "macOS 15.6"
}
```
- [ ] Tests: watts; remainingLabel variants.
- [ ] Implement, build, tests, commit.

---

### Task 8: Component library (Wave B)

**Files:** Create under `Sources/XeneonWidgets/UI/Components/`: `BoxContainer.swift`, `HistoryGraph.swift`, `MirrorGraph.swift`, `Sparkline.swift`, `BigNumber.swift`, `KVRow.swift`, `StatePill.swift`, `Chip.swift`, `ChipRow.swift`, `CoreBars.swift`, `SegBar.swift`, `Legend.swift`, `DiskRow.swift`, `ProcRow.swift`, `ProcHeader.swift`, `BatteryPill.swift`, `AlertChip.swift`, `Hairline.swift`, `DashButton.swift`, `HoldToConfirmButton.swift`, `AppIconView.swift`, `PageDots.swift`.

**Spec:** §Box container; §Type; §Spacing & radii; §Motion; the component descriptions inside §01–§08; `html_reference/btop/components.jsx` for exact geometry (read it). Screenshots 01, 03, 05 for look.

**Interfaces — Consumes:** Theme/Typography/Metrics/Motion, GraphMath, Threshold, StateLevel, Formatters. **Produces (views take plain values only — no providers):**

```swift
struct BoxContainer<Content: View>: View {
    init(title: String, meta: String? = nil, value: String? = nil, valueColor: Color? = nil,
         glow: Color? = nil, padding: CGFloat = Metrics.boxPadding, gap: CGFloat = Metrics.innerGap,
         @ViewBuilder content: () -> Content)
    // RoundedRectangle(20) fill theme.surface, 1 px hairline stroke (or glow colour + shadow "0 0 0 1 glow, 0 0 40 −6 glow"), header row per Global Constraints, then content in a VStack(spacing: gap). Clips content.
}
enum GraphStyle { case ramp; case solid(Color) }
struct HistoryGraph: View {
    init(values: [Double], min: Double = 0, max: Double = 100, style: GraphStyle = .ramp, showGrid: Bool = true,
         thresholds: [Double] = [50, 80], lineWidth: CGFloat = 2, fillOpacity: Double = 0.28, cornerLabel: String? = nil)
    // Fills its frame (use GeometryReader). Path = smoothSegments(points(...)); area fill gradient (bottom 0.02 → top fillOpacity) of rampLow→rampHigh (ramp) or the solid colour; dashed hairlines "3 5" at thresholds when showGrid; cornerLabel 12 mono text3 top-right. Values are drawn as-is; caller pads/buckets.
}
struct MirrorGraph: View {
    init(down: [Double], up: [Double], downScale: Double, upScale: Double, downLabel: String, upLabel: String)
    // down above centre (accent, fill 0.4→0.02), up mirrored below (theme.up), centre line text3 @ 50 %, labels 12 mono text3 at top-left / bottom-left. halfHeight = h/2 − 6.
}
struct Sparkline: View { init(values: [Double], color: Color, max: Double? = nil, min: Double = 0, lineWidth: CGFloat = 1.5) }   // fill 0.35 → 0
struct BigNumber: View { init(value: String, unit: String? = nil, label: String? = nil, size: CGFloat = 72, color: Color? = nil) }  // unit at 36 % size text2; label 15 Pro text3 beneath; tracking −2 when size ≥ 56; `.contentTransition(.numericText())` + Motion.numberTween
struct KVRow: View { init(key: String, value: String, valueColor: Color? = nil, mono: Bool = true) }    // key 15 Pro text3 left, value 15 mono text2 right
struct StatePill: View { init(label: String, value: String, level: StateLevel) }   // 32 tall r16 surface2; 8 px dot in level colour; "Thermal · Nominal" 14 pro text2; value in level colour
struct Chip: View { init(title: String, selected: Bool, height: CGFloat = 56, action: @escaping () -> Void) }   // selected = fill theme.text, label theme.bg; else surface2 fill, text2 label; radius 14; chip font 15 Pro Semibold
struct ChipRow: View { init(titles: [String], selectedIndex: Int, height: CGFloat = 56, onSelect: @escaping (Int) -> Void, onLongPress: ((Int) -> Void)? = nil) }   // equal widths, gap 8
struct CoreBars: View { init(title: String, values: [Double], barWidth: CGFloat = 32, barHeight: CGFloat = 96, gap: CGFloat = 8) }  // header: title 13 pro text3 + "avg NN%" 14 mono text2; bars radius 6 track surface2, fill = ramp gradient anchored to full track height (mask a full-height gradient with the % rect); value 12 mono text3 beneath
struct SegBar: View { struct Segment: Identifiable { let id: String; let value: Double; let color: Color; let opacity: Double } ; init(segments: [Segment], height: CGFloat = 14) }   // 2 px gaps, radius h/2
struct Legend: View { init(items: [(label: String, value: String, color: Color, opacity: Double)], columns: Int = 2) }   // 10 px swatch r3 · label 15 Pro text3 · value 15 mono text2
struct DiskRow: View { init(name: String, kind: String, capacityLabel: String, percent: Double, readHistory: [Double]?, writeHistory: [Double]?, readLabel: String?, writeLabel: String?, showIO: Bool, crit: Bool) }   // 56 tall; grid 1fr 150 84 (showIO) or 1fr 120; 6 px bar disk-threshold colour; sparklines 70 × 22 accent/up; "R 12.4 MB/s" 12 mono with R in accent, W in up
struct ProcRow: View {
    struct Model: Identifiable, Equatable { let id: pid_t; let icon: NSImage?; let name: String; let pid: String; let user: String; let threads: String; let mem: String; let cpu: Double; let memHistory: [Double]; let cpuHistory: [Double] }
    init(model: Model, wide: Bool, selected: Bool, height: CGFloat, fontSize: CGFloat, onTap: @escaping () -> Void)
    // compact grid 28 1fr 60 96 92 76 40 (icon name pid user mem cpu thr); wide grid 32 480 80 140 60 90 110 90 90 + filler (icon name pid user thr memSpark mem cpuSpark cpu); gap 12; h-padding 10; radius 12; selected → surface2 fill + 1 px accent inset ring; cpu coloured by Threshold.process
}
struct ProcHeader: View { init(wide: Bool, sort: ProcSort, onTap: @escaping (ProcSort) -> Void) }   // 24 tall; 12 Pro tracking 1.2 uppercase text3; active column text + semibold + "↓" on cpu/mem
struct BatteryPill: View { init(percent: Double, isCharging: Bool, detail: String) }   // 40 tall r20 surface + hairline; 30 × 14 glyph (fill ok when charging, crit < 20 %, else text); "82%" 18 mono semibold; ⚡︎ ok when charging (SF "bolt.fill"); detail 14 mono text3
struct AlertChip: View { init(text: String, age: String, level: StateLevel, action: @escaping () -> Void) }   // 40 tall r20; fill level colour 18 %, border 45 %, text level colour 15 Pro Semibold; dot 10 px pulsing (Motion.alertPulse, opacity 1 → 0.35); age 15 mono @ 75 %
struct Hairline: View { init(vertical: Bool = false) }   // 1 px theme.hairline
enum ButtonKind { case primary, secondary, destructive, destructiveTinted }
struct DashButton: View { init(_ title: String, kind: ButtonKind = .secondary, width: CGFloat? = nil, height: CGFloat = 56, action: @escaping () -> Void) }
// primary: fill text, label bg; secondary: surface2 + hairline, label text; destructive: crit fill, white; destructiveTinted: crit 18 % fill, crit 50 % border, crit label. radius 16, 18 Pro Semibold
struct HoldToConfirmButton: View { init(title: String, holdSeconds: Double, action: @escaping () -> Void) }
// crit fill, white 18 semibold; left→right rgba(0,0,0,0.25) overlay showing progress; trailing "0.6 / 1.0 s" 14 mono; releasing before holdSeconds cancels; fires once on completion. Implement with DragGesture(minimumDistance: 0) onChanged start + CADisplayLink/Timer progress, onEnded cancel.
struct AppIconView: View { init(image: NSImage?, size: CGFloat) }   // rounded radius size×0.24; placeholder surface2 when nil
struct PageDots: View { init(count: Int, index: Int) }   // 6 px dots gap 8, active = text, others text3
```
- [ ] Build each component; keep each file focused. No tests possible for views in the self-test target — instead **verify by compiling** and by writing a temporary `#if DEBUG` preview-free harness? No: acceptance = `swift build` with zero warnings and every signature above present exactly. Commit per group: `feat(ui): graph components`, `feat(ui): box container, pills, chips, buttons`, `feat(ui): rows (disk, proc, battery, alert)`.

---

### Task 9: HeaderBar (Wave C)

**Files:** Create `Sources/XeneonWidgets/UI/Boxes/HeaderBar.swift`.

**Spec:** §HeaderBar; §05 AlertStrip (chips, max 3 + "+N"); FEATURES §1. Screenshots 01 (header) and 05 (alerts).

**Consumes:** `ClockProvider`, `PowerProvider`, `DashboardState` (alerts, isDisplayConnected, sampling, preset for page dots), components `BatteryPill`, `AlertChip`, `PageDots`, `Formatters`. **Produces:**
```swift
struct HeaderBar: View {
    init(clock: ClockProvider, power: PowerProvider, state: DashboardState, onAlertTap: @escaping (Alert) -> Void, showPageDots: Bool)
    // Height 56. Left cluster (15 Pro text3, gap 12): 8 px dot (ok when state.isDisplayConnected else text3) · hostname (text2 semibold) · osVersion · "·" · Formatters.uptime · "·" · "Xeneon Connected"/"Xeneon Not Connected" · "·" · sampling.label (mono).
    // Centre: HStack of AlertChips (gap 10) for the first 3 alerts, then "+N" chip (surface2) when more; age = Formatters.age(now − since). Page dots (when showPageDots) sit under/next to the strip.
    // Right: BatteryPill (only when power.battery != nil; detail = PowerMath.remainingLabel) · clock "14:32" 44 mono semibold + ":07" 44 regular text3 · "Thu 4 Sep · W36" 16 Pro text2 (date) / text3 (week).
}
```
- [ ] Implement, `swift build` zero warnings, commit `feat(ui): header bar with alert strip`.

---

### Task 10: CPUBox + TimeRangePopover (Wave C)

**Files:** Create `Sources/XeneonWidgets/UI/Boxes/CPUBox.swift`, `UI/Boxes/TimeRangePopover.swift`.

**Spec:** §01 Overview cpu (rows 1–3, all sizes), §02 Focus CPU (core grid 8 × 2), §08 time-range popover, §Fallbacks. Screenshots 01, 02, 08. `boxes.jsx` CPU section.

**Consumes:** `CPUProvider`, `DashboardState` (timeRange(for: .cpu), setTimeRange, sampling), components. **Produces:**
```swift
enum CPUBoxMode { case overview, focus }
struct CPUBox: View {
    init(cpu: CPUProvider, state: DashboardState, mode: CPUBoxMode, uptime: TimeInterval)
    // BoxContainer(title: "cpu", meta: "\(cpuModel) · \(coreConfigLabel) · \(Formatters.uptime(uptime))", value: "34%", valueColor: stateColor(total, .cpu))
    // Row 1 (gap 24): HistoryGraph (overview 404 × 240; focus: fills width − 268 − 24, height 200) of totalHistory windowed to state.timeRange(for: .cpu) → padLeading → bucket(into: Int(width/3)); cornerLabel "\(range.label) · tap for range"; tap → TimeRangePopover. Right column 268: BigNumber("34", unit: "%", label: "total · 16 cores"); StatePill("Thermal", thermal.label, level); KVRow("load 1 · 5 · 15", "3.21  2.87  2.40"); freq row hidden (perCoreFrequencyAvailable == false).
    // Row 2 overview: CoreBars("12 P-cores", P values) · 1 px vertical Hairline · CoreBars("4 E-cores", E values). focus: LazyVGrid 8 columns × 2 rows, gap 12, cell surface2 r12 padding 8/10, 3 px left border accent for E-cores (transparent for P): "P0 … 23%" 13 mono (value state-coloured) + HistoryGraph(style: .ramp, showGrid: false) height 56 from coreHistories windowed like row 1.
    // Row 3 (only when cpu.gpu != nil): Hairline; HStack(gap 20): "gpu" boxTitle · HistoryGraph(showGrid: false) width clamp(innerWidth − 470, 160, 320) × 56 · BigNumber("18", unit "%", size 34, label "40-core GPU" → use "GPU") · right KVs "gpu memory" "4.2 / 36 GB", "source" "IOKit perf stats". When gpu == nil the cores row grows.
}
struct TimeRangePopover: View { init(selected: TimeRange, onSelect: @escaping (TimeRange) -> Void) }   // 4 chips 92 × 56 ("1 min" "5 min" "15 min" "1 h"), padding 8, r18, fill theme.sheet, shadow 0 20 60 rgba(0,0,0,.45). Presented centred over the graph via an overlay + @State in CPUBox; tap outside closes.
```
- [ ] Implement, build zero warnings, commit `feat(ui): cpu box (overview + focus) and time-range picker`.

---

### Task 11: MemBox with disks (Wave C)

**Files:** Create `Sources/XeneonWidgets/UI/Boxes/MemBox.swift`.

**Spec:** §01 Overview mem (items 1–5), §02 compact variant (480 wide: disks without I/O sparks, grid 1fr 120, legend single column), §05 (crit states: value crit, pressure pill crit, disk row value crit ≥ 90 %). Screenshots 01, 02, 05. `boxes.jsx` MEM section.

**Consumes:** `MemoryProvider`, `DiskProvider`, `DashboardState`, components. **Produces:**
```swift
struct MemBox: View {
    init(memory: MemoryProvider, disks: DiskProvider, compact: Bool, glow: Color? = nil)
    // BoxContainer(title: "mem", meta: memory.totalLabel, value: MemoryMath.memValueLabel(used,total), valueColor: pressure != .normal ? pressure colour : stateColor(usedPercent, .memory), glow: glow)
    // 1: HStack: BigNumber("53", unit "%", size 56, label "used", color mem state) · VStack: StatePill("Pressure", pressure.label, pressure.stateLevel) + "swap 1.2 / 4 GB" 14 mono text3
    // 2: SegBar App(rampHigh) Wired(rampMid) Compressed(up) Cached files(rampLow) Free(text3 @ 0.25)
    // 3: Legend (2 columns; compact → 1) values Formatters.gigabytes(_, decimals: 1)
    // 4: Hairline; HStack: "disks" boxTitle · Spacer · "\(count) volumes · R W MB/s" 14 mono text3 with "R" accent / "W" up (compact: "\(count) volumes")
    // 5: up to 4 DiskRows (56 tall), showIO: !compact; crit when percent ≥ 90; io from disks.io[volume.id]; histories in MB/s
}
```
- [ ] Implement, build, commit `feat(ui): memory box with disks`.

---

### Task 12: NetBox + InterfacePopover (Wave C)

**Files:** Create `Sources/XeneonWidgets/UI/Boxes/NetBox.swift`, `UI/Boxes/InterfacePopover.swift`.

**Spec:** §01 Overview net (items 1–4), §02 compact (500 wide, graph 230 tall, **no chip row**), §08 interface popover; §Fallbacks (No Wi-Fi → footer shows link type only). Screenshots 01, 02, 08. `boxes.jsx` NET section.

**Consumes:** `NetworkProvider`, `DashboardState`, `SettingsStore` (persist selection via provider.selection didSet handled in Task 14), components. **Produces:**
```swift
struct NetBox: View {
    init(network: NetworkProvider, compact: Bool)
    // BoxContainer(title: "net", meta: network.metaLabel, value: network.valueLabel)
    // 1: MirrorGraph 436 × 300 (compact: height 230) — down/up histories windowed to 5 min (fixed), bytes → MB/s; scales GraphMath.niceScale(peak of window, floor 1); labels NetworkMath.rateScaleLabel
    // 2: two Rate blocks: "↓" 30 mono accent + "12.4" 36 mono semibold + "MB/s" 14 text3; below "peak 48.2 · total 3.1 GB" 13 mono text3. Same for "↑" in theme.up.
    // 3 (not compact): ChipRow 56: "Auto" · "Wi-Fi" · "Ethernet" · "USB" — selected = matches network.selection (auto, or kind of the selected interface); tap → select auto / first active interface of that kind (disabled look at 40 % opacity when no such interface); long-press → InterfacePopover.
    // 4: footer 14 mono text3 joined by " · ": "RSSI −54 dBm" (wifi only), "link 866 Mb/s" (wifi txRate) or "link Ethernet", "ping 1.1.1.1 12 ms" (value coloured by Threshold.ping; segment hidden when pingMilliseconds == nil)
}
struct InterfacePopover: View { init(interfaces: [NetInterface], selected: NetworkSelection, onSelect: @escaping (NetworkSelection) -> Void) }
// rows 56 tall: "Auto" then each interface: "Wi-Fi" 17 Pro Medium + "en0 · 192.168.1.42" 14 mono sub; ✓ on selected; selected row surface2; container r18 theme.sheet, shadow like the time-range popover; presented above the chip row.
```
- [ ] Implement, build, commit `feat(ui): network box and interface picker`.

---

### Task 13: ProcBox, ProcessDetailSheet, Force-Quit confirmation (Wave C)

**Files:** Create `Sources/XeneonWidgets/UI/Boxes/ProcBox.swift`, `UI/Boxes/ProcessDetailSheet.swift`, `UI/Boxes/ForceQuitConfirmCard.swift`.

**Spec:** §01 Overview proc (items 1–4), §03 Focus Processes (wide table 9 × 44, DetailSheet layout), §07 confirmation card + hold semantics, §08 gestures (tap row → sheet, tap header → sort, long-press chip → sort menu is out of scope beyond header tap). Screenshots 01, 03, 07. `presets.jsx` sheet section, `boxes.jsx` PROC.

**Consumes:** `ProcessProvider`, `DashboardState` (selectedPID, confirm), components (`ProcRow`, `ProcHeader`, `ChipRow`, `DashButton`, `HoldToConfirmButton`, `HistoryGraph`, `AppIconView`, `Sparkline`). **Produces:**
```swift
struct ProcBox: View {
    init(processes: ProcessProvider, state: DashboardState, wide: Bool, onHeaderTap: (() -> Void)? = nil)
    @State sort: ProcSort = .cpu; @State filter: ProcFilter = .all
    // BoxContainer(title: "proc", meta: "412 processes · 2418 threads", value: wide ? "\(rows) · \(sort) ↓" : "top 7 · cpu ↓", gap: 12)
    // ChipRow 48 tall of ProcFilter titles; ProcHeader(wide, sort, onTap: set sort); rows: overview 7 × 54 (17 pt), wide 9 × 44 (16 pt) from ProcessMath.sort(filter(...)); ProcRow.Model built from ProcessSample (mem via ProcessMath.memLabel, histories only for wide from provider.detail when pid == watched else []).
    // Row tap → state.selectedPID = pid (and processes.watchedPID = pid). Footer 14 text3: "tap row → details · long-press → sort" | "tap header → full list" (the latter triggers onHeaderTap when non-nil).
    // In wide mode the selected row shows surface2 + accent ring and the ProcessDetailSheet is overlaid on the trailing edge.
}
struct ProcessDetailSheet: View {
    init(process: ProcessSample, icon: NSImage?, detail: ProcessDetail?, state: DashboardState, onTerminate: @escaping () -> Void, onForceQuit: @escaping () -> Void, onClose: @escaping () -> Void)
    // 780 wide, full body height, fill theme.sheet, r24, hairline, shadow −30 0 90 rgba(0,0,0,.55), padding 28, gap 20:
    // header: AppIconView 64 · name 30 Pro Semibold · "PID 2210 · philipp · Running · since 09:40" 15 mono text3 · × close 56 ⌀ surface2
    // command: path 14 mono text2 in surface2 r12 padding 12/14, wraps
    // 4 stat tiles (gap 12, surface2 r14, padding 12/14): label 13 text3 + value 28 mono semibold — "CPU" (state-coloured), "Memory", "Threads", "Files" (openFiles ?? "—")
    // two graphs 354 × 96: "CPU · last 60 s" (ramp), "Memory · last 60 s" (solid accent, no thresholds)
    // bottom (Spacer above): when state.confirm == nil → DashButton("Terminate", .secondary) + DashButton("Force Quit…", .destructiveTinted); else → ForceQuitConfirmCard
}
struct ForceQuitConfirmCard: View {
    init(processName: String, action: ConfirmAction, onCancel: @escaping () -> Void, onConfirm: @escaping () -> Void)
    // fill crit 12 %, border crit 40 %, r18, padding 20: title "Force quit Docker?" / "Terminate Docker?" 20 Pro Semibold · body "Running containers will stop and unsaved state is lost. This cannot be undone." (force quit) / "The process is asked to quit and may save its state first." (terminate) 15 text2 · HStack: DashButton("Cancel", .secondary) flex 1 + HoldToConfirmButton("Hold to Force Quit"/"Hold to Terminate", holdSeconds: 1.0 / 0.5) flex 1.4
}
```
- [ ] Implement, build zero warnings, commit `feat(ui): process box, detail sheet, hold-to-confirm`.

---

### Task 14: Presets, root view, swipe, wiring, preview mode, old code removal (Wave D)

**Files:**
- Create `Sources/XeneonWidgets/UI/Presets/DashboardRootView.swift`, `PresetLayoutView.swift`, `OverviewPreset.swift`, `FocusCPUPreset.swift`, `FocusProcessesPreset.swift`, `AmbientPreset.swift`, `SimpleBoxes.swift`
- Create `Sources/XeneonWidgets/App/DashboardEnvironment.swift`
- Modify `Sources/XeneonWidgets/App/AppDelegate.swift`, `Display/WidgetWindow.swift`, `Sources/XeneonWidgets/main.swift`
- Delete `Sources/XeneonWidgets/Widgets/*.swift`, `Sources/XeneonWidgets/Data/SystemStatsProvider.swift`

**Spec:** §Screen geometry, §Row 1 (all four presets incl. §04 Ambient), §08 gestures (swipe ← → with page dots), §State & architecture (touch gestures), §Fallbacks. Screenshots 01–04.

**Consumes:** everything from Tasks 2–13. **Produces:**
```swift
// DashboardEnvironment.swift — composition root (owned by AppDelegate)
@MainActor final class DashboardEnvironment {
    let settings: SettingsStore, layoutStore: LayoutStore, state: DashboardState
    let sampler: Sampler
    let cpu: CPUProvider, memory: MemoryProvider, disks: DiskProvider, network: NetworkProvider, processes: ProcessProvider, power: PowerProvider, clock: ClockProvider
    init()                    // builds everything with settings.sampling.historyCapacity; registers providers with sampler; network.selection ← settings.networkSelection and persists changes
    func start(); func stop()
    func setSampling(_ interval: SamplingInterval)    // state.sampling + sampler.setInterval + settings
}
struct DashboardRootView: View {
    init(env: DashboardEnvironment)
    // ZStack: theme.bg; content = PresetPager showing state.preset; DragGesture(minimumDistance: 40) on background/header → previous/next preset with Motion.presetSwipe whole-screen translation; PageDots visible for 1.5 s after a swipe (passed to HeaderBar showPageDots). Any tap/drag → state.noteActivity(). `.environment(\.theme, state.theme)`. Fixed frame 2560 × 720.
}
struct PresetLayoutView: View {
    init(env: DashboardEnvironment, preset: Preset, @ViewBuilder box: @escaping (BoxPlacement) -> AnyView)
    // VStack(spacing: 16): HeaderBar (56) then HStack(spacing: 16) of visible boxes each `.frame(width: placement.width, height: 608)`; padding 24. Ambient renders without header (handled by AmbientPreset).
}
struct OverviewPreset: View        // cpu(.overview) · mem(compact: false) · net(compact: false) · proc(wide: false, onHeaderTap → state.preset = .focusProcesses) + SimpleBoxes for gpu/battery/clock when un-hidden
struct FocusCPUPreset: View        // cpu(.focus) · mem(compact: true) · net(compact: true)
struct FocusProcessesPreset: View  // proc(wide: true) with ProcessDetailSheet overlay when state.selectedPID != nil (sheet anchored trailing, over the table)
struct AmbientPreset: View
    // No header. Horizontal padding 72, content vertically centred, space-between: ClockBig "14:32" 300 mono ultraLight tracking −12 + "07" at 32 % size text3; second line 33 Pro text2 "Thursday, 4 September · W36" + " · next: <title> · 15:00" only when clock.nextEvent != nil. Right column (gap 28) three rows: label 16 mono tracked ("cpu" "mem" "net ↓") · Sparkline 420 × 64 (cpu/mem state-coloured by current %, net accent) · value 36 mono medium right-aligned width 220 ("34%", "53%", "12.4 MB/s").
struct GPUBox, BatteryBox, ClockBox: View   // SimpleBoxes.swift — minimal BoxContainers reusing the GPU row / BatteryPill + cycle count KVs / clock + date; used only when un-hidden via edit mode
```
AppDelegate: replace `SystemStatsProvider`/`WidgetContainerView` with `DashboardEnvironment` + `DashboardRootView`; set `state.isDisplayConnected` from DisplayManager; add menu items **Preset ▸** (radio of `Preset.allCases`) and **Sampling ▸** (`SamplingInterval.allCases`, `menuLabel`) that drive `state.preset` / `env.setSampling`. **Preview mode:** when launched with `--preview` (or env `XENEON_PREVIEW=1`) and no Xeneon is connected, open the `WidgetWindow` on the main screen as a normal 1280 × 360 titled window whose content is the 2560 × 720 root view scaled 0.5 (`.scaleEffect(0.5, anchor: .topLeading)` in a 1280 × 360 frame) — used for screenshots during development. `swift run XeneonWidgets --preview` must show the Overview.
- [ ] Wire, delete old files, build zero warnings, run self-tests, run `swift run XeneonWidgets --preview` for ≥ 10 s and capture `screencapture -x /tmp/xeneon-preview.png` for the report; commit `feat(app): btop dashboard presets, swipe, and preview mode`.

---

### Task 15: Edit mode (Wave E)

**Files:** Create `Sources/XeneonWidgets/UI/Presets/EditModeOverlay.swift`, `UI/Presets/EditToolbar.swift`; Modify `UI/Presets/PresetLayoutView.swift` and `UI/Presets/DashboardRootView.swift` only where noted.

**Spec:** §06 Edit mode (handles, tilt, dashed outline, drag lift shadow, sibling slide, toolbar geometry, persistence per preset). Screenshot 06.

**Consumes:** `DashboardState.editMode/layout(for:)/updateLayout/resetLayout`, `LayoutSpec.hide/show/move/resize`, `Motion.siblingSlide`, `Motion.editTiltDegrees`, `DashButton`, `Chip`. **Produces:**
```swift
struct EditModeOverlay: View { init(index: Int, onHide: @escaping () -> Void, onResize: @escaping (CGFloat /* delta x */) -> Void, onResizeEnd: @escaping () -> Void) }
// three 56 ⌀ handles: "×" top-right (hide), "⋮⋮" grip top-left (drag handle — the drag is attached to the whole box in PresetLayoutView), resize grip bottom-right (28 × 28 L-shape 3 px text3; DragGesture → onResize(delta)). Dashed 2 px accent outline offset 4. Tilt: index even → −0.5°, odd → +0.5° (static).
struct EditToolbar: View { init(presetTitle: String, hidden: [BoxID], onShow: @escaping (BoxID) -> Void, onReset: @escaping () -> Void, onDone: @escaping () -> Void) }
// bottom-centre floating, r24 theme.sheet + hairline: "Editing · Overview" 15 text3 · Hairline(vertical) · "Hidden" + Chip("+ Battery") 140 × 56 per hidden box · Hairline · DashButton("Reset", .secondary, width 160) · DashButton("Done", .primary, width 160)
```
PresetLayoutView changes: `LongPressGesture(minimumDuration: 0.6)` on any box → `state.editMode = true`; in edit mode each box gets `EditModeOverlay`, `DragGesture` on the box moves it (lifted: shadow 0 30 80 rgba(0,0,0,.5), z-index up) and reorders when its centre crosses a sibling's midpoint → `LayoutSpec.move` with `Motion.siblingSlide`; resize grip → `LayoutSpec.resize(id, width + delta)`; all edits go through `state.updateLayout(spec, for: preset)` (persisted). DashboardRootView shows `EditToolbar` when `state.editMode`; swipe disabled in edit mode.
- [ ] Implement, build, verify in `--preview` (long-press a box with the mouse), commit `feat(ui): on-display edit mode with persisted layouts`.

---

### Task 16: Alerts monitor, edge glow, glance/burn-in mode (Wave E)

**Files:** Create `Sources/XeneonWidgets/UI/Presets/AlertMonitor.swift`, `UI/Presets/GlanceController.swift`; Modify `App/DashboardEnvironment.swift` (instantiate + start both), `UI/Presets/OverviewPreset.swift`/`FocusCPUPreset.swift` (pass `glow:` to affected boxes), `UI/Boxes/HeaderBar.swift` (only if the alert tap callback needs extra plumbing), `UI/Presets/DashboardRootView.swift` (glance dim/drift + auto-ambient, tap on alert chip → highlight box).

**Spec:** §05 alerts (rules, chips, edge glow, tap → highlight, auto-clear), §04 Ambient behaviour (enter after N idle minutes, brightness 60 %, ±4 px drift every 60 s, exit on touch or activity spike), FEATURES §7, §10.

**Consumes:** `AlertEngine`, providers, `DashboardState.alerts/glance/lastActivity/idleMinutes/preset`. **Produces:**
```swift
@MainActor final class AlertMonitor {
    init(state: DashboardState, cpu: CPUProvider, memory: MemoryProvider, disks: DiskProvider, power: PowerProvider)
    func start()   // Combine: on any provider publish (throttled to 1 s) build AlertInputs and set state.alerts = engine.evaluate(...)
    func stop()
    static func glowColor(for box: BoxID, alerts: [Alert], theme: Theme) -> Color?   // highest level alert for that box (crit > warn) else nil
}
@MainActor final class GlanceController {
    init(state: DashboardState, cpu: CPUProvider, network: NetworkProvider)
    func start(); func stop()
    @Published private(set) var driftOffset: CGSize   // new ±4 px value every 60 s while glance
    // every 10 s: if !glance && now − lastActivity ≥ idleMinutes → glance = true, remember previousPreset, state.preset = .ambient
    // exit: state.noteActivity() (touch) OR activity spike = cpu.total jumps ≥ 30 points vs 10 s ago or downRate > 5 MB/s → glance = false, preset = previousPreset
}
```
DashboardRootView: `.opacity(state.glance ? 0.6 : 1)` + `.offset(driftOffset)` animated 1 s; alert chip tap → `state.preset` switches to a preset containing the box if needed and the box flashes its glow (opacity pulse once, 0.6 s). Boxes receive `glow: AlertMonitor.glowColor(for:…)` → `BoxContainer(glow:)`.
- [ ] Implement, build, commit `feat(app): alert monitor with edge glow and glance mode`.

---

### Task 17: Docs and build script (Wave F)

**Files:** Modify `README.md`, `build.sh` (no functional change unless the bundle needs `NSCalendarsFullAccessUsageDescription` copied — it already copies `Resources/Info.plist`).

- [ ] README: replace Features/Project structure/Technical notes with the new dashboard (presets, gestures, alerts, edit mode, sampling, preview mode `swift run XeneonWidgets --preview`, data sources table from FEATURES §12, fallbacks §13, design docs location `docs/design/handoff-btop/`). Keep Install/Run/Login sections. Commit `docs: describe btop dashboard`.
