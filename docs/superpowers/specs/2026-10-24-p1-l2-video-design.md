# L-2 — protected video on R2 (SEC-01, LRN-02, C-2) — design

> Status: draft · 2026-10-24 · Branch `feat/P1-l2-video`
> The user skipped the question round ("ابدأ"). **user** marks the decisions the user made earlier in this conversation; everything else is the router's call.

## Intent

Students watch each topic's video inside the app, protected (an encrypted HLS stream with a moving watermark), with their progress saved. Watching the video becomes the first step on the topic path (LRN-01/02: Video → Notes → Practice). The teacher pays nothing for hosting.

## Inputs already settled

- **user: Cloudflare R2 free tier**, so the teacher never pays.
  - The `videos` bucket exists (private, Western Europe). The secrets `R2_ACCOUNT_ID`, `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY` and `R2_BUCKET` are set on staging.
  - **The app enforces a cap of `settings.video_storage_cap_mb` (9216, i.e. 9 GB)**, so the free 10 GB can never be exceeded.
  - **540p** is the only rendition, to stay small (about 270 MB per hour).
- **user: the free intro video (topic 1.1) goes on YouTube unlisted**, so it uses no R2 space. A video asset can be `provider = 'youtube'` (embed) or `provider = 'r2_hls'` (protected).
- **Spike** (`docs/spikes/2026-10-08-encrypted-hls.md`, ADR-002):
  - AES-128 HLS, with one random key per video, packaged by `ffmpeg` (`tools/video-pipeline/package.ts`).
  - The token sits in the path: `/v/<token>/master.m3u8`. Variant playlists and the key are relative; only the segment lines are rewritten to presigned R2 URLs.
  - **Split TTLs**: the key route ≤ 5 min (`settings.video_key_ttl_s` = 300); playlists and segments last the session (`settings.video_playlist_ttl_s` = 14400).
  - The key comes from `private.video_keys` through a `security definer` RPC that **only `service_role`** can execute.
  - **Web: our own small `dart:js_interop` wrapper around a self-hosted, pinned `hls.js` (1.7.3)**, because `video_player_web_hls` swallows errors and leaves picture-in-picture enabled. The stall watchdog plus re-OTP recovery stays.
  - Fullscreen is app-level, so the overlay survives. The watermark gets an outline or shadow so it stays readable on bright frames.
  - The `api` Edge Function uses `verify_jwt = false`, and each route checks its own auth.
- **Existing tables**:
  - `topic_assets` (kind `video`, `video_provider_id`, `duration_s`, `subtopic_id`);
  - `video_progress(watched_ranges int4range[], pct, last_position_s)`;
  - `video_chapters`;
  - `settings.video_done_pct` = 80.

## Goals

