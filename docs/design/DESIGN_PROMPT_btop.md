# Claude Design prompt — XeneonWidgets × btop

Copy everything below the line into Claude Design.

---

## Brief

Redesign **XeneonWidgets**, a native macOS menu-bar app that turns the **Corsair Xeneon Edge** touch display into a live system-stats dashboard, so that it carries the full **information content of `btop`** (the terminal resource monitor) — but as a purpose-built, glanceable, touch-friendly dashboard for a 32:9 strip display, not as a terminal emulation.

Produce a multi-artboard design canvas (specs below). Think "btop's data model, reimagined as a native macOS glass dashboard".

## The canvas you are designing for

- **Display:** Corsair Xeneon Edge, **2560 × 720 px** (14.5", 32:9, 5:1.4 aspect), capacitive **touch**. It sits under or beside the main monitor, usually at arm's length, so it is read in glances, not studied. Also support the display in **portrait orientation, 720 × 2560 px**.
- **Rendering:** SwiftUI, native, crisp at full resolution. Everything you draw must be expressible in SwiftUI (shapes, paths, gradients, materials, SF Symbols, SF Mono / SF Pro / SF Rounded). No raster assets, no scaled bitmaps.
- **Dark environment:** the display is always on, often in a dim room, so the design must be **OLED-friendly**: near-black background, no large bright areas, no white panels. But also design one **light/daylight** variant.
- **Input:** touch only on this screen (no hover, no cursor, no keyboard focus). Minimum tap target 56 × 56 px. Swipes and long-press are fine. Everything must also be usable non-interactively — the dashboard is 95 % display, 5 % control.

## What exists today (baseline to improve, not to preserve)

Four equal `ultraThinMaterial` cards in a 4-column grid on black, 24 px outer padding, 16 px gaps, ~580 px tall:

1. **Clock** — HH:MM:SS in large monospace, date below.
2. **CPU** — 240° arc gauge, percentage in the middle, "CPU" label, thermal-pressure dot (Nominal / Fair / Serious / Critical).
3. **RAM** — same arc gauge, percentage.
4. **Network** — globe icon, ↓ download and ↑ upload rate in KB/s.

Colour coding: green < 50 %, yellow < 80 %, red ≥ 80 %. Sampling: CPU/RAM/network every ~1 s, clock every 1 s. It is clean but shallow: no history, no per-core view, no processes, no disks, no GPU, no interaction.

## The content model to adopt — everything btop shows

Map every btop panel onto the dashboard. Data density is the goal; btop's visual idiom (braille graphs, box-drawing borders) is optional inspiration, not a requirement.

### 1. CPU box
- Total CPU usage **as a scrolling history graph** (btop's signature element), plus the current percentage.
- **Per-core** usage: on Apple Silicon, distinguish **efficiency (E) and performance (P) cores** — btop shows a flat core list; do better by grouping them.
- **Load average** (1 / 5 / 15 min).
- **Frequency** where available (Apple Silicon does not expose per-core clocks reliably — design the slot so it can be hidden without leaving a hole).
- **Temperature:** Apple Silicon blocks SMC temperature reads without a private entitlement, so show **thermal pressure state** (Nominal / Fair / Serious / Critical) as the first-class signal, with an optional temperature slot for Intel Macs / future support.
- **Uptime** and **CPU model name** (e.g. "Apple M3 Max · 12P + 4E").
- New: **GPU** usage and GPU memory (available on Apple Silicon via IOKit performance statistics) — btop has GPU support on Linux; give it its own sub-panel or a toggle inside the CPU box.

### 2. Memory box
- Memory split the way btop does it: **Used / Available / Cached / Free** — for macOS this is **App memory, Wired, Compressed, Cached files, Free**, plus **memory pressure** (macOS's own green/yellow/red signal, which is more meaningful than a raw percentage).
- **Swap** used / total.
- **Disks:** every mounted volume with used / free / total and a usage bar, plus **disk I/O read/write throughput** with small history graphs (btop's `io_mode`). Include the boot volume, external drives, and Time Machine / network volumes when mounted.

### 3. Network box
- Download and upload **history graphs** (btop draws them mirrored: download above the baseline, upload below — consider that).
- Current rate, **peak** rate, and **total bytes** transferred since app start for each direction.
- Active **interface** selector (Wi-Fi / Ethernet / USB tethering) with the interface name and IP address; an auto mode that sums active `en*` interfaces.
- New: Wi-Fi signal/RSSI and link speed, latency ping to a configurable host.

### 4. Process box
- A **process list** with the btop columns: **PID, name (with app icon on macOS), user, memory, CPU %**, plus threads. Sortable by CPU, memory, PID, name.
- **Tree view** toggle (parent → child processes).
- Tap a process to open a **detail sheet**: full command, CPU/mem history graph, status, threads, open time, and touch-sized **Terminate / Force Quit** buttons with a confirmation step — this is the only destructive action in the app; design the confirmation carefully.
- **Filter/search** — with touch only, design a large on-screen input or a "quick filter" chip row (Apps / Background / System / My processes / High CPU).
- Show **top-N** by default (fits the height); expand to full list on tap.

### 5. Global elements
- **Clock** stays: time, date, optionally week number and calendar next-event.
- **Battery** (MacBook): charge %, charging state, time remaining, cycle count / health, and power draw in watts.
- **System header:** hostname, macOS version, uptime, and the app's own status (Xeneon connected, sampling interval).
- **Alerts:** a subtle, non-modal way to show "CPU pegged for 30 s", "disk 95 % full", "memory pressure critical", "thermal throttling". No pop-ups on a secondary display; think status strip or card edge glow.

## New features to design (beyond btop)

1. **Presets / layouts** — btop has `presets` (e.g. `cpu:1:default,proc:0:default`). Design a **preset switcher** (swipe left/right between full-screen layouts, or a tab strip):
   - *Overview* — all five boxes, balanced.
   - *Focus CPU* — CPU box takes 60 % width with per-core graphs.
   - *Focus Processes* — full-width process table.
   - *Minimal / Ambient* — huge clock + three tiny sparklines, for when the Mac is idle. Dims further after a timeout (burn-in protection).
   - *Portrait* variants of Overview and Ambient.
2. **Configurable columns / boxes** — each box can be hidden or resized; design the **edit mode** (long-press → boxes wobble/outline, drag to reorder, tap × to hide, + to add). Editing must be doable on the touch screen itself; a settings panel on the main Mac window is a fallback.
3. **Themes** — btop ships many themes (Default, Dracula, Nord, Gruvbox, Tokyo Night, Solarized…). Design a theme system with **semantic tokens** (background, surface, text primary/secondary, graph gradient low→mid→high, accent, warning, critical) and show at least **four themes**: a Default dark glass, an OLED pure-black, a Nord-inspired, and a Light/daylight. Make gradient graphs use a 3-stop low→high ramp like btop.
4. **Time ranges** — history graphs at 1 min / 5 min / 15 min / 1 h, switchable by tapping the graph.
5. **Sampling interval** — 500 ms / 1 s / 2 s / 5 s, exposed in settings and reflected in the header.
6. **Glance mode / burn-in protection** — after N minutes idle, subtly shift the layout by a few pixels and dim to ~60 %.
7. **Menu-bar & settings window (Mac side)** — redesign the menu-bar dropdown (Show/Hide dashboard, preset picker, theme picker, target display picker, launch at login, quit) and a compact **Settings** window with tabs: Display, Layout, Sampling, Theme, Processes, About.

## Design principles

- **Glanceable first:** the single most important number in each box must be readable from 1.5 m. Hierarchy: big number → graph → detail rows.
- **Information density like btop, legibility like a car dashboard.** Use tabular monospace figures (SF Mono / SF Pro with monospaced digits) for every changing number so nothing jitters.
- **Colour means state, not decoration.** Green / yellow / red thresholds consistent across all boxes; graphs use the theme's gradient ramp so the colour itself encodes intensity.
- **Ultra-wide aware:** 2560 × 720 is very wide and very short. Avoid vertical stacking that pushes content below 720 px; prefer horizontal rows, side-by-side sub-panels, and horizontally scrolling graphs. Never centre a small element in a huge card.
- **Native macOS feel:** glass materials, SF Symbols, rounded 16–24 px corners, subtle hairline separators — not a terminal, not a gamer HUD. But keep a deliberate nod to btop (e.g. box titles in the top-left corner of each card, with the current value on the top-right, exactly like btop's box headers).
- **Motion:** graphs scroll smoothly; numbers tween; no bouncing, no glow pulsing except the alert strip.
- **Accessibility:** contrast ≥ 4.5:1 for all text on all themes; every colour-coded state also has a label or icon.

## Deliverables — artboards on one canvas

Lay these out on a single pan/zoom canvas, grouped by row:

**Row 1 — Dashboard presets (2560 × 720 each, Default dark theme)**
1. Overview (all boxes)
2. Focus CPU
3. Focus Processes (with one row selected and the detail sheet open)
4. Ambient / Minimal

**Row 2 — States & interactions (2560 × 720)**
5. Overview with an active alert (memory pressure critical + disk 95 %)
6. Edit mode (drag-to-reorder, hide/add controls visible)
7. Process detail sheet with Force Quit confirmation
8. Time-range and interface pickers open (annotated touch gestures)

**Row 3 — Themes (2560 × 720, Overview layout)**
9. OLED pure-black
10. Nord-inspired
11. Light / daylight
12. One additional theme of your choice (Dracula / Gruvbox / Tokyo Night)

**Row 4 — Portrait (720 × 2560)**
13. Overview portrait
14. Ambient portrait

**Row 5 — Mac-side UI**
15. Menu-bar dropdown (native macOS menu, ~280 px wide)
16. Settings window (~720 × 480), Layout tab and Theme tab

**Row 6 — Component sheet & tokens**
17. Component library: box header, big-number tile, history graph (with gradient ramp), per-core mini bars, disk row, process row, battery pill, alert strip, chip row, tap targets — each with pixel dimensions and type sizes.
18. Design tokens: colour tokens for all four themes, type scale, spacing scale, corner radii, graph thresholds.

Annotate each artboard briefly (what data source feeds each element, what happens on tap/long-press/swipe). Where a value is not obtainable on macOS/Apple Silicon (per-core clock, SMC temperature), show the fallback design explicitly rather than faking data.

Use realistic sample data for a MacBook Pro M3 Max, 36 GB RAM, on Wi-Fi, with a handful of recognisable macOS processes (WindowServer, kernel_task, Safari, Xcode, Spotify, Docker, com.apple.WebKit.WebContent).
