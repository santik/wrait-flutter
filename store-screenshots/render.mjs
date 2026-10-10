// Renders HTML replicas of the Wrait screens inside a Pixel 9 Pro frame
// (https://sneas.github.io/telephone) for every locale in ./locales.
//
//   node render.mjs                 # all locales, all screens
//   node render.mjs de-DE ja-JP     # selected locales
//   SCREENS=main,entries node render.mjs
import { readdir, readFile, mkdir } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import { chromium } from 'playwright';
import { screens } from './screens.mjs';

const root = path.dirname(fileURLToPath(import.meta.url));
const telephoneJs = await readFile(
  path.join(root, 'node_modules/@sneas/telephone/pixel-9-pro.js'),
  'utf8',
);

// Final image: Play Store phone screenshot, 1080x1920.
const WIDTH = 1080;
const HEIGHT = 1920;
const THEME = process.env.THEME === 'dark' ? 'dark' : 'light';

const available = (await readdir(path.join(root, 'locales')))
  .filter((f) => f.endsWith('.json'))
  .map((f) => f.replace('.json', ''));
const wanted = process.argv.slice(2);
const locales = wanted.length ? wanted : available;
const only = process.env.SCREENS?.split(',');

const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: WIDTH, height: HEIGHT } });

for (const tag of locales) {
  const t = JSON.parse(await readFile(path.join(root, 'locales', `${tag}.json`), 'utf8'));
  const outDir = path.join(root, 'out', tag);
  await mkdir(outDir, { recursive: true });

  for (const [i, screen] of screens.entries()) {
    if (only && !only.includes(screen.id)) continue;
    const html = `<!doctype html>
<html lang="${t.lang}" dir="${t.dir}"><head><meta charset="utf-8">
<style>
  :root { color-scheme: ${THEME}; }
  * { box-sizing: border-box; }
  html, body { margin: 0; width: ${WIDTH}px; height: ${HEIGHT}px; }
  body { display: flex; flex-direction: column; align-items: center;
         background: ${THEME === 'dark' ? '#0F0F0D' : '#F0EDE8'};
         font-family: -apple-system, 'Segoe UI', Roboto, 'Noto Sans', 'Noto Sans CJK JP', 'Noto Sans CJK KR', sans-serif; }
  h1 { margin: 90px 70px 0; font-size: 68px; line-height: 1.15; font-weight: 700; text-align: center;
       color: ${THEME === 'dark' ? '#EDE9E3' : '#2C2B27'}; }
  pixel-9-pro { display: block; width: 740px; margin-top: 44px; }
  ${screen.css(THEME)}
</style>
</head>
<body>
  <h1>${t.captions[i] ?? ''}</h1>
  <pixel-9-pro mode="${THEME === 'dark' ? 'dark' : 'light'}">${screen.html(t, THEME)}</pixel-9-pro>
</body></html>`;
    await page.setContent(html, { waitUntil: 'load' });
    await page.addScriptTag({ content: telephoneJs });
    await page.evaluate(() => document.fonts.ready);
    const file = path.join(outDir, `${String(i + 1).padStart(2, '0')}-${screen.id}.png`);
    await page.screenshot({ path: file });
    console.log(file);
  }
}
await browser.close();