1. **Packaging and upload are local, by the developer or teacher (router's call; there is no free cloud transcoding).** A command `deno task video:publish --topic <id> [--subtopic <id>] --title "…" <file.mp4>`:
   - packages 540p encrypted HLS (an evolution of `package.ts`);
   - **checks the cap first**, through `teacher_video_quota()`;
   - uploads the output to `videos/<asset_id>/…` with the S3 API, using the R2 keys from the operator's **local env, never committed**;
   - registers the asset with `teacher_register_video(…)` (which stores the key through a service-role-only path);
   - prints the asset id.
   It runs with a teacher's Supabase session (it signs in interactively) or with the service role locally. Its README covers installing `ffmpeg`.
2. **Server.**
   - `private.video_keys(asset_id, key bytea, iv bytea)`.
   - RPCs:
     - `teacher_video_quota()` → `{used_mb, cap_mb}`;
     - `teacher_register_video(topic_id, subtopic_id?, title, duration_s, size_mb, key_hex, iv_hex)`. It is teacher-only, **refuses past the cap**, and writes the key into `private` and the asset with `provider='r2_hls'`, `ready=true`;
     - `teacher_add_youtube_video(topic_id, subtopic_id?, title, youtube_id, duration_s)`;
     - `teacher_delete_video(asset_id)`;
     - `private.get_video_key(asset_id)`, executable by **service_role only**.
   - **`api` Edge Function routes:**
     - `POST /video-otp {asset_id}` checks the JWT, enrolment, the open topic and the device. It returns `{hls_url: '/v/<token>/master.m3u8', watermark: {name, short_id}}`.
     - `GET /v/<token>/master.m3u8`, the variant playlists (segments rewritten to presigned URLs), and `/v/<token>/key` (`cache-control: no-store`).
     - The token is an HMAC from an EF secret `VIDEO_TOKEN_SECRET`. **The router generates it with a random generator and the user pastes it into Supabase secrets.** It is the same kind of step as the R2 keys.
   - `save_video_progress(asset_id, from_s, to_s, position_s)` merges the watched ranges server-side and computes `pct` from `duration_s`. The client never sends `pct`.
   - **Video gate:** `private.notes_satisfied`'s sibling `private.video_satisfied(uid, topic)` is true when the topic has no ready video, or every ready video has `pct ≥ video_done_pct`, or the student has finished (the same exemption as notes: `practice_count ≥ practice_min` or the quiz passed). Notes and practice require the video step first: `get_topic` adds `videos`/`video_done`, and the notes step shows "Watch the video first." when it isn't done.
3. **Client** (web first; mobile later):
   - A **Video** step on the topic page before Notes.
   - `VideoPlayerScreen` (deferred import, like notes):
     - for R2, the hls.js interop with our controls (play/pause, seek, speed 1×/1.25×/1.5×, app-level fullscreen);
     - a **moving watermark** (name · short id) with an outline;
     - progress sent every 15 s and on pause/leave;
     - resume at `last_position_s`;
     - for YouTube, the `youtube_player_iframe` embed (or an `iframe` via `HtmlElementView`; the builder picks the lighter option with justification).
   - Seeking forward past unwatched parts is allowed (`pct` counts only watched ranges).
4. **Teacher UI:** the topic row menu gets **"Videos…"**. It lists the videos (title, duration, size, provider), and lets the teacher add a YouTube video, rename, reorder and delete. It also shows the **storage meter** ("3.2 of 9 GB used"). Uploading R2 videos stays in the CLI, so the screen says "Upload with the video tool".

## Non-goals

- In-browser upload or transcoding of R2 videos.
- Multiple renditions or ABR (540p only).
- Video chapters UI (CRS-04).
- Android/iOS players, FLAG_SECURE (SEC-03).
- DRM.
- Server-side watermark burn-in.

## Anti-goals

- A key reaching anyone without a valid short-lived token. Students never call `private.get_video_key`; the EF uses the service role.
- **An R2 bill above $0.** The cap is checked server-side at register time, and the CLI checks it before uploading.
- R2 keys or `VIDEO_TOKEN_SECRET` landing in the repo, the client bundle or logs.
- The progress `pct` being trusted from the client.
- A student without access getting a playable URL (pgTAP + Deno tests).

## Decisions (router's calls)

| # | Decision |
|---|----------|
| D1 | `topic_assets` gains `provider text check in ('r2_hls','youtube')`, `size_mb int`, `ready` (exists since L-3). `video_provider_id` holds the YouTube id for `youtube`. |
| D2 | New settings: `video_storage_cap_mb` 9216, `video_key_ttl_s` 300, `video_playlist_ttl_s` 14400, `video_progress_interval_s` 15. |
| D3 | The **new EF secret `VIDEO_TOKEN_SECRET`** (32 random bytes, base64) is generated by the router locally and shown to the user once, to paste into Supabase secrets. It is never committed. |
| D4 | Video gate is like notes: steps go Video → Notes → Practice, and finished students are exempt. A topic with no video skips the step, so the demo topics keep working. |
| D5 | Delivery in **3 PRs**, each a draft until CI is green: **L-2a** server (migration, RPCs, EF routes, Deno + pgTAP tests); **L-2b** the CLI (`tools/video-pipeline`), tested on a 30 s sample clip against staging; **L-2c** the client (Video step, player, watermark, progress, teacher Videos screen). |
| D6 | The staging check uses a **sample clip** (CC0, a few MB) until the teacher sends real videos. The teacher's own answers are on the decisions board (Q-12 segmentation). |

## Constraints

- CLAUDE.md rules 1–10, A, B; `docs/16` §2; SQL from templates; the EF template; pgTAP's `reset role` rule; no `$$` inside function bodies; no `dart:html` (use `package:web` + `dart:js_interop`).
- Deno tests for the EF:
  - a tampered, expired or wrong-kind token → 403;
  - a segment token can't open the key;
  - the key is served with `no-store`;
  - path traversal is refused;
  - `/video-otp` refuses no access, a locked topic, an unready asset, and the YouTube provider (it returns the embed id instead).
- pgTAP:
  - the cap refusal;
  - only `service_role` can run `get_video_key`;
  - range merging in `save_video_progress` and the pct;
  - the video gate and its exemption;
  - teacher RPCs are `forbidden` for students.

## Left to the builder

- The player controls' layout, following `Learning Path.dc.html` / `Content and Help.dc.html`.
- The watermark motion pattern: a slow drift, repositioned every N seconds, from settings.
- Whether the CLI signs in with an email OTP or a local service-role key; it should be documented either way.
