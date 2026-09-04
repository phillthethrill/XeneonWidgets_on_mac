# Implementation prompt — remaining btop-dashboard review fixes

Copy this file into an agent session (or open it in-repo) and execute it. Implement only the listed **still-open** items. Do not invent features. Do not re-implement Tasks 1–17.

**Reviewed:** 2026-09-04 · merged HEAD `3bf1ab2` (`btop-dashboard`, 76 commits vs `main` `df7aa82`)  
**Executed:** 2026-09-05 — `fix-a-core-providers` and `fix-b-ui` merged; GPU used-only label + process-detail graph bucketing applied. `swift build` / `XeneonWidgetsSelfTest` green.  
**Previous prompt:** Waves A–D only (Tasks 1–14). This rewrite covers the whole branch after Waves E–F landed.

---

You are a senior macOS / Swift implementer working in the **XeneonWidgets** repo on branch `btop-dashboard`.

## Goal

Apply the remaining surgical fixes from the full-branch review. Prefer small patches. Keep `swift build` and `swift run XeneonWidgetsSelfTest` green with **zero warnings in new code**.

## Status of the plan (do not re-do)

| Wave | Tasks | Merged HEAD |
|---|---|---|
| A | 1 Core, 2 App foundation | Done |
| B | 3–8 providers + components | Done |
| C | 9–13 boxes | Done |
| D | 14 presets, swipe, preview, old widgets deleted | Done |
| E | 15 edit mode, 16 alerts + glance | Done (one fix round each) |
| F | 17 README | Done (`3bf1ab2`) |

`swift build` is clean. `XeneonWidgetsSelfTest` passes. Preview screenshots of all four presets, edit mode, and synthetic alerts were captured during implementation.

**Merged:** `fix-a-core-providers` and `fix-b-ui` are on `btop-dashboard`. Do not re-implement Tasks 1–17 or the numbered review items.

## Do not do

- Do **not** add themes, portrait layouts, a Mac Settings window, or third-party dependencies.
- Do **not** rewrite the architecture (Core / providers / Theme / Sampler).
- Do **not** fake unavailable data (GPU, per-core freq, Wi-Fi, calendar, desktop battery).
- Do **not** relabel the detail-sheet **Files** tile as **Ports** (controller ruling: keep Files / FDs; it is open-file count from `PROC_PIDLISTFDS`).
- Do **not** change MemBox Free-legend swatch from 0.35 (matches JSX `Legend`; bar stays 0.25).
- Do **not** “fix” body height back to 608. Code is correct at **600** (`720 − 2·24 − 56 − 16`). The `// 608` comment in `presets.jsx` and Spec §Screen geometry are stale.
- Do **not** skip tests. Add a self-test wherever an item names one.

## Repo facts

- Product: menu-bar SwiftPM app that fills a Corsair Xeneon Edge (`2560×720` touch) with a btop-class system dashboard. macOS 13+. No App Sandbox. No third-party deps.
- Binding spec: `docs/design/handoff-btop/README.md` (OLED Black only).
- Plan: `docs/superpowers/plans/2026-09-04-btop-dashboard.md`.
- Layers:
  - `Sources/XeneonWidgetsCore/` — pure, testable math.
  - `Sources/XeneonWidgets/` — AppKit + SwiftUI, providers, theme, boxes, presets.
  - `Sources/XeneonWidgetsSelfTest/` — no-XCTest harness; `swift run XeneonWidgetsSelfTest` is the suite.
- Invariants:
  - Providers sample on `Sampler`’s background queue; `@Published` UI updates hop to main.
  - Ring buffers sized for 1 h at the current `SamplingInterval`.
  - Only destructive action: Terminate / Force Quit behind hold-to-confirm (`SIGTERM` / `SIGKILL`).
  - Theme via `@Environment(\.theme)`; only `.oled` shipped.
  - Body row = `Metrics.bodyHeight` (600). Pager is a 2560×720 viewport, HStack leading-aligned, offset `-index * 2560`.

