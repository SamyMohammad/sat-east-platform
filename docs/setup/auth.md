# Setup: sign-in email and Google (A-1, AUTH-01)

Decisions (docs/02 AUTH notes): email confirmation is on in staging and prod, and Google sign-in
is coded in A-1 but shown only once the steps below are done.

## 0. Site URL (every hosted project, before the first sign-up)
Supabase dashboard → Authentication → URL Configuration:
- **Site URL** = the web app URL (staging `https://sat-staging.pages.dev`; prod: its domain).
- **Redirect URLs** add `<web app URL>/**`.
- Also add `<web app URL>/?flow=recovery` for password reset; staging:
  `https://sat-staging.pages.dev/?flow=recovery`. Native reset deep links are
  deferred until the store builds.

### Password policy
Hosted projects must match `supabase/config.toml`: minimum length **8** and required characters
**letters and digits** (`password_requirements = "letters_digits"`). Dashboard → Authentication →
Sign In / Providers → Email (or Attack Protection / password settings). The client mirrors the rule
for UX only; GoTrue re-validates and answers `weak_password`.

### Captcha (Cloudflare Turnstile)
Sign-up, sign-in and password-reset requests carry a Turnstile token (web build only).
1. Cloudflare dashboard → Turnstile → add a widget. Hostnames: `sat-staging.pages.dev` and the prod
   web hostname. Managed mode.
2. Supabase dashboard → Authentication → Attack Protection → enable CAPTCHA, provider
   **Turnstile**, paste the **secret key** there (never in the repo or in `env/*.json`).
3. Put the **site key** (public) in the client build as `TURNSTILE_SITE_KEY` in `env/<flavor>.json`.
   Empty means captcha off: no widget and no token. Turn the Supabase CAPTCHA setting on only
   together with a client build that has the key, otherwise sign-in is rejected with
   `captcha_failed`.
4. The CSP in `apps/client/web/_headers` already allows `https://challenges.cloudflare.com`.
   Local Supabase keeps captcha off (`[auth.captcha]` stays commented in `config.toml`).

The default Site URL is `http://localhost:3000`. If it is left as is, the confirmation link still
confirms the email, but it then redirects to localhost and shows "This site can't be reached".

## 1. Email sender (SMTP), needed before beta
Supabase's built-in mailer is rate-limited and meant only for testing.
1. Use Brevo SMTP (host `smtp-relay.brevo.com`, port `587`). Verify the sending domain.
2. Supabase dashboard → Project settings → Authentication → SMTP: fill in host, port, login and
   key. The login and key live in the GitHub secrets `BREVO_SMTP_LOGIN` / `BREVO_SMTP_KEY` and are
   set on prod at go-live; they never go in the repo.
3. Authentication → Providers → Email: turn **Confirm email** on (staging and prod). Local dev
   keeps `enable_confirmations = false` in `supabase/config.toml`.
4. Edit the confirmation and reset-password templates to read in English (UI copy rule 8).

## 2. Google sign-in
1. In Google Cloud console, create project `sat-east`, then set up the OAuth consent screen
   (External, app name, support email, logo).
2. Create an OAuth client ID of type **Web application**, with this authorised redirect URI:
   `https://<project-ref>.supabase.co/auth/v1/callback` (one per Supabase project: staging, prod).
3. Supabase dashboard → Authentication → Providers → Google: enable it and paste the client ID and
   secret. The secret goes only into the dashboard.
4. Authentication → URL configuration: the site URL is the web app URL, and the redirect URLs add
   the mobile deep link (decided in A-1, e.g. `dev.sateast.satEast://login-callback`).
5. Tell Claude it is done, so the Google button gets switched on in the client.
