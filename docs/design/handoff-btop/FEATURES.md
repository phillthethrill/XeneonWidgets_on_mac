# XeneonWidgets × btop — Feature Reference

Complete feature inventory of the design. **Scope for this handoff: sections 1–8 and the OLED Black theme (9.2).** Everything else is documented for later phases.

## 0. Platform & constraints
- Target: Corsair Xeneon Edge 2560 × 720 (landscape) and 720 × 2560 (portrait), capacitive touch only — no hover, cursor or keyboard focus.
- Always-on OLED-friendly: pure-black background, no large bright areas.
- Minimum tap target 56 × 56. Gestures: tap, long-press, horizontal swipe.
- 95 % display / 5 % control: every screen is fully useful with zero interaction.
- All changing numbers use monospaced digits so nothing jitters.
- Colour = state (ok / warn / crit), never decoration; every colour-coded state also has a label.
- Contrast ≥ 4.5:1 for all text on all themes.

## 1. Header strip (56 px)
- System identity: hostname, macOS version, uptime.
- App status: Xeneon connection dot + label, current sampling interval.
- Alert strip (centre) — see §7.
- Battery pill: %, charging bolt, time remaining, power draw (W). Long-press → cycle count & health.
- Clock HH:MM(:SS) + short date + ISO week.
- Preset page-dots appear during/after a swipe.

## 2. cpu box
- Total CPU history graph (ramp-coloured), current %, `tap for range`.
- Hero number 72 pt, state-coloured, `total · 16 cores`.
- Thermal pressure pill (Nominal / Fair / Serious / Critical) — first-class signal instead of SMC temperature.
- Load average 1 / 5 / 15.
- Frequency row — collapses when not exposed (Apple Silicon).
- Per-core usage grouped **P-cores / E-cores** (bars in Overview, mini history graphs in Focus CPU).
- GPU sub-row: utilisation history, %, GPU memory used / total, source label.
- Meta: CPU model + core config + uptime in the header.

## 3. mem box
- Hero % used, memory-pressure pill (macOS signal), swap used / total.
- Segmented bar App · Wired · Compressed · Cached files · Free with legend.
- Disks: every mounted volume (internal, external, Thunderbolt, SMB/Time Machine) with kind, used / total, usage bar, read/write sparklines and live R/W MB/s.
- Disk rows highlight in crit when ≥ 90 %; alert at 95 %.

## 4. net box
- Mirrored history graph: download above the baseline, upload below, auto-scaled with scale labels.
- Current ↓ / ↑ rate, peak, total since app start.
- Interface chip row: Auto (sums en*) · Wi-Fi · Ethernet · USB; long-press → list with interface name, IP, link state.
- Wi-Fi detail: SSID, IP, RSSI, link speed; ping latency to configurable host (state-coloured).

## 5. proc box
- Columns PID, name + app icon, user, memory, CPU %, threads (wide preset adds memory/CPU sparklines).
- Sort by CPU (default), memory, PID, name via column-header tap; long-press → sort menu.
- Quick-filter chips: All · Apps · Background · System · Mine · High CPU.
- Top-N (7 in Overview) → tap header for full list (Focus Processes).
- Tree view toggle (parent → child indentation) in the full list — design intent, not drawn.
- Tap row → Detail sheet: icon, name, PID, user, status, start time, full command, stat tiles (CPU, memory, threads, ports), 60 s CPU/memory graphs.
- Terminate (SIGTERM) and Force Quit (SIGKILL) with **hold-to-confirm** (0.5 s / 1.0 s) and an inline explanation card. Only destructive action in the app.

## 6. Presets (swipe ← → or menu)
1. **Overview** — header + cpu 740 / mem 600 / net 480 / proc 644.
2. **Focus CPU** — cpu 1500 with 16 per-core graphs; mem 480 + net 500 compact.
3. **Focus Processes** — full-width 9-row table + detail sheet.
4. **Ambient / Minimal** — 300 pt clock, date, next calendar event, three sparklines; auto-enters after idle; dims to 60 %; drifts ±4 px / 60 s.
5. **Portrait Overview** (720 × 2560) — header 100, cpu 600, mem 600, net 480, proc 668 stacked. *(later phase)*
6. **Portrait Ambient** — clock 168 pt + three stacked 300 × 120 sparklines. *(later phase)*
- Time range per graph: 1 min / 5 min / 15 min / 1 h (tap graph).
- Sampling interval 0.5 / 1 / 2 / 5 s, reflected in the header.

