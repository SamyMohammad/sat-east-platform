# Setup: sign-in email and Google (A-1, AUTH-01)

Decisions (docs/02 AUTH notes): email confirmation is on in staging and prod, and Google sign-in
is coded in A-1 but shown only once the steps below are done.

## 1. Email sender (SMTP), needed before beta
Supabase's built-in mailer is rate-limited and meant only for testing.
1. Create a sender account, e.g. Resend (docs/05 lists it for receipts). Verify the sending domain.
2. Supabase dashboard → Project settings → Authentication → SMTP: fill in host, port, user and
   password. The password goes only here, never in the repo.
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
