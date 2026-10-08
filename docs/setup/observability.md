# Setup: Sentry, PostHog, Firebase (F-5, ADR-008)

The code is ready and switched off. Each service starts working once you create the account and
put its key in the place listed here. Client keys are public by design (`docs/05` §6). Server
keys go only into Edge Function or CI secrets.

## 1. Sentry (crashes and errors)
1. Create a free account at sentry.io, with organisation `sat-east`.
2. Create two projects:
   - **Flutter**, named `client`;
   - **Deno**, named `edge-functions`.
3. For the client, copy the `client` DSN into `apps/client/env/<flavor>.json` as `"SENTRY_DSN"`.
   Use one DSN for all flavors: `environment` is set from `FLAVOR`. For the staging deploy, add
   it to the CI env step in `.github/workflows/ci.yml` (repo variable `STAGING_SENTRY_DSN`) when
   staging should report.
4. For Edge Functions, copy the `edge-functions` DSN in as a secret:
   `supabase secrets set SENTRY_DSN_EF=<dsn> SENTRY_ENVIRONMENT=staging --project-ref <ref>`.
5. Check it: run the app with the DSN, then throw a test error from a debug button or with
   `Sentry.captureMessage`. In Sentry → Issues, the event should carry a user id only, with no
   email and no request body.

## 2. PostHog (product events)
1. Create a free account at posthog.com and pick the **EU** cloud (closer to Egypt and the Gulf).
2. Copy the project token (`phc_…`) into `env/<flavor>.json` as `"POSTHOG_KEY"`, and set
   `"POSTHOG_HOST": "https://eu.i.posthog.com"`.
3. Project settings: leave autocapture, session replay and surveys **off**. The app also turns
   them off in code.
4. Check it: run the app. A feature calling `getIt<AnalyticsService>().track(...)` should show
   up in PostHog → Activity within about 30 s (events are batched).

## 3. Firebase (FCM push + App Check only)
1. In console.firebase.google.com, create project `sat-east`. Analytics: **off**.
2. Register the apps: Android `dev.sateast.sat_east_client` (plus `.dev` / `.staging` suffixes per flavor), iOS, and Web.
3. App Check providers:
   - Web: **reCAPTCHA Enterprise**, which needs a site key for the web domain.
   - Android: **Play Integrity**.
   - iOS: **App Attest**.
4. Note the **project number** (Project settings → General), then set it as an Edge Function secret:
   `supabase secrets set FIREBASE_PROJECT_NUMBER=<number> APP_CHECK_MODE=monitor`.
5. Client follow-up story, which Claude can do once the project exists:
   `dart pub global activate flutterfire_cli` → `flutterfire configure` in `apps/client`
   (generates `firebase_options.dart`) → add `firebase_core`, `firebase_app_check`,
   `firebase_messaging` → call `FirebaseAppCheck.instance.getToken()` and send it as
   `X-Firebase-AppCheck` on the sensitive Edge Function calls.
6. After a week of clean `app-check monitor` logs, set `APP_CHECK_MODE=enforce`.
7. FCM sending (`send-push`) needs a service account JSON. It goes only into an Edge Function
   secret, never into the repo.