## Verification after each patch (and at the end)

```bash
swift build
swift run XeneonWidgetsSelfTest
```

Both must pass.

---

## Verdict from this review (HEAD `3bf1ab2`)

**Ship with fixes.** Tasks 1–17 are on the branch and review-approved. Do not ship Terminate/Force Quit as-is (PID-only `kill`), and do not ship the Ventura calendar request (missing `NSCalendarsUsageDescription`). The rest is spec drift, cost, or leftover copy.

Closed since the previous prompt (do not re-open):

| Item | Why closed |
|---|---|
| Task 15 / 16 / 17 “not implemented” | All merged. Edit persist-on-end, exclusive enter-edit long-press, Done clears drag state, `glanceEnabled` gate, README rewrite. |
| Pager pin / body 600 / sheet over header / exclusive swipe | Task 14 fix rounds 1–2. |
| Files → Ports | Ruling: keep **Files**. |
| Free swatch 0.35 | Ruling: matches JSX Legend. |
| `--preview` even when Xeneon connected | Accepted developer flag. |

---

## P0 — implement first

### 1. EventKit request crashes on macOS 13 — FIXED

- Where: `Resources/Info.plist:26`, `Sources/XeneonWidgets/Data/ClockProvider.swift` (`requestAccess(to: .event)` on 13)
- Problem: Minimum OS is 13.0. `start()` always requests calendar. On 13 that uses `EKEventStore.requestAccess(to: .event)`, which requires `NSCalendarsUsageDescription`. The plist only has `NSCalendarsFullAccessUsageDescription` (14+). Missing usage string → process abort on first launch when status is `.notDetermined`.
- Fix: add the Ventura key (keep the 14+ key). Optional: skip `requestAccess` until Ambient is shown.
- Unmerged: `fix-a` `9de629e`.

### 2. Terminate / Force Quit identifies by PID only — FIXED

- Where: `DashboardState.swift:6-8` (`ConfirmAction` is `terminate(pid_t)` / `forceQuit(pid_t)`), `ProcessProvider.swift:169-175` (`kill(pid, SIGTERM/SIGKILL)`), `FocusProcessesPreset.swift`
- Problem: Sampling keys CPU by `pbi_start_tvsec`. Kill does not. `HoldToConfirmButton` keeps the action captured at press; if that PID is reused during the 0.5–1.0 s hold, `kill` hits the new occupant. Also does not refuse `getpid()`.
- Fix: carry `startTime` through `ConfirmAction`; `terminate/forceQuit(_:startedAt:)` refuse `getpid()` and require `ProcessMath.identityMatches`. Wire the sheet/preset to pass `process.startTime`. Test: same pid, different startTime → false.
- Unmerged: `fix-a` `94284bc`, `f1d540f`.

---

## P1 — implement next

### 3. `LayoutSpec.normalize()` can shrink boxes below `minBoxWidth` — FIXED

- Where: `Sources/XeneonWidgetsCore/LayoutSpec.swift:133-144`
- Problem: `resize` clamps the neighbour to 320, then `normalize()` scales **all** visible widths. An expand that floors the neighbour makes `current > target`, so the min-clamped box is scaled down. Edit mode persists this.
- Evidence: `resize(.cpu, width: 1500)` on default overview → mem clamped to 320, row sum 2944, scale ≈ 0.837 → mem ≈ 268.
- Fix: after scaling, clamp to `minBoxWidth`. If clamp makes the row short, pull width from boxes still above min (or refuse the extra delta in `resize`).
- Test: `resize(.cpu, width: 1500)` keeps all ≥ min and still fills `contentWidth`.
- Unmerged: `fix-a` `aaa61fd`.

### 4. Overview process tap does not open details — FIXED

- Where: `ProcBox.swift:99-103` (sets `selectedPID` / `watchedPID` only), `OverviewPreset.swift:34-37` (header tap → `.focusProcesses`; row tap does not)
- Problem: Spec: “tap row → details”. Only `FocusProcessesPreset` mounts `ProcessDetailSheet`. Footer copy is a lie; Overview row tap appears to do nothing.
- Fix: in `ProcBox.select` when `!wide`, also `state.preset = .focusProcesses` (or do it in `OverviewPreset` via a callback). Keep Focus Processes behaviour unchanged.

