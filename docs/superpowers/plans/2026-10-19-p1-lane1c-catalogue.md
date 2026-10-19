# Lane 1c — catalogue + course page — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

## Context

A student with no enrolment hits "No course yet", which is a dead end, and visitors have nowhere to see what the courses cover (P-1, PAY-01). The backend has been done since PR #11: `get_catalogue` and `get_course_page` are callable by `anon`. Lane 1c adds the client screens only, with no SQL.

**Spec:** `docs/superpowers/specs/2026-10-19-p1-lane1c-catalogue-design.md` (user: "go"). Decisions D1–D8 live there.
**Worktree:** `C:/Users/Lenovo/sat-wt-lane1c`, branch `feat/P1-lane1c-catalogue` (the spec commit `d1c19d9` is on it).
**Implementer:** Codex through `codex-delegate`, in a new session with `--cd C:/Users/Lenovo/sat-wt-lane1c`. Codex writes the tests too and does not commit. Claude runs the Flutter gates and reviews.

## Global constraints

- CLAUDE.md rules A/B: layers, `Result<T>`, `isClosed` after `await`, `go_router` only, `const`, no codegen, direction-aware content text, layouts at 360 px and 1280 px.
- Lint: `package:` imports, sorted directives, lines of 80 chars or fewer, inferred locals, `--fatal-infos`.
- Shared hotspots: only **append** to `lib/core/di/injection.dart` and `lib/core/router/app_router.dart`.
- Reserved: routes `/catalogue` and `/catalogue/:slug`, feature folder `lib/features/catalogue`. No new error codes: the plan uses `invalid_input` and the existing network/unknown codes.
- Copy (English, exact):

  | Use | Copy |
  |-----|------|
  | Screen title | "Courses" |
  | Card button | "See the syllabus" |
  | Topic count | "{n} topics" |
  | Badge | "Free" |
  | Code link | "Have an activation code?" |
  | App-build note | "Sign in or enter an activation code." |
  | Empty catalogue | "No courses yet" / "Courses will appear here once they're published." |
  | Not found | "Course not found" / "This course isn't available." + "Browse courses" |
  | Entry links | "Browse courses" |

## Review focus

1. No price or purchase wording renders when `Env.enablePurchase` is false. Tests cover both values: inject the flag into the screen or widget, never read `Env` inside a test-hostile path.
2. The router: `/catalogue` and `/catalogue/<slug>` stay put in `AuthSignedOut` and `AuthSignedIn`. Each of `AuthConfirmationSent`, `AuthDeviceGate` and `AuthRecovery` keeps its current redirect. `/catalogue-x` is not treated as public (exact `/catalogue` or the `/catalogue/` prefix).
3. Every price formatting case: `240000` EGP → `EGP 2,400`; `1999` USD → `USD 19.99`; `null` price → row hidden.
4. `invalid_input` from `get_course_page` → "Course not found", not the generic error.

---

### Task 0: Land the plan (Claude)
- [ ] Copy this plan to `docs/superpowers/plans/2026-10-19-p1-lane1c-catalogue.md` and commit it.

### Task 1: Catalogue feature: data + domain + cubits (Codex)

**Files to create** (mirror `lib/features/activation/**` and its tests):
- `domain/entities/`: `CatalogueCourse` (`id`, `slug`, `title`, `description`, `topicCount`, `Price? price`), `CoursePage` (`course` fields + `List<CourseUnit> units`), `CourseUnit` (`title`, `List<SyllabusTopic>`), `SyllabusTopic` (`slug`, `title`, `isFreePreview`, `subtopicCount`), `Price` (`currency`, `amountMinor`).
- `domain/repositories/catalogue_repository.dart`: `getCatalogue()` and `getCoursePage(String slug)`, each returning `Future<Result<…>>`.
- `data/models/…`: hand-written `fromJson` for the RPC shapes in `20261009010000_pay01_catalogue.sql`.
- `data/datasources/catalogue_remote_data_source.dart`: `rpc('get_catalogue', params: {'p_country': null})` and `rpc('get_course_page', params: {'p_slug': slug, 'p_country': null})`. Errors go through the shared mapper `lib/core/errors/supabase_error_mapper.dart`.
- `data/repositories/catalogue_repository_impl.dart`.
- `presentation/cubit/`: `CatalogueCubit.load()` and `CoursePageCubit.load(String slug)`, plus `retry()` on each. The sealed states are `…Loading`, `…Loaded(data)` and `…Failed(AppError)`.

