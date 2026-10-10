// HTML replicas of the Wrait screens. Colours mirror
// lib/presentation/theme/wrait_colors.dart; keep them in sync with the app.
const palette = {
  light: { bg: '#FAF9F7', bg2: '#F0EDE8', surface: '#F0EDE8', primary: '#2C2B27', onPrimary: '#FAF9F7',
           secondary: '#5C5953', outline: '#8C8983', border: '#E8E4DD', warnBg: '#FEF3C7', warn: '#F59E0B' },
  dark:  { bg: '#0F0F0D', bg2: '#1A1917', surface: '#1A1917', primary: '#E8E4DD', onPrimary: '#1A1917',
           secondary: '#A8A4A0', outline: '#6E6B67', border: '#2A2926', warnBg: '#3D2B00', warn: '#F59E0B' },
};

// The phone screen is ~690px wide in the final image; the replica is designed
// at ~320 CSS px wide and scaled up.
const SCALE = 2.15;

const esc = (s) => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;');

// Shared: fills the phone's screen slot.
const base = (theme) => {
  const c = palette[theme];
  return `
  .app { width: calc(100% / ${SCALE}); height: calc(100% / ${SCALE}); transform: scale(${SCALE}); transform-origin: 0 0; background: linear-gradient(${c.bg}, ${c.bg2}); color: ${c.primary};
         display: flex; flex-direction: column; padding-top: 50px; overflow: hidden; font-size: 15px; }
  .small { font-size: 12px; color: ${c.secondary}; }
  .label { font-size: 14px; font-weight: 500; color: ${c.secondary}; }`;
};

export const screens = [
  {
    id: 'main',
    css: (theme) => base(theme) + `
      .main { align-items: center; justify-content: center; gap: 20px; text-align: center; }
      .btn { width: 160px; height: 160px; border-radius: 50%; background: ${palette[theme].primary};
             color: ${palette[theme].onPrimary}; display: grid; place-items: center; font-size: 26px; font-weight: 500;
             box-shadow: 0 0 0 10px ${palette[theme].primary}22, 0 0 0 26px ${palette[theme].primary}11; margin: 36px 0 18px; }
`,
    html: (t) => `<div class="app main">
      <div class="label">${esc(t.language)}</div>
      <div class="btn">${esc(t.wait)}</div>
      <div class="label">${esc(t.tap)}</div>
      <div class="label" style="margin-top:28px;color:inherit">${esc(t.stats.replace('{n}', 42).replace('{d}', 17))}</div>
    </div>`,
  },
  {
    id: 'entries',
    css: (theme) => base(theme) + `
      .list { padding: 54px 14px 0; gap: 10px; }
      .search { background: ${palette[theme].surface}; border: 1px solid ${palette[theme].border}; border-radius: 12px;
                padding: 11px 14px; color: ${palette[theme].outline}; margin-bottom: 4px; }
      .card { background: ${palette[theme].surface}; border-radius: 12px; padding: 14px; }
      .row { display: flex; justify-content: space-between; align-items: center; margin-bottom: 8px; }
      .preview { font-size: 14px; font-weight: 500; line-height: 1.35; display: -webkit-box;
                 -webkit-line-clamp: 2; -webkit-box-orient: vertical; overflow: hidden; }
      .badge { background: ${palette[theme].warnBg}; color: ${palette[theme].warn}; font-size: 11px; border-radius: 4px; padding: 3px 8px; }`,
    html: (t) => `<div class="app list">
      <div class="search">${esc(t.search)}</div>
      ${t.entries.map((e, i) => `<div class="card">
        <div class="row"><span class="small">${esc(t.dates[i])}</span>${i === 0 ? `<span class="badge">${esc(t.draft)}</span>` : ''}</div>
        <div class="preview">${esc(e)}</div>
        <div class="small" style="margin-top:6px">${esc(t.language.split(': ')[1])}</div>
      </div>`).join('')}
    </div>`,
  },
  {
    id: 'entry',
    css: (theme) => base(theme) + `
      .detail { padding: 54px 18px 0; }
      .back { color: ${palette[theme].secondary}; margin-bottom: 18px; font-size: 14px; }
      .text { font-size: 17px; line-height: 1.55; margin-top: 14px; }`,
    html: (t) => `<div class="app detail">
      <div class="back">‹ ${esc(t.back)}</div>
      <div class="small">${esc(t.dates[0])}</div>
      <div class="text">${esc(t.entries[0])}</div>
    </div>`,
  },
];
