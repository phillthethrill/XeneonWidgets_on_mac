# Handoff: XeneonWidgets × btop — system dashboard for Corsair Xeneon Edge

## Overview
Replace the current four-card XeneonWidgets dashboard with a btop-class system monitor for the Corsair Xeneon Edge (2560 × 720, touch). This package covers **Row 1 (four presets)** and **Row 2 (states & interactions)** of the design canvas, rendered in the **OLED Black** theme only. Other themes, portrait layouts, the Mac-side Settings window and the component/token sheets are documented in `FEATURES.md` but are **out of scope for this implementation**. Build the theme system so more themes can be added later, but ship only OLED Black.

Supersedes the system-stats part of `design_handoff_xeneon_pipeline` (the Docling pipeline panels are unaffected).

## About the design files
`html_reference/` is a **design reference built in HTML/React** — not code to ship. Open `html_reference/btop-dashboard.html` in a browser (needs network for React CDN) to see all artboards on a pan/zoom canvas; the OLED artboard is "09 · OLED Black" and all Row 1/2 artboards should be read with the OLED tokens below substituted. Recreate the design in **SwiftUI** inside the existing `XeneonWidgets` project, following its providers/`@Published` patterns. Every visual is expressible in SwiftUI (Shape/Path, LinearGradient, `.ultraThinMaterial`, SF Symbols, SF Mono/SF Pro).

## Fidelity
**High-fidelity.** Sizes, type, colours and spacing below are final. Sample data in the reference is deterministic mock data — wire real providers.

---

## Design tokens (OLED Black)

### Colour
| token | value | use |
|---|---|---|
| bg | `#000000` | screen background (pure black — OLED) |
| surface | `rgba(255,255,255,0.04)` | box fill (on top of `.ultraThinMaterial` is acceptable, but keep luminance ≤ this) |
| surface2 | `rgba(255,255,255,0.09)` | chips, pills, selected rows, bar tracks |
| hairline | `rgba(255,255,255,0.12)` | box border, separators, dashed graph thresholds |
| text | `rgba(255,255,255,0.92)` | primary numbers/names |
| text2 | `rgba(255,255,255,0.60)` | secondary values, box titles |
| text3 | `rgba(255,255,255,0.40)` | labels, meta, units |
| rampLow | `oklch(0.82 0.14 190)` ≈ `#4FD8CF` | graph gradient bottom (0 %) |
| rampMid | `oklch(0.86 0.16 85)` ≈ `#F2C24E` | graph gradient middle (50 %) |
| rampHigh | `oklch(0.70 0.22 22)` ≈ `#F0533F` | graph gradient top (100 %) |
| accent | `oklch(0.80 0.11 235)` ≈ `#7FBDF5` | download, read I/O, E-core marker, selection ring |
| up | `oklch(0.78 0.14 300)` ≈ `#C89AF0` | upload, write I/O, "Compressed" segment |
| ok | `oklch(0.80 0.17 150)` ≈ `#4ED17A` | state green |
| warn | `oklch(0.86 0.16 82)` ≈ `#F2C24E` | state amber |
| crit | `oklch(0.70 0.22 22)` ≈ `#F0533F` | state red |

Use `Color(.displayP3, …)` or the sRGB hex approximations; oklch values are the source of truth.

State thresholds (`stateColor(pct, lo, hi)`): CPU/GPU/core 50/80 · Memory 70/90 (pressure state overrides) · Disk 80/90 (alert at 95) · Process CPU 10/25 · Thermal: Nominal ok, Fair warn, Serious/Critical crit.

### Type (all changing numbers: SF Mono, `.monospacedDigit()`)
| name | size / weight | use |
|---|---|---|
| display | 300 / Mono Light (200) | ambient clock |
| clock | 44 / Mono Semibold | header clock (seconds in text3, Regular) |
| big | 72 / Mono Semibold, tracking −2 | box hero number (`unit` at 36 % size, text2) |
| numMd | 56 / 36 / 34 Mono Semibold | mem %, net rates, GPU % |
| boxValue | 22 / Mono Medium | value in box header top-right |
| boxTitle | 16 / Mono Regular, tracking +2.4, lowercase | `cpu` `mem` `net` `proc` `gpu` `disks` |
| body | 17 / Pro Medium | process name; process mem/cpu (Mono) |
| small | 15 / Pro Regular | meta, KV labels, pills |
| micro | 13–14 / Mono Regular | legends, peak/total, R/W |
| colHead | 12 / Pro, tracking +1.2, uppercase | process column headers |

