# Phase 0 row 9 — Spike: protected PDF viewer (design)

Story: docs/15 §1 row 9 (SEC-02). Sources: `docs/02` SEC-02, CRS-02/05; `docs/04` S-17; `docs/05`
(PDF row, private `notes` / `book` buckets); `docs/06` `topic_assets.storage_path`; `docs/07` `pdf-url`.

## Goal
In about a day, prove that `pdfrx` shows a notes PDF on web and Android with a watermark of the
student's identity on every page. The PDF must come only from a short-lived (≤ 5 min) signed URL,
and the viewer must offer no download, print or copy. Find what breaks before the Notes story.

## Scope
**In:** `spikes/pdf-viewer/`:
- a Deno + Hono server shaped like the `api` `/pdf-url` route, plus a token-scoped file route
  that stands in for Supabase Storage signed URLs;
- optional server-side stamping with `pdf-lib`;
- a throwaway Flutter viewer;
- a Playwright web check;
- a runbook for Android.

**Out:**
- auth and access checks (stubbed with `x-spike-user`, as in the earlier spikes);
- the `notes` bucket and policies;
- `mark_notes_opened`;
- FLAG_SECURE (SEC-03);
- teacher upload (ADM-02).

## Questions
1. **Signed-URL expiry vs lazy loading.** Does pdfrx fetch parts of the file (range requests)
   after the document opens? If so, a 5-min URL breaks later page loads. Test with a 30 s TTL,
   then jump to the last page after expiry. Candidate fix: download once into memory and open
   from bytes.
2. **Disk cache.** Does pdfrx keep a copy of a URL-loaded PDF in the app cache (Android)?
3. **Per-page watermark** with `pageOverlaysBuilder`: name + short id, tiled, about 25 % opacity,
   staying correct at every zoom, never catching taps.
4. **No download / print / copy.** No toolbar actions, text selection off, context menu off.
5. **Web cost.** pdfrx renders with PDFium compiled to WASM. Measure its size and where it loads
   from.
6. **Server-side stamping.** A pdf-lib stamp written into the file makes a leaked PDF traceable,
   which the overlay alone cannot do. Measure time and memory for a 40-page PDF against Edge
   Function limits, then recommend overlay, stamp, or both.

## Success criteria
- Server tests cover: tokens (expiry, tamper), `no-store` and no `attachment` disposition, unknown
  asset, and a stamped file that carries the identity on every page.
- Web: first page renders with the watermark, and the last page still renders after the URL
  expired. Network shows a single PDF fetch.
- Stamping numbers are recorded.
- Android: runbook steps, with results filled in later by the developer.
