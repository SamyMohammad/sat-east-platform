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
   Use one DSN for all flavors: `environment` is set from `FLAVOR`. CI reads it from the repo
   variables `STAGING_SENTRY_DSN` (staging deploy) and `PROD_SENTRY_DSN` (prod deploy). Empty
   means Sentry is off. Every web build sets `SENTRY_RELEASE` to the commit SHA automatically.
4. For Edge Functions, copy the `edge-functions` DSN in as a secret:
   `supabase secrets set SENTRY_DSN_EF=<dsn> SENTRY_ENVIRONMENT=staging --project-ref <ref>`.
5. Source maps (readable stack traces). Web deploys build with `--source-maps`. When both
   of these exist, CI uploads the maps to Sentry (`@sentry/cli`, pinned in the workflows,
   project `client`, release = commit SHA):
   - repo variable `SENTRY_ORG` (the org slug, e.g. `sat-east`);
   - repo secret `SENTRY_AUTH_TOKEN` (create it in Sentry → Settings → Auth Tokens, scope
     `project:releases`; add `org:read` only if the upload asks for it).
   If either is missing the upload is skipped with a notice. Either way, the `.map` files are
   deleted from `build/web` before the deploy, so they are never served from Pages.
6. Alert rules (Sentry → Alerts, project `client` and `edge-functions`):
   - "A new issue is created" → email the owner;
   - issue spike (for example more than 10 events in 1 hour) → email the owner;
   - Telegram, if free: Sentry has no first-party Telegram integration, so use a webhook
     (Settings → Integrations → Webhooks) pointing at a Telegram bot relay, or skip it.
7. Check it: run the app with the DSN, then throw a test error from a debug button or with
   `Sentry.captureMessage`. In Sentry → Issues, the event should carry a user id only, with no
   email and no request body.

## 1b. Uptime monitoring (UptimeRobot, free plan)
Create two HTTP(s) monitors with a 5-minute interval:
1. The web app URL (the Pages domain), expecting HTTP 200.
2. `https://<project-ref>.supabase.co/functions/v1/api/health`, expecting HTTP 200. The route
   needs no auth and returns only `{"ok":true}`; it answers 503 when the database ping fails.
   Do this for staging and prod.

Alert contacts: email, plus Telegram (UptimeRobot → My Settings → Alert Contacts → Telegram).

The prod `/health` monitor also keeps the free Supabase project awake, so it replaces the prod
keep-alive workflow (P2.1). Keep the staging keep-alive until a staging monitor exists.

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
