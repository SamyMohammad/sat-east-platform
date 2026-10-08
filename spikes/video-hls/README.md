# Spike: encrypted HLS (ADR-002, docs/15 §1 row 7)

Throwaway code. Findings: [`docs/spikes/2026-10-08-encrypted-hls.md`](../../docs/spikes/2026-10-08-encrypted-hls.md).
Not analysed by CI and not deployed. SEC-01 rebuilds the parts worth keeping in `apps/client` and
the `api` Edge Function.

| Folder | What |
|---|---|
| `../../tools/video-pipeline/package.ts` | ffmpeg → AES-128 HLS (720p + 480p), one key per video, optional R2 upload |
| `server/` | Deno + Hono stand-in for the `api` Edge Function video routes |
| `player/` | Flutter app (web, Android, iOS): `VideoSource`, moving watermark, stall recovery |
| `e2e/web_e2e.mjs` | Playwright checks on web: `play`, `recover`, `expire` |

Needs: ffmpeg, Deno 2, Flutter 3.44.1, Node 22 + Playwright (web checks only).

## 1. Package a video
```sh
deno run -A tools/video-pipeline/package.ts my-video.mp4 demo1 --out out/videos
```
Writes `out/videos/demo1/` (playlists + encrypted segments) and `out/videos/demo1.key.hex`.
`out/` is git-ignored. Never commit or upload a `.key.hex`.

## 2. Run the server
```sh
# PowerShell: $env:VIDEO_TOKEN_SECRET = "<32+ random chars>"
export VIDEO_TOKEN_SECRET="<32+ random chars>"
deno run -A spikes/video-hls/server/main.ts        # local storage, serves out/videos on :8787
deno test -A spikes/video-hls/server/              # unit tests
```
Options: `TOKEN_TTL_S` (300), `SEGMENT_TTL_S` (14400), `PORT` (8787), `KEYS_DIR`, `VIDEOS_DIR`.

### With Cloudflare R2 (the real target)
1. Cloudflare dashboard → R2 → create a **private** bucket, e.g. `sat-videos-dev`.
2. R2 → Manage API tokens → token with **Object Read & Write** on that bucket only.
3. Bucket → Settings → CORS policy (hls.js fetches segments with XHR from the web app origin):
   ```json
   [{ "AllowedOrigins": ["http://localhost:8080"], "AllowedMethods": ["GET", "HEAD"],
      "AllowedHeaders": ["*"], "MaxAgeSeconds": 3600 }]
   ```
4. Upload and serve:
   ```sh
   export R2_ACCOUNT_ID=... R2_ACCESS_KEY_ID=... R2_SECRET_ACCESS_KEY=... R2_BUCKET=sat-videos-dev
   deno run -A tools/video-pipeline/package.ts my-video.mp4 demo1 --out out/videos --upload
   STORAGE=r2 KEYS_DIR=out/videos deno run -A spikes/video-hls/server/main.ts
   ```
   These R2 values stay in your shell (later: Edge Function secrets). Never in `env/*.json`.

## 3. Run the player
```sh
cd spikes/video-hls/player
flutter run -d chrome --web-port 8080                          # web
flutter run --dart-define=SERVER_URL=http://<PC LAN IP>:8787   # Android / iOS device on the same Wi-Fi
```
Android emulator: `SERVER_URL=http://10.0.2.2:8787`. iOS simulator: `http://localhost:8787`.
Web query overrides: `?asset=demo1&user=Sara&autoplay=1&server=http://localhost:8787`.

**Device checklist** (write results into the findings doc, table "Platform results"):
1. Video plays, sound works, 720p picked on good Wi-Fi.
2. Watermark visible over the video and jumps every 5 s.
3. Pause 6 min (longer than `TOKEN_TTL_S`), resume → keeps playing.
4. Stop the server for 15 s mid-play, start it again → the app recovers at the same position
   (log line `recovering at …`).
5. Screen recording: Android shows the video (no FLAG_SECURE yet, SEC-03); note what iOS does.

## 4. Web checks (Playwright)
```sh
cd spikes/video-hls/player && flutter build web --release
npx http-server build/web -p 8080 -s &
node spikes/video-hls/e2e/web_e2e.mjs play .     # also: recover (asset ≥ 3 min), expire (server with TOKEN_TTL_S=15)
```
Use Chrome, not the Playwright Chromium build: Chromium has no H.264 in MSE. Set `CHROME=<path>`.
