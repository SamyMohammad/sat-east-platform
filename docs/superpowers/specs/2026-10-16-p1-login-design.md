# P1 slice part 2 — Login + device limit — design

Status: approved 2026-10-16. Parent: [`2026-10-16-p1-slice-demo-seed-design.md`](2026-10-16-p1-slice-demo-seed-design.md) (slice overview, part 2). Stories: `docs/03` A-1 (email only), A-3. Reqs: AUTH-01 (email part), AUTH-04. Tier **L** (`docs/15` §2): new feature with auth, state, routing and three screens.
Design source: `docs/design/claude-design-export/Account and Commerce.dc.html` (S-03 sign-in / sign-up, S-11 device limit).

## Goal
A student can create an account and sign in with email and password on staging. The device is registered on sign-in. A third device is sent to the device-limit screen, and a device removed elsewhere is signed out within one minute. Unauthenticated users are kept on sign-in. This unblocks the course map (part 3).

## Scope (decided 2026-10-16)
- **In:** email sign-up (with full name), sign-in, sign-out, `register_device` on sign-in, the device-limit screen, a periodic device-revocation check, and a go_router auth guard.
- **Out (later in S1):** password reset (AUTH-06), Google sign-in (the button stays hidden until OAuth is set up, per the AUTH-01 decision), onboarding/profile (S-10, AUTH-02), and teacher device tools (AUTH-05, whose backend already exists).
- **Backend:** none planned. It reuses `public.register_device(p_fingerprint, p_platform, p_label) → jsonb`, `public.device_status(p_fingerprint) → text` and `public.remove_device(p_device_id) → jsonb` from `supabase/migrations/20261009000000_auth04_device_limit.sql`, all granted to `authenticated`. If planning finds a gap (for example, no RPC that lists the caller's devices for S-11), the plan adds the smallest RPC following rule 9 and the SQL checklist.

## 1. Structure (`lib/features/auth/`, ADR-007 §4)
```
data/
  datasources/auth_remote_data_source.dart     signUp, signIn, signOut, authStateChanges (supabase_flutter)
  datasources/device_remote_data_source.dart   registerDevice, deviceStatus, removeDevice (RPC)
  datasources/device_id_store.dart             one random UUID per install, kept in hive_ce
  models/…                                     hand-written fromJson (no codegen, B.2)
  repositories/auth_repository_impl.dart, device_repository_impl.dart
domain/
  entities/app_user.dart, device.dart, device_registration.dart (sealed: Allowed | LimitReached(devices) | ChangesExhausted)
  repositories/auth_repository.dart, device_repository.dart   → Result<T> (lib/core/errors/result.dart)
presentation/
  cubit/auth_cubit.dart + auth_state.dart       sealed states
  screens/sign_in_screen.dart, sign_up_screen.dart, device_limit_screen.dart
```
- **Errors:** data sources catch `AuthException`/`PostgrestException` and map them to `AppError` with `docs/07` §9 codes, for example invalid credentials, email not confirmed, the device limit and its allowance, and network errors. Presentation maps the codes to English copy and never shows raw exception text.
- **DI:** register everything in `lib/core/di/injection.dart`. Repositories and data sources are lazy singletons, and `AuthCubit` is a singleton because it is app-wide auth state the router reads. That is the one stated exception to "factories for cubits", recorded in the plan.
- **Device label/platform:** `platform` is `web`, `android` or `ios`. `label` is a readable string such as "Chrome on Windows" when it is cheap to derive, otherwise the platform name. No new package without justification (A.5).

## 2. Flow
- **App start:** if Supabase has a restored session, run the device check (below). Otherwise the state is signed out.
- **Sign-up:** send email, password and full name (`options.data.full_name`, which `private.handle_new_user` reads).
  - Confirmation on (staging/prod): show "Check your email to confirm your account", then go to sign-in.
  - Confirmation off (local dev): continue as for sign-in.
- **Sign-in, then device registration:** `register_device(fingerprint, platform, label)`.
  - **Allowed:** the state is signed in, and the router goes to `/`.
  - **Limit reached:** the state is needs-device-removal with the device list, and the router goes to `/devices`. Removing a device calls `remove_device`, then retries registration.
  - **Changes exhausted** (no changes left this month): show "You've used your device changes for this month. Contact your teacher.", then sign out.
  - The exact response shape of `register_device` / `remove_device` comes from the migration and is confirmed in the plan.
- **Revocation check:** while signed in, call `device_status(fingerprint)` every 60 s and when the app resumes (`AppLifecycleListener`). A revoked device signs out with the message "This device was removed from your account." The timer lives in the Cubit with an injected clock/ticker, so tests are deterministic (A.7). It is cancelled in `close()`.
- **Sign-out:** `signOut`, then the router goes to `/sign-in`.
- **Router guard** (`lib/core/router/app_router.dart`, `redirect` + `refreshListenable` from the Cubit stream):
  - signed out → `/sign-in` or `/sign-up` only;
  - needs-device-removal → `/devices` only;
  - signed in → the shell routes. `/sign-in` redirects to `/`.
  - `/gallery` stays reachable outside prod regardless of auth.

## 3. UI (English copy, Booklet theme, 360 and 1280)
- **Sign in:** email, password, the "Sign in" primary button, and a "Create an account" link. Show inline field validation (UX only; the server re-validates) and a loading state on the button.
- **Sign up:** full name, email, password (min 8), "Create account", and a "Have an account? Sign in" link.
- **Device limit (S-11):** the copy explains the 2-device limit. The list shows each device's label, platform and last seen time, with a "Remove" action per device behind a confirm dialog (`showBookletDialog`). It also shows remaining changes this month if the RPC returns it, and a "Sign out" secondary action.
- Controllers and focus nodes are created in `initState` and disposed (B.7). `BlocBuilder`/`BlocSelector` wrap the smallest subtree.

## 4. Testing (`docs/15`, CLAUDE.md A.7; test files by `test-writer`)
- **Data:** each data source maps success and each error to the right `AppError` code, using faked Supabase clients/RPC responses. `DeviceIdStore` generates once and returns the same id afterwards.
- **Repositories:** return `Success`/`Failure`.
- **Cubit** (`bloc_test`):
  - every public method, success and failure;
  - sign-in that is allowed, hits the limit, or has no changes left;
  - remove then re-register;
  - the revocation tick signing out, using a fake clock;
  - resume triggering a check;
  - `close()` cancelling the timer.
- **Widgets:** the three screens at 360 and 1280. Check validation, loading, error copy, the remove confirm and the sign-out.
- **Router:** each guard redirect, including `/gallery` staying reachable signed out.
- **No real network, no real timers.**

## Done when
- `dart format`, `flutter analyze --fatal-infos` and `flutter test` are clean, and CI is green.
- On staging (`https://sat-staging.pages.dev/#/sign-in`), the following are checked by hand:
  - a new account confirms by email and signs in;
  - a third browser profile hits the device screen;
  - removing a device lets you in;
  - the removed session signs out within about a minute;
  - the new student has the demo enrolment from part 1.
- `docs/STATUS.md` is updated.

## Deltas from planning (2026-10-16)
1. **No backend change.** S-11 at sign-in uses `register_device`'s `limit_reached` payload: `devices[{id, platform, label, last_seen_at}]` and `changes_left`. The "manage devices" page (not at sign-in) is deferred, and so is a "list my devices" RPC. RLS already allows `select` on own `devices` rows if that page is built later.
2. **Exact RPC contract** (`supabase/migrations/20261009000000_auth04_device_limit.sql`):
   - **`register_device`** returns either `{"status":"ok","device_id"}` or `{"status":"limit_reached","devices":[…],"changes_left":int}`. It raises `not_authenticated` or `invalid_input`. The fingerprint must match `^[A-Za-z0-9_-]{16,128}$`, the platform must be one of `web|android|ios`, and the label is at most 80 characters.
   - **`remove_device`** returns `{"changes_left":int}`. It raises `forbidden` (not yours, or already revoked) or `device_limit` (no changes left).
   - **`device_status`** returns `'active'`, `'revoked'` or `'unknown'` as text.
   - Exceptions reach the client as `PostgrestException.message` equal to the code.
3. **The device is registered on every sign-in and on session restore**, which also refreshes `last_seen_at`. `device_status` is used only for the 60-second and app-resume revocation checks:
   - `'revoked'` → sign out with reason `deviceRemoved`;
   - `'unknown'` → register again;
   - `'active'` → do nothing.
4. **The App Check Edge Function `register-device` (docs/07) is not used yet.** The client calls the RPC directly, and the Edge Function arrives with App Check enforcement later.
5. **Client-side auth codes** are added to `docs/07` §9 as a separate "client-only (GoTrue / transport)" list:
   - `invalid_credentials`, `email_not_confirmed`, `email_taken`, `weak_password` and `network`;
   - `rate_limited` reuses the existing code.
6. **Hidden in this part** (out of scope): "Continue with Google", "Forgot password?" and "Contact support". The no-changes-left gate shows "Contact your teacher" text instead.
