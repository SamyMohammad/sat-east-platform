# Production setup: closed beta on Supabase Free

This runbook is the closed-beta exception to the Pro + PITR target in
[architecture §6](../05-system-architecture.md#6-environments) and
[playbook §7](../16-supabase-playbook.md#7-free-projects-pause--three-environments).
Use `sat-prod` on Free, with purchases disabled and our own encrypted backups.
Free has no downloadable daily Supabase backups/PITR; Supabase recommends off-site
exports for Free projects ([backup documentation](https://supabase.com/docs/guides/platform/backups)).
The repository, Actions logs and artifacts are **public**. Never paste credentials,
database rows, dumps or activation codes into logs, issues or artifacts.

## 1. Create the production database

1. Open the Supabase dashboard. Select the account/organization you intend to own
   production. Check how many active Free projects that owner/admin already has
   across organizations: the limit is two. Staging uses a separate account; do
   not assume the main account has space. Resolve the limit before proceeding.
2. Click **New project**, choose the Free organization, enter **sat-prod** and
   generate a strong database password. Save it in a password manager immediately.
3. Select the same region as staging (currently **Central EU / Frankfurt,
   eu-central-1**; verify in staging's settings). Click **Create new project**.
4. Wait for it to be healthy. In **Project Settings → General**, copy the project
   reference ID. It must differ from staging. In **Connect**, check that the server
   is Postgres **17**, matching `supabase/config.toml`. Stop if it differs.
5. In **Project Settings → API / API Keys**, copy the project URL and the
   **publishable** key (`sb_publishable_…`). Never copy a service-role/secret key
   into a GitHub variable or Flutter environment file.

## 2. Choose the production web address and configure Auth

1. Choose a unique Pages name, for example `sat-prod`. The initial address will be
   `https://sat-prod.pages.dev` if that name is available. The deploy creates the
   Pages project for you; use this exact name in `CF_PAGES_PROJECT_PROD`. Do not
   run Wrangler from an AI agent to create it: that can create a Worker instead
   of Pages (ADR-009). An existing project must be a Direct Upload Pages project.
2. In **Supabase → sat-prod → Authentication → URL Configuration**, set **Site URL**
   to your chosen HTTPS address. Add `<site>/**` and `<site>/?flow=recovery` to
   **Redirect URLs**, then click **Save**. Follow [Auth §0](auth.md#0-site-url-every-hosted-project-before-the-first-sign-up).
3. In **Authentication → Sign In / Providers → Email**, leave email/password
   enabled and turn **Confirm email OFF**, then save. This is a temporary,
   closed-beta exception to the normal confirmation-on policy: without SMTP the
   default mailer is unsuitable for real students. Anyone can claim an unverified
   email address, so invite known students and verify their identity before
   handing out activation codes. Do not treat an email address as verified identity.
4. Until SMTP exists, password resets are handled by the teacher: verify the
   student's identity out of band, open **Authentication → Users → the student**
   and use the dashboard's password update control to set a temporary password.
   Share it privately and have the student change it. If the dashboard only offers
   an email reset action, stop and ask the developer for a private Admin Auth
   password update; email reset still requires SMTP. Never change password hashes
   with SQL or share a service-role key with a student.
5. Before opening beyond the closed beta, complete [Auth §1](auth.md#1-email-sender-smtp-needed-before-beta),
   turn **Confirm email ON** again and test confirmation and self-service password
   recovery. Google sign-in is optional and needs Auth §2.
6. A custom domain is optional: after the Pages project exists, open **Cloudflare →
   Workers & Pages → your project → Custom domains → Set up a custom domain**.
   Follow the DNS prompts. If you switch addresses, update Auth Site URL, redirect
   URLs, video CORS and `VIDEO_ALLOWED_ORIGINS` together.

## 3. Create separate encrypted-backup storage

1. Open **Cloudflare → R2 Object Storage → Create bucket**. Name it **backups**,
   select Standard storage, and create it. Keep public access off; never enable
   an `r2.dev` URL or a public custom domain for this bucket.
2. Open **R2 → Manage R2 API tokens → Create API token**. Name it `sat-prod-backups`,
   choose **Object Read & Write**, and scope it to **only the backups bucket**.
   Copy its Access Key ID, Secret Access Key and account ID into your password
   manager. These are S3 credentials, not the Pages API token. Use a separate
   token for the video bucket; never give the video function access to backups.
3. Open **backups → Settings → Object lifecycle rules → Add rule**. Give it a name,
   apply it to prefix `prod/`, select **Delete objects** after **30 days**, and save.
   Confirm the rule is enabled. Keep the bucket empty of unrelated data.
4. Generate a strong independent backup passphrase (for example,
   `openssl rand -base64 48`) on your trusted computer. Store it outside GitHub in
   the password manager as well: losing it makes every encrypted backup unusable.
   Keep old passphrases until all backups using them have expired.
5. Open your **video bucket → Settings → CORS policy**, add the exact production
   origin to the existing allowed origins, preserve the existing methods/headers,
   and save. Do not add a wildcard or make the bucket public.
6. R2's **10 GB-month Standard free allowance is shared** by videos and backups
   across the account ([R2 pricing](https://developers.cloudflare.com/r2/pricing/)).
   Thirty daily dumps plus pre-deploy dumps count too. In the teacher's settings,
   budget `video_storage_cap_mb` to leave room for them; its existing 9216 MB
   default is not a backup-space reservation. Check R2 usage and billing weekly.

## 4. Set production Edge Function secrets

1. Open **Supabase → sat-prod → Edge Functions → Secrets**. Add the names below.
   Copy production video values from your password manager, using the separate
   video-bucket API token from step 3. Do not copy staging credentials blindly.
   These values stay in Supabase, never the Flutter bundle.
2. This is the complete current `Deno.env.get` inventory under `supabase/functions`
   (names only):

   - `R2_ACCOUNT_ID`
   - `R2_ACCESS_KEY_ID`
   - `R2_SECRET_ACCESS_KEY`
   - `R2_BUCKET`
   - `VIDEO_TOKEN_SECRET`
   - `VIDEO_ALLOWED_ORIGINS`
   - `FIREBASE_PROJECT_NUMBER`
   - `APP_CHECK_MODE`
   - `SENTRY_DSN_EF`
   - `SENTRY_ENVIRONMENT`
   - `SUPABASE_URL`
   - `SUPABASE_SERVICE_ROLE_KEY`

3. Generate a **new** `VIDEO_TOKEN_SECRET` locally with
   `openssl rand -base64 32`; save it privately and paste it into Secrets.
   For `VIDEO_ALLOWED_ORIGINS`, use the exact HTTPS production origin (comma-separated
   if both Pages and a custom domain are used). `R2_BUCKET` is the video bucket.
4. `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are supplied automatically by
   Supabase; do not override or copy them into GitHub. `SENTRY_DSN_EF` is optional;
   set `SENTRY_ENVIRONMENT` to `prod`. For App Check, use the production Firebase
   project number when configured and start `APP_CHECK_MODE` in `monitor`; plan
   enforcement after monitoring. An unset project number means App Check is not
   configured. No Paymob/LLM/Desmos secret is read by the current functions.

## 5. Configure GitHub environments, variables and secrets

1. Open **GitHub repository → Settings → Environments → New environment**. Create
   **production**. Under protection rules, add **Required reviewers → your owner
   account → Save**. If you are the only reviewer, leave **Prevent self-review**
   off so you can approve your own manual run. Restrict deployment branches to
   **main**, and disable administrator bypass where available.
2. Create **production-backup** with **no required reviewer** so schedules run
   unattended. Restrict its deployment branches to **main** too. These protections
   apply to the workflow's branch; the deploy separately checks its input commit
   for a successful CI push run on main. Review the requested ref before approval.
3. Inside each environment, use **Environment variables → Add variable** and
   **Environment secrets → Add secret** for the following exact names. Keep prod
   secrets environment-scoped, rather than exposing them to every workflow.

| Variable | Environment(s) | Where the value comes from |
|---|---|---|
| `PROD_PROJECT_REF` | Both | sat-prod → Project Settings → General → Reference ID |
| `STAGING_PROJECT_REF` | production (or existing repository variable) | sat-staging → General → Reference ID; required isolation check |
| `PROD_SUPABASE_URL` | production | sat-prod → API → Project URL |
| `PROD_PUBLISHABLE_KEY` | production | sat-prod → API Keys → publishable key; intentionally public |
| `CF_PAGES_PROJECT_PROD` | production | Chosen Direct Upload Pages project name, not a URL |
| `PROD_SENTRY_DSN` | production, optional | Sentry client project's public DSN; empty/unset disables |
| `PROD_POSTHOG_KEY` | production, optional | EU PostHog project's public key; empty/unset disables |
| `BACKUP_BUCKET` | Both, optional | `backups`; empty/unset defaults to `backups` |

| Secret | Environment(s) | Where the value comes from |
|---|---|---|
| `SUPABASE_ACCESS_TOKEN` | Both | Supabase account → Access Tokens; use a token scoped to sat-prod with link/migration/function deployment access; save expiry/rotation reminder |
| `PROD_DB_PASSWORD` | Both | Database password saved when creating sat-prod |
| `CLOUDFLARE_API_TOKEN` | production | Cloudflare → My Profile → API Tokens → Create Custom Token; Account / Cloudflare Pages / Edit for the production account |
| `CLOUDFLARE_ACCOUNT_ID` | production | Cloudflare account overview → Account ID |
| `BACKUP_PASSPHRASE` | Both | Independent passphrase from step 3; preserve an offline/password-manager copy |
| `R2_ACCOUNT_ID` | Both | R2 S3 endpoint's account ID (same account ID if using one Cloudflare account) |
| `R2_ACCESS_KEY_ID` | Both | backups-only R2 token's Access Key ID |
| `R2_SECRET_ACCESS_KEY` | Both | backups-only R2 token's Secret Access Key |

4. Both environments need the same backup values. `GH_TOKEN` is supplied
   automatically from `github.token` with `actions: read`; do not create a PAT for it.
   `PGPASSWORD` is mapped from `PROD_DB_PASSWORD` per step. No `PROD_DB_URL` secret
   is needed: the script calls pinned Supabase CLI `link` and reads its
   `supabase/.temp/pooler-url`, exactly as staging does. It masks that derived URL,
   refuses embedded passwords and uses `PGPASSWORD` with TLS. The script additionally
   needs `SUPABASE_ACCESS_TOKEN` for linking. Do not print the cached URL.
5. Both workflows register the signed PGDG repository and install the Postgres **17**
   client (security patch updates within major 17), AWS CLI **2.37.13**, and
   Supabase CLI **2.117.0**. GnuPG comes from Ubuntu 24.04. The script checks the
   client and server majors and fails on a mismatch. Review these pins before a
   server upgrade; never solve a backup failure by skipping it.

## 6. First deploy and smoke checks

1. Have the config/docs change merged to **main**. Open **Actions → CI**, select
   the main push run for the desired commit and wait for the entire run to be green
   (including staging deploy). A successful PR run alone does not qualify.
2. Open **Actions → Deploy prod → Run workflow**. Choose workflow branch **main**,
   leave input **ref = main** (or paste that successful main commit's full SHA),
   and click **Run workflow**. Review the ref and approve the `production` deployment.
3. Wait for all steps. The order is configuration/isolation/CI checks, build and
   secret scan, Pages project creation, encrypted backup upload, migrations,
   Edge Functions, then Pages upload. A backup failure blocks migrations.
   There is no seed step or `--include-seed`; the guard also rejects demo seed
   paths/globs. Never run `supabase/seeds/demo` on production.
4. Open Pages' production URL and check at phone and desktop widths:

   - HTTPS loads; no purchase/payment UI is shown.
   - Create a test student, sign out and sign back in. The email is unverified
     during this exception. No confirmation redirect goes to localhost.
   - Courses initially contain no staging demo. Empty states render normally.
   - In Supabase, verify migrations and the `api` Edge Function deployed.
   - In R2 → backups → Objects, find the new `prod/…-pre-migrate.dump.gpg` object
     with nonzero size. Never download it on a shared computer.
   - Exercise a teacher-managed password reset; once SMTP is configured, test the
     emailed recovery link reaches `/?flow=recovery` and permits a new password.

5. Sign up your own teacher email in the app. In **Supabase → SQL Editor → New
   query**, run the following, replacing the email. Verify exactly your account
   changed, then sign out/in. This is the documented owner bootstrap, not a schema
   change or a command to run against staging:

   ```sql
   update public.profiles
   set role = 'teacher'
   where id = (select id from auth.users where email = 'YOUR_TEACHER_EMAIL')
   returning id, role;
   ```

6. Use the teacher area to create the real course, taxonomy and pilot content;
   publish it. Generate and distribute codes privately following
   [Activation codes](activation-codes.md). Test redemption as the student, then
   practice → submit → review, quiz → unlock, PDF access and video playback/upload
   with the production origin. Confirm answer keys appear only after submission.
7. Open **Actions → Backup prod → Run workflow → main** once, with no approval
   required. Check it succeeds and creates another encrypted object. Scheduled
   runs are **02:30 UTC daily** (Cairo time varies with DST). Enable GitHub failure
   notifications and check daily; schedules can be delayed, and public-repo
   schedules can be disabled after 60 days of repository inactivity. Verify the
   next automatic run. A paused Free project must be resumed from its dashboard.
   The existing keep-alive targets staging only; monitor prod health separately.
8. Deploys and backups share `production` concurrency without cancelling running
   work. GitHub can replace older pending runs in a concurrency group; verify a
   requested deploy actually ran if several jobs were queued.

## 7. Run one restore drill before inviting students

1. Ask the developer to start a disposable **local Supabase Postgres 17** instance,
   or a dedicated scratch Supabase project (subject to the Free project limit).
   It needs Supabase roles/extensions and managed schemas; an empty vanilla
   PostgreSQL database is not sufficient for a faithful full restore. Never use
   staging or prod for this drill. Disable outbound mail, integrations and jobs;
   it will contain production PII and must not contact students.
2. On a trusted private machine, install Postgres 17 client tools, GnuPG and AWS
   CLI. Use a private working directory (`umask 077`). Load the backups-only R2
   credentials as `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` from the password
   manager without pasting them into shell history. Set `R2_ACCOUNT_ID` to the
   account ID. Download the object key shown in the successful workflow:

   ```bash
   aws s3 cp 's3://backups/prod/REPLACE_WITH_OBJECT.dump.gpg' ./restore.dump.gpg \
     --endpoint-url "https://$R2_ACCOUNT_ID.r2.cloudflarestorage.com" --region auto
   gpg --output restore.dump --decrypt restore.dump.gpg
   pg_restore --list restore.dump > restore-list.txt
   ```

3. GnuPG prompts privately for the saved backup passphrase. Check the archive
   contains **public, private, auth, storage and supabase_migrations**. Never paste
   its table-of-contents or decrypted contents into a public ticket.
4. Set `SCRATCH_DB_URL` to the scratch connection URL **without a password**;
   supply its password through `PGPASSWORD` privately. Confirm its host/project
   twice, then restore (this destroys/replaces objects in the target):

   ```bash
   pg_restore --clean --if-exists --no-owner --no-privileges \
     --exit-on-error -d "$SCRATCH_DB_URL" restore.dump
   ```

5. A full `pg_dump` includes Supabase-managed schemas. Managed ownership,
   extensions and dependencies may prevent a direct clean restore even with
   `postgres`. If it fails, keep the drill failed: have the developer prepare a
   compatible local Supabase database and a reviewed restore list for the managed
   objects, following [Supabase's migration guide](https://supabase.com/docs/guides/platform/migrating-within-supabase/backup-restore).
   Do not ignore restore errors or promote a scratch database to prod. This dump
   uses `--no-owner --no-privileges`; cluster roles and grants are not backed up.
   Reapply repository migrations/security grants as appropriate and verify RLS
   as student/teacher before any real recovery.
6. Compare private source/restore counts for profiles, courses, enrollments,
   attempts, answer keys and Auth users. Check migration history, sign-in and
   representative student/teacher RLS access locally. Record only the object key,
   time, success/failure and non-sensitive validation summary in a private record.
7. Delete `restore.dump`, `restore.dump.gpg`, `restore-list.txt` and the scratch
   database/volume, clear credentials from the shell and empty local trash.
   Prefer an encrypted disk; file deletion does not guarantee physical erasure.

The nightly backup is a logical database snapshot, including Auth PII and private
answer/video keys, encrypted with AES-256 **before** upload. It is not PITR: allow
for up to a day of lost writes, longer if a run fails. It contains Storage metadata,
not Storage object bytes, R2 videos, Edge Function secrets, project/Auth settings
or external configuration. Preserve original videos/PDFs separately and keep
secrets in the password manager. Before paid/public launch, revisit Pro + PITR,
SMTP, backup monitoring, media recovery and a fully rehearsed production restore.
