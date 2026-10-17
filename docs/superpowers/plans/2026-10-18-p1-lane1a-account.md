# Lane 1a — password reset + My account — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A student can reset a forgotten password on the web, and the shell's Profile tab becomes "My account" (read-only name/email, change password, list/remove own devices, sign out); students can no longer change their own name.

**Architecture:** One small migration (column revoke + `list_my_devices`). Client work stays inside `lib/features/auth` (data → domain → presentation): new repository methods, an `AuthRecovery` state on the app-wide `AuthCubit`, two auth screens, and an `AccountCubit` + screen that replaces the `/profile` placeholder.

**Tech Stack:** Flutter (web/Android/iOS), Cubit, go_router, get_it, `supabase_flutter` ^2.18 (PKCE default), Postgres/pgTAP.

**Spec:** `docs/superpowers/specs/2026-10-18-p1-lane1a-account-design.md` (approved).

**Context:** Lane 1 of the parallel lanes. Worktree `C:/Users/Lenovo/sat-wt-lane1`, branch `feat/P1-lane1-account` (spec at `f7f4a83`). Lane 2b runs at the same time in `sat-wt-lane2` (SQL only; touches `docs/07` rows for quiz/practice RPCs — conflict risk limited to `docs/07`, rebase after whichever merges first). Codex implements via `codex-delegate` in a **new** Codex session (`--cd C:/Users/Lenovo/sat-wt-lane1`); Claude reviews and commits. Flutter gates run locally one lane at a time (`flutter test -j 2`).

## Global Constraints

- CLAUDE.md A + B rules: layers, Cubit only, no codegen, domain imports no `flutter`/`supabase_flutter`, data sources map exceptions to `AppError`, repos return `Result<T>`, DI only in `lib/core/di/injection.dart` (append-only; factories for cubits), go_router only, `const`, controllers in `initState`/`dispose`.
- UI copy English; reuse `AuthCard`, `AuthTextField`, `AuthFooterLink`, `auth_copy.dart`, `CheckInboxScreen`, theme tokens — no new look.
- Password rules = `lib/features/auth/domain/form_rules.dart`.
- Never log email, tokens or fingerprints.
- New client-only error code `link_expired` (`ErrorCodes.linkExpired`); listed in `docs/07` §9 client-only list. No new server codes.
- Reserved: migration `20261018300000_lane1a_account.sql`, test `supabase/tests/30_account.test.sql`, routes `/forgot-password`, `/reset-password`; Profile keeps `/profile`.
- Test names carry the requirement ID (`AUTH-06:`, `AUTH-04:`, `S-34:`). Codex writes the tests (the `*_test.dart` hook is for test-writer and must not block Codex).
- Codex does not commit.

## Review Focus

1. Recovery link opened in a fresh tab while signed out → the code exchange finishes after `AuthCubit.start()` already emitted `AuthSignedOut`; the user must still land on `/reset-password`, not `/sign-in` (cubit test with a late recovery event).
2. Expired/used link (`error_code=otp_expired` in the URL) → Set-new-password is not shown; Forgot-password screen with the expired message (unit test on the URL parser + cubit).
3. In `AuthRecovery`, navigating to `/` or a topic → redirected back to `/reset-password`; device registration not called until `updatePassword` succeeds (cubit + router tests).
4. Forgot password for an unknown email → same success copy as a known one (cubit test: repository returns success either way; the data source never surfaces "user not found").
5. Remove device with `changesLeft == 0` → button disabled with reason; server `device_limit` error still mapped if it happens (cubit test).

---

### Task 0: Land the plan (Claude)

- [ ] Copy to `docs/superpowers/plans/2026-10-18-p1-lane1a-account.md`, commit `docs(P1): lane 1a plan`.

### Task 1: Backend — lock the name, list my devices (AUTH-04)

**Files:** Create `supabase/migrations/20261018300000_lane1a_account.sql`, `supabase/tests/30_account.test.sql`; modify `docs/07-backend-logic-and-api.md` (RPC row).