**Modify:** `lib/core/di/injection.dart` (append: lazy-singleton data source and repo, factory cubits).

- [ ] **Step 1: Tests first**: model parsing (full row, null price, empty units/topics), the data source (success, `PostgrestException invalid_input` → `AppError(invalid_input)`, network), the repository, and every cubit method (success + failure, no emit after `close`).
- [ ] **Step 2: Implement.**

### Task 2: Screens, routes, entry points (Codex, after Task 1)

**Create:**
- `presentation/catalogue_copy.dart` (copy table above).
- `presentation/price_format.dart`: `formatPrice(Price)` with the cases from Review focus 3.
- `presentation/screens/catalogue_screen.dart`: a list of course cards. Each card shows the title, the description, "{n} topics", the price (purchase builds only) and "See the syllabus" → `/catalogue/<slug>`.
- `presentation/screens/course_page_screen.dart`: a header (title + description), then the syllabus. Each unit gets a heading, and its topics are numbered `u.t` (D8) with the subtopic count and a **Free** badge when `isFreePreview`. Then the price block (purchase builds only) and the activation CTA. The CTA goes to `/activate` when signed in and to `/sign-up` when signed out (D4); the auth state is read from `AuthCubit` with `context.select`. App builds show the app-build note instead of a price.
- Both screens: `const bool enablePurchase = Env.enablePurchase` as a constructor default, so tests can pass either value. Loading uses `BookletSkeleton`; the error states use `EmptyState` / `ErrorRetry` (`lib/shared/widgets/`). Content text goes through the helper in `lib/core/text/text_direction.dart`. Widgets come from the Booklet tokens (`lib/core/theme/booklet_tokens.dart`); the layout follows "Courses" and the course page in `docs/design/claude-design-export/Public Pages.dc.html`.

**Modify:**
- `lib/core/router/app_router.dart`: `AppRoutes.catalogue` and the routes `/catalogue` and `/catalogue/:slug` (top-level, outside the shell). In `_authRedirect`, add `_isPublic(path)` (exact `/catalogue` or the `/catalogue/` prefix), which returns `null` for `AuthSignedOut` and `AuthSignedIn` (D1).
- `lib/shared/widgets/empty_state.dart`: add an optional `secondaryActionLabel` / `onSecondaryAction` (a text button under the main action). Existing callers stay unchanged.
- `lib/features/course_map/presentation/screens/course_map_screen.dart`: the not-enrolled state keeps "Enter activation code" and adds the secondary "Browse courses" → `/catalogue`.
- `lib/features/auth/presentation/screens/sign_in_screen.dart`: a "Browse courses" link → `/catalogue`, styled like the existing sign-up / forgot-password links.

- [ ] **Step 1: Tests first**:
  - `formatPrice` cases.
  - Widget tests for each screen: loading, empty, error, retry, data; price shown and hidden by the flag; the Free badge; the topic numbering; the CTA target signed in and signed out; "Course not found".
  - `EmptyState` secondary action.
  - The course map not-enrolled actions.
  - The sign-in link.
  - Router tests: Review focus 2.
- [ ] **Step 2: Implement.**

### Task 3: Gates, review, PR (Claude)
- [ ] `dart format .`, `flutter analyze --fatal-infos`, `flutter test -j 2` (from `apps/client`).
- [ ] Read `git diff --stat`, then the hunks against Review focus 1–4.
- [ ] `/flutter-code-review`, then offer `code-reviewer`.
- [ ] Update STATUS (1c row → PR). Commit by path (never `.codex/` / `.impeccable/`), push, open the PR "feat(P1): catalogue + course page (P-1, PAY-01)".
- [ ] Staging check (user, after merge): `https://sat-staging.pages.dev/#/catalogue` signed out, then the course page; "Browse courses" from a not-enrolled account.

## Verification

- Gates green locally, and CI green on the PR.
- Manual: `flutter run -d chrome --dart-define-from-file=env/dev.json`. Open `#/catalogue` signed out, then the demo course `SAT` → syllabus, the Free badge, no price (the flag is false in dev). Run again with `ENABLE_PURCHASE=true` → the price shows. Check at 360 px and 1280 px.
