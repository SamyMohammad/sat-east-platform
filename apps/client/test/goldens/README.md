# Component goldens

Baselines use Flutter 3.44.1 on Windows and the bundled Noto, Material Icons
and KaTeX fonts. Run from `apps/client/`:

```powershell
flutter test test/goldens --tags golden
flutter test --exclude-tags golden
```

For an intentional visual change, regenerate on Windows and inspect every
changed PNG before committing:

```powershell
flutter test test/goldens --update-goldens --tags golden
```

The 52 baselines cover answer inputs plus controls, statuses and overlays
at 360 and 1280 pixels, light/dark themes, and 360-pixel 2× text variants.
Shell captures use the full viewport at 360, 768 and 1280 pixels, including
2× text and focus mode without destination navigation. QuestionView captures
(practice idle, first miss, correct, revealed, homework) use the full
viewport at 360 and 1280 pixels, plus a 360-pixel 2× text first-miss.
Feedback sheets sample animations after 180 ms, then stop decorative tickers
to compare a visible, deterministic loading phase. Linux CI excludes the
`golden` tag because font rasterisation differs between platforms.
