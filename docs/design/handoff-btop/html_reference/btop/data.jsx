// btop/data.jsx — deterministic sample data: MacBook Pro M3 Max, 36 GB, Wi-Fi
(function () {
  let seed = 4242;
  const rnd = () => { seed = (seed * 16807) % 2147483647; return (seed - 1) / 2147483646; };
  function series(n, base, amp, drift = 0.12, min = 0, max = 100) { const o = []; let v = base; for (let i = 0; i < n; i++) { v += (rnd() - 0.5) * amp + (base - v) * drift; v = Math.max(min, Math.min(max, v)); o.push(v); } return o; }
  function spiky(n, base, amp, p = 0.08, spike = 60, max = 100) { return series(n, base, amp).map(v => (rnd() < p ? Math.min(max, v + spike * rnd()) : v)); }
  const cpu = { hist: series(120, 34, 26), now: 34, load: [3.21, 2.87, 2.40], thermal: 'Nominal', model: 'Apple M3 Max', p: 12, e: 4, uptime: '3d 14h 22m',
    pCores: Array.from({ length: 12 }, (_, i) => series(60, 18 + ((i * 7) % 45), 34)), eCores: Array.from({ length: 4 }, (_, i) => series(60, 42 + i * 6, 30)),
    gpu: { hist: series(120, 18, 20), now: 18, mem: 4.2, memTotal: 36 } };
  cpu.pNow = cpu.pCores.map(s => s[s.length - 1]); cpu.eNow = cpu.eCores.map(s => s[s.length - 1]);
  const mem = { total: 36, app: 12.8, wired: 4.1, compressed: 2.3, cached: 6.4, free: 10.4, pressure: 'Normal', swapUsed: 1.2, swapTotal: 4, hist: series(120, 59, 6) };
  mem.used = mem.app + mem.wired + mem.compressed; mem.pct = Math.round((mem.used / mem.total) * 100);
  const memCrit = { ...mem, app: 24.6, wired: 5.2, compressed: 4.1, cached: 1.6, free: 0.5, pressure: 'Critical', swapUsed: 3.8, hist: series(120, 92, 5) };
  memCrit.used = memCrit.app + memCrit.wired + memCrit.compressed; memCrit.pct = Math.round((memCrit.used / memCrit.total) * 100);
  const disks = [
    { name: 'Macintosh HD', kind: 'APFS · internal', used: 612, total: 926, r: spiky(60, 6, 6, 0.1, 40), w: spiky(60, 3, 4, 0.08, 30), rNow: 12.4, wNow: 3.1 },
    { name: 'T7 Shield', kind: 'exFAT · USB 3.2', used: 1420, total: 2000, r: series(60, 1, 2), w: spiky(60, 8, 10, 0.1, 50), rNow: 0.4, wNow: 24.8 },
    { name: 'TimeMachine', kind: 'APFS · Thunderbolt', used: 3100, total: 4000, r: series(60, 0.2, 0.5), w: series(60, 0.5, 1), rNow: 0, wNow: 0.2 },
    { name: 'Shared', kind: 'SMB · nas.local', used: 1800, total: 6000, r: series(60, 0.1, 0.3), w: series(60, 0, 0.2), rNow: 0, wNow: 0 },
  ];
  const disksCrit = disks.map((d, i) => (i === 0 ? { ...d, used: 880 } : d));
  const net = { iface: 'en0', kind: 'Wi-Fi', ssid: 'Tolaria', ip: '192.168.1.42', rssi: -54, link: 866, ping: 12, pingHost: '1.1.1.1',
    down: spiky(120, 8, 8, 0.1, 40, 60), up: spiky(120, 2, 2, 0.06, 12, 20), downNow: 12.4, upNow: 1.8, downPeak: 48.2, upPeak: 14.6, downTotal: '3.1 GB', upTotal: '412 MB',
    ifaces: [{ id: 'auto', label: 'Auto', sub: 'sum en*' }, { id: 'en0', label: 'Wi-Fi', sub: 'en0 · 192.168.1.42' }, { id: 'en5', label: 'Ethernet', sub: 'en5 · no link' }, { id: 'en7', label: 'USB', sub: 'en7 · iPhone' }] };
  const procs = [
    { pid: 8812, name: 'Xcode', user: 'philipp', mem: 3.92, cpu: 31.6, thr: 48, ic: 'Xc', col: '#1b8ff5', kind: 'app', cmd: '/Applications/Xcode.app/Contents/MacOS/Xcode', since: '09:12', status: 'Running' },
    { pid: 437, name: 'WindowServer', user: '_windowserver', mem: 1.84, cpu: 18.4, thr: 22, ic: 'WS', col: '#8e8e93', kind: 'sys', cmd: '/System/Library/PrivateFrameworks/SkyLight.framework/Resources/WindowServer', since: 'boot', status: 'Running' },
    { pid: 0, name: 'kernel_task', user: 'root', mem: 2.31, cpu: 9.2, thr: 512, ic: 'k', col: '#48484a', kind: 'sys', cmd: 'kernel_task', since: 'boot', status: 'Running' },
    { pid: 2210, name: 'Docker', user: 'philipp', mem: 4.62, cpu: 6.1, thr: 64, ic: 'Dk', col: '#1d63ed', kind: 'app', cmd: '/Applications/Docker.app/Contents/MacOS/Docker', since: '09:40', status: 'Running' },
    { pid: 9120, name: 'Safari', user: 'philipp', mem: 1.36, cpu: 5.4, thr: 31, ic: 'Sf', col: '#2f8ef5', kind: 'app', cmd: '/Applications/Safari.app/Contents/MacOS/Safari', since: '08:55', status: 'Running' },
    { pid: 7731, name: 'com.apple.WebKit.WebContent', user: 'philipp', mem: 1.12, cpu: 4.8, thr: 19, ic: 'WK', col: '#5e5ce6', kind: 'bg', cmd: '/System/Library/Frameworks/WebKit.framework/Versions/A/XPCServices/com.apple.WebKit.WebContent.xpc', since: '10:02', status: 'Running' },
    { pid: 5540, name: 'Spotify', user: 'philipp', mem: 0.62, cpu: 2.9, thr: 27, ic: 'Sp', col: '#1db954', kind: 'app', cmd: '/Applications/Spotify.app/Contents/MacOS/Spotify', since: '09:01', status: 'Running' },
    { pid: 1201, name: 'mds_stores', user: 'root', mem: 0.48, cpu: 2.2, thr: 9, ic: 'md', col: '#636366', kind: 'sys', cmd: '/System/Library/Frameworks/CoreServices.framework/Frameworks/Metadata.framework/Versions/A/Support/mds_stores', since: 'boot', status: 'Running' },
    { pid: 6023, name: 'Terminal', user: 'philipp', mem: 0.21, cpu: 1.1, thr: 8, ic: '>_', col: '#2c2c2e', kind: 'app', cmd: '/System/Applications/Utilities/Terminal.app/Contents/MacOS/Terminal', since: '09:14', status: 'Running' },
    { pid: 3312, name: 'com.docker.backend', user: 'philipp', mem: 0.94, cpu: 0.9, thr: 41, ic: 'db', col: '#1d63ed', kind: 'bg', cmd: '/Applications/Docker.app/Contents/MacOS/com.docker.backend', since: '09:40', status: 'Running' },
    { pid: 812, name: 'bluetoothd', user: 'root', mem: 0.06, cpu: 0.4, thr: 6, ic: 'bt', col: '#636366', kind: 'sys', cmd: '/usr/sbin/bluetoothd', since: 'boot', status: 'Running' },
    { pid: 4410, name: 'Finder', user: 'philipp', mem: 0.33, cpu: 0.3, thr: 12, ic: 'Fi', col: '#3a9bfc', kind: 'app', cmd: '/System/Library/CoreServices/Finder.app/Contents/MacOS/Finder', since: 'login', status: 'Running' },
  ];
  procs.forEach(p => { p.cpuHist = series(60, p.cpu, p.cpu * 0.6, 0.1, 0, 100); p.memHist = series(60, p.mem, 0.3, 0.1, 0, 8); });
  const sys = { host: 'philipp-mbp', os: 'macOS 26.1', total: 412, threads: 2418, sampling: '1 s', xeneon: 'Connected', battery: { pct: 82, charging: true, remaining: '2:41', watts: 18.4, cycles: 214, health: 96 } };
  const clock = { time: '14:32:07', hm: '14:32', s: '07', date: 'Thursday, 4 September', short: 'Thu 4 Sep', week: 'W36', next: 'Design sync · 15:00' };
  window.btop = Object.assign(window.btop || {}, { data: { cpu, mem, memCrit, disks, disksCrit, net, procs, sys, clock } });
})();
