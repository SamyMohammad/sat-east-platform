# P1 part 3 — Course map Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development (router dispatches `implementer` per task, reviews each diff). Steps use `- [ ]`.
> On approval this file is copied to `docs/superpowers/plans/2026-10-17-p1-course-map.md` and committed on `feat/P1-course-map`.

**Goal:** Enrolled student opens the Courses tab and sees the demo course map (continue card + topics as completed / open / locked), with lock state computed only by a new RPC.

**Architecture:** One `security definer` RPC `public.get_course_map(p_slug text default null) → jsonb` applies the `docs/07` §2 state machine for `auth.uid()`. New client feature `lib/features/course_map/` (data → domain → presentation, Cubit) renders it on the `/courses` shell branch; a topic stub at `/courses/topics/:topicId`. Plus part-2 carry-over: shell splash while auth is unknown/busy, AuthCubit hardening.

**Tech stack:** Postgres/plpgsql + pgTAP, Flutter, flutter_bloc, get_it, go_router, supabase_flutter, bloc_test + mocktail.

**Spec:** `docs/superpowers/specs/2026-10-17-p1-course-map-design.md` (approved). Tier **L**.

## Context
Part 2 (login, #27) is merged. Part 3 makes the student's next step visible and is the entry point for part 4 (practice, replaces the stub). `get_course_page` is public catalogue data with no per-student state, so a new RPC is needed.

## Global Constraints
- Errors raised as `raise exception '<code>'` (P0001), codes from `docs/07` §9: `not_authenticated`, `invalid_input`, `not_enrolled`, `access_expired`.
- RPC: start from `supabase/templates/rpc.sql`; `set search_path = ''`, fully qualified names; `auth.uid()` null check on first line; `revoke execute … from public, anon; grant execute … to authenticated` only; passes `supabase/templates/README.md` 9-item checklist.
- No map without an active enrolment (user decision): status ≠ `active` or `expires_at <= now()` → `access_expired`, no free-topic fallback.
- Null slug → caller's enrolment of **any** status with latest `starts_at`.
- Client never computes lock state. No codegen; hand-written `fromJson`. Domain imports no flutter/supabase. Cubit depends on repository interface. `isClosed` check after await.
- UI copy English, exact strings in Task 5. Check 360 px and 1280 px.
- Test names prefixed `L-1` (story) / `LRN-01`; commits `feat(P1): …` / `test(P1): …`.

## Review Focus
1. **Unpublished topic between two published ones** → skipped for "previous" and `sort_label` (Task 1 test: C's `after_title` is B, label 1.3).
2. **Another student's progress** must not leak into the caller's statuses (Task 1 test with students a/b).
3. **Course with zero published topics / units with none** → unit hidden; `units: []` renders an empty-course message, not a crash (Task 1 test U3 hidden; Task 5 widget test "empty course").
4. **Null `continue`** (all completed or all locked) → no continue card, list still shown (Task 1 + Task 3 model test + Task 5 widget test).
5. **Cold deep link to `/courses/topics/<id>`** with no `extra` → stub shows "Topic", no crash (Task 5 router test).

---

### Task 1: RPC `get_course_map` + pgTAP + docs/07

**Files:**
- Create: `supabase/migrations/20261017000000_lrn01_course_map.sql` (from `supabase/templates/rpc.sql`)
- Create: `supabase/tests/15_course_map.test.sql` (from `supabase/templates/test.sql`; pattern of `14_catalogue.test.sql`)
- Modify: `docs/07-backend-logic-and-api.md` §1 table (new row) and §2 (one line: "`get_course_map` is the read side of this state machine")

**Produces:** `public.get_course_map(p_slug text default null) returns jsonb`, shape exactly as spec §1:
```json
{"course":{"id","slug","title"},
 "continue":{"topic_id","slug","title","unit_title"}|null,
 "units":[{"title":text|null,"topics":[{"id","slug","title","sort_label","is_free_preview","status":"completed|open|locked","locked_reason":null|"previous_quiz","after_title":null|text}]}]}
```

**Algorithm (not determined by tests alone):**
1. `v_uid` null → `not_authenticated`.
2. Resolve course: slug given → published course by slug else `invalid_input`; then the caller's enrolment for it, none → `not_enrolled`. Slug null → caller's enrolment (any status) `order by starts_at desc limit 1`, none → `not_enrolled`; its course must be published else `invalid_input`.
3. Enrolment `status <> 'active' or expires_at <= now()` → `access_expired`.
4. One CTE over published topics of the course, left-joined to `units` and to `topic_progress` **for `v_uid` only**. Course order: units with a unit first, by `u.sort, u.title`, then unit-less topics; inside by `t.sort, t.title`. Compute `pos = row_number()` over course order, `done = quiz_passed_at is not null`, `prev_done = lag(done)`, `prev_title = lag(title)`, `unit_no = dense_rank()` over shown units, `topic_no = row_number() over (partition by unit_id …)`.
5. Status: `done` → completed; else `pos = 1 or is_free_preview or prev_done or unlocked_at is not null` → open; else locked with `locked_reason='previous_quiz'`, `after_title=prev_title`.
6. `sort_label`: `unit_no || '.' || topic_no`; unit-less → `topic_no::text`. Unit-less group emitted last with `"title": null`.
7. `continue` = first open topic in course order, else null.

- [ ] **Step 1: Write pgTAP test** `15_course_map.test.sql`. Fixture (fixed UUIDs, inserted as `reset role`): course `cm` (published, slug `cm-course`) with unit U1 (sort 1): A(sort1), B(2), X(3, **unpublished**), C(4); U2 (sort 2): D(1, `is_free_preview`); unit-less E(1); U3 (sort 3) with only an unpublished topic. Course `cm2` published (slug `cm2-course`) with one topic; course `cm-hidden` unpublished. Students via `tests.create_supabase_user`: `a`, `b` active enrolments on cm (expires +30d); `c` expired status; `e` refunded; `f` active but `expires_at = now() - 1 day`; `d` no enrolment; `g` older active enrolment on cm2 + newer (`starts_at` later) expired on cm. Assertions (descriptions prefixed `L-1:`):
  - anon `select public.get_course_map('cm-course')` → `throws_ok(…,'42501',null,…)`
  - `clear_authentication(); set local role authenticated;` → `'P0001','not_authenticated'`
  - as a: `'nope'` and `'cm-hidden'` slugs → `invalid_input`
  - as d: null slug and `'cm-course'` → `not_enrolled`
  - as c, e, f (null slug) → `access_expired`; as g null slug → `access_expired` (latest any-status wins)
  - as a, fresh: statuses `A open, B locked, C locked, D open, E locked`; C `after_title = 'B'`; B `after_title='A'`, `locked_reason='previous_quiz'`; labels `A 1.1, B 1.2, C 1.3, D 2.1, E 1`; `jsonb_array_length(units) = 3`, last unit title null; X not present; `continue.slug = A`
  - insert `topic_progress(a, A, quiz_passed_at=now())` → A completed, B open, `continue.slug = B`, A `locked_reason` null
  - as b after that: B still locked
  - `topic_progress(a, C, unlocked_at=now())` → C open
  - mark A–E passed for a → `continue` is JSON null
  Use a helper SQL expression like `(public.get_course_map('cm-course')#>>'{units,0,topics,1,status}')` with `is(…)`.
- [ ] **Step 2:** `scripts/db-test.ps1` → new file FAILS (function missing).
- [ ] **Step 3:** Write the migration per algorithm above.
- [ ] **Step 4:** `scripts/db-reset.ps1` (or `supabase migration up --local` workaround per STATUS) then `scripts/db-test.ps1` → all pass; `supabase db lint` no new issues.
- [ ] **Step 5:** docs/07 edits. Commit `feat(P1): get_course_map RPC (L-1)`.

### Task 2: Core prep — error codes, shared RpcCaller, shared FakeRpc

**Files:**
- Modify: `apps/client/lib/core/errors/error_codes.dart` — add `notEnrolled='not_enrolled'`, `accessExpired='access_expired'`, `topicLocked='topic_locked'` and include them in `_serverCodes`.
- Create: `apps/client/lib/core/supabase/rpc_caller.dart` — move `typedef RpcCaller` here (A.2: now used by 2 features); update import in `features/auth/data/datasources/device_remote_data_source.dart` and DI.
- Move: `FakeRpc` from `test/features/auth/data/fakes.dart` to `test/core/fakes/fake_rpc.dart`; update auth test imports.
- Test: existing mapper test under `test/core/errors/` (add cases).

- [ ] Step 1: test `L-1: mapPostgrestException keeps not_enrolled / access_expired / topic_locked` (PostgrestException(message: code) → `AppError(code)`). Run → FAIL.
- [ ] Step 2: implement; move typedef + fake. `flutter test` → all pass (auth tests unchanged behaviour).
- [ ] Step 3: commit `feat(P1): server codes for course access; share RpcCaller`.

### Task 3: Domain + data

**Files:**
- Create `lib/features/course_map/domain/entities/course_map.dart`:
  `enum TopicStatus { completed, open, locked }`; `sealed class LockReason` + `final class PreviousQuiz(String afterTitle)`; `CourseMap({courseId, slug, title, ContinueTopic? continueTopic, List<MapUnit> units})`; `ContinueTopic({topicId, slug, title, String? unitTitle})`; `MapUnit({String? title, List<MapTopic> topics})`; `MapTopic({id, slug, title, sortLabel, isFreePreview, status, LockReason? lockReason})`. All `Equatable`.
- Create `domain/repositories/course_map_repository.dart`: `abstract interface class CourseMapRepository { Future<Result<CourseMap>> getCourseMap({String? slug}); }`
- Create `data/models/course_map_model.dart`: `CourseMap courseMapFromJson(Map<String,Object?> json)` — throws `FormatException` on missing/unknown fields (unknown status, `previous_quiz` without `after_title`).
- Create `data/datasources/course_map_remote_data_source.dart`: `CourseMapRemoteDataSource(RpcCaller rpc)`; `Future<Result<CourseMap>> getCourseMap({String? slug})` calls `rpc('get_course_map', {if (slug != null) 'p_slug': slug})`; same catch ladder as `DeviceRemoteDataSource._call` (Postgrest → mapper, FormatException → internal "malformed rpc payload", other → `mapUnknownError`).
- Create `data/repositories/course_map_repository_impl.dart` (delegates).
- Modify `lib/core/di/injection.dart`: lazy singletons for data source (`getIt<SupabaseClient>().rpc(fn, params: params)`) and `CourseMapRepository`.
- Tests: `test/features/course_map/data/course_map_model_test.dart`, `course_map_remote_data_source_test.dart` (use `FakeRpc`).

- [ ] Step 1 tests: parses the spec example (all three statuses, `PreviousQuiz('A')`, unit-less `title: null`, `sortLabel '2.1'`); `continue: null` → `continueTopic == null`; unknown status → FormatException; data source: passes `{}` for null slug and `{'p_slug':'x'}` otherwise; `PostgrestException('not_enrolled')` → `Failure(AppError('not_enrolled'))`; malformed payload → `Failure(internal)`; SocketException → `network`. Run → FAIL.
- [ ] Step 2 implement; `flutter test test/features/course_map` → PASS. Commit `feat(P1): course map data layer`.

### Task 4: Cubit

**Files:** `presentation/cubit/course_map_state.dart` (sealed: `CourseMapLoading`, `CourseMapLoaded(CourseMap map)`, `CourseMapFailed(AppError error)`, Equatable), `presentation/cubit/course_map_cubit.dart` (`CourseMapCubit(CourseMapRepository)`, initial `CourseMapLoading`; `Future<void> load()` emits Loading then Loaded/Failed, `isClosed` check after await; `Future<void> retry() => load()`). DI: `registerFactory<CourseMapCubit>`.
- [ ] Tests `test/features/course_map/presentation/course_map_cubit_test.dart` (blocTest + mocktail): load success → [Loading, Loaded]; load each of `not_enrolled`, `access_expired`, `network` → [Loading, Failed(code)]; retry after failure → Loaded; close during in-flight load emits nothing after close. FAIL → implement → PASS. Commit.

### Task 5: Screens, widgets, routing

**Files:**
- `presentation/screens/course_map_screen.dart`: `CourseMapScreen` = `BlocProvider(create: (_) => getIt<CourseMapCubit>()..load(), child: CourseMapView())`; `CourseMapView` reads state (testable with a mock cubit). Loading → `BookletSkeleton`; Loaded → scrollable column within `BookletSize.readingColumn`: course title, `ContinueCard` if any, per unit a section header (null title → no header) + `TopicRow`s; `units` empty → `EmptyState` "This course has no topics yet."; Failed → see copy.
- `presentation/widgets/continue_card.dart`, `widgets/topic_row.dart` (BookletSpace/BookletColors tokens; completed = `greenTick` check; open = primary highlight + chevron; locked = lock icon, `inkDisabled`, not tappable, lock message line; free → `BookletChip` "Free"). `Semantics(label: '<sortLabel> <title>, <completed|open|locked>')`.
- `presentation/course_map_copy.dart` (exact strings):
  - continue eyebrow `Continue where you left off`, button `Continue`
  - lock line `Pass the $afterTitle quiz to unlock`
  - `not_enrolled` → `EmptyState` title `No course yet`, body `You're not enrolled in a course yet.`
  - `access_expired` → `EmptyState` title `Access ended`, body `Your access has ended. Contact your teacher.`
  - `network` → `ErrorRetry` title `Couldn't load your course`, body `Check your connection and try again.`; any other code → same title, body `Something went wrong. Try again.`
- `presentation/screens/topic_stub_screen.dart`: `TopicStubScreen({String? title})` shows `title ?? 'Topic'` and `Practice is coming next.`
- `lib/core/router/app_router.dart`: `AppRoutes.topic(String id) => '/courses/topics/$id'`; in the branch loop, `courses` builds `CourseMapScreen()` and gets child `GoRoute(path: 'topics/:topicId', builder: TopicStubScreen(title: state.extra as String?))`; others unchanged. Rows navigate with `context.go(AppRoutes.topic(t.id), extra: t.title)`; continue card the same.
- Tests: `test/features/course_map/presentation/course_map_view_test.dart` (mock cubit): three row states render and semantics labels; locked tap does not navigate; open tap goes to `/courses/topics/<id>`; continue card hidden when null; each error/empty copy; Retry calls `retry()`; at 360×800 and 1280×800 no overflow. Router test in `test/core/router/app_router_test.dart`: `/courses/topics/x` cold → shows "Topic".
- [ ] FAIL → implement → PASS → `dart format .`, `flutter analyze --fatal-infos`. Commit `feat(P1): course map screen (L-1)`.

### Task 6: Shell splash while auth unknown/busy (carry-over 1)

**Files:** Create `lib/shared/widgets/app_splash.dart` (`AppSplash`: centered `BookletProgress`/logo, semantics "Loading"). Modify `createRouter`: when `auth != null`, the shell builder wraps with `BlocSelector<AuthCubit, AuthState, bool>(bloc: auth, selector: (s) => s is AuthUnknown || s is AuthBusy, builder: (_, busy) => busy ? const AppSplash() : AppShell(...))`. Without `auth` unchanged.
- [ ] Test `test/core/router/auth_guard_test.dart`: with auth state `AuthUnknown` at `/courses` → `AppSplash` shown and `CourseMapScreen` not in tree; switch to `AuthSignedIn` → shell shown. FAIL → implement → PASS. Commit `fix(P1): splash on shell paths while auth is unknown`.

### Task 7: AuthCubit hardening + router assert (carry-over 2)

**Files:** `features/auth/presentation/cubit/auth_cubit.dart`, `lib/core/router/app_router.dart`, tests `test/features/auth/presentation/auth_cubit_test.dart`, `test/core/router/app_router_test.dart`.
- `_onUserChanged` passes `_session` to `_sessionLost(int gen)`; `_sessionLost` returns if `_stale(gen)`, then `_invalidateInFlight()`, captures the new `_session`, and after its awaits returns if stale before emitting.
- `createRouter`: `assert(refresh == null || auth != null, 'refresh requires auth')`.
- [ ] Tests: two null `userChanges` events back-to-back while signed in → exactly one `AuthSignedOut` and `clearUser` called once; null `userChanges` during in-flight `signIn` (state `AuthBusy`) → ends `AuthSignedIn`, no `AuthSignedOut`; `createRouter(refresh: ValueNotifier(0))` → `throwsAssertionError`. FAIL (first) → implement → PASS. Commit `fix(P1): AuthCubit stale session-loss guard; router refresh assert`.

### Task 8: Docs, gates, PR
- [ ] `docs/STATUS.md`: Now row → part 3 in review with spec/plan/branch/PR; move part 2 to Done (#27); remove the two carry-over Open items; add Open "Staff course preview — teachers see not_enrolled on Courses".
- [ ] `/flutter-code-quality:review-gate` (format, analyze, tests) → clean. `scripts/db-test.ps1` → pass. `scripts/api-private-check.ps1` → pass.
- [ ] `/security-review` on the migration; `/flutter-code-review`; offer `code-reviewer`.
- [ ] `git-expert`: push `feat/P1-course-map`, PR `feat(P1): course map (L-1)`; `gh pr checks --watch` green.
- [ ] `graphify update .`

## Verification (end-to-end)
- Local: `scripts/db-up.ps1`, seed demo (`scripts/db-seed-demo.ps1`), `flutter run -d chrome --dart-define-from-file=env/dev.json`, sign in as an enrolled student → Courses: "SAT Math (Demo)", Continue → Linear Equations, 1.1 open + Free, 1.2/1.3 locked with "Pass the … quiz to unlock"; tap 1.1 → stub; tap locked → nothing. 360 px and 1280 px.
- Staging after merge: same check (user confirms).
