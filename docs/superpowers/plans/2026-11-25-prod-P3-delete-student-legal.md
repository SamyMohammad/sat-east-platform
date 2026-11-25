# P3.7 — `admin_delete_student` + Privacy / Terms pages

Spec: `docs/superpowers/specs/2026-11-21-prod-readiness-design.md` (P3.7). NFR-12, R-12, AUTH-03 (teacher = admin).

## Decisions (owner, 2026-11-25)
1. **Hard delete** (not anonymise). Deleting the student's `auth.users` row cascades to `profiles` and every `user_id` table (attempts, progress, AI threads, devices, notifications, enrollments, ...). `activation_codes.redeemed_by` → null (code stays used). One `audit_log` row survives: `actor` = teacher, `action` `student_deleted`, `entity` `profiles`, `entity_id` = the deleted id, `diff` = row counts only — no name, email or phone.
2. **Teacher only.** No student self-delete. Requests arrive by email; the teacher deletes from the dashboard after retyping the student's email.
3. **Contact email**: a new dedicated address the owner will create. Until then use one constant placeholder `privacy@example.com` defined in ONE place per app, listed in the go-live checklist (`docs/setup/prod.md`) as "replace before go-live".

There is no teacher student list today, so the teacher finds the student by email.

## Task A — RPC + teacher UI (worktree `sat-p3-delete`)
A1. Migration `supabase/migrations/20261125110000_p3_admin_delete_student.sql` (start from `supabase/templates/rpc.sql`; `docs/16` §2 checklist):
- `public.admin_delete_student(p_email text) returns jsonb`, `security definer`, `set search_path = ''`, `grant execute ... to authenticated` only (revoke from public/anon).
- Errors (codes from `docs/07` §9, raised as message like the other RPCs): `not_authenticated`; `forbidden` unless caller is a teacher; `invalid_input` for empty/blank email; `not_found` is NOT a listed code → return `{ok:false, error:'invalid_input'}`-style? No: add a new code `student_not_found` to `docs/07` §9 and use it. Never deletes a teacher or parent (target role must be `student`, else `forbidden`), never the caller.
- Email match case-insensitive and trimmed, against `auth.users.email`.
- `orders` has `on delete restrict`: if the student has any order, raise `forbidden`? No — add code `student_has_orders` to `docs/07` §9 and raise it (financial records; none exist in the beta).
- Count rows per user table first (for the audit diff), insert the audit row, then `delete from auth.users where id = ...`. Verify locally that `postgres`-owned definer code may delete from `auth.users`; if not, stop and report (fallback would be the `api` Edge Function with the service role — do not build it without asking).
- Returns `{ok:true, deleted_user_id, counts}`.
- Rate limit: reuse the existing private rate-limit helper if one fits (e.g. 20 / hour per teacher); read how other RPCs do it.
A2. pgTAP `supabase/tests/56_admin_delete_student.test.sql` (template `test.sql`, names tagged `P3`): student caller → forbidden; anon → not executable; teacher deletes a student with data in several tables → `auth.users`, `profiles` and child rows gone, activation code still `redeemed`/used with null `redeemed_by`, one audit row with no email/name/phone in `diff`; unknown email → `student_not_found`; teacher email → forbidden; mixed-case email with spaces works; order present → `student_has_orders`.
A3. Flutter (run `/flutter-feature` conventions — read `.claude/skills/flutter-feature` or the project skill; ADR-007): in the existing teacher settings feature (`apps/client/lib/features/teacher/settings/`), add a "Delete a student" section: email field, a confirm dialog that requires retyping the email exactly, a destructive button, success and error copy (English; map every error code above to user-facing text). Data source calls the RPC and maps `PostgrestException` → `AppError`; repository returns `Result`; cubit method with `isClosed` checks. DI in `lib/core/di/injection.dart`. Tests: data source (success + each error), repository, every public cubit method (success + failure), one widget test for the confirm-mismatch guard. Check layout at 360 and 1280.
A4. Docs: `docs/07` (RPC row + the two new codes), `docs/06` (deletion behaviour), `docs/setup/prod.md` go-live line for the placeholder email.

Gates: `scripts/db-reset.ps1`, `scripts/db-test.ps1`, `scripts/api-private-check.ps1`; in `apps/client`: `dart format .`, `flutter analyze --fatal-infos`, `flutter test -j 2`.

## Task B — Privacy + Terms (worktree `sat-p3-legal`)
B1. `apps/landing/privacy.html` and `apps/landing/terms.html`, same look as `index.html` (reuse `styles.css`, header/footer), English, LTR, linked from the landing footer. Plain, short, honest DRAFT text with a visible "Draft — under review" note at the top:
- Privacy: who we are; most users are minors (parent/guardian may contact us); data collected (account: email, name, optional phone/country/school/grade/timezone; learning activity; device identifiers for the 2-device limit; AI tutor conversations stored for quality, not used to train third-party models — NFR-13); processors (Supabase — database/auth, Cloudflare — hosting/video storage, Brevo — email, Sentry — crash reports, PostHog — product analytics, the AI provider used by the tutor — check `supabase/functions` for which one); no selling of data; retention (account lifetime; backups up to the retention in `docs/setup/prod.md`); deletion on request by email to the contact address, completed by the teacher and irreversible; contact.
- Terms: closed beta, as-is; one account per student, max devices per `settings`; activation codes personal; acceptable use (no sharing content/answers, no scraping); content ownership; termination; changes; contact.
- Contact address: the single placeholder constant in `main.js` or one shared snippet — one place.
B2. `apps/landing/_headers`: make sure the new pages get the same security headers (they probably match `/*` already — check).
B3. Client sign-up (`apps/client/lib/features/auth/presentation/screens/sign_up_screen.dart`): a short line under the submit button: "By creating an account you agree to the Terms and the Privacy Policy." with both as links to the landing pages. Landing base URL: find how it is configured (env / `--dart-define`, docs/setup); add a public `LANDING_URL` define only if none exists (example env files too). Opening links: no new package unless needed — check whether `url_launcher` is the least-cost option vs. an existing dependency/`package:web`; justify in the report. Widget test that both links render and are tappable (mock the launcher behind an interface in core if needed).

Gates: in `apps/client`: `dart format .`, `flutter analyze --fatal-infos`, `flutter test -j 2`. Landing: open the two pages locally (any static server) and confirm no console errors.

## Out of scope
Student self-delete, a teacher student list, Paymob refund policy, anonymised retention, changing Brevo sender.
