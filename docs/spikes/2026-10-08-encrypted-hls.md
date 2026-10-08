# Spike findings: encrypted HLS (ADR-002)

Date: 2026-10-08 · docs/15 §1 row 7 · Design: `docs/superpowers/specs/2026-10-08-adr002-hls-spike-design.md`
Code: `tools/video-pipeline/`, `spikes/video-hls/` (runbook in its README).

## Verdict
**Web: works.** AES-128 HLS packaged by ffmpeg plays in Chrome through hls.js inside Flutter
`video_player`, with the key served only through a short-lived signed URL and a moving watermark.
**Android, iOS and real R2: not run yet.** They need the developer's machine, phones and a
Cloudflare account (runbook in `spikes/video-hls/README.md`). The free option in ADR-002 stays
viable. Three changes are needed before SEC-01 (below).

## Platform results
| Check | Web (Chrome 141, sandbox) | Android | iOS |
|---|---|---|---|
| Plays encrypted HLS, 720p | ✅ | ⬜ to run | ⬜ to run |
| Key fetched once, with token | ✅ | ⬜ | ⬜ |
| Watermark visible + moving | ✅ (see below: low contrast on bright frames) | ⬜ | ⬜ |
| Resume after segment URLs fail (pause > TTL) | ✅ via stall watchdog, resumed at 17 s | ⬜ | ⬜ |
| Down-switch to 480p after token expiry | ❌ 403, stays on 720p (finding 2) | ⬜ | ⬜ |
| Real R2 presigned segments + CORS | ⬜ (URL shape checked offline only) | ⬜ | ⬜ |

## What was proven
1. **Packaging.** `package.ts` makes 720p + 480p with one random 16-byte key per video in 12 s for
   a 40 s clip on 4 cores. A raw segment does not decode (`ffprobe`: *Invalid data*), and it decodes
   with the key. The key file is written next to, never inside, the upload folder.
2. **Token-in-path design works.** `video-otp` returns `/v/<token>/master.m3u8`. The variant
   playlists and the key are relative URIs, so the players resolve them under the same token with
   no rewriting. Only segment lines are rewritten to signed URLs.
3. **Server checks** (7 Deno tests): tampered, expired or wrong-kind token → 403, and a segment
   token cannot open the key. That last case was a real bug in the first draft, fixed by adding a
   token kind. The key is sent with `cache-control: no-store`. Path traversal in playlists is refused.
4. **Recovery.** When segment URLs start failing (403 from segment #3), the app calls `video-otp`
   again and resumes at the last position.

## Findings that change the plan
1. **`video_player_web_hls` 1.3.0 swallows fatal errors in release builds.** Its `ErrorData`
   parser does dynamic access on a `JSObject` and throws (`NoSuchMethodError … gjk`). So
   `VideoPlayerController` never gets `hasError`, and a dead stream just stalls. The package was
   last published 2024-08. It also gives no access to the hls.js config (retry policy, buffer
   size), and it leaves Picture-in-Picture enabled (`disablePictureInPicture` is set only when
   native controls are on).
   **→ SEC-01: own web implementation, a small `dart:js_interop` wrapper around hls.js**
   (`Hls.Events.ERROR` → our error stream, our config, `disablePictureInPicture = true`). Until
   then, the stall watchdog in the spike works on all platforms, and SEC-01 keeps it as a safety net.
2. **Short playlist TTL breaks ABR.** After the 5 min token expires, hls.js cannot load the other
   rendition's playlist (403, non-fatal), so a student on a slow line stays stuck on 720p and
   buffers. **→ Split the TTLs:** the key route keeps ≤ 5 min. Playlists only hold signed,
   encrypted segment URLs, so they can live for the session (e.g. 4 h). Use one token with two
   expiries (`ek` for the key, `ep` for playlists). Both renditions use the same key URI, so the
   players should reuse the cached key on a switch. This is not verified yet: check it in SEC-01
   on web and devices.
3. **hls.js buffers far ahead.** It pulled about 150 s of video in 4 s on a fast line. That is
   fine for UX. But segment-URL expiry only hurts after long pauses, so the 4 h segment TTL
   covers normal use and the recovery path covers the rest.
4. **Edge Function auth for player requests.** hls.js, ExoPlayer and AVPlayer fetch playlists
   and the key **without** an `Authorization` header, so the token in the path is the only auth.
   The `api` function needs `verify_jwt = false` in `supabase/config.toml`, and every route
   checks auth itself: `verifyAuth` for `/video-otp`, the token for `/v/*`. That already matches
   the EF template.
5. **Self-host hls.js.** Bundle it in `web/` (pinned, 1.7.3 used here) rather than loading it
   from a CDN. No third-party script at runtime, and it fits a future CSP.
6. **Keys from `private.video_keys`.** The EF cannot read the `private` schema over PostgREST.
   SEC-01 needs a `security definer` RPC that only `service_role` can execute, plus a pgTAP test
   that `authenticated` cannot call it.

## Smaller notes
- ffmpeg writes one explicit IV (`0x0…0`) for all segments of a rendition. With one key per
  video, this leaks only whether two segments start with identical blocks (TS headers, which are
  public anyway). Acceptable. SEC-01 may write a random IV per video into the key-info file.
- Watermark at 35 % white is hard to read on bright or yellow frames. Use a dark outline or
  shadow, or alternate light and dark. Recorded lectures are mostly a whiteboard or tablet, so
  check on real content.
- Full screen must be app-level (the whole Flutter view), never the `<video>` element's own full
  screen, or the overlay is lost. `controls = false` and the context menu blocked help here.
- Web leak risk is as written in ADR-002. Anyone who opens dev tools sees the key response and
  can download the stream. Nothing found changes that.
- Cloudflare terms: since the 2023 update, video served through the CDN is allowed when it is
  hosted on a Cloudflare service such as R2 ([Cloudflare blog](https://blog.cloudflare.com/updated-tos/)).
  Presigned `r2.cloudflarestorage.com` URLs bypass the CDN entirely, so the clause is moot for
  this design. Re-read the current Service-Specific Terms before launch.
- Sandbox-only issues (not product issues): Playwright's Chromium has no H.264, so use Chrome.
  The CanvasKit CDN was blocked here, so build with `--no-web-resources-cdn`.

## Next
1. Developer: run the device checklist (README §3) on one Android phone and one iPhone, plus the
   R2 path (README §2). Fill in the table above.
2. Teacher: ADR-002 action item 2 (accept the web-download risk, or fund VdoCipher).
3. SEC-01 story: `private.video_keys` + RPC, `/video-otp` in `api`, split TTLs, hls.js interop,
   `VideoSource` in `apps/client` (Cubit per ADR-007), tunables in `settings`.
