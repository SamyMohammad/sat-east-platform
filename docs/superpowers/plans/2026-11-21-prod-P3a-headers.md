# Prod P3a: security and cache headers (CSP report-only) + NFR-07 client test

Spec: [prod readiness](../specs/2026-11-21-prod-readiness-design.md) §P3.1, §P3.6, §P5.1. Both apps deploy to Cloudflare Pages, which reads a `_headers` file from the output root. Flutter copies `apps/client/web/*` into `build/web`.

## Task 1: `apps/client/web/_headers`
Security headers on `/*`:
- `Strict-Transport-Security: max-age=31536000` (no preload; the host is `*.pages.dev`)
- `X-Content-Type-Options: nosniff`
- `Referrer-Policy: strict-origin-when-cross-origin`
- `Permissions-Policy: camera=(), microphone=(), geolocation=(), payment=()`
- `X-Frame-Options: DENY`
- `Cross-Origin-Opener-Policy: same-origin`
- **No** COEP and no CORP (they break jsDelivr, R2 and Supabase fetches; the single-thread ffmpeg core doesn't need them)

`Content-Security-Policy-Report-Only` (**report-only**; enforcement waits for a clean staging pass). Build it from what the app actually loads, and verify each origin in code rather than trusting this list:
- `default-src 'self'`
- `script-src 'self' 'wasm-unsafe-eval' blob: https://cdn.jsdelivr.net` (ffmpeg core blob URL). Check whether `index.html` or `flutter_bootstrap.js` has inline script. If it does, prefer moving it to a file over adding `'unsafe-inline'`, and note any remaining need.
- `worker-src 'self' blob:`
- `connect-src 'self' https://*.supabase.co wss://*.supabase.co https://cdn.jsdelivr.net https://*.r2.cloudflarestorage.com https://eu.i.posthog.com https://*.ingest.sentry.io https://*.ingest.de.sentry.io` plus any origin pdfrx, CanvasKit or fonts fetch at runtime. Check pdfrx 2.4.8 web (pdfium wasm source) with `read_package_uris` / `rip_grep_packages`, and check whether Flutter 3.44 loads CanvasKit from `www.gstatic.com` by default.
- `img-src 'self' data: blob:`
- `media-src 'self' blob:`
- `font-src 'self' data:` (plus `fonts.gstatic.com` only if the app fetches Google Fonts at runtime; check)
- `style-src 'self' 'unsafe-inline'` (Flutter injects styles)
- `frame-src` and `object-src 'none'`, `base-uri 'self'`, `frame-ancestors 'none'`, `form-action 'self'`

Cache rules (Pages `_headers` supports path patterns; later matches add headers, so make sure there are no conflicting duplicate `Cache-Control` values; check the Cloudflare Pages `_headers` docs for how matching rules combine):
- `no-cache` on `/`, `/index.html`, `/flutter_bootstrap.js`, `/flutter_service_worker.js`, `/main.dart.js`, `/version.json`, `/manifest.json`, and deferred `main.dart.js_*.part.js` if they are not content-hashed (check the build output names)
- `public, max-age=31536000, immutable` on `/canvaskit/*` (versioned by Flutter engine path? check; if not versioned use `max-age=86400`) and on `/vendor/*` (version in the folder name)
- `/assets/*`: `max-age=86400` (not hashed)

## Task 2: `apps/landing/_headers`
Same security headers. CSP report-only from what `index.html`/`main.js` load (`vendor/` GSAP and anything else; check). Cache: `no-cache` on HTML, `max-age=86400` on assets, fonts and vendor. Check `apps/landing/wrangler.jsonc` so the file lands in the deployed output dir.

## Task 3: CI check
In the `client-build` job of `.github/workflows/ci.yml`, after the build, assert `build/web/_headers` exists and contains `Content-Security-Policy` and `Strict-Transport-Security` (a short grep). This guards against a future web dir change dropping it.

## Task 4: NFR-07 client test (answer keys never reach the client before submit)
Add a test per data source that loads questions before submit: practice, quiz, homework, mock (find them under `apps/client/lib/features/*/data/`). Feed the model's `fromJson` a payload that *includes* `correct_answer`, `answer_key`, `explanation`, `key` fields, and assert the parsed entity exposes none of them: no such fields exist on the entity and `toJson`/props don't carry them. If an entity *does* have a key or explanation field that is filled before submit, **stop and report it** instead of changing it. Name tests with the NFR-07 ID.

## Out of scope
Enforcing CSP, Turnstile, auth settings, the grant revoke and privacy pages (later P3 parts). Don't touch `ci.yml` beyond Task 3.

## Gates
`dart format` · `flutter analyze --fatal-infos` · `flutter test -j 2` on the new tests · `flutter build web --release` with a placeholder env, then `cat build/web/_headers`. Router: after merge, check the staging response headers with `curl -sI` and the browser console for CSP report-only violations across boot, login, practice, notes, video.