### 5. Proc footer promises long-press sort; rows have no long-press — FIXED

- Where: `ProcBox.swift:87` (`"tap row → details · long-press → sort"`), `ProcRow.swift` (tap only)
- Problem: Sort is header-tap only (`ProcHeader`).
- Fix: add `LongPressGesture(minimumDuration: 0.6)` on `ProcRow` (optional `onLongPress` default nil) that cycles `ProcSort.allCases`, gated so it does not fire `onTap` (same pattern as `ChipRow` / `ChipLongPressGate`). Or change the footer to `tap header → sort`.

### 6. Overview sort label never updates — FIXED

- Where: `ProcBox.swift:43-44`
- Problem: Compact value is hardcoded `"top 7 · cpu ↓"`.
- Fix: `"top \(rowLimit) · \(sort.rawValue) ↓"`.

### 7. Force Quit body is always the Docker sample text — FIXED

- Where: `ForceQuitConfirmCard.swift:34`
- Problem: `"Running containers will stop…"` applies to every process.
- Fix: `"This cannot be undone. Unsaved state in \(processName) will be lost."` Keep the terminate sentence.

### 8. Detail sheet “Files” vs “Ports” — WON'T FIX

Controller ruling. Tile is open-file count. Keep label **Files** (or **FDs**). Do not label Ports unless you count sockets only.

### 9. Time-range popover pinned to graph top-leading — FIXED

- Where: `CPUBox.swift:39-58` (`ZStack(alignment: .topLeading)` + popover `.frame(width: graphW, height: graphH)`)
- Problem: Spec: centred on the cpu graph.
- Fix: centre the popover on the graph; keep the dimming tap-catcher.

### 10. Net chips are four independent rows — FIXED

- Where: `NetBox.swift:132-144` (four `ChipRow(titles: [one])`)
- Problem: Spec: one 56-tall row of four equal chips. Singletons size to the label.
- Fix: one `ChipRow` of four titles if unavailable kinds can still dim to 40 %, else keep four rows but `.frame(maxWidth: .infinity)` each.
- Unmerged (partial): `fix-a` `7815d7b`.

---

## P2 — implement after P0/P1

### 11. All four presets stay mounted and live — FIXED

