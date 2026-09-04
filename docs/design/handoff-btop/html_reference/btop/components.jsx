// btop/components.jsx — component library (all btop-prefixed on window.btop.ui)
(function () {
  const B = window.btop; const { useTheme, stateColor, mono, sans, type } = B;
  const num = { fontFamily: mono, fontVariantNumeric: 'tabular-nums', fontFeatureSettings: '"tnum"' };

  // geometry
  function pts(values, w, h, min, max) { const n = values.length; return values.map((v, i) => [(i / (n - 1)) * w, h - ((v - min) / (max - min)) * h]); }
  function smooth(p) { if (p.length < 2) return ''; let d = `M${p[0][0]},${p[0][1]}`; for (let i = 0; i < p.length - 1; i++) { const p0 = p[i - 1] || p[i], p1 = p[i], p2 = p[i + 1], p3 = p[i + 2] || p2; const c1 = [p1[0] + (p2[0] - p0[0]) / 6, p1[1] + (p2[1] - p0[1]) / 6], c2 = [p2[0] - (p3[0] - p1[0]) / 6, p2[1] - (p3[1] - p1[1]) / 6]; d += ` C${c1[0]},${c1[1]} ${c2[0]},${c2[1]} ${p2[0]},${p2[1]}`; } return d; }
  const uid = () => React.useId().replace(/:/g, '');

  // History graph — gradient ramp low→mid→high encodes value on the Y axis (btop-style)
  function HistoryGraph({ values, w, h, min = 0, max = 100, color, solid = false, grid = true, thresholds = [50, 80], strokeWidth = 2, fillOpacity = 0.28, style }) {
    const t = useTheme(); const id = uid(); const p = pts(values, w, h, min, max); const line = smooth(p);
    const area = `${line} L${w},${h} L0,${h} Z`; const stroke = solid ? color || t.accent : `url(#${id})`;
    return (<svg width={w} height={h} viewBox={`0 0 ${w} ${h}`} style={{ display: 'block', ...style }}>
      <defs><linearGradient id={id} x1="0" y1="1" x2="0" y2="0"><stop offset="0" stopColor={t.rampLow} /><stop offset="0.5" stopColor={t.rampMid} /><stop offset="1" stopColor={t.rampHigh} /></linearGradient>
        <linearGradient id={id + 'f'} x1="0" y1="1" x2="0" y2="0"><stop offset="0" stopColor={solid ? color || t.accent : t.rampLow} stopOpacity="0.02" /><stop offset="1" stopColor={solid ? color || t.accent : t.rampHigh} stopOpacity={fillOpacity} /></linearGradient></defs>
      {grid && thresholds.map(th => { const y = h - ((th - min) / (max - min)) * h; return <line key={th} x1="0" x2={w} y1={y} y2={y} stroke={t.hairline} strokeDasharray="3 5" />; })}
      <path d={area} fill={`url(#${id}f)`} /><path d={line} stroke={stroke} strokeWidth={strokeWidth} fill="none" strokeLinejoin="round" strokeLinecap="round" />
    </svg>);
  }

  // Mirrored network graph: download above baseline, upload below
  function MirrorGraph({ down, up, w, h, maxDown = 60, maxUp = 20 }) {
    const t = useTheme(); const id = uid(); const hh = h / 2 - 6;
    const pd = pts(down, w, hh, 0, maxDown); const pu = pts(up, w, hh, 0, maxUp).map(([x, y]) => [x, h - y]);
    const ld = smooth(pd), lu = smooth(pu);
    return (<svg width={w} height={h} viewBox={`0 0 ${w} ${h}`} style={{ display: 'block' }}>
      <defs><linearGradient id={id + 'd'} x1="0" y1="0" x2="0" y2="1"><stop offset="0" stopColor={t.accent} stopOpacity="0.4" /><stop offset="1" stopColor={t.accent} stopOpacity="0.02" /></linearGradient>
        <linearGradient id={id + 'u'} x1="0" y1="1" x2="0" y2="0"><stop offset="0" stopColor={t.up} stopOpacity="0.4" /><stop offset="1" stopColor={t.up} stopOpacity="0.02" /></linearGradient></defs>
      <path d={`${ld} L${w},${hh} L0,${hh} Z`} fill={`url(#${id}d)`} /><path d={ld} stroke={t.accent} strokeWidth="2" fill="none" />
      <path d={`${lu} L${w},${h - hh} L0,${h - hh} Z`} fill={`url(#${id}u)`} /><path d={lu} stroke={t.up} strokeWidth="2" fill="none" />
      <line x1="0" x2={w} y1={h / 2} y2={h / 2} stroke={t.text3} strokeOpacity="0.5" />
      <text x="0" y="14" fill={t.text3} fontFamily={mono} fontSize="12">↓ {maxDown} MB/s</text><text x="0" y={h - 4} fill={t.text3} fontFamily={mono} fontSize="12">↑ {maxUp} MB/s</text>
    </svg>);
  }

  function Spark({ values, w, h, color, max, min = 0 }) {
    const t = useTheme(); const mx = max ?? Math.max(1, ...values); const p = pts(values, w, h, min, mx); const l = smooth(p); const id = uid(); const c = color || t.accent;
    return (<svg width={w} height={h} viewBox={`0 0 ${w} ${h}`} style={{ display: 'block' }}><defs><linearGradient id={id} x1="0" y1="0" x2="0" y2="1"><stop offset="0" stopColor={c} stopOpacity="0.35" /><stop offset="1" stopColor={c} stopOpacity="0" /></linearGradient></defs><path d={`${l} L${w},${h} L0,${h} Z`} fill={`url(#${id})`} /><path d={l} stroke={c} strokeWidth="1.5" fill="none" /></svg>);
  }

  // Box — btop-style header: title top-left, live value top-right
  function Box({ title, meta, value, valueColor, children, w, h, style, glow, edit, wobble, pad = 22, gap = 16, onDark }) {
    const t = useTheme();
    return (<div style={{ width: w, height: h, boxSizing: 'border-box', background: t.surface, border: `1px solid ${glow ? glow : t.hairline}`, borderRadius: 20, padding: pad, display: 'flex', flexDirection: 'column', gap, position: 'relative', overflow: 'hidden', boxShadow: glow ? `0 0 0 1px ${glow}, 0 0 40px -6px ${glow}` : 'none', transform: wobble ? `rotate(${wobble}deg)` : 'none', outline: edit ? `2px dashed ${t.accent}` : 'none', outlineOffset: 4, ...style }}>
      <div style={{ display: 'flex', alignItems: 'baseline', justifyContent: 'space-between', gap: 12, minHeight: 28 }}>
        <div style={{ display: 'flex', alignItems: 'baseline', gap: 14, minWidth: 0 }}><span style={{ ...num, fontSize: 16, letterSpacing: 2.4, color: t.text2, textTransform: 'lowercase' }}>{title}</span>{meta && <span style={{ fontFamily: sans, fontSize: 15, color: t.text3, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{meta}</span>}</div>
        {value !== undefined && <span style={{ ...num, fontSize: 22, fontWeight: 500, color: valueColor || t.text, whiteSpace: 'nowrap' }}>{value}</span>}
      </div>
      {children}
      {edit && <EditHandles />}
    </div>);
  }
  function EditHandles() { const t = useTheme(); const btn = { position: 'absolute', width: 56, height: 56, borderRadius: 28, background: t.surface2, border: `1px solid ${t.hairline}`, display: 'flex', alignItems: 'center', justifyContent: 'center', color: t.text, fontSize: 24, fontFamily: sans, backdropFilter: 'blur(20px)' }; return (<><div style={{ ...btn, top: 12, right: 12 }}>×</div><div style={{ ...btn, top: 12, left: 12, color: t.text2 }}><Grip /></div><div style={{ position: 'absolute', right: 12, bottom: 12, width: 28, height: 28, borderRight: `3px solid ${t.text3}`, borderBottom: `3px solid ${t.text3}`, borderRadius: '0 0 8px 0' }} /></>); }
  const Grip = () => (<svg width="20" height="20" viewBox="0 0 20 20" fill="currentColor"><circle cx="7" cy="5" r="1.8" /><circle cx="13" cy="5" r="1.8" /><circle cx="7" cy="10" r="1.8" /><circle cx="13" cy="10" r="1.8" /><circle cx="7" cy="15" r="1.8" /><circle cx="13" cy="15" r="1.8" /></svg>);

  function Big({ v, unit, size = 72, color, label, style }) { const t = useTheme(); return (<div style={{ display: 'flex', flexDirection: 'column', gap: 2, ...style }}><div style={{ display: 'flex', alignItems: 'baseline', gap: 4 }}><span style={{ ...num, fontSize: size, fontWeight: 600, lineHeight: 1, letterSpacing: -size * 0.03, color: color || t.text }}>{v}</span>{unit && <span style={{ ...num, fontSize: size * 0.36, color: t.text2 }}>{unit}</span>}</div>{label && <span style={{ fontFamily: sans, fontSize: 15, color: t.text3, letterSpacing: 0.3 }}>{label}</span>}</div>); }
  function KV({ k, v, vColor, size = 15, mono: m = true }) { const t = useTheme(); return (<div style={{ display: 'flex', justifyContent: 'space-between', gap: 12, alignItems: 'baseline', whiteSpace: 'nowrap' }}><span style={{ fontFamily: sans, fontSize: size, color: t.text3 }}>{k}</span><span style={{ ...(m ? num : { fontFamily: sans }), fontSize: size, color: vColor || t.text2 }}>{v}</span></div>); }
  function Pill({ children, color, bg, icon, size = 15, h = 32, style }) { const t = useTheme(); const c = color || t.text2; return (<span style={{ display: 'inline-flex', alignItems: 'center', gap: 8, height: h, padding: '0 14px', borderRadius: h / 2, background: bg || t.surface2, color: c, fontFamily: sans, fontSize: size, fontWeight: 500, whiteSpace: 'nowrap', ...style }}>{icon !== false && <span style={{ width: 8, height: 8, borderRadius: 4, background: c, boxShadow: `0 0 8px ${c}` }} />}{children}</span>); }
  function Chip({ children, active, w, h = 56, style, sub }) { const t = useTheme(); return (<div style={{ height: h, width: w, flex: w ? 'none' : 1, borderRadius: 14, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 1, background: active ? t.text : t.surface2, color: active ? (t.mode === 'dark' ? t.bg : '#fff') : t.text2, fontFamily: sans, fontSize: 16, fontWeight: 600, border: `1px solid ${active ? 'transparent' : t.hairline}`, ...style }}>{children}{sub && <span style={{ ...num, fontSize: 11, opacity: 0.7, fontWeight: 400 }}>{sub}</span>}</div>); }
  function ChipRow({ items, active, h = 56, gap = 8, style }) { return (<div style={{ display: 'flex', gap, ...style }}>{items.map(i => <Chip key={i.label || i} active={(i.id || i) === active} h={h} sub={i.sub}>{i.label || i}</Chip>)}</div>); }
  function Hair({ v, style }) { const t = useTheme(); return <div style={{ background: t.hairline, ...(v ? { width: 1, alignSelf: 'stretch' } : { height: 1, width: '100%' }), ...style }} />; }

  // Per-core bars grouped P / E
  function CoreBars({ values, label, barW = 32, barH = 96, gap = 8 }) { const t = useTheme(); return (<div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}><div style={{ display: 'flex', justifyContent: 'space-between', whiteSpace: 'nowrap', gap: 8 }}><span style={{ fontFamily: sans, fontSize: 14, color: t.text3, letterSpacing: 0.3 }}>{label}</span><span style={{ ...num, fontSize: 14, color: t.text2 }}>avg {Math.round(values.reduce((a, b) => a + b, 0) / values.length)}%</span></div>
    <div style={{ display: 'flex', gap, alignItems: 'flex-end' }}>{values.map((v, i) => (<div key={i} style={{ width: barW, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 5 }}><div style={{ width: barW, height: barH, borderRadius: 6, background: t.surface2, position: 'relative', overflow: 'hidden' }}><div style={{ position: 'absolute', left: 0, right: 0, bottom: 0, height: `${v}%`, background: `linear-gradient(to top, ${t.rampLow}, ${t.rampMid} 60%, ${t.rampHigh})`, backgroundSize: `100% ${barH}px`, backgroundPosition: 'bottom', borderRadius: 4 }} /></div><span style={{ ...num, fontSize: 12, color: t.text3 }}>{Math.round(v)}</span></div>))}</div></div>); }

  // Segmented memory bar
  function SegBar({ segs, h = 14 }) { const t = useTheme(); const total = segs.reduce((a, s) => a + s.v, 0); return (<div style={{ display: 'flex', height: h, borderRadius: h / 2, overflow: 'hidden', gap: 2 }}>{segs.map(s => <div key={s.k} style={{ width: `${(s.v / total) * 100}%`, background: s.c, opacity: s.k === 'Free' ? 0.25 : 1 }} />)}</div>); }
  function Legend({ segs, cols = 2, fs = 15 }) { const t = useTheme(); return (<div style={{ display: 'grid', gridTemplateColumns: `repeat(${cols},1fr)`, columnGap: 20, rowGap: 8 }}>{segs.map(s => (<div key={s.k} style={{ display: 'flex', alignItems: 'center', gap: 10 }}><span style={{ width: 10, height: 10, borderRadius: 3, background: s.c, opacity: s.k === 'Free' ? 0.35 : 1 }} /><span style={{ fontFamily: sans, fontSize: fs, color: t.text3, flex: 1 }}>{s.k}</span><span style={{ ...num, fontSize: fs, color: t.text2 }}>{s.v.toFixed(1)} GB</span></div>))}</div>); }

  function DiskRow({ d, w, io = true, crit }) { const t = useTheme(); const pct = Math.round((d.used / d.total) * 100); const c = stateColor(t, pct, 80, 90); const fmt = v => (v >= 1000 ? (v / 1000).toFixed(2) + ' TB' : v + ' GB');
    return (<div style={{ display: 'grid', gridTemplateColumns: io ? '1fr 150px 84px' : '1fr 120px', gap: 16, alignItems: 'center', height: 56 }}>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 6, minWidth: 0 }}><div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', gap: 10 }}><span style={{ fontFamily: sans, fontSize: 16, fontWeight: 500, color: t.text, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis', minWidth: 0 }}>{d.name}<span style={{ color: t.text3, fontWeight: 400, fontSize: 13, marginLeft: 8 }}>{d.kind}</span></span><span style={{ ...num, fontSize: 13, color: crit ? t.crit : t.text2, whiteSpace: 'nowrap', flex: 'none' }}>{fmt(d.used)} / {fmt(d.total)}</span></div>
        <div style={{ height: 6, borderRadius: 3, background: t.surface2 }}><div style={{ width: `${pct}%`, height: '100%', borderRadius: 3, background: c }} /></div></div>
      {io && <div style={{ display: 'flex', gap: 8 }}><div style={{ flex: 1 }}><Spark values={d.r} w={70} h={22} color={t.accent} max={50} /></div><div style={{ flex: 1 }}><Spark values={d.w} w={70} h={22} color={t.up} max={50} /></div></div>}
      {io && <div style={{ display: 'flex', flexDirection: 'column', ...num, fontSize: 12, color: t.text3, lineHeight: 1.3 }}><span><span style={{ color: t.accent }}>R</span> {d.rNow.toFixed(1)} MB/s</span><span><span style={{ color: t.up }}>W</span> {d.wNow.toFixed(1)} MB/s</span></div>}
    </div>); }

  function AppIcon({ p, size = 28 }) { return <div style={{ width: size, height: size, borderRadius: size * 0.24, background: p.col, color: '#fff', fontFamily: sans, fontSize: size * 0.42, fontWeight: 700, display: 'flex', alignItems: 'center', justifyContent: 'center', flex: 'none', letterSpacing: -0.5 }}>{p.ic}</div>; }
  function ProcRow({ p, cols, h = 54, selected, wide, fs = 17 }) { const t = useTheme(); const cc = stateColor(t, p.cpu, 10, 25); return (<div style={{ display: 'grid', gridTemplateColumns: cols, gap: 12, alignItems: 'center', height: h, padding: '0 10px', borderRadius: 12, background: selected ? t.surface2 : 'transparent', boxShadow: selected ? `inset 0 0 0 1px ${t.accent}` : 'none' }}>
    <AppIcon p={p} /><span style={{ fontFamily: sans, fontSize: fs, color: t.text, fontWeight: 500, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{p.name}</span>
    <span style={{ ...num, fontSize: fs - 2, color: t.text3 }}>{p.pid}</span><span style={{ fontFamily: sans, fontSize: fs - 2, color: t.text3, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{p.user}</span>
    {wide && <span style={{ ...num, fontSize: fs - 2, color: t.text3 }}>{p.thr}</span>}
    {wide && <Spark values={p.memHist} w={80} h={22} color={t.text3} max={8} />}<span style={{ ...num, fontSize: fs, color: t.text2, textAlign: 'right' }}>{p.mem.toFixed(2)} GB</span>
    {wide && <Spark values={p.cpuHist} w={80} h={22} color={cc} max={100} />}<span style={{ ...num, fontSize: fs, color: cc, textAlign: 'right', fontWeight: 600 }}>{p.cpu.toFixed(1)}%</span>
    {!wide && <span style={{ ...num, fontSize: fs - 2, color: t.text3, textAlign: 'right' }}>{p.thr}</span>}
  </div>); }
  function ProcHead({ cols, wide, sort = 'cpu' }) { const t = useTheme(); const s = { fontFamily: sans, fontSize: 12, color: t.text3, letterSpacing: 1.2, textTransform: 'uppercase' }; const a = k => (k === sort ? { color: t.text, fontWeight: 600 } : {}); return (<div style={{ display: 'grid', gridTemplateColumns: cols, gap: 12, padding: '0 10px', height: 24, alignItems: 'center' }}><span /><span style={{ ...s, ...a('name') }}>Name</span><span style={{ ...s, ...a('pid') }}>PID</span><span style={s}>User</span>{wide && <span style={s}>Thr</span>}{wide && <span />}<span style={{ ...s, textAlign: 'right', ...a('mem') }}>Mem</span>{wide && <span />}<span style={{ ...s, textAlign: 'right', ...a('cpu') }}>CPU {sort === 'cpu' ? '↓' : ''}</span>{!wide && <span style={{ ...s, textAlign: 'right' }}>Thr</span>}</div>); }

  function BatteryPill({ b, h = 40 }) { const t = useTheme(); const c = b.pct < 20 ? t.crit : t.text; return (<div style={{ display: 'flex', alignItems: 'center', gap: 12, height: h, padding: '0 16px', borderRadius: h / 2, background: t.surface, border: `1px solid ${t.hairline}` }}><div style={{ position: 'relative', width: 30, height: 14, border: `1.5px solid ${t.text2}`, borderRadius: 4 }}><div style={{ position: 'absolute', right: -5, top: 3, width: 3, height: 6, background: t.text2, borderRadius: 1 }} /><div style={{ position: 'absolute', left: 2, top: 2, bottom: 2, width: `${b.pct * 0.9}%`, background: b.charging ? t.ok : c, borderRadius: 2 }} /></div><span style={{ ...num, fontSize: 18, color: t.text, fontWeight: 600 }}>{b.pct}%</span>{b.charging && <span style={{ color: t.ok, fontSize: 16 }}>⚡︎</span>}<span style={{ ...num, fontSize: 14, color: t.text3, whiteSpace: 'nowrap' }}>{b.remaining} · {b.watts} W</span></div>); }

  function AlertStrip({ alerts, h = 40 }) { const t = useTheme(); return (<div style={{ display: 'flex', gap: 8 }}>{alerts.map((a, i) => { const c = a.level === 'crit' ? t.crit : t.warn; return (<div key={i} style={{ display: 'flex', alignItems: 'center', gap: 10, height: h, padding: '0 16px 0 12px', borderRadius: h / 2, background: `color-mix(in oklab, ${c} 18%, transparent)`, border: `1px solid color-mix(in oklab, ${c} 45%, transparent)`, color: c, fontFamily: sans, fontSize: 15, fontWeight: 600 }}><span style={{ width: 10, height: 10, borderRadius: 5, background: c, boxShadow: `0 0 10px ${c}`, animation: 'btopPulse 1.6s ease-in-out infinite' }} />{a.text}<span style={{ ...num, fontWeight: 400, opacity: 0.75 }}>{a.since}</span></div>); })}</div>); }

  function Btn({ children, kind = 'secondary', w, h = 56, style }) { const t = useTheme(); const bg = kind === 'destructive' ? t.crit : kind === 'primary' ? t.text : t.surface2; const col = kind === 'destructive' ? '#fff' : kind === 'primary' ? (t.mode === 'dark' ? t.bg : '#fff') : t.text; return <div style={{ height: h, width: w, flex: w ? 'none' : 1, borderRadius: 16, background: bg, color: col, display: 'flex', alignItems: 'center', justifyContent: 'center', fontFamily: sans, fontSize: 18, fontWeight: 600, border: kind === 'secondary' ? `1px solid ${t.hairline}` : 'none', ...style }}>{children}</div>; }
  function Toggle({ on }) { const t = useTheme(); return <div style={{ width: 38, height: 22, borderRadius: 11, background: on ? t.ok : t.surface2, position: 'relative', border: `1px solid ${on ? 'transparent' : t.hairline}` }}><div style={{ position: 'absolute', top: 2, left: on ? 18 : 2, width: 16, height: 16, borderRadius: 8, background: '#fff', boxShadow: '0 1px 3px rgba(0,0,0,.3)' }} /></div>; }

  // Touch annotation glyph (for annotated artboards)
  function Touch({ x, y, label, kind = 'tap', w = 220 }) { const c = '#ff7a3d'; const glyph = kind === 'swipe' ? '⟷' : kind === 'long' ? '◉' : '●'; return (<div style={{ position: 'absolute', left: x, top: y, display: 'flex', alignItems: 'center', gap: 12, zIndex: 20 }}><div style={{ width: 56, height: 56, borderRadius: 28, border: `3px solid ${c}`, background: 'rgba(255,122,61,0.22)', display: 'flex', alignItems: 'center', justifyContent: 'center', color: c, fontSize: 20, flex: 'none' }}>{glyph}</div><div style={{ width: w, background: c, color: '#1a0d05', fontFamily: sans, fontSize: 14, fontWeight: 600, padding: '8px 12px', borderRadius: 10, lineHeight: 1.3 }}>{label}</div></div>); }

  if (!document.getElementById('btop-kf')) { const s = document.createElement('style'); s.id = 'btop-kf'; s.textContent = '@keyframes btopPulse{0%,100%{opacity:1}50%{opacity:.35}} a{color:inherit} a:hover{opacity:.8}'; document.head.appendChild(s); }
  B.ui = { HistoryGraph, MirrorGraph, Spark, Box, Big, KV, Pill, Chip, ChipRow, Hair, CoreBars, SegBar, Legend, DiskRow, AppIcon, ProcRow, ProcHead, BatteryPill, AlertStrip, Btn, Toggle, Touch, Grip, num };
})();
