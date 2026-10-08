# Phase 0 row 10 — F-5: Sentry, PostHog skeleton, Firebase (design)

Story: docs/15 §1 row 10, `docs/03` F-5. Sources: ADR-008, NFR-18, `docs/16` §5 (App Check),
`docs/05` §6 (public client keys), CLAUDE.md rules A.6 / B.3 / B.6.

## Goal
Put the plumbing in now, while the app is tiny: crash and error reports (client + Edge Functions),
one `AnalyticsService` for the NFR-18 events, and the server half of App Check. Every piece is
**off until its key is set**, so dev, CI and forks run without accounts.

## Scope
**In:**
- Client:
  - `ErrorReporter` (Sentry) and `AnalyticsService` (PostHog) in `lib/core/`;
  - DI registration;
  - `main.dart` wiring;
  - env keys;
  - tests.
- Edge Functions:
  - `supabase/functions/_shared/sentry.ts` (init + capture, PII-free);
  - `supabase/functions/_shared/app_check.ts` (verify a Firebase App Check JWT, monitor mode);
  - the EF template using both;
  - Deno tests;
  - a CI job that runs them.
- Docs:
  - the env-key rule (CLAUDE.md A.6, aligned with `docs/05` §6);
  - a Firebase setup runbook.

**Out (needs accounts the developer creates first, runbook provided):**
- the Sentry and PostHog projects;
- the Firebase project;
- client Firebase init (`firebase_core`, App Check, FCM). That waits for `flutterfire configure`
  to generate `firebase_options.dart`, because adding the packages without it breaks the build.
- Push sending (`send-push`) is a later story.

## Decisions
1. **Client keys:** `SENTRY_DSN`, `POSTHOG_KEY`, `POSTHOG_HOST` go in `env/<flavor>.json`. They are
   public by design (`docs/05` §6), like the Supabase publishable key. An empty value means the
   service is off and a no-op implementation is registered. CLAUDE.md A.6 is updated to list them
   explicitly. Server-side DSNs and the FCM service account stay in EF secrets.
2. **Interfaces in `lib/core/`, used from 2+ features (rule A.2):**
   - `ErrorReporter { captureError(error, stack, {hint}); setUser(id); clearUser(); }`
   - `AnalyticsService { track(AnalyticsEvent); identify(id); reset(); }`

   `AnalyticsEvent` is a sealed class with one subclass per NFR-18 event: `signup`, `purchase`,
   `step_complete`, `quiz_pass` / `quiz_fail`, `mock_complete`. Each subclass maps itself to a name
   and properties, so the event names live in one place. These files have no Flutter imports.
3. **No PII:**
   - Only the Supabase user id goes to either tool: no email, name or phone.
   - Sentry runs with `sendDefaultPii = false`, and a `beforeSend` scrubber drops request bodies,
     cookies and the user's email / IP.
   - PostHog runs with `person_profiles: identified_only`, and autocapture, pageview capture,
     session replay and surveys are all off. Replay would record screens with student data.
4. **PostHog on web:** `posthog_flutter` cannot initialise on web; it expects `window.posthog`.
   - We vendor `posthog-js` 1.434.13 `array.no-external.js`. It never loads extra scripts from
     PostHog's CDN, and it is about 100 KB gzipped.
   - Dart injects it and calls `posthog.init` **only when `POSTHOG_KEY` is set**, so the bundle
     costs nothing while analytics is off, and the key comes from the same env file as on mobile.
5. **Sentry wraps `runApp`** through `SentryFlutter.init(appRunner: …)` only when the DSN is set.
   The `environment` is the flavor and the `release` is the app version. Errors that flow up as
   `AppError` with code `internal` are reported by the data layer in later stories; this story
   ships the reporter.
6. **Edge Functions:**
   - `_shared/` holds no `index.ts`, so `supabase functions deploy` skips it.
   - Sentry Deno is pinned to `npm:@sentry/deno@10.75.3`, with init guarded by `SENTRY_DSN_EF`.
   - App Check verifies the `X-Firebase-AppCheck` JWT with `jose`: RS256, Firebase's JWKS,
     `iss = https://firebaseappcheck.googleapis.com/<project number>`, and `aud` containing
     `projects/<project number>`.
   - Mode is `monitor` (log, allow) or `enforce` (reject with 401 `forbidden`). It is read from
     `APP_CHECK_MODE`, defaulting to `monitor` (`docs/16` §5).
7. **CI:** a `functions` job runs `deno test supabase/functions/_shared/` (pinned Deno), in parallel
   with `client` and `db`. Deploy waits for it too.

## Tests
- Client: event → name and properties; the no-op services; the Sentry scrubber (pure function);
  the PostHog service calling a fake client; DI picks the no-op services when keys are empty.
- EF: App Check accepts a valid token from an injected JWKS. It rejects a wrong issuer, wrong
  audience, expired, bad signature or missing token. Monitor mode allows and logs; enforce mode
  blocks. Sentry init is a no-op without a DSN.