- Where: `DashboardRootView.swift:33-42`
- Problem: Overview + Focus CPU (~16 `HistoryGraph`s) + Focus Processes + Ambient all exist every tick. Off-screen views still subscribe and redraw.
- Fix: keep the pager offset and leading-alignment; mount current ± 1 only (`Color.clear` placeholders for the rest). Preserve swipe animation and page dots. If `state.glance` was true at drag start, treat the gesture as exit-only (see #23).

### 12. Ambient (and process) graphs skip `GraphMath.bucket` — FIXED

- Where: `AmbientPreset.swift:77-92` (`cpu.totalHistory.elements` etc.), `ProcBox` / `ProcessDetailSheet` sparklines
- Problem: CPU box windows + buckets. Ambient passes up to 3600 points into Catmull-Rom every tick.
- Fix: reuse the CPUBox pattern: `suffix(sampleCount)` → `padLeading` → `bucket(into: max(2, Int(width/3)))`.

### 13. Full `proc_listpids` + path + workspace refresh every process tick — FIXED

- Where: `ProcessProvider.swift:73-80` (`scheduleRunningAppRefresh()` every sample)
- Problem: Every ≥1 s: list all PIDs, two `proc_pidinfo` + `proc_pidpath` each, then `NSWorkspace.shared.runningApplications` on main.
- Fix: throttle running-app refresh to 5 s (or launch/terminate notifications). Cache `proc_pidpath` until start-time changes. Keep the 1 Hz cap.
- Unmerged: `fix-a` `f1d540f`.

### 14. Disk I/O first-busy-driver fallback — FIXED

- Where: `DiskProvider.swift:115`, `211-242`
- Problem: If BSD match fails, `internalFallback` is the first driver with any I/O. Two internal volumes can show identical R/W.
- Fix: `nil` when BSD match fails (hide sparks / `"—"`).
- Unmerged: `fix-a` `030a24d`.

### 15. GPU memory total is `physicalMemory` — FIXED (UI used-only when `!hasRealTotal`)

- Where: `CPUProvider.swift:230-235`
- Problem: Used bytes from IOKit `"In use system memory"`. Total is always system RAM. Wrong on discrete GPU.
- Fix: if no GPU-specific total in the registry, show used only or hide the KV. Do not print a fake denominator. Keep existing property names compiling (`memoryTotalBytes` optional, or a `hasRealTotal` flag) so `CPUBox` can follow.
- Unmerged: `fix-a` `60e43cc`.

### 16. Auto selection sums `en*`, header names one interface — FIXED

- Where: `NetworkProvider.swift:51-54`
- Problem: Auto rates = sum of active `en*`. `valueLabel` still `"\(name) · \(displayName)"` of one iface.
- Fix: in `.auto`, `valueLabel = "Auto · \(n) ifaces"` (or `Auto · en*`).
- Unmerged: `fix-a` `7815d7b`.

### 17. Process detail graphs are 60 samples, not 60 seconds — FIXED

- Where: `ProcessProvider.swift` detail rings (60 slots), UI “last 60 s”
- Problem: `minGap = max(interval.rawValue, 1)` so at 2 s / 5 s the ring is 2–5 minutes.
- Fix: size rings to `60 / max(interval, 1)` samples (resize on interval change), or change the label.
- Unmerged: check `fix-a` `f1d540f`.

### 18. `perCoreFrequencyAvailable` UI is inverted (latent) — FIXED

- Where: `CPUBox.swift:95-97`
- Problem: Flag is always `false` today. If it becomes true, UI shows `n/a · Apple Silicon`.
- Fix: show the KV only when you have a real frequency string.

### 19. Ping footer ignores persisted host — FIXED

- Where: `NetBox.swift:169,252` (`private static let pingHost = "1.1.1.1"`)
- Problem: Provider pings `settings.pingHost`. Footer always prints `1.1.1.1`.
- Fix: expose `pingHost` on `NetworkProvider` and interpolate it. Call `ping.setHost` if settings change.
- Unmerged: `fix-a` `7815d7b`.

### 20. `ClockProvider.deinit` invalidates timers asynchronously — FIXED

- Where: `ClockProvider.swift:30-36`
- Problem: `deinit` only `DispatchQueue.main.async` invalidates; a leaked env could leave timers running.
- Fix: invalidate inline when `Thread.isMainThread`; otherwise `stop()` is the live path.
- Unmerged: `fix-a` `8265ac0`.

### 21. `AlertEngine` traps on duplicate disk names — FIXED

- Where: `AlertEngine.swift:150` (`Dictionary(uniqueKeysWithValues:)`)
- Problem: Two volumes sharing a display name (`id: "disk:\(name)"`) trap. Task 16 now calls `evaluate` every second.
- Fix: unique volume ids + `Dictionary(_, uniquingKeysWith:)`. Test: two disks named `"Untitled"`.
- Unmerged: `fix-a` `db447fa`.

### 22. `StatsMath.networkRates` still uses wrapping subtract — FIXED

- Where: `StatsMath.swift:62-72` (`currentIn &- previousIn`)
- Problem: Production uses `NetworkMath.rates`. This leftover is still tested from `CoreTests`.
- Fix: delegate to `NetworkMath.rates` (or delete + retarget tests).
- Unmerged: `fix-a` `a61f9fe`.

### 23. Glance-exit swipe can advance an extra page — FIXED

- Where: `DashboardRootView.swift:64-66` (`noteActivityOnce()` inside swipe `onChanged`), `DashboardState.swift:108-110` (`noteActivity()` sets `glance = false`), `GlanceController.restorePresetIfNeeded` (restores previous preset when `glance` drops), `settleSwipe` (`DashboardRootView.swift:111-127` reads `state.preset.index`)
- Problem: A swipe that exits glance calls `noteActivity()` first. That restores `previousPreset` **before** `settleSwipe` pages. The user can land one preset past the one they left.
- Fix: if `state.glance` was true at drag start, treat the gesture as exit-only (snap `dragOffset` back, do not call `settleSwipe`).

### 24. `XENEON_PREVIEW_PRESET` is not gated on preview — FIXED

- Where: `main.swift:12-16`
- Problem: `previewEdit` / `previewAlerts` / `previewSelectPID` require `isPreview`. `previewPreset` applies whenever the env var is set, including a normal (non-`--preview`) launch.
- Fix: `guard isPreview, let raw = …`.

---

## Nits — do if cheap

| Item | HEAD | Notes |
|---|---|---|
| `MemoryProvider` strong `self` on main hop | FIXED | `[weak self]` |
| `Typography.display` `.ultraLight` vs spec Light/200 | FIXED | `.thin` |
| `SimpleBoxes` “unavailable” text | FIXED | Empty when GPU/battery nil |
| `Formatters.capacity` 999 GB → 0.98 TB | FIXED | Switches at 1024 GB |
| `PingService.stop()` timer no-op in `deinit` | FIXED | Timer cancelled in `stop()` |
| `NetworkMath.byteDelta` still internal + duplicated in provider | FIXED | `public` |
| `README.md` still embeds `screenshot.png` | FIXED | Overview capture |
| Plan `docs/superpowers/plans/2026-09-04-btop-dashboard.md` still says body **608** | doc only | Banner notes 600; sketches still 608 |
| Glance flash is fade not pulse; `glanceEnabled=false` exits on next 10 s tick | deferred | Acceptable |

---

## Spec / completeness — already done (do not implement)

- Edit mode, tilt, handles, toolbar, persist-on-end, exclusive long-press, clear state on Done.
- `AlertMonitor` / `GlanceController` / edge glow / chip-tap highlight / `glanceEnabled` + `idleMinutes` gate / ±4 px drift / activity-spike exit.
- README describes the btop dashboard (preview hooks, data sources, fallbacks).
- Calendar next-event hidden when `nextEvent == nil`.
- GPU row hidden when `cpu.gpu == nil`; desktop battery omitted when `power.battery == nil`.
- Pager leading-aligned; sheet overlays the 600-pt body row only; root swipe is `simultaneousGesture` + horizontal-only.

---

## Suggested patch order

1. **Merge `fix-a-core-providers`** (covers #1–3, #10/13–17/19–22 and several nits). Rebuild + self-test. Re-diff this list.
2. Thread any leftover kill-identity / plist gaps if the merge did not take them.
3. Overview row tap → Focus Processes; footer/sort label; generic force-quit copy; centre time-range popover; net equal chips if still open.
4. Mount current ± 1 presets; bucket Ambient/proc graphs; glance-exit swipe is exit-only; gate `XENEON_PREVIEW_PRESET`.
5. Frequency KV / SimpleBoxes empty state / display `.thin` / replace `screenshot.png`.
6. Update this file’s OPEN rows to FIXED as you go.

Commit style: `fix(<area>): …`, `test(<area>): …`. Small, frequent commits. Do not commit unless the human asks.

---

## Original review output (verbatim, Waves A–D)

The block below is the first whole-branch review (Tasks 1–14 only). Several “spec / completeness gaps” in it (Tasks 15–17) are now closed. Use the numbered list above as the source of truth for what is still open on `3bf1ab2`.

## Verdict

**Ship with fixes.** The dashboard builds, tests pass, and the provider/Core split is coherent. Do not ship Terminate/Force Quit as-is (PID-only `kill`), and do not ship the Ventura calendar request (missing usage key). Everything else is spec drift or cost, not a rewrite.
