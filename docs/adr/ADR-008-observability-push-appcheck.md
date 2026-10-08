# ADR-008: Observability, push and app attestation

**Status:** Accepted (F-5, 2026-10-08) · **Date:** 2026-10-05 · **Deciders:** Developer

## Context
Supabase has no crash reporting, product analytics, push or app attestation (see
[16-supabase-playbook.md](../16-supabase-playbook.md) §4–5). The web build is the primary platform
(ADR-006), so every tool must support Flutter web as well as Android/iOS.

## Decision
- **Crashes & errors:** Sentry — Flutter (web + mobile) and Edge Functions (Deno SDK).
- **Product analytics:** PostHog behind a single `AnalyticsService` (events per NFR-18).
- **Firebase, narrowly:** one Firebase project used **only** for FCM push and App Check.
  No Firestore, Firebase Auth, Crashlytics or Firebase Analytics.

## Options considered
| Option | Pros | Cons |
|---|---|---|
| Sentry + PostHog + Firebase(FCM, App Check) (chosen) | All support web; one crash tool across client + EFs; PostHog free tier is large | Three vendors to configure |
| Firebase for everything | One console | Crashlytics has no web support; analytics weaker for funnels |

## Consequences
- Firebase config files are added to the app, but Supabase stays the only backend/auth.
- App Check starts in monitor mode on sensitive EFs, enforced after clean logs.
- FCM service-account JSON and Sentry DSN for EFs live in Edge Function secrets.

## Implementation (F-5, 2026-10-08)
Design: `docs/superpowers/specs/2026-10-08-f5-observability-design.md`. Setup: `docs/setup/observability.md`.
- Client: `ErrorReporter` (Sentry) and `AnalyticsService` (PostHog) in `apps/client/lib/core/`.
  Both are off until `SENTRY_DSN` / `POSTHOG_KEY` are set, and the no-op versions are used
  otherwise. Only the Supabase user id is sent.
  - Sentry scrubs request bodies, headers, cookies and URL tokens.
  - PostHog runs with no autocapture, no pageviews, no session replay and no surveys.
  - On web, a vendored `posthog-js` (no-external build) is injected only when the key is set.
- Edge Functions: `supabase/functions/_shared/sentry.ts` (secret `SENTRY_DSN_EF`) and
  `_shared/app_check.ts` (`FIREBASE_PROJECT_NUMBER`, `APP_CHECK_MODE`). The EF template uses
  both. CI job `functions` runs their Deno tests.
- Still open: the client Firebase setup (`firebase_core`, App Check, FCM). It needs the Firebase
  project and `flutterfire configure`; the steps are in the setup doc.
