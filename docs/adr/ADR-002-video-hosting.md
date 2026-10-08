# ADR-002: Video hosting and protection

**Status:** Proposed (revised 2026-10-06) · **Deciders:** Teacher (cost / risk), Developer

## Context
Paid course videos are the main leak risk. Needs: protected streaming, per-student watermark,
playback on Flutter web/Android/iOS — and, for launch, **near-zero cost** (budget constraint).
YouTube (unlisted) and Google Drive were rejected: links are shareable, no per-user watermark,
Drive is not built for streaming at scale and allows download.

## Decision
**Phase 1 (MVP + beta): self-built protection** — encrypted HLS on Cloudflare R2.
**Upgrade path:** VdoCipher (or Bunny Stream DRM) behind the same client interface, switched on
when leaks appear or revenue justifies it.

### Self-built design
| Layer | How |
|-------|-----|
| Packaging | `ffmpeg` → HLS (720p + 480p renditions), **AES-128** segment encryption, one key per video. Script in `tools/video-pipeline/`. |
| Storage / delivery | **Cloudflare R2** (10 GB free, **zero egress fees**), private bucket. |
| Access | `video-otp` route (Edge Function `api`) checks enrollment + access window, returns short-lived (≤ 5 min) signed playlist URL + key URL. Keys stored in `private.video_keys`, never in R2. |
| Watermark | Flutter overlay: student name + phone/short id, moving position every few seconds, semi-transparent. |
| Capture blocking | Android `FLAG_SECURE`; iOS capture detection → blur (SEC-03). |
| Players | `video_player` (ExoPlayer / AVPlayer) on mobile; `hls.js` on web (Safari native HLS). |
| Sharing | Device limit (AUTH-04). |

Client code depends only on a `VideoSource` interface (`getPlayback(assetId) → PlaybackInfo`);
`R2HlsVideoSource` now, `VdoCipherVideoSource` later — swapping is one data-source change.

## Options considered
| Option | Cost | Protection | Notes |
|---|---|---|---|
| **Self-built AES-128 HLS on R2 (chosen for MVP)** | ≈ $0–1 / month | Medium | Strong on mobile (FLAG_SECURE); weak on web — see consequences |
| VdoCipher (upgrade path) | Annual plan | Strong: Widevine/FairPlay DRM + built-in dynamic watermark | Common in MENA ed-tech |
| Bunny Stream | Pay per GB, low | Token auth + optional DRM | Watermark needs custom overlay |
| Self-hosted Widevine/FairPlay | Free licences but… | Strong | Needs Google/Apple approval + licence servers — not realistic for a solo dev |

## Consequences
- **Known weakness (teacher must accept):** on the **web**, a technical user can extract the AES key
  from dev tools and download the video. A downloaded file has **no watermark** (it is an overlay),
  so a leak cannot be traced to a student. On **mobile**, protection is close to the DRM option.
- Encryption + watermark + device limit deter the large majority of students; the residual risk is
  accepted for launch and re-evaluated after the beta (track as R-04).
- Cloudflare's terms for serving video from R2 must be confirmed during the spike.
- Costs scale with storage only (egress is free) — monitor monthly.

## Spike results (2026-10-08)
Findings: [`docs/spikes/2026-10-08-encrypted-hls.md`](../spikes/2026-10-08-encrypted-hls.md).
Web is proven. Android, iOS and real R2 are still open. Changes to the design above:
- **Web player:** own `dart:js_interop` wrapper around a self-hosted hls.js, not
  `video_player_web_hls`. That plugin swallows fatal errors in release builds and hides the
  hls.js config.
- **TTLs:** the key URL stays ≤ 5 min. Playlist URLs live for the session, because a 5 min
  playlist token blocks ABR switching. Segment URLs are presigned for about 4 h; they are
  encrypted, so they hold no secret.
- **Access:** `video-otp` returns `/v/<token>/master.m3u8`. Playlists and the key resolve
  relative to it. `api` runs with `verify_jwt = false` and checks auth per route.
- **Client:** a stall watchdog plus a fresh `video-otp` call resumes playback at the last position.

## Action items
1. [~] Spike (1 day): encrypted HLS from R2 playing on web (hls.js), Android and iOS, with the
       watermark overlay and a signed key URL from a local Edge Function. **Web done. Devices and
       R2: run `spikes/video-hls/README.md` §2–3.**
2. [ ] Teacher: accept the web-download risk in writing, or fund VdoCipher from launch.
3. [ ] Naming convention for uploads: `SAT_T05_Linear_03_Parallel-Perpendicular.mp4`.