**Interfaces:**
- Consumes: `public.devices`, `private.active_devices_json` / `remove_device` allowance logic (`20261009000000_auth04_device_limit.sql`), settings `device_changes_30d`.
- Produces: `public.list_my_devices(p_fingerprint text) returns jsonb` → `{devices: [{id, label, platform, last_seen_at, created_at, is_current}], changes_left}`; non-revoked only, `last_seen_at desc nulls last`; fingerprint never returned.

- [ ] **Step 1: Tests** — `AUTH-04: student cannot update own full_name` (`throws_ok` 42501 as authenticated); `AUTH-04: student can still update own phone`; `AUTH-04: sign-up trigger still stores full_name`; `AUTH-04: list_my_devices returns only my non-revoked devices`; `…marks is_current by fingerprint`; `…changes_left equals remove_device's allowance` (2 with no changes, 1 after one removal); `…null/blank fingerprint → invalid_input`; `…anon → not_authenticated / no execute`; grants.
- [ ] **Step 2: Implement** `revoke update (full_name) on public.profiles from authenticated;` + the RPC from `templates/rpc.sql` (compute `changes_left` with the exact expression `remove_device` uses — factor a private helper only if both use it).
- [ ] **Step 3: Verify (Claude)** — draft PR, CI `db` green.

### Task 2: Data + domain (AUTH-06, AUTH-04, S-34)

**Files:** modify `lib/features/auth/data/datasources/auth_remote_data_source.dart`, `device_remote_data_source.dart`, `data/repositories/*_impl.dart`, `domain/repositories/auth_repository.dart`, `device_repository.dart`, `lib/core/errors/error_codes.dart`, `supabase_error_mapper.dart`; create `domain/entities/my_profile.dart`, `domain/entities/my_devices.dart`, `domain/recovery_link.dart`; tests under `test/features/auth/data/` and `test/features/auth/domain/`.

**Interfaces (Produces):**
- `AuthRepository`: `Stream<void> get passwordRecovery` (fires on `AuthChangeEvent.passwordRecovery`), `Future<Result<void>> requestPasswordReset(String email)`, `Future<Result<void>> updatePassword(String password)`, `Future<Result<MyProfile>> getMyProfile()`.
- `MyProfile(fullName: String, email: String)`.
- `DeviceRepository.listMine() → Future<Result<MyDevices>>`; `MyDevices(devices: List<Device>, changesLeft: int)`; `Device` gains `bool isCurrent` (default false) and `DateTime? createdAt` if not present.
- `RecoveryLink.parse(Uri uri) → RecoveryLinkResult` sealed: `RecoveryNone`, `RecoveryRequested` (URL carries the `flow=recovery` marker), `RecoveryExpired` (`error_code` = `otp_expired` / `error` = `access_denied`, query or fragment).
- `ErrorCodes.linkExpired = 'link_expired'` (client-only set).
- `requestPasswordReset` calls `auth.resetPasswordForEmail(email, redirectTo: '${Uri.base.origin}/?flow=recovery')` on web; a GoTrue "user not found" never becomes a failure (Review Focus 4); `rate_limited`/`network` still map.

- [ ] **Step 1: Tests** — data-source tests with the existing fakes (`test/features/auth/data/fakes.dart`) for each new call (success + each mapped failure); `RecoveryLink.parse` table test (marker in query, error in query, error in fragment `#error_code=otp_expired`, plain URL, hash-route URL `/#/sign-in`).
- [ ] **Step 2: Implement.** Before coding, confirm with `read_package_uris`/`rip_grep_packages` how `supabase_flutter` 2.18 on web handles a PKCE `?code=` redirect and which `AuthChangeEvent` it emits for recovery; if it emits `signedIn` instead of `passwordRecovery`, `passwordRecovery` must also fire when the URL marker was present at startup (parse `Uri.base` once in the data source). Report what you found.
- [ ] **Step 3: Verify (Claude)** — `dart format .`, `flutter analyze --fatal-infos`, `flutter test -j 2 test/features/auth test/core`.

### Task 3: Password reset flow (AUTH-06, S-03)

**Files:** modify `presentation/cubit/auth_cubit.dart`, `auth_state.dart`, `auth_copy.dart`, `presentation/screens/sign_in_screen.dart` (add "Forgot password?" link), `check_inbox_screen.dart` (reset variant copy), `lib/core/router/app_router.dart` (+ `AppRoutes`); create `presentation/screens/forgot_password_screen.dart`, `set_new_password_screen.dart`; tests: `test/features/auth/presentation/auth_cubit_test.dart` (extend), screen widget tests at 360 + 1280, `test/core/router/app_router_test.dart` (extend).

