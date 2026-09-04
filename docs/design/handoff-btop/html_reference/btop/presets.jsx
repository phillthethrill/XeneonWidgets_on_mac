// btop/presets.jsx — full-screen layouts + states
(function () {
  const B = window.btop; const { ThemeCtx, themes, useTheme, stateColor, mono, sans, data: D } = B;
  const { HistoryGraph, Spark, Box, Big, KV, Pill, Chip, ChipRow, Hair, AppIcon, Btn, Touch, num } = B.ui;
  const { HeaderBar, CPUBox, MemBox, NetBox, ProcBox, ClockBig } = B.boxes;
  const W = 2560, H = 720, P = 24, G = 16;

  function Screen({ theme = 'default', w = W, h = H, children, dim, style }) { const t = themes[theme]; return (<ThemeCtx.Provider value={t}><div style={{ width: w, height: h, boxSizing: 'border-box', padding: P, background: t.mode === 'dark' && t.id === 'default' ? `radial-gradient(1200px 600px at 20% -10%, rgba(120,140,255,0.08), transparent 60%), ${t.bg}` : t.bg, position: 'relative', overflow: 'hidden', display: 'flex', flexDirection: 'column', gap: G, fontFamily: sans, color: t.text, filter: dim ? 'brightness(0.6)' : 'none', ...style }}>{children}</div></ThemeCtx.Provider>); }

  // Annotated frame: display + notes footer (footer is NOT part of the display)
  function Frame({ w = W, h = H, notes = [], children }) { return (<div style={{ width: w, display: 'flex', flexDirection: 'column', background: '#f7f5f0' }}><div style={{ width: w, height: h, overflow: 'hidden', flex: 'none' }}>{children}</div>
    <div style={{ height: 150, boxSizing: 'border-box', padding: '14px 24px', borderTop: '1px solid rgba(0,0,0,0.12)', display: 'flex', flexDirection: 'column', gap: 8 }}><div style={{ fontFamily: sans, fontSize: 11, letterSpacing: 1.6, textTransform: 'uppercase', color: 'rgba(0,0,0,0.45)' }}>Annotations · not part of the display</div>
      <div style={{ display: 'grid', gridTemplateColumns: w > 1000 ? 'repeat(3,1fr)' : '1fr', columnGap: 32, rowGap: 6 }}>{notes.map((n, i) => <div key={i} style={{ fontFamily: sans, fontSize: 13, lineHeight: 1.4, color: '#3a352d', display: 'flex', gap: 8 }}><span style={{ ...num, color: '#c96442', fontWeight: 600, flex: 'none' }}>{String(i + 1).padStart(2, '0')}</span><span><b>{n[0]}</b> — {n[1]}</span></div>)}</div></div></div>); }

  const BODY = H - P * 2 - 56 - G; // 608
  const COLS = { cpu: 740, mem: 600, net: 480, proc: 2512 - 740 - 600 - 480 - 48 };

  // 1 · Overview
  function Overview({ theme, alert, edit, pickers }) { const t = themes[theme || 'default']; const alerts = alert ? [{ level: 'crit', text: 'Memory pressure · Critical', since: '2m 14s' }, { level: 'warn', text: 'Macintosh HD · 95% full', since: '41m' }] : null; const wob = i => (edit ? (i % 2 ? 0.5 : -0.5) : 0);
    return (<Screen theme={theme}><HeaderBar w={2512} alerts={alerts} />
      <div style={{ display: 'flex', gap: G, height: BODY, position: 'relative' }}>
        <CPUBox w={COLS.cpu} h={BODY} graphH={240} edit={edit} wobble={wob(0)} picker={pickers} />
        <div style={{ position: 'relative' }}><MemBox w={COLS.mem} h={BODY} crit={alert} glow={alert ? t.crit : null} edit={edit} wobble={wob(1)} />{edit && <div style={{ position: 'absolute', inset: -6, borderRadius: 26, boxShadow: `0 30px 80px rgba(0,0,0,.5)`, pointerEvents: 'none' }} />}</div>
        <NetBox w={COLS.net} h={BODY} graphH={300} edit={edit} wobble={wob(2)} picker={pickers} />
        <ProcBox w={COLS.proc} h={BODY} edit={edit} wobble={wob(3)} />
        {edit && <EditToolbar />}
        {pickers && <><Touch x={260} y={120} label="Tap graph → time range picker (1 min · 5 min · 15 min · 1 h). Range is per-box and persists." />
          <Touch x={1440} y={430} kind="long" label="Tap chip → switch interface. Long-press → interface list with IP + link state." />
          <Touch x={1100} y={-70} kind="swipe" label="Swipe ← → anywhere on the background → previous / next preset. Dots in header show position." w={300} />
          <Touch x={1980} y={220} label="Tap process row → detail sheet. Tap column header → sort." />
          <Touch x={40} y={560} kind="long" label="Long-press any box (0.6 s) → edit mode: reorder, hide, resize." /></>}
      </div></Screen>); }
  function EditToolbar() { const t = useTheme(); return (<div style={{ position: 'absolute', left: '50%', bottom: 16, transform: 'translateX(-50%)', display: 'flex', alignItems: 'center', gap: 12, padding: 10, borderRadius: 24, background: t.mode === 'dark' ? '#0e1016' : 'rgba(255,255,255,0.95)', border: `1px solid ${t.hairline}`, boxShadow: '0 24px 70px rgba(0,0,0,.5)', zIndex: 5 }}>
    <span style={{ fontFamily: sans, fontSize: 15, color: t.text3, padding: '0 8px' }}>Editing · Overview</span><Hair v /><span style={{ fontFamily: sans, fontSize: 15, color: t.text3, paddingLeft: 8 }}>Hidden</span>{['Battery', 'GPU', 'Clock'].map(x => <Chip key={x} w={140} h={56}>{`+ ${x}`}</Chip>)}<Hair v /><Btn w={160}>Reset</Btn><Btn w={160} kind="primary">Done</Btn></div>); }

  // 2 · Focus CPU
  function FocusCPU({ theme }) { return (<Screen theme={theme}><HeaderBar w={2512} /><div style={{ display: 'flex', gap: G, height: BODY }}><CPUBox w={1500} h={BODY} graphH={200} cores="graphs" /><MemBox w={480} h={BODY} io={false} legendCols={1} /><NetBox w={500} h={BODY} graphH={230} /></div></Screen>); }

  // 3 · Focus Processes (+ detail sheet)
  function FocusProc({ theme, sheet = true, confirm = false }) { const p = D.procs[3]; return (<Screen theme={theme}><HeaderBar w={2512} /><div style={{ position: 'relative', height: BODY }}><ProcBox w={2512} h={BODY} rows={9} rowH={44} fs={16} wide selected={sheet ? p.pid : null} />{sheet && <DetailSheet p={p} confirm={confirm} />}</div></Screen>); }
  function DetailSheet({ p, confirm }) { const t = useTheme(); const cc = stateColor(t, p.cpu, 10, 25); return (<div style={{ position: 'absolute', top: 0, right: 0, bottom: 0, width: 780, boxSizing: 'border-box', padding: 28, borderRadius: 24, background: t.mode === 'dark' ? '#0e1016' : 'rgba(255,255,255,0.97)', border: `1px solid ${t.hairline}`, boxShadow: '-30px 0 90px rgba(0,0,0,.55)', display: 'flex', flexDirection: 'column', gap: 20 }}>
    <div style={{ display: 'flex', alignItems: 'center', gap: 18 }}><AppIcon p={p} size={64} /><div style={{ flex: 1, minWidth: 0 }}><div style={{ fontFamily: sans, fontSize: 30, fontWeight: 600, color: t.text }}>{p.name}</div><div style={{ ...num, fontSize: 15, color: t.text3 }}>PID {p.pid} · {p.user} · {p.status} · since {p.since}</div></div><div style={{ width: 56, height: 56, borderRadius: 28, background: t.surface2, display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 24, color: t.text2 }}>×</div></div>
    <div style={{ ...num, fontSize: 14, color: t.text2, background: t.surface2, borderRadius: 12, padding: '12px 14px', wordBreak: 'break-all', lineHeight: 1.45 }}>{p.cmd}</div>
    <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4,1fr)', gap: 12 }}>{[['CPU', `${p.cpu.toFixed(1)}%`, cc], ['Memory', `${p.mem.toFixed(2)} GB`], ['Threads', p.thr], ['Ports', 42]].map(([k, v, c]) => <div key={k} style={{ background: t.surface2, borderRadius: 14, padding: '12px 14px' }}><div style={{ fontFamily: sans, fontSize: 13, color: t.text3 }}>{k}</div><div style={{ ...num, fontSize: 28, fontWeight: 600, color: c || t.text }}>{v}</div></div>)}</div>
    <div style={{ display: 'flex', gap: 16 }}><div style={{ flex: 1 }}><div style={{ fontFamily: sans, fontSize: 13, color: t.text3, marginBottom: 6 }}>CPU · last 60 s</div><HistoryGraph values={p.cpuHist} w={354} h={96} /></div><div style={{ flex: 1 }}><div style={{ fontFamily: sans, fontSize: 13, color: t.text3, marginBottom: 6 }}>Memory · last 60 s</div><HistoryGraph values={p.memHist} w={354} h={96} max={8} solid color={t.accent} thresholds={[]} /></div></div>
    <div style={{ marginTop: 'auto' }}>{!confirm ? <div style={{ display: 'flex', gap: 12 }}><Btn>Terminate</Btn><Btn kind="destructive" style={{ background: `color-mix(in oklab, ${t.crit} 22%, transparent)`, color: t.crit, border: `1px solid color-mix(in oklab, ${t.crit} 50%, transparent)` }}>Force Quit…</Btn></div>
      : <div style={{ background: `color-mix(in oklab, ${t.crit} 12%, transparent)`, border: `1px solid color-mix(in oklab, ${t.crit} 40%, transparent)`, borderRadius: 18, padding: 20, display: 'flex', flexDirection: 'column', gap: 14 }}><div style={{ fontFamily: sans, fontSize: 20, fontWeight: 600, color: t.text }}>Force quit {p.name}?</div><div style={{ fontFamily: sans, fontSize: 15, color: t.text2, lineHeight: 1.4 }}>Running containers will stop and unsaved state is lost. This cannot be undone.</div>
        <div style={{ display: 'flex', gap: 12 }}><Btn>Cancel</Btn><div style={{ flex: 1.4, height: 56, borderRadius: 16, background: t.crit, color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 12, fontFamily: sans, fontSize: 18, fontWeight: 600, position: 'relative', overflow: 'hidden' }}><div style={{ position: 'absolute', left: 0, top: 0, bottom: 0, width: '62%', background: 'rgba(0,0,0,0.25)' }} /><span style={{ position: 'relative' }}>Hold to Force Quit</span><span style={{ ...num, fontSize: 14, opacity: 0.8, position: 'relative' }}>0.6 / 1.0 s</span></div></div></div>}</div>
  </div>); }

  // 4 · Ambient
  function Ambient({ theme, dim, shift = 0 }) { const t = themes[theme || 'default']; return (<Screen theme={theme} dim={dim}><ThemeCtx.Provider value={t}><div style={{ flex: 1, display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '0 72px', transform: `translate(${shift}px,${shift}px)` }}><ClockBig size={300} /><AmbientSparks /></div></ThemeCtx.Provider></Screen>); }
  function AmbientSparks({ w = 420, vertical }) { const t = useTheme(); const rows = [['cpu', D.cpu.hist, `${D.cpu.now}%`, stateColor(t, D.cpu.now)], ['mem', D.mem.hist, `${D.mem.pct}%`, stateColor(t, D.mem.pct, 70, 90)], ['net ↓', D.net.down, `${D.net.downNow} MB/s`, t.accent]];
    return (<div style={{ display: 'flex', flexDirection: 'column', gap: vertical ? 40 : 28 }}>{rows.map(([l, v, val, c]) => <div key={l} style={{ display: 'flex', alignItems: 'center', gap: 24 }}><span style={{ ...num, fontSize: 16, letterSpacing: 2.4, color: t.text3, width: 70 }}>{l}</span><Spark values={v} w={w} h={vertical ? 120 : 64} color={c} max={l === 'net ↓' ? 60 : 100} /><span style={{ ...num, fontSize: 36, fontWeight: 500, color: t.text, width: 220, textAlign: 'right' }}>{val}</span></div>)}</div>); }

  // 13/14 · Portrait
  function PortraitHeader({ t }) { const s = D.sys, c = D.clock; return (<div style={{ display: 'flex', flexDirection: 'column', gap: 10, height: 100 }}><div style={{ display: 'flex', alignItems: 'baseline', justifyContent: 'space-between' }}><span style={{ ...num, fontSize: 56, fontWeight: 600, letterSpacing: -1.5, lineHeight: 1 }}>{c.hm}<span style={{ color: t.text3, fontWeight: 400 }}>:{c.s}</span></span><span style={{ fontFamily: sans, fontSize: 18, color: t.text2 }}>{c.short} · <span style={{ color: t.text3 }}>{c.week}</span></span></div><div style={{ display: 'flex', alignItems: 'center', gap: 10, fontFamily: sans, fontSize: 14, color: t.text3, whiteSpace: 'nowrap' }}><span style={{ width: 8, height: 8, borderRadius: 4, background: t.ok }} /><span style={{ color: t.text2, fontWeight: 600 }}>{s.host}</span><span>{s.os}</span><span>· {s.sampling}</span><span style={{ marginLeft: 'auto', ...num }}>⚡︎ {s.battery.pct}% · {s.battery.watts} W</span></div></div>); }
  function PortraitOverview({ theme }) { const t = themes[theme || 'default']; return (<Screen theme={theme} w={720} h={2560}><PortraitHeader t={t} /><CPUBox w={672} h={600} graphH={260} coreBarW={26} coreGap={6} /><MemBox w={672} h={600} /><NetBox w={672} h={480} graphH={200} /><ProcBox w={672} h={668} rows={8} /></Screen>); }
  function PortraitAmbient({ theme }) { return (<Screen theme={theme} w={720} h={2560} dim><div style={{ flex: 1, display: 'flex', flexDirection: 'column', justifyContent: 'center', gap: 160, padding: '0 24px' }}><ClockBig size={168} /><AmbientSparks w={300} vertical /></div></Screen>); }

  B.presets = { Screen, Frame, Overview, FocusCPU, FocusProc, Ambient, PortraitOverview, PortraitAmbient, DetailSheet };
})();