### Spacing & radii
outer padding 24 · box gap 16 · box padding 22 · inner gap 16 (12 in proc) · header strip 56 · box radius 20 · popover/sheet radius 18/24 · chip radius 14 · button radius 16 · pill height 32 (r 16) · battery pill 40 (r 20) · **min tap target 56 × 56** · hairline 1 px.

### Motion
Graphs shift left one sample per tick, linear. Numbers tween 240 ms ease-out; colour changes cross-fade 400 ms. Preset swipe: 320 ms spring (damping 0.8), whole screen translates. Only pulse allowed: alert dot, 1.6 s ease-in-out (opacity 1 → 0.35). Edit mode tilt is static (±0.5°), no wobble animation.

---

## Screen geometry (landscape, 2560 × 720)
```
padding 24
┌ HeaderBar 2512 × 56 ──────────────────────────────────────────┐
gap 16
┌ cpu 740 ┐┌ mem 600 ┐┌ net 480 ┐┌ proc 644 ┐   all 608 tall, gap 16
```
Body height = 720 − 48 − 56 − 16 = **608**.

### HeaderBar (all presets except Ambient)
Left cluster, 15 pt Pro, text3, gap 12: ● ok-dot 8 px (Xeneon connected) · **hostname** (text2, semibold) · macOS version · `·` · `up 3d 14h 22m` · `·` · `Xeneon Connected` · `·` · `1 s sampling` (mono).
Centre: alert strip (empty when no alerts).
Right: BatteryPill (40 tall: 30 × 14 battery glyph, `82%` 18 Mono Semibold, ⚡︎ in ok when charging, `2:41 · 18.4 W` 14 mono text3) · clock `14:32` 44 Mono Semibold + `:07` text3 Regular · `Thu 4 Sep · W36` 16 Pro text2/text3.
Sources: `Host.current().localizedName`, `ProcessInfo.operatingSystemVersion`, `ProcessInfo.systemUptime`, IOPowerSources (`IOPSCopyPowerSourcesInfo`), your existing display-connection state, sampling interval setting.

### Box container (btop nod)
`RoundedRectangle(20)` filled surface, 1 px hairline stroke, padding 22, VStack gap 16. Header row: title (boxTitle, text2) + optional meta (15 Pro text3, truncating) on the left; live value (boxValue, text or state colour) on the right. **Every box header follows this pattern.**

---

## Row 1 — Presets

### 01 · Overview
**cpu 740 × 608** — meta `Apple M3 Max · 12P + 4E · up 3d 14h 22m`; value `34%` state-coloured.
1. Row (gap 24): HistoryGraph **404 × 240** (total CPU, 120 samples, 0–100, ramp gradient, dashed hairlines at 50/80; small `5 min · tap for range` 12 mono text3 top-right) · right column 268 wide: Big `34%` + label `total · 16 cores`; Pill `Thermal · Nominal` (ok dot); KV `load 1 · 5 · 15` → `3.21  2.87  2.40`; KV `freq` → `n/a · Apple Silicon` (text3; **collapse the row when unavailable** — no hole).
2. Cores row: two `CoreBars` groups side by side with a 1 px vertical hairline between: `12 P-cores` (12 bars) and `4 E-cores` (4 bars). Each bar 32 × 96, radius 6, track surface2, fill height = % with a vertical low→mid→high gradient anchored to the full track height (so the colour at the top of the fill encodes the value); value 12 mono text3 beneath; group header shows `avg NN%`.
3. Hairline. GPU row (gap 20): `gpu` title · HistoryGraph 226 × 56 (no grid; width = inner − 470, clamped 160–320) · Big `18%` 34 pt + label `40-core GPU` · right-aligned KVs `gpu memory 4.2 / 36 GB`, `source IOKit perf stats`.
Sources: `host_processor_info` (per-core ticks; group via `sysctl hw.perflevel0/1.logicalcpu`), `getloadavg`, `ProcessInfo.thermalState`, IOKit `AGXAccelerator` → `PerformanceStatistics["Device Utilization %"]`, `"In use system memory"`.

