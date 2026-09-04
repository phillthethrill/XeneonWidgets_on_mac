// btop/boxes.jsx — the five btop boxes + header, parameterised by size
(function () {
  const B = window.btop; const { useTheme, stateColor, mono, sans, data: D } = B;
  const { HistoryGraph, MirrorGraph, Spark, Box, Big, KV, Pill, ChipRow, Hair, CoreBars, SegBar, Legend, DiskRow, ProcRow, ProcHead, BatteryPill, AlertStrip, num } = B.ui;

  // ---------- Header strip ----------
  function HeaderBar({ w, alerts, compact }) { const t = useTheme(); const s = D.sys, c = D.clock; return (<div style={{ width: w, height: 56, display: 'flex', alignItems: 'center', gap: 24 }}>
    <div style={{ display: 'flex', alignItems: 'center', gap: 12, fontFamily: sans, fontSize: 15, color: t.text3, whiteSpace: 'nowrap' }}><span style={{ width: 8, height: 8, borderRadius: 4, background: t.ok, boxShadow: `0 0 8px ${t.ok}` }} /><span style={{ color: t.text2, fontWeight: 600 }}>{s.host}</span><span>{s.os}</span><span>·</span><span>up {D.cpu.uptime}</span><span>·</span><span>Xeneon {s.xeneon}</span><span>·</span><span style={num}>{s.sampling} sampling</span></div>
    <div style={{ flex: 1, display: 'flex', justifyContent: 'center' }}>{alerts && <AlertStrip alerts={alerts} />}</div>
    {!compact && <BatteryPill b={s.battery} />}
    <div style={{ display: 'flex', alignItems: 'baseline', gap: 14 }}><span style={{ ...num, fontSize: 44, fontWeight: 600, color: t.text, letterSpacing: -1, lineHeight: 1 }}>{c.hm}<span style={{ color: t.text3, fontWeight: 400 }}>:{c.s}</span></span><span style={{ fontFamily: sans, fontSize: 16, color: t.text2 }}>{c.short} <span style={{ color: t.text3 }}>· {c.week}</span></span></div>
  </div>); }

  // ---------- CPU ----------
  function CPUBox({ w, h, graphH = 200, cores = 'bars', gpu = true, glow, edit, wobble, picker, range = '5 min', coreBarW = 32, coreGap = 8 }) { const t = useTheme(); const c = D.cpu; const iw = w - 44; const col = stateColor(t, c.now); const rightW = 268; const gw = iw - rightW - 24;
    return (<Box title="cpu" meta={`${c.model} · ${c.p}P + ${c.e}E · up ${c.uptime}`} value={`${c.now}%`} valueColor={col} w={w} h={h} glow={glow} edit={edit} wobble={wobble}>
      <div style={{ display: 'flex', gap: 24, position: 'relative' }}>
        <div style={{ position: 'relative' }}><HistoryGraph values={c.hist} w={gw} h={graphH} /><span style={{ position: 'absolute', right: 0, top: -2, ...num, fontSize: 12, color: t.text3 }}>{range} · tap for range</span>
          {picker && <div style={{ position: 'absolute', left: '50%', top: '50%', transform: 'translate(-50%,-50%)', display: 'flex', gap: 8, padding: 8, borderRadius: 18, background: t.mode === 'dark' ? '#0e1016' : 'rgba(255,255,255,0.96)', border: `1px solid ${t.hairline}`, boxShadow: '0 20px 60px rgba(0,0,0,.45)' }}>{['1 min', '5 min', '15 min', '1 h'].map(r => <B.ui.Chip key={r} w={92} active={r === range}>{r}</B.ui.Chip>)}</div>}</div>
        <div style={{ width: rightW, display: 'flex', flexDirection: 'column', gap: 12 }}><Big v={c.now} unit="%" color={col} label="total · 16 cores" /><Pill color={t.ok}>Thermal · {c.thermal}</Pill>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 4 }}><KV k="load 1 · 5 · 15" v={c.load.map(l => l.toFixed(2)).join('  ')} /><KV k="freq" v="n/a · Apple Silicon" vColor={t.text3} /></div></div>
      </div>
      {cores === 'bars' && <div style={{ display: 'flex', gap: 24 }}><CoreBars values={c.pNow} label={`${c.p} P-cores`} barW={coreBarW} gap={coreGap} /><Hair v /><CoreBars values={c.eNow} label={`${c.e} E-cores`} barW={coreBarW} gap={coreGap} /></div>}
      {cores === 'graphs' && <CoreGraphs w={iw} />}
      {gpu && <><Hair /><div style={{ display: 'flex', alignItems: 'center', gap: 20 }}><span style={{ ...num, fontSize: 16, letterSpacing: 2.4, color: t.text2 }}>gpu</span><HistoryGraph values={c.gpu.hist} w={Math.max(160, Math.min(320, iw - 470))} h={56} grid={false} /><Big v={c.gpu.now} unit="%" size={34} label="40-core GPU" /><div style={{ marginLeft: 'auto', display: 'flex', flexDirection: 'column', gap: 4, width: 200 }}><KV k="gpu memory" v={`${c.gpu.mem} / ${c.gpu.memTotal} GB`} /><KV k="source" v="IOKit perf stats" vColor={t.text3} /></div></div></>}
    </Box>); }
  function CoreGraphs({ w }) { const t = useTheme(); const c = D.cpu; const all = [...c.pCores.map((s, i) => ({ s, l: `P${i}` })), ...c.eCores.map((s, i) => ({ s, l: `E${i}`, e: true }))]; const cols = 8; const gw = (w - (cols - 1) * 12) / cols;
    return (<div style={{ display: 'grid', gridTemplateColumns: `repeat(${cols}, 1fr)`, gap: 12 }}>{all.map(({ s, l, e }) => (<div key={l} style={{ background: t.surface2, borderRadius: 12, padding: '8px 10px', display: 'flex', flexDirection: 'column', gap: 4, borderLeft: e ? `3px solid ${t.accent}` : `3px solid transparent` }}><div style={{ display: 'flex', justifyContent: 'space-between', ...num, fontSize: 13 }}><span style={{ color: t.text3 }}>{l}{e ? ' · eff' : ''}</span><span style={{ color: stateColor(t, s[s.length - 1]) }}>{Math.round(s[s.length - 1])}%</span></div><HistoryGraph values={s} w={gw - 20} h={56} grid={false} strokeWidth={1.5} /></div>))}</div>); }

  // ---------- Memory ----------
  function MemBox({ w, h, crit, disks = true, io = true, glow, edit, wobble, legendCols = 2 }) { const t = useTheme(); const m = crit ? D.memCrit : D.mem; const ds = crit ? D.disksCrit : D.disks; const iw = w - 44; const pc = m.pressure === 'Critical' ? t.crit : m.pressure === 'Warning' ? t.warn : t.ok;
    const segs = [{ k: 'App', v: m.app, c: t.rampHigh }, { k: 'Wired', v: m.wired, c: t.rampMid }, { k: 'Compressed', v: m.compressed, c: t.up }, { k: 'Cached files', v: m.cached, c: t.rampLow }, { k: 'Free', v: m.free, c: t.text3 }];
    return (<Box title="mem" meta="36 GB unified" value={`${m.used.toFixed(1)} / ${m.total} GB`} valueColor={crit ? t.crit : undefined} w={w} h={h} glow={glow} edit={edit} wobble={wobble}>
      <div style={{ display: 'flex', alignItems: 'flex-end', gap: 20 }}><Big v={m.pct} unit="%" size={56} color={stateColor(t, m.pct, 70, 90)} label="used" /><div style={{ display: 'flex', flexDirection: 'column', gap: 8, alignItems: 'flex-start', paddingBottom: 4 }}><Pill color={pc}>Pressure · {m.pressure}</Pill><span style={{ ...num, fontSize: 14, color: t.text3, paddingLeft: 2 }}>swap {m.swapUsed} / {m.swapTotal} GB</span></div></div>
      <SegBar segs={segs} /><Legend segs={segs} cols={legendCols} />
      {disks && <><Hair /><div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline' }}><span style={{ ...num, fontSize: 16, letterSpacing: 2.4, color: t.text2 }}>disks</span><span style={{ ...num, fontSize: 14, color: t.text3 }}>{ds.length} volumes · <span style={{ color: t.accent }}>R</span> <span style={{ color: t.up }}>W</span> MB/s</span></div>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 4 }}>{ds.map((d, i) => <DiskRow key={d.name} d={d} w={iw} io={io} crit={crit && i === 0} />)}</div></>}
    </Box>); }

  // ---------- Network ----------
  function NetBox({ w, h, graphH = 200, chips = true, picker, glow, edit, wobble }) { const t = useTheme(); const n = D.net; const iw = w - 44;
    const Rate = ({ dir, v, peak, total, c }) => (<div style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: 6 }}><div style={{ display: 'flex', alignItems: 'baseline', gap: 6 }}><span style={{ ...num, fontSize: 30, color: c, fontWeight: 600 }}>{dir}</span><span style={{ ...num, fontSize: 36, fontWeight: 600, color: t.text, letterSpacing: -1 }}>{v.toFixed(1)}</span><span style={{ ...num, fontSize: 14, color: t.text3 }}>MB/s</span></div><div style={{ display: 'flex', gap: 14, ...num, fontSize: 13, color: t.text3 }}><span>peak <span style={{ color: t.text2 }}>{peak}</span></span><span>total <span style={{ color: t.text2 }}>{total}</span></span></div></div>);
    return (<Box title="net" meta={`${n.ssid} · ${n.ip}`} value={`${n.iface} · ${n.kind}`} w={w} h={h} glow={glow} edit={edit} wobble={wobble}>
      <MirrorGraph down={n.down} up={n.up} w={iw} h={graphH} />
      <div style={{ display: 'flex', gap: 16 }}><Rate dir="↓" v={n.downNow} peak={n.downPeak} total={n.downTotal} c={t.accent} /><Rate dir="↑" v={n.upNow} peak={n.upPeak} total={n.upTotal} c={t.up} /></div>
      {chips && <div style={{ position: 'relative' }}><ChipRow items={n.ifaces} active="en0" />
        {picker && <div style={{ position: 'absolute', left: 0, right: 0, bottom: 64, padding: 8, borderRadius: 18, background: t.mode === 'dark' ? '#0e1016' : 'rgba(255,255,255,0.96)', border: `1px solid ${t.hairline}`, boxShadow: '0 20px 60px rgba(0,0,0,.45)', display: 'flex', flexDirection: 'column', gap: 4 }}>{n.ifaces.map(i => <div key={i.id} style={{ height: 56, display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '0 16px', borderRadius: 12, background: i.id === 'en0' ? t.surface2 : 'transparent', fontFamily: sans, fontSize: 17, color: t.text, fontWeight: 500 }}><span>{i.label}</span><span style={{ ...num, fontSize: 14, color: t.text3 }}>{i.sub}{i.id === 'en0' ? '  ✓' : ''}</span></div>)}</div>}</div>}
      <div style={{ display: 'flex', justifyContent: 'space-between', ...num, fontSize: 14, color: t.text3 }}><span>RSSI <span style={{ color: t.text2 }}>{n.rssi} dBm</span></span><span>link <span style={{ color: t.text2 }}>{n.link} Mb/s</span></span><span>ping {n.pingHost} <span style={{ color: t.ok }}>{n.ping} ms</span></span></div>
    </Box>); }

  // ---------- Processes ----------
  function ProcBox({ w, h, rows = 7, chips = true, wide = false, selected, glow, edit, wobble, rowH = 54, fs = 17 }) { const t = useTheme(); const cols = wide ? '32px 480px 80px 140px 60px 90px 110px 90px 90px 1fr' : '28px 1fr 60px 96px 92px 76px 40px';
    return (<Box title="proc" meta={`${D.sys.total} processes · ${D.sys.threads} threads`} value={`top ${rows} · cpu ↓`} w={w} h={h} glow={glow} edit={edit} wobble={wobble} gap={12}>
      {chips && <ChipRow items={[{ id: 'all', label: 'All' }, { id: 'apps', label: 'Apps' }, { id: 'bg', label: 'Background' }, { id: 'sys', label: 'System' }, { id: 'mine', label: 'Mine' }, { id: 'hot', label: 'High CPU' }]} active="all" h={48} />}
      <ProcHead cols={cols} wide={wide} /><div style={{ display: 'flex', flexDirection: 'column' }}>{D.procs.slice(0, rows).map(p => <ProcRow key={p.pid} p={p} cols={cols} h={rowH} wide={wide} selected={selected === p.pid} fs={fs} />)}</div>
      <div style={{ marginTop: 'auto', display: 'flex', justifyContent: 'space-between', fontFamily: sans, fontSize: 14, color: t.text3 }}><span>tap row → details · long-press → sort</span><span>tap header → full list</span></div>
    </Box>); }

  // ---------- Clock (ambient) ----------
  function ClockBig({ size = 280, dim }) { const t = useTheme(); const c = D.clock; return (<div style={{ display: 'flex', flexDirection: 'column', gap: 10, opacity: dim ? 0.6 : 1 }}><div style={{ ...num, fontSize: size, fontWeight: 200, letterSpacing: -size * 0.04, lineHeight: 1, color: t.text }}>{c.hm}<span style={{ fontSize: size * 0.32, color: t.text3, marginLeft: size * 0.06 }}>{c.s}</span></div><div style={{ fontFamily: sans, fontSize: size * 0.11, color: t.text2, fontWeight: 400 }}>{c.date} <span style={{ color: t.text3 }}>· {c.week} · next: {c.next}</span></div></div>); }

  B.boxes = { HeaderBar, CPUBox, MemBox, NetBox, ProcBox, ClockBig, CoreGraphs };
})();
