# Store screenshots

Generates localized Play Store screenshots: HTML replicas of the app screens
rendered inside a Pixel 9 Pro frame by [Telephone](https://sneas.github.io/telephone),
with a caption on top. Output is 1080x1920 PNG per locale/screen. No emulator or
Flutter build needed.

```bash
cd store-screenshots
npm install
npx playwright install chromium   # first time only

npm run screenshots               # all locales
node render.mjs de-DE ja-JP       # selected locales
SCREENS=main,entries npm run screenshots
THEME=dark npm run screenshots
```

Results land in `out/<locale>/01-main.png`, `02-entries.png`, `03-entry.png`
(git-ignored). Locale folder names match `app-listings/`-style tags.

## Adding a language

Copy `locales/en-US.json` to `locales/<tag>.json` and translate: UI strings
(copy them from `lib/l10n/app_*.arb` where available), three sample entries,
and the three captions (one per screen, in order).

## Changing screens

`screens.mjs` holds the HTML/CSS for each screen. Colors mirror
`lib/presentation/theme/wrait_colors.dart`; update both if the theme changes.
These are replicas, so re-check them against the real app after UI changes.
