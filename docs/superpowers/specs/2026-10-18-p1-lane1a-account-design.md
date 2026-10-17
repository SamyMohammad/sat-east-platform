# Lane 1a — password reset + My account (design)

Status: draft · 2026-10-18 · Lane 1 of the parallel lanes in `docs/STATUS.md`
Reqs: AUTH-06 (A-5), AUTH-04 (A-3, manage devices), S-03, S-34
Follows: lane 1b onboarding (A-2: target test + date), lane 1c catalogue + course page (P-1).
Deferred: Google sign-in (A-1) — needs Google OAuth set up; email login is enough for the closed beta.

## 1. Intent

The closed beta runs with the teacher's current students on activation codes. Before any sales page,
those students need to recover a forgotten password and see/manage their own account and devices
without asking the teacher. Today the app has sign-up, sign-in, check-inbox and the device gate
(shown only when a third device hits the limit); there is no reset flow and no account page.

## 2. Decisions

- **Name is locked after sign-up (user decision).** The student's `full_name` is printed as the notes
  watermark (SEC-02); a self-service rename would defeat leak tracing. My account shows it read-only
  with "Contact your teacher to change your name." The server enforces it: the `authenticated` role
  loses `update (full_name)` on `public.profiles` (today it has it). A teacher rename RPC belongs to
  the teacher area (lane 3), not here.
- **No account enumeration.** "Forgot password" always answers "If an account exists for that
  email, we sent a reset link."
- **Reset is web-only for the beta (Claude's call, from the roadmap).** Store builds are Phase 2
  (`docs/11`); the mobile deep link arrives with them. Staging URL: `https://sat-staging.pages.dev`.
- **No re-authentication for an in-app password change (Claude's call)** — matches
  `secure_password_change = false`; client password rules stay as in `form_rules.dart`.
- **Test date is not on My account yet** — it arrives with onboarding (lane 1b), where editing rules
  are decided (it drives the access window).

## 3. Password reset (S-03, AUTH-06)

Flow: Sign in → "Forgot password?" → **Forgot password** screen (email) →
`auth.resetPasswordForEmail(email, redirectTo: <site>/…)` → "Check your inbox" →
email link → app opens → Supabase emits `AuthChangeEvent.passwordRecovery` → **Set new password**
screen (new password + confirm, same rules as sign-up `form_rules.dart`) → `auth.updateUser(password)` →
signed in → normal post-login routing (device registration, course map).

- Works on web with the existing hash URLs. The builder confirms how `supabase_flutter` (PKCE) returns
  on web with hash routing and picks the `redirectTo` that survives it; the chosen URL is added to the
  Supabase Redirect URLs list in `docs/setup/auth.md` §0 (user does staging/prod dashboard).
- **Recovery state (Claude's call):** the auth data source exposes the auth *event* (not just the
  user), and `AuthCubit` gains a state `AuthRecovery`. In `AuthRecovery` the router allows only
  `/reset-password`; device registration does **not** run until `updateUser` succeeds, then the cubit
  continues the normal signed-in path. `/forgot-password` and `/reset-password` join the router's
  signed-out allow-list. The builder must handle the URL code exchange finishing after `start()`
  (recovery can arrive after an initial `AuthSignedOut`).
- Errors → English copy: expired/used link ("This link has expired. Request a new one." + button back
  to Forgot password), `weak_password`, `rate_limited`, `network`. Never show raw exception text.
  Expiry arrives as URL error params (`error_code=otp_expired`), not an exception: add a
  **client-only** code `link_expired` to `ErrorCodes` and to the client-only list in `docs/07` §9.
- Reuse `AuthCard`, `AuthTextField`, `AuthFooterLink`, `auth_copy.dart`, `CheckInboxScreen` (with a
  reset variant of the copy) — no new look.

## 4. My account (S-34)

The existing shell **Profile** destination (`/profile`, today a `PlaceholderScreen` branch) gets the
real screen — no new route, no new nav entry, label stays "Profile". Sections:
- **Profile:** full name (read-only + teacher note), email (read-only). The name is read from the
  caller's own `public.profiles` row (RLS "student selects own" already allows it) in the auth data
  layer — no new RPC.
- **Password:** change password while signed in — new + confirm → `auth.updateUser`.
- **Devices:** list of the student's active devices — label/platform, "This device" badge on the
  current one (`is_current` from the RPC, see §5), last seen; **Remove** on the others →
  existing `remove_device` RPC, confirmation dialog, then refresh. Show "N changes left this month"
  from `changes_left`; when 0, Remove is disabled with the reason. Removing the current device is not
  offered (that is sign out).
- **Sign out.**

## 5. Backend (small, lane-owned)

Migration `20261018300000_lane1a_account.sql`, test `supabase/tests/30_account.test.sql`:
- `revoke update (full_name) on public.profiles from authenticated;` — other self-editable columns
  keep their grant. This also blocks the teacher over REST until lane 3 ships a rename RPC (intended).
  The sign-up trigger is security definer and still sets the name. Test: student update of own
  `full_name` fails; own `phone` still succeeds; sign-up still stores the name.
- `public.list_my_devices(p_fingerprint text) returns jsonb` → `{devices: [{id, label, platform,
  last_seen_at, created_at, is_current}], changes_left}` — caller's non-revoked devices, newest
  `last_seen_at` first; `is_current` = row fingerprint equals `p_fingerprint` (the client passes the
  value from `device_id_store`; the fingerprint itself is not returned). `changes_left` computed
  exactly as `remove_device` does (`20261009000000_auth04_device_limit.sql`; extend or mirror
  `private.active_devices_json`, which lacks `created_at`). Errors `not_authenticated`,
  `invalid_input` (null/blank fingerprint). Grant to `authenticated`.
  Update `docs/07` RPC table.

## 6. Client structure

Inside the existing `lib/features/auth` feature (data → domain → presentation): repository methods
`requestPasswordReset`, `updatePassword`, `getMyProfile`, `listMyDevices`; `AuthCubit` handles the recovery state;
a new `AccountCubit` (factory) loads profile + devices and removes a device. Every public Cubit
method tested (success + failure); widget tests for the three screens at 360 and 1280.

## 7. Goals / non-goals / anti-goals

- Goals: a student can recover access alone; a student can see and remove their own devices.
- Non-goals: Google sign-in, phone/school/grade editing UI, test date, teacher rename, email change.
- Anti-goals: revealing whether an email has an account; a student changing their own name by any
  path (UI or direct REST); removing a device without the 30-day allowance check (server already
  enforces it — the UI must not bypass or misreport it).

## 8. Reserved names (parallel-lane protocol)

Migration `20261018300000_lane1a_*`; pgTAP from `30_`; routes `/forgot-password`,
`/reset-password` (Profile reuses `/profile`); DI: append-only in `lib/core/di/injection.dart`;
one new client-only error code `link_expired`.

## 9. Left to the builder

Widget composition, exact recovery redirect mechanics, cubit state shapes, how the shell shows the
Account entry. Follow `flutter-feature` layout, ADR-007, CLAUDE.md A/B rules.
