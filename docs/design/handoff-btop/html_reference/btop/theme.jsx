// btop/theme.jsx — semantic theme tokens + context
(function () {
  const sans = "-apple-system, BlinkMacSystemFont, 'SF Pro Display', 'SF Pro Text', 'Helvetica Neue', sans-serif";
  const mono = "ui-monospace, 'SF Mono', 'JetBrains Mono', Menlo, monospace";
  const rounded = "-apple-system, BlinkMacSystemFont, 'SF Pro Rounded', 'Helvetica Neue', sans-serif";
  const themes = {
    default: { id: 'default', name: 'Default Glass', mode: 'dark',
      bg: '#0b0d13', bgDeep: '#07080c', surface: 'rgba(255,255,255,0.055)', surface2: 'rgba(255,255,255,0.10)', hairline: 'rgba(255,255,255,0.09)',
      text: 'rgba(255,255,255,0.95)', text2: 'rgba(255,255,255,0.64)', text3: 'rgba(255,255,255,0.42)',
      rampLow: 'oklch(0.80 0.13 195)', rampMid: 'oklch(0.85 0.15 85)', rampHigh: 'oklch(0.68 0.21 22)',
      accent: 'oklch(0.78 0.10 235)', ok: 'oklch(0.78 0.16 150)', warn: 'oklch(0.84 0.15 82)', crit: 'oklch(0.68 0.21 22)', up: 'oklch(0.76 0.13 300)' },
    oled: { id: 'oled', name: 'OLED Black', mode: 'dark',
      bg: '#000000', bgDeep: '#000000', surface: 'rgba(255,255,255,0.04)', surface2: 'rgba(255,255,255,0.09)', hairline: 'rgba(255,255,255,0.12)',
      text: 'rgba(255,255,255,0.92)', text2: 'rgba(255,255,255,0.60)', text3: 'rgba(255,255,255,0.40)',
      rampLow: 'oklch(0.82 0.14 190)', rampMid: 'oklch(0.86 0.16 85)', rampHigh: 'oklch(0.70 0.22 22)',
      accent: 'oklch(0.80 0.11 235)', ok: 'oklch(0.80 0.17 150)', warn: 'oklch(0.86 0.16 82)', crit: 'oklch(0.70 0.22 22)', up: 'oklch(0.78 0.14 300)' },
    nord: { id: 'nord', name: 'Nord', mode: 'dark',
      bg: '#2e3440', bgDeep: '#272c36', surface: '#3b4252', surface2: '#434c5e', hairline: '#4c566a',
      text: '#eceff4', text2: '#d8dee9', text3: '#a3adc2',
      rampLow: '#8fbcbb', rampMid: '#ebcb8b', rampHigh: '#bf616a',
      accent: '#88c0d0', ok: '#a3be8c', warn: '#ebcb8b', crit: '#bf616a', up: '#b48ead' },
    light: { id: 'light', name: 'Daylight', mode: 'light',
      bg: '#e4e5ea', bgDeep: '#d8d9df', surface: 'rgba(255,255,255,0.72)', surface2: 'rgba(255,255,255,0.95)', hairline: 'rgba(0,0,0,0.09)',
      text: '#15161c', text2: 'rgba(0,0,0,0.64)', text3: 'rgba(0,0,0,0.46)',
      rampLow: '#0a8f74', rampMid: '#b86f00', rampHigh: '#c72e26',
      accent: '#2a63c9', ok: '#1e8a4a', warn: '#a86300', crit: '#c72e26', up: '#7a4fc9' },
    tokyo: { id: 'tokyo', name: 'Tokyo Night', mode: 'dark',
      bg: '#16161e', bgDeep: '#111117', surface: '#1f2335', surface2: '#292e42', hairline: '#3b4261',
      text: '#c0caf5', text2: '#a9b1d6', text3: '#7d86b3',
      rampLow: '#7dcfff', rampMid: '#e0af68', rampHigh: '#f7768e',
      accent: '#7aa2f7', ok: '#9ece6a', warn: '#e0af68', crit: '#f7768e', up: '#bb9af7' },
  };
  const ThemeCtx = React.createContext(themes.default);
  const useTheme = () => React.useContext(ThemeCtx);
  const stateColor = (t, pct, lo = 50, hi = 80) => (pct < lo ? t.ok : pct < hi ? t.warn : t.crit);
  const type = { display: 200, clock: 44, big: 72, num: 36, h: 22, body: 17, small: 15, micro: 13 };
  const space = { pad: 24, gap: 16, boxPad: 22, radius: 20, radiusSm: 12, tap: 56 };
  window.btop = Object.assign(window.btop || {}, { themes, ThemeCtx, useTheme, stateColor, sans, mono, rounded, type, space });
})();
