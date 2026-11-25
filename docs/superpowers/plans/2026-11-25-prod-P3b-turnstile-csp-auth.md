# P3b — Turnstile captcha, CSP enforce, password policy

Spec: `docs/superpowers/specs/2026-11-21-prod-readiness-design.md` P3.1–P3.3.

## Facts (router, 2026-11-25)
- Staging pass with the report-only CSP (`apps/client/web/_headers`): boot, practice, video playback (XHR to `*.r2.cloudflarestorage.com` → `blob:` media) → zero `securitypolicyviolation` events; resource origins = self, `www.gstatic.com`, `fonts.gstatic.com`, `*.supabase.co`, R2. Upload (jsDelivr ffmpeg core) worked for the owner on staging.
- No captcha code exists anywhere yet. Turnstile site key + secret come from the owner later.
- `supabase/config.toml:181-184`: `minimum_password_length = 6`, `password_requirements = ""`.

## Task 1 — Turnstile in the client (optional until a site key exists)
- New public define `TURNSTILE_SITE_KEY` (`lib/core/env/env.dart`, the three `env/*.example.json`; empty = captcha off). Public key only (CLAUDE.md A6).
- Widget on sign-up, sign-in and forgot-password (web build). When the key is empty, no widget, no token, flows unchanged. When set, submit is disabled until a token exists; token expiry/error resets it; after any failed auth call, reset the widget (tokens are single-use).
- Data layer: pass `captchaToken` to `signUp`, `signInWithPassword`, `resetPasswordForEmail` (check the exact `supabase_flutter` API with `read_package_uris`/`rip_grep_packages`). Map GoTrue captcha failures to a client-only code `captcha_failed` (add to `docs/07` §9 client-only list) with English copy.
- Implementation choice: compare a maintained pub.dev package (e.g. `cloudflare_turnstile`) with a small `package:web` + `HtmlElementView` interop in `lib/core/` behind an interface; pick the lower-cost production-grade option and justify it (CLAUDE.md A5). Mobile builds: no widget (web-only per beta scope), never crash.
- Tests first: data source passes the token (success + captcha failure mapping), cubit methods, widget test that submit is gated when a key is configured and not gated when empty (fake captcha behind the interface).

## Task 2 — CSP: add Turnstile, then enforce
- `apps/client/web/_headers`: add `https://challenges.cloudflare.com` to `script-src` and `frame-src` (replace `frame-src 'none'`), and to `connect-src` only if Turnstile docs require it. Switch `Content-Security-Policy-Report-Only` → `Content-Security-Policy`. Update the comment block (evidence: the staging pass above).
- `apps/landing/_headers`: switch its report-only CSP to enforced too, after checking `index.html`, `privacy.html`, `terms.html` and `main.js` load only what it allows (gsap/vendor files are same-origin? verify).
- `docs/16` or the `_headers` comments: how to add an origin later (edit + staging check).

## Task 3 — password policy (local mirror)
- `supabase/config.toml`: `minimum_password_length = 8`, `password_requirements = "letters_digits"`.
- Client: sign-up / reset-password validation mirrors it (UX only; server re-validates) and `weak_password` copy says "at least 8 characters with letters and numbers". Tests for the validator.
- `docs/setup/auth.md` §0: password policy, captcha (Turnstile; secret in Supabase Auth settings, site key as public define; hostnames `sat-staging.pages.dev` + prod), and fix the stale "Resend" mention → Brevo SMTP (host `smtp-relay.brevo.com`, port 587, login/key in GitHub secrets `BREVO_SMTP_LOGIN` / `BREVO_SMTP_KEY`, set on prod at go-live).

## Out of scope
Changing hosted Supabase auth settings (router does it), creating the Turnstile widget (owner), `device_header_required` on prod (P6).

## Gates
In `apps/client`: `dart format .`, `flutter analyze --fatal-infos`, `flutter test -j 2 --exclude-tags golden`; goldens only for screens you changed (regenerate those, Windows baselines). `scripts/db-reset.ps1` still applies `config.toml` (run it; `scripts/db-test.ps1` green).