## 7. Alerts
- Non-modal: chips in the header centre + edge glow on the affected box.
- Rules: CPU ≥ 95 % for 30 s · memory pressure Warning/Critical · disk ≥ 95 % · thermal Serious/Critical · battery ≤ 10 % discharging.
- Each chip shows age; max 3, then `+N`; tap → highlight box; auto-clear.
- Alert dot pulse (1.6 s) is the only glow/pulse animation in the app.

## 8. Edit mode (on the display)
- Long-press any box 0.6 s → boxes tilt ±0.5°, dashed accent outline.
- Handles: × hide, ⋮⋮ drag-to-reorder (siblings slide), corner resize grip.
- Toolbar: hidden boxes as `+` chips, Reset, Done.
- Per-preset layout persisted; mirrored by Settings › Layout on the Mac.

## 9. Themes (semantic tokens)
Tokens: bg, surface, surface2, hairline, text, text2, text3, rampLow/Mid/High, accent, up, ok, warn, crit. Graphs use the 3-stop ramp so Y-position encodes intensity.
1. Default Glass (dark, subtle radial tint) *(later)*
2. **OLED Black** — `#000` bg, 4 % surfaces, 12 % hairlines — **ship this**
3. Nord *(later)*
4. Daylight / light *(later)*
5. Tokyo Night *(later)*
- Import of btop `.theme` files by mapping colour keys to tokens *(later)*.
- Optional "follow system appearance" *(later)*.

## 10. Glance mode / burn-in protection
- After N idle minutes: brightness 60 %, content drifts ±4 px every 60 s, optional switch to Ambient.
- Exit on touch or activity spike.

## 11. Mac-side UI *(later phase)*
- Menu-bar dropdown (~280 px): live cpu/mem/net line, Show Dashboard, ⌥⌘X toggle, Preset ▸, Theme ▸, Target Display ▸, Sampling ▸, Launch at Login, Glance-mode toggle, Settings… ⌘, Quit ⌘Q.
- Settings window 720 × 480, tabs Display · Layout · Sampling · Theme · Processes · About. Layout tab: preset list, box diagram, per-box toggles, "Edit on Display…". Theme tab: theme cards with mini previews, ramp preview, thresholds, glance dim level, burn-in shift.

## 12. Data sources (macOS / Apple Silicon)
| data | API |
|---|---|
| CPU total / per core | `host_processor_info(PROCESSOR_CPU_LOAD_INFO)` deltas; core groups via `sysctl hw.perflevel*.logicalcpu` |
| Load average | `getloadavg` |
| Thermal | `ProcessInfo.processInfo.thermalState` + `NSProcessInfoThermalStateDidChange` |
| GPU | IOKit `AGXAccelerator` service → `PerformanceStatistics` dict |
| Memory | `host_statistics64(HOST_VM_INFO64)`; pressure `DispatchSource.makeMemoryPressureSource`; swap `sysctl vm.swapusage` |
| Disks | `FileManager.mountedVolumeURLs`, volume capacity keys; I/O from `IOBlockStorageDriver` Statistics |
| Network | `getifaddrs` (`if_data` bytes) per interface; CoreWLAN for RSSI/link/SSID; ICMP ping |
| Processes | `proc_listpids`, `proc_pidinfo(PROC_PIDTASKINFO / PROC_PIDTBSDINFO)`, `proc_pidpath`; icons `NSWorkspace` |
| Battery | `IOPSCopyPowerSourcesInfo`, `IOPSGetProvidingPowerSourceType`; watts from `AppleSmartBattery` (Amperage × Voltage) |
| Uptime / host / OS | `ProcessInfo`, `Host.current()` |
| Calendar next event | EventKit (optional) |

## 13. Known fallbacks
- Per-core clock: not exposed → row hidden.
- SMC temperature: no entitlement → thermal pressure only; temperature pill only on Intel.
- No GPU stats → GPU row hidden.
- No Wi-Fi → footer shows link type only; RSSI omitted.
- Calendar access denied → "next:" segment omitted.