**Interfaces:**
- States: `AuthRecovery({AppError? error, bool saving = false})`; `AuthResetLinkSent(email)` (or reuse `AuthConfirmationSent` with a `kind` — pick one, keep email out of `toString`); expired link → `AuthSignedOut(error: AppError(ErrorCodes.linkExpired))` with the router sending it to `/forgot-password`.
- Cubit methods: `requestPasswordReset(String email)`, `setNewPassword(String password)`; recovery subscription started in `start()`, cancelled in `close()`; a recovery event arriving after `AuthSignedOut` switches to `AuthRecovery` (Review Focus 1); `setNewPassword` success → continue the existing signed-in path (device registration) exactly as after sign-in.
- Router: `_signedOutPaths` += `/forgot-password`, `/reset-password`; `AuthRecovery` → only `/reset-password` allowed.
- Copy (exact): Forgot screen title "Reset your password", button "Send reset link", success "If an account exists for that email, we sent a reset link."; Set screen title "Choose a new password", button "Save password"; expired "This link has expired. Request a new one."; sign-in link "Forgot password?".

- [ ] **Step 1: Tests** — every new public cubit method success + failure; Review Focus 1–4 cases; router redirects for `AuthRecovery` and signed-out reset paths; widget tests: form validation, loading, error copy, success copy.
- [ ] **Step 2: Implement.**
- [ ] **Step 3: Verify (Claude)** — format, analyze, `flutter test -j 2`; goldens not required (no new design), but run existing goldens for auth screens if any change.

### Task 4: My account (S-34, AUTH-04)

**Files:** create `presentation/cubit/account_cubit.dart`, `account_state.dart`, `presentation/screens/account_screen.dart` (+ small widgets under `presentation/widgets/`); modify `lib/core/router/app_router.dart` (Profile branch builds `AccountScreen` instead of `PlaceholderScreen`), `lib/core/di/injection.dart` (append `AccountCubit` factory), `docs/setup/auth.md` (§0: add `<site>/?flow=recovery` to Redirect URLs; staging `https://sat-staging.pages.dev`); tests `test/features/auth/presentation/account_cubit_test.dart`, `screens/account_screen_test.dart`.

**Interfaces:**
- Consumes: `AuthRepository.getMyProfile`, `updatePassword`, `signOut` (via `AuthCubit`), `DeviceRepository.listMine`, `remove`.
- `AccountCubit` methods: `load()`, `changePassword(String)`, `removeDevice(String id)`; states sealed: `AccountLoading`, `AccountLoaded(profile, devices, changesLeft, {busy, error, passwordSaved})`, `AccountError(AppError)`; `isClosed` check after awaits.
- Copy (exact): section titles "Profile", "Password", "Devices"; name note "Contact your teacher to change your name."; badge "This device"; allowance "{n} changes left this month" / "No changes left this month"; remove confirm "Remove this device?" / "Remove"; button "Sign out".

- [ ] **Step 1: Tests** — every `AccountCubit` method success + failure (incl. `device_limit`, Review Focus 5); widget: name read-only (no text field), current device has no Remove button, Remove disabled at 0, confirm dialog, sign out calls `AuthCubit.signOut`; layout at 360 and 1280.
- [ ] **Step 2: Implement.**
- [ ] **Step 3: Verify (Claude)** — format, analyze, `flutter test -j 2`; run on web (`flutter run -d chrome --dart-define-from-file=env/dev.json`) against local or staging and click through Forgot → link → Set → Profile; then `/flutter-code-quality:review-gate` and `/flutter-code-review`; mark PR ready.

## Verification (end to end)

- CI on the draft PR (client + db jobs) green.
- Manual on staging after merge (user): add `https://sat-staging.pages.dev/?flow=recovery` to Supabase Redirect URLs (docs/setup/auth.md §0), request a reset from Sign in, open the email link, set a new password, land on the course map; open Profile, see name read-only and devices, remove a second device.