**mem 600 × 608** — meta `36 GB unified`; value `19.2 / 36 GB`.
1. Row: Big `53%` 56 pt (mem thresholds) label `used` · beside it Pill `Pressure · Normal` (ok/warn/crit by DISPATCH_MEMORYPRESSURE) and `swap 1.2 / 4 GB` 14 mono text3.
2. SegBar 14 tall, radius 7, 2 px gaps, segments in order App (rampHigh) · Wired (rampMid) · Compressed (up) · Cached files (rampLow) · Free (text3 @ 25 % opacity).
3. Legend 2-column grid, rows: 10 px swatch · label 15 Pro text3 · `12.8 GB` 15 mono text2.
4. Hairline. `disks` title row with `4 volumes · R W MB/s` (R in accent, W in up) right.
5. DiskRow × 4, each 56 tall, grid `1fr 150 84`: name 16 Pro Medium + kind 13 text3 (`APFS · internal`), `612 GB / 926 GB` 13 mono right, no wrap (name truncates); 6 px bar (disk thresholds); two sparklines 70 × 22 (read accent, write up); `R 12.4 MB/s` / `W 3.1 MB/s` 12 mono.
Sources: `host_statistics64(HOST_VM_INFO64)` — App = internal − purgeable, Wired, Compressed (`compressor_page_count`), Cached = purgeable + external, Free; `sysctl vm.swapusage`; `FileManager.mountedVolumeURLs` + `volumeAvailableCapacityForImportantUsageKey`; IOKit `IOBlockStorageDriver` Statistics (bytes read/written deltas).

**net 480 × 608** — meta `Tolaria · 192.168.1.42`; value `en0 · Wi-Fi`.
1. MirrorGraph **436 × 300**: download above centre line (accent, fill 0.4→0.02), upload below (up colour), 1 px centre line text3 @ 50 %, scale labels `↓ 60 MB/s` / `↑ 20 MB/s` 12 mono at top-left/bottom-left. Scales auto-fit to peak.
2. Two Rate blocks side by side: `↓` 30 Mono in accent + `12.4` 36 Mono Semibold + `MB/s` 14 text3; below `peak 48.2 · total 3.1 GB` 13 mono. Same for `↑` in up.
3. ChipRow (56 tall, 4 equal chips): `Auto` · `Wi-Fi` (selected) · `Ethernet` · `USB`. Selected chip = text-coloured fill with bg-coloured label.
4. Footer 14 mono text3: `RSSI −54 dBm` · `link 866 Mb/s` · `ping 1.1.1.1 12 ms` (ping value ok/warn/crit at 50/150 ms).
Sources: `getifaddrs` byte counters per interface, Auto sums `en*`; CoreWLAN `CWInterface` (`rssiValue`, `transmitRate`, `ssid`); ICMP ping (SimplePing) to a configurable host.

**proc 644 × 608** — meta `412 processes · 2418 threads`; value `top 7 · cpu ↓`. Inner gap 12.
1. ChipRow 48 tall: All (selected) · Apps · Background · System · Mine · High CPU.
2. Column header 24 tall: ` · NAME · PID · USER · MEM · CPU ↓ · THR` (active sort column in text, semibold).
3. 7 ProcRows, 54 tall, grid `28 1fr 60 96 92 76 40`, gap 12, h-padding 10, radius 12: app icon 28 (NSWorkspace icon, radius 7) · name 17 Pro Medium · pid 15 mono text3 · user 15 text3 · `3.92 GB` 17 mono text2 · `31.6%` 17 mono semibold state-coloured (process thresholds) · threads 15 mono text3.
4. Footer 14 text3: `tap row → details · long-press → sort` | `tap header → full list`.
Sources: `proc_listpids`, `proc_pidinfo(PROC_PIDTASKINFO)` deltas for CPU, `pti_resident_size`, `pti_threadnum`; `NSRunningApplication.icon` / `NSWorkspace.shared.icon(forFile:)`.

