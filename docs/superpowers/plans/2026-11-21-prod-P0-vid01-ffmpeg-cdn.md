# Prod P0 — VID-01: ffmpeg core from jsDelivr with SHA-256 check

Spec: [prod readiness](../specs/2026-11-21-prod-readiness-design.md) §P0.

**Why:** `apps/client/web/vendor/ffmpeg-core-0.12.10/ffmpeg-core.wasm` is 32,232,419 bytes, which is over Cloudflare Pages' 25 MiB per-file limit, so the staging/prod web deploy would fail. Serve the unmodified upstream build from jsDelivr instead and verify its bytes before use.

Pinned sources (verified 2026-11-21; each one is byte-identical to the vendored copy):

| File | URL | SHA-256 |
|------|-----|---------|
| core JS (UMD) | `https://cdn.jsdelivr.net/npm/@ffmpeg/core@0.12.10/dist/umd/ffmpeg-core.js` | `b266ab5b952555881dd6310663986994a182acb2b7ff25cf10a25f7a37ac2b21` |
| core wasm | `https://cdn.jsdelivr.net/npm/@ffmpeg/core@0.12.10/dist/umd/ffmpeg-core.wasm` | `9f57947a5bd530d8f00c5b3f2cb2a3492faa7e5d823315342d6a8656d0a6b7b7` |

The `@ffmpeg/ffmpeg` wrapper (`web/vendor/ffmpeg-0.12.15/`) stays self-hosted. It is small and same-origin.

## Task 1 — load the core from the CDN, verify, blob URL
Files: `apps/client/lib/features/teacher/videos/data/services/video_transcoder_web.dart` (`_coreScript`/`_coreWasm`, `load(...)` around line 171), `apps/client/lib/core/errors/error_codes.dart`, `docs/07-backend-logic-and-api.md` §9.
- Replace the two vendor paths with the two URLs and hashes above. Put the constants in one place in the data layer, next to the existing ones.
- Before `ffmpeg.load`, fetch each file and compute SHA-256 with `crypto.subtle.digest` (via `dart:js_interop` / `package:web`; no new package). Compare it with the constant, then create a `Blob` URL (`URL.createObjectURL`) and pass the blob URLs as `coreURL`/`wasmURL`. Revoke the blob URLs after load completes or fails.
- On a network failure or a hash mismatch, throw/map to `AppError` with the new code `video_engine_load_failed`. Add it to `error_codes.dart`, add a row to `docs/07` §9 and add English copy in `teacher_videos_copy.dart` ("Couldn't load the video tools. Check your connection and try again."). Never surface raw exception text.
- Pull the hash comparison into a pure Dart function (bytes → hex → equals) so it can be unit-tested without a browser.
- Tests first: unit-test the pure hash-compare helper (match, mismatch, case), and test that the cubit/repository maps `video_engine_load_failed` to the copy, following the existing teacher videos tests.

## Task 2 — remove the vendored core, docs
- Delete `apps/client/web/vendor/ffmpeg-core-0.12.10/` (both files). Leave `ffmpeg-0.12.15/`, `hls-*`, `posthog-*` in place.
- Update the comment at `video_transcoder_web.dart:15`: core from pinned jsDelivr plus a SHA-256 check, wrapper self-hosted, single-thread (no COOP/COEP).
- Add a short GPL note to `docs/adr/ADR-002-video-hosting.md`: the client loads the unmodified LGPL/GPL `@ffmpeg/core@0.12.10` from jsDelivr. Upstream source: github.com/ffmpegwasm/ffmpeg.wasm (tag v0.12.10). We neither modify it nor redistribute it from our origin.
- If a CSP or `_headers` exists, note it in the report. CSP itself is P3, not this task.

## Out of scope
CSP/_headers (P3), R2 CORS and the staging migration (owner/router, STATUS VID-01), anything in `apps/client/lib/shared/widgets/spr_input.dart` or the golden `failures/` images (unrelated, uncommitted work in the tree; don't touch it or commit it).

## Gates (run from `apps/client/`)
`dart format .` · `flutter analyze --fatal-infos` · `flutter test -j 2 test/features/teacher/videos test/core` · `flutter build web --release --dart-define-from-file=env/ci.json` (create a placeholder env as in `ci.yml` if one is missing), then `find build/web -size +25M` must print nothing.

## Router after merge-ready
Squash the branch's local commits so the 32 MB wasm never reaches GitHub (the branch is unpushed), then rebase on `origin/main` (MCK-09 merged), push, open the PR and do the manual browser upload check on staging.
