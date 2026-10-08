# Spike findings: protected PDF viewer (SEC-02)

Date: 2026-10-08 · docs/15 §1 row 9 · Design: `docs/superpowers/specs/2026-10-08-sec02-pdf-spike-design.md`
Code: `spikes/pdf-viewer/` (runbook in its README).

## Verdict
**Web works.** pdfrx 2.4.8 renders a 40-page notes PDF in Chrome. A watermark with the student's
identity sits on every page, and an Arabic name is shaped correctly. Text selection is off. After
the 20 s signed URL expired, the last page still rendered, because the file was fetched once.
**Android and iOS are not run yet.** The runbook is ready; the most important open check is the
cache (see finding 1). pdfrx stays the choice, with the changes below.

## Platform results
| Check | Web (Chrome 141) | Android | iOS |
|---|---|---|---|
| Renders, sharp at zoom | ✅ | ⬜ | ⬜ |
| Watermark on every page, Arabic shaped, taps pass through | ✅ (3 widget tests) | ⬜ | ⬜ |
| Last page renders after URL expiry | ✅ memory and uri mode | ⬜ | ⬜ |
| No text selection / copy | ✅ | ⬜ | ⬜ |
| No PDF copy in app cache (memory mode) | n/a | ⬜ | ⬜ |
| Screen recording | n/a | ⬜ (expect visible, SEC-03) | ⬜ |

## Findings that change the plan
1. **Open from memory, never from the URL.** In pdfrx's source
   (`pdfrx_engine/lib/src/native/pdf_file_cache.dart`), `PdfViewer.uri` on Android and iOS
   writes the PDF to `<app cache>/pdfrx.cache/…/<hash>.pdf`. That is a plain, unwatermarked copy
   of the notes on the device. Because every signed URL is different, it also leaves a new file
   on every open.
   **→ The Notes story downloads the bytes once while the URL is valid, then calls
   `PdfViewer.data`.** This also settles the expiry question on every platform: nothing is fetched
   after the file opens. On web, uri mode made a single full GET as well (no range requests by
   default), but memory mode keeps all platforms the same.
2. **pdfrx's latest version (2.6.x) needs Flutter ≥ 3.47.** We are pinned to 3.44.1 (CI), so we
   use 2.4.8 for now. Raise this at the next Flutter upgrade. 2.4.8 already has everything the
   spike needed.
3. **Web cost: `pdfium.wasm` is 5.2 MB** (uncompressed), plus its worker JS. It ships inside the
   app bundle (`assets/packages/pdfrx/`), with no CDN, and the browser fetches it only when a
   viewer first opens. Cloudflare Pages compresses it. For the first-load budget, keep the Notes
   route lazy (a deferred import) so the landing page never loads it.
4. **Server-side stamp is cheap and closes the "downloaded copy" gap.** With the
   `@cantoo/pdf-lib` fork (the original `pdf-lib` was last published in 2021), a light stamp (one
   diagonal id + a footer line per page) took **38 ms** on a 40-page scanned PDF (4.3 MB → 4.3 MB).
   A tiled stamp took 140 ms on the same file. On text PDFs the tiled stamp grows the file about
   5×. A 150-page tiled stamp reached 335 MB RSS, which risks the Edge Function memory limit.
   **→ Recommendation: overlay always (in the app), plus a light server stamp for the book
   (CRS-05) and for any PDF that leaks.** The stamp needs the Edge Function to stream the bytes
   (a token route like this spike's) instead of returning a Storage signed URL. That costs EF
   egress, so measure it before turning the stamp on for all notes.
5. **The stamp cannot carry Arabic names.** The standard PDF fonts cover Latin only, and the fork
   *silently* writes unsupported characters as `?`. The spike now refuses non-ASCII text, so the
   stamp uses the short id (and later the phone tail), never the name. The in-app overlay shows
   the name.

## Smaller notes
- Watermark: `pageOverlaysBuilder` draws in page coordinates, so it zooms and scrolls with the
  page. The font size follows the page width. 25 % grey is readable on white pages without
  hiding the content. Check it on real scanned notes.
- Real Supabase Storage supports Range and sets its own cache headers. Our stand-in returns
  `cache-control: no-store` and no `attachment` disposition. Check what Storage sends in the
  Notes story. With memory loading, nothing depends on Range.
- The web leak risk matches ADR-002. Anyone with dev tools can save the PDF from the network
  tab, and finding 4 is the only mitigation that survives that.
- Spike-only: custom HTTP headers cannot carry Arabic (`x-spike-user`). The real app identifies
  the user by JWT, and the name comes back in the JSON body.

## Next
1. Developer: Android checklist (README). The cache check (item 4) confirms finding 1 on a device.
2. Notes story (S-17, SEC-02):
   - `pdf-url` in `api`, with `has_access_topic` and a 5-min signed URL;
   - memory loading;
   - per-page overlay;
   - lazy Notes route on web;
   - `mark_notes_opened`.
   - Decide on the server stamp for the book (CRS-05).