### 02 · Focus CPU
cpu box **1500 × 608** with `cores: graphs`; graph 200 tall. Core grid 8 × 2 cells, gap 12, each cell surface2 radius 12, padding 8/10, left 3 px border (accent for E-cores, transparent for P): row `P0 … 23%` 13 mono (value state-coloured) + HistoryGraph (cell width − 20) × 56, no grid. Right: mem **480** (disks **without** I/O sparks: grid `1fr 120`, legend single column) · net **500** (graph 230, **no chip row**). proc is hidden in this preset.

### 03 · Focus Processes
proc box **2512 × 608**, `wide` column set `32 480 80 140 60 90 110 90 90 · 1fr filler` (icon, name, PID, user, thr, mem spark 80 × 22, mem, cpu spark 80 × 22 state-coloured, cpu), 9 rows × 44, 16 pt text. Selected row: surface2 fill + 1 px accent inset ring.
**DetailSheet** 780 wide, full body height, anchored right over the table: fill `#0e1016` (opaque on OLED; `.ultraThinMaterial` acceptable), radius 24, hairline border, shadow `−30 0 90 rgba(0,0,0,.55)`, padding 28, gap 20:
- Header: AppIcon 64 · name 30 Pro Semibold · `PID 2210 · philipp · Running · since 09:40` 15 mono text3 · × close button 56 ⌀ surface2.
- Command: full path 14 mono text2 in surface2 box radius 12, padding 12/14, wraps.
- 4 stat tiles (grid 4, gap 12, surface2 radius 14, padding 12/14): label 13 text3 + value 28 Mono Semibold — CPU (state-coloured), Memory, Threads, Ports.
- Two graphs side by side 354 × 96: `CPU · last 60 s` (ramp) and `Memory · last 60 s` (solid accent, no thresholds).
- Bottom (pushed to bottom): `Terminate` secondary + `Force Quit…` tinted crit (18 % fill, 50 % border, crit text). Both 56 tall, radius 16, 18 Pro Semibold.

### 04 · Ambient / Minimal
No header. Content vertically centred, horizontal padding 72, space-between: ClockBig (`14:32` 300 Mono Light, tracking −12; `07` at 32 % size text3; second line 33 Pro text2 `Thursday, 4 September · W36 · next: Design sync · 15:00`) · right column of three rows gap 28: label 16 mono tracked (`cpu`, `mem`, `net ↓`) · Spark 420 × 64 (cpu/mem state-coloured, net accent) · value 36 Mono Medium right-aligned width 220.
Behaviour: enters after N idle minutes (setting). Brightness 60 %; every 60 s the whole content drifts ±4 px (burn-in protection). Any touch or activity spike returns to the previous preset. Next event via EventKit (optional; hide the segment if no access).

---

## Row 2 — States & interactions

### 05 · Overview with active alerts
- AlertStrip in header centre: chips 40 tall, radius 20, padding 0 16 0 12, gap 10: 10 px dot (pulsing) · text 15 Pro Semibold · age 15 mono @ 75 %. Fill `color-mix(crit 18 %)`, border `color-mix(crit 45 %)`, text crit (warn variants for warn level). Sample: `Memory pressure · Critical 2m 14s` (crit) · `Macintosh HD · 95% full 41m` (warn). Max 3 visible, older ones collapse to `+N`.
- Affected box gets **edge glow**: border colour = alert colour, shadow `0 0 0 1 alert, 0 0 40 −6 alert`. mem in the sample (value in crit, pressure pill crit, Free 0.5 GB, swap 3.8 / 4, Macintosh HD row value crit).
- Alert rules (defaults, all configurable): CPU ≥ 95 % for 30 s · memory pressure Warning/Critical · any disk ≥ 95 % · thermal Serious/Critical · battery ≤ 10 % not charging. Clear automatically when the condition ends; tapping a chip scrolls/highlights the box.

### 06 · Edit mode
Enter: long-press (0.6 s) any box. State: boxes tilt alternately −0.5°/+0.5°, dashed 2 px accent outline offset 4, and each shows three 56 ⌀ handles: `×` hide (top-right), `⋮⋮` drag (top-left), resize grip (bottom-right corner, 28 × 28 L-shape 3 px text3). The dragged box (mem in sample) lifts with shadow `0 30 80 rgba(0,0,0,.5)`; siblings slide to make room (spring 320 ms). Floating toolbar bottom-centre (radius 24, `#0e1016`, hairline): `Editing · Overview` 15 text3 · hairline · `Hidden` + chips `+ Battery` `+ GPU` `+ Clock` (140 × 56) · hairline · `Reset` secondary 160 · `Done` primary 160. Layout persists per preset (JSON in Application Support).

