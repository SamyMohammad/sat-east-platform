# ADR-008: Observability, push and app attestation

**Status:** Proposed · **Date:** 2026-10-05 · **Deciders:** Developer

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
