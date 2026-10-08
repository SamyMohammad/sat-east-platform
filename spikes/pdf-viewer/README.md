# Spike: protected PDF viewer (SEC-02, docs/15 §1 row 9)

Throwaway code. Findings: [`docs/spikes/2026-10-08-pdf-viewer.md`](../../docs/spikes/2026-10-08-pdf-viewer.md).
Not analysed by CI and not deployed. The Notes story (S-17) rebuilds it in `apps/client` and the
`api` `/pdf-url` route.

| Path | What |
|---|---|
| `server/app.ts` | `/pdf-url` + token-scoped file route (stand-in for Storage signed URLs, supports Range) |
| `server/stamp.ts` | optional server-side identity stamp (`@cantoo/pdf-lib`) + sample PDF generator |
| `server/app_test.ts` | 6 Deno tests |
| `player/` | Flutter app (web, Android, iOS): pdfrx 2.4.8, per-page watermark, memory vs URL loading |
| `e2e/web_e2e.mjs` | Playwright: open → wait past URL expiry → last page still renders |

## Run
```sh
# PowerShell: $env:NAME = "value" instead of export
export PDF_TOKEN_SECRET="<32+ random chars>"
TOKEN_TTL_S=20 deno run -A spikes/pdf-viewer/server/main.ts      # :8792, 40-page sample "notes1"
#   STAMP=1 → every copy carries the student's id inside the PDF
#   PDF_DIR=<folder> → serve your own <assetId>.pdf files (e.g. a real notes PDF)
deno test -A spikes/pdf-viewer/server/

cd spikes/pdf-viewer/player
flutter run -d chrome --web-port 8081
flutter run --dart-define=SERVER_URL=http://localhost:8792   # Android device, after: adb reverse tcp:8792 tcp:8792
```
Web query overrides: `?mode=memory|uri&jumpAfter=30&asset=notes1&user=Sara`.
On Android/iOS the mode is memory unless you change `loadFromMemory` in `main.dart`.

## Android checklist (fill in the findings doc table)
1. Notes open, and pages render sharply at 2–3× pinch zoom.
2. The watermark (the name, which can be Arabic, plus the short id) is on every page and scales
   with zoom. Taps and scrolling still work.
3. Wait longer than `TOKEN_TTL_S`, then scroll to the last page: it still renders.
4. Cache check: after viewing in **uri** mode, run
   `adb shell run-as com.satest.spike.pdf_spike find cache -name '*.pdf'` and note any file found.
   Repeat in **memory** mode. The expected result is a cached copy in uri mode and nothing in
   memory mode.
5. Long-press on text: nothing is selected and no copy menu appears.
6. Screen recording shows the page. This is expected, because FLAG_SECURE is SEC-03 and not part
   of this spike.