### 07 · Force Quit confirmation
Same sheet as 03; bottom area replaced by a confirmation card: fill `color-mix(crit 12 %)`, border `color-mix(crit 40 %)`, radius 18, padding 20: title `Force quit Docker?` 20 Pro Semibold · body `Running containers will stop and unsaved state is lost. This cannot be undone.` 15 text2 · row: `Cancel` secondary (flex 1) + **Hold to Force Quit** (flex 1.4, crit fill, white 18 Semibold) with a left-to-right darker overlay (`rgba(0,0,0,.25)`) showing hold progress and `0.6 / 1.0 s` 14 mono. Release before 1.0 s cancels. `Terminate` uses the same pattern with 0.5 s hold. Send `SIGTERM` / `SIGKILL` via `kill(2)`; show a toast-free inline result (row disappears from list).

### 08 · Pickers open
- Time-range popover centred on the cpu graph: 4 chips 92 × 56 (`1 min` `5 min` `15 min` `1 h`), padding 8, radius 18, fill `#0e1016`, shadow `0 20 60 rgba(0,0,0,.45)`. Range is per box and persisted; the graph re-buckets its ring buffer (1 h at 1 s = 3600 samples → downsample to width).
- Interface popover above the net chip row: list rows 56 tall, `Wi-Fi … en0 · 192.168.1.42 ✓` 17 Pro Medium + 14 mono sub, selected row surface2.
- Gestures (orange callouts in the reference are annotations only): tap graph → range; tap chip → switch, long-press chip → interface list; swipe ← → on background/header → previous/next preset (page dots in header); tap process row → sheet; tap column header → sort; long-press box → edit mode.

---

## State & architecture
- `DashboardState` (`ObservableObject`): `preset: Preset` (overview, focusCPU, focusProcesses, ambient), `theme: Theme` (only `.oled` shipped), `layout: [Preset: LayoutSpec]`, `timeRange: [BoxID: TimeRange]`, `sampling: Interval` (0.5/1/2/5 s), `editMode: Bool`, `alerts: [Alert]`, `selectedPID: pid_t?`, `confirm: ConfirmAction?`, `glance: Bool`.
- Providers publish ring buffers (`RingBuffer<Double>` sized for 1 h at the current interval): `CPUProvider` (total, perCore[16], gpu, load, thermal), `MemoryProvider` (breakdown, pressure, swap), `DiskProvider` (volumes, io), `NetworkProvider` (per-interface rates, wifi, ping), `ProcessProvider` (top-N + detail histories for the selected PID), `PowerProvider`, `ClockProvider`.
- Theme = `struct Theme` with the token names above; inject via `@Environment(\.theme)`.
- Touch: `DragGesture(minimumDistance: 40)` for preset swipe; `LongPressGesture(minimumDuration: 0.6)` for edit; hold-to-confirm = `LongPressGesture(minimumDuration: 1.0)` driving a progress `@State`.

## Fallbacks (design explicitly)
Per-core frequency → hide KV row (Apple Silicon). SMC temperature → thermal pressure pill is the primary signal; add a temperature pill only when a sensor is readable (Intel). GPU stats missing → hide GPU row and let cores row grow. No Wi-Fi → footer shows link type only.

## Screenshots
`screenshots/` — native 2560 × 720 PNGs of the eight in-scope artboards in OLED Black (01-overview · 02-focus-cpu · 03-focus-processes · 04-ambient · 05-alerts · 06-edit-mode · 07-force-quit-confirm · 08-pickers-gestures). Orange callouts in 08 are annotations, not UI.

## Files
- `html_reference/btop-dashboard.html` — canvas entry; `btop/theme.jsx` tokens · `btop/data.jsx` sample data · `btop/components.jsx` component library (graph maths for smoothing/gradient) · `btop/boxes.jsx` the five boxes + header · `btop/presets.jsx` presets, sheet, edit mode, pickers · `btop/mac.jsx`, `btop/sheet.jsx` out of scope references.
- `FEATURES.md` — every feature of the full design, including out-of-scope items.
