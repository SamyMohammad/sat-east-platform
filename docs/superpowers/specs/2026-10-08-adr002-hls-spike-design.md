# Phase 0 row 7 — Spike: encrypted HLS (design)

Story: docs/15 §1 row 7 (ADR-002 action item 1). Sources: ADR-002, `docs/05` §5.2, `docs/06`
(`topic_assets`, `private.video_keys`), `docs/07` (`video-otp`), `docs/02` SEC-01.

## Goal
Prove, in about a day, that the free option in ADR-002 works: an AES-128 encrypted HLS video
plays on web (hls.js), Android and iOS (`video_player`), with a moving watermark, and the key is
only reachable through a short-lived signed URL from an Edge-Function-shaped server. Write down
what breaks, so SEC-01 is built on facts.

## Scope
**In:**
- `tools/video-pipeline/package.ts` (Deno, cross-platform): ffmpeg → 720p + 480p HLS, AES-128,
  one random key per video; optional upload to R2. The key never goes to R2.
- `spikes/video-hls/server/` — a local Deno + Hono server with the same shape as the future
  `api` Edge Function routes: `POST /video-otp`, then token-scoped playlist and key routes.
  Storage is `local` (a folder, for this sandbox and quick tests) or `r2` (presigned GET URLs).
- `spikes/video-hls/player/` — a throwaway Flutter app (web, Android, iOS) with a `VideoSource`
  interface, a moving watermark overlay and recovery from an expired URL.
- Findings + a runbook for the parts that need the developer's machine (R2 account, phones).

**Out:** auth and enrolment checks (stubbed: the caller names itself), `private.video_keys`
migration, App Check, FLAG_SECURE / iOS capture blur (SEC-03), progress tracking
(`save_video_progress`), teacher upload UI (ADM-02). All of these belong to SEC-01 / later stories.

The spike lives outside `apps/client` and `supabase/functions` on purpose: CI does not analyse it
and the staging deploy does not ship it.

## Decisions
1. **Token in the path.** `video-otp` returns `/v/<token>/master.m3u8`. The variant playlists and
   the key are relative URIs (`720p.m3u8`, `key`), so they inherit the token without rewriting.
   Token = base64url(`{a: assetId, u: userId, e: expiry}`) + `.` + HMAC-SHA256 with a server secret
   (`VIDEO_TOKEN_SECRET`). Stateless, no DB read per request.
2. **Only the key is the secret.** Segments are encrypted, so a segment URL is worthless without
   the key. Segment URLs are presigned R2 GETs with a long TTL (default 4 h, covers pauses);
   playlist and key URLs carry the short token (≤ 5 min, ADR-002). This is checked in the spike:
   what happens when the token expires mid-video (rendition switch, long pause)?
3. **Recovery on the client.** On a fatal player error the client calls `video-otp` again and
   resumes at the last position. One retry, then show an error.
4. **MPEG-TS segments, 6 s, IV = sequence number** (ffmpeg default). Most compatible across hls.js,
   ExoPlayer and AVPlayer.
5. **Web player:** `video_player` + `video_player_web_hls` (hls.js). The plugin was last published
   2024-08 — record whether it still works on Flutter 3.44; fallback is a small hls.js interop.
6. **Watermark** = Flutter overlay: name + short id, ~35 % opacity, jumps to a random position
   every 5 s, `IgnorePointer`. Full screen must be Flutter-level, never the `<video>` element's own
   full screen, or the overlay is lost.
7. **Tunables** (token TTL, segment TTL, watermark interval) are server/client config in the spike;
   SEC-01 moves them to `settings` (rule 5).

## Success criteria
- Encrypted segments do not decode without the key (ffprobe fails on a raw segment).
- Web: video plays in Chromium; key and playlists fetched with a valid token; tampered or expired
  token → 403; watermark visible and moving.
- Server unit tests: token sign/verify/expiry/tamper, playlist rewrite.
- Android / iOS / real R2: runbook steps the developer runs; results go into the findings doc.
