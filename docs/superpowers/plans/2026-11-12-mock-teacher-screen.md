# Mock exams teacher screen (MCK-03, T-14 reduced) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

## Context

Part 1 (assembly server, #87) is merged and staging-checked: the seven `teacher_*mock*` RPCs work, but only through SQL. Part 2 gives the teacher a "Mock exams" page in the teacher area to assemble a form, read the shortage report, review the 66 questions, swap one, delete a draft and publish. Spec: `docs/superpowers/specs/2026-11-12-mock-sat-design.md` "Part 2 — Teacher screen". Server contract: `docs/07-backend-logic-and-api.md` §1.1 rows `teacher_mock_*` / `teacher_*_mock_*`.

**Goal:** A teacher-only Flutter page that drives the Part 1 RPCs end to end, following the existing teacher-area patterns.

**Architecture:** New sub-feature `apps/client/lib/features/teacher/mock/` (data / domain / presentation) like `teacher/questions`. Two screens with their own `go_router` routes: a list page (overview) and a form detail page. Two Cubits (overview, form). Question preview reuses `teacher_get_question` through the existing questions repository and a preview widget extracted from the editor.

**Tech Stack:** Flutter, Cubit (`flutter_bloc`), `get_it`, `go_router`, `supabase_flutter` RPC via `RpcCaller`. No new packages. No SQL.

**Spec:** `docs/superpowers/specs/2026-11-12-mock-sat-design.md` (Part 2).

## Global Constraints

- CLAUDE.md sections A and B: layers presentation → domain → data; domain imports no Flutter or Supabase; Cubits depend on domain repository interfaces only; sealed states + exhaustive `switch`; hand-written JSON parsing as top-level functions (style of `teacher/questions/data/models/bank_models.dart`); DI only in `lib/core/di/injection.dart` (lazy singletons for data source/repo, factories for Cubits); `go_router` only; `const` wherever possible; check `isClosed` after every `await`.
- Data sources take an `RpcCaller` and use the `_call` pattern of `question_bank_remote_data_source.dart` (catch `PostgrestException` → `mapPostgrestException`, `FormatException` → `internal`, other → `mapUnknownError`).
- English-only UI copy, in a feature `mock_copy.dart` (style of `bank_copy.dart` / `course_builder_copy.dart`). Never show raw exception text.
- Visuals from `DESIGN.md` and `lib/shared/widgets/` (`AppDialog`, `EmptyState`, `ErrorRetry`, `AppSkeleton`, `AppBanner`, `AppChip`, `LoadingButton`). No new design tokens.
- The page never shows a key or explanation except inside the single-question preview (which uses the teacher-only `teacher_get_question`).
- Web checked at 360 px and 1280 px.
- Test names carry requirement IDs (`MCK-03: ...`). Tests are written first by the implementer. Fakes: `FakeRpc` (`test/core/fakes/fake_rpc.dart`) for data sources; hand-written fake repos or mocktail for Cubits.
- Do not commit. Never stage `.codex/`, `.impeccable/`, `.vscode/`, `.wrangler/`, `content/`.
- Gates (from `apps/client/`): `dart format .` (then `git status` — revert any untouched files it reformatted), `flutter analyze --fatal-infos`, `flutter test -j 2`.

## Router calls (decided here, not by the owner)

1. **Course:** the page loads `teacher_list_courses` (existing `CourseBuilderRepository.listCourses()`, returns `code`) and uses the course whose `code == 'SAT'`. No SAT course → an `EmptyState` "No SAT course yet". It never falls back to "first course" (EST would raise `invalid_input`).
2. **Readiness:** no server change. The page shows "Ready to assemble a form" when `next_form.missing` is empty, else the shortage list (cell, needed, available, per-module counts) plus `no_domain` ("N mock questions have no single SAT domain"). The 19-cell `need_per_form` table is shown collapsed as "What one form needs".
3. **Set number:** an "Assemble form" button opens a dialog with a set picker: existing set numbers plus "next set", default set 1.
4. **Results that are not errors** are sealed success types: `AssembleResult = Assembled(setNo, formNo) | Shortage(missing, noDomain)` and `PublishResult = Published | Stale(questionIds)`.
5. **Routes:** `/teacher/mock-exams` (overview) and `/teacher/mock-exams/:setNo/:formNo` (detail), both inside `TeacherShell`, so refresh and back work.
6. **Published forms:** detail page is read-only — no swap, delete or publish; preview still works.
7. **Preview:** tapping a question loads it on demand through the existing `QuestionEditorRepository.get(id)` (`teacher_get_question`). The draft → `QuestionView` mapping in `editor_preview.dart` is extracted into a reusable `TeacherQuestionPreview` widget under `features/teacher/questions/presentation/widgets/`, used by both the editor and the mock page. Both are sub-modules of the one teacher feature, so this stays inside it (CLAUDE.md A.2).
8. **Nav:** a fifth teacher destination "Mock exams" (`AppIcons.mockExams`) after "Questions".

## Review Focus

1. **Server says the form is already published** (another tab published it): swap/delete/publish show "This form is already published" and reload, not "Something went wrong" → Task 1 adds `mock_form_published` to the client error codes; Task 3 tests the copy.
2. **Stale publish**: the stale questions are visibly marked on the detail page and the teacher can swap them; publishing again after the swap succeeds (Task 4).
3. **Shortage**: assembling with a short bank shows the shortage list and does not navigate to a form (Task 3).
4. **Deep link to a form that no longer exists** (deleted draft, refresh): detail page shows an `EmptyState`/`ErrorRetry` with a way back, not a blank page (Task 4).
5. **No SAT course / teacher without data**: overview shows an empty state, no RPC with a null course id (Task 3).

---

### Task 0: Worktree and plan copy (router)

- [ ] Worktree `C:/Users/Lenovo/sat-wt-mock2` on `feat/MCK-03-mock-teacher-screen` from `origin/main` (`git -c core.longpaths=true worktree add`).
- [ ] Copy this plan to `docs/superpowers/plans/2026-11-12-mock-teacher-screen.md`, commit (ends with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`), push, open a **draft** PR `feat(mock): MCK-03 teacher mock exams screen`.

### Task 1: Data and domain

**Files:**
- Modify `apps/client/lib/core/errors/error_codes.dart` (add `mockFormPublished = 'mock_form_published'` to the constants and to `isServerCode`).
- Create `features/teacher/mock/domain/entities/mock_entities.dart`, `domain/repositories/teacher_mock_repository.dart`, `data/models/mock_models.dart`, `data/datasources/teacher_mock_remote_data_source.dart`, `data/repositories/teacher_mock_repository_impl.dart`.
- Tests: `test/core/errors/` (mapper case), `test/features/teacher/mock/data/teacher_mock_remote_data_source_test.dart`, `test/features/teacher/mock/mock_fixtures.dart`.

**Interfaces — Produces** (domain, plain Dart, `Equatable` where the codebase does):
- `MockCell(domain, difficulty, type, count)`; `MockShortageCell(domain, difficulty, type, needed, available, Map<String,int> modules)`
- `MockFormSummary(setNo, formNo, status: MockFormStatus {draft, published}, publishedAt?)`
- `MockOverview(templateName, List<MockCell> needPerForm, List<MockFormSummary> forms, List<MockShortageCell> missing, int noDomain)` with getter `bool get canAssemble => missing.isEmpty`
- `MockSlot(slotNo, questionId, externalRef, type, difficulty, domain, stemMd)`; `MockModule(name, List<MockSlot> slots)`; `MockForm(setNo, formNo, status, publishedAt?, List<MockModule> modules)`
- `MockCandidate(id, externalRef, stemMd)`
- `sealed class AssembleResult` → `Assembled(setNo, formNo)`, `Shortage(List<MockShortageCell> missing, int noDomain)`
- `sealed class PublishResult` → `Published()`, `Stale(List<String> questionIds)`
- `abstract interface class TeacherMockRepository`:
  - `Future<Result<MockOverview>> overview(String courseId)`
  - `Future<Result<AssembleResult>> assemble(String courseId, int setNo)`
  - `Future<Result<MockForm>> form(String courseId, int setNo, int formNo)`
  - `Future<Result<List<MockCandidate>>> candidates(String courseId, int setNo, int formNo, String questionId)`
  - `Future<Result<void>> swap(String courseId, int setNo, int formNo, String oldId, String newId)`
  - `Future<Result<void>> deleteDraft(String courseId, int setNo, int formNo)`
  - `Future<Result<PublishResult>> publish(String courseId, int setNo, int formNo)`
- RPC names and params exactly as `docs/07` §1.1 (`p_course_id`, `p_set_no`, `p_form_no`, `p_question_id`, `p_old_id`, `p_new_id`).

- [ ] **Step 1: Failing tests:** mapper turns `PostgrestException(message: 'mock_form_published')` into `AppError('mock_form_published')`. For each repository method with `FakeRpc`: the exact RPC name and params map; JSON → entities for the shapes in `docs/07` (fixtures copied from the Part 1 staging output: 19 `need_per_form` cells, 3 modules × 22 slots); `{ok:false, missing, no_domain}` → `Shortage`; `{ok:false, stale:[…]}` → `Stale`; a malformed payload → `Failure(internal)`; `PostgrestException('forbidden')` → `Failure(forbidden)`.
- [ ] **Step 2:** `flutter test test/features/teacher/mock test/core/errors` → fails.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Tests pass; `flutter analyze --fatal-infos` clean.
- [ ] **Step 5:** Report (no commit).

### Task 2: Shared preview widget

**Files:** create `features/teacher/questions/presentation/widgets/teacher_question_preview.dart`; modify `editor_preview.dart` to use it; test `test/features/teacher/questions/presentation/teacher_question_preview_test.dart`.

**Produces:** `class TeacherQuestionPreview extends StatelessWidget { const TeacherQuestionPreview({required QuestionDraft draft, String title = 'Preview'}); }` — exactly the `QuestionView` built today in `editor_preview.dart` (practice mode, correct feedback with the explanation, `showNavigation: false`).

- [ ] Failing widget test: renders the stem, the four choices of an MCQ draft and the explanation; SPR draft renders without choices.
- [ ] Implement; `EditorPreview` becomes a `BlocSelector` around `TeacherQuestionPreview`. Existing editor tests and goldens stay green unchanged.
- [ ] Gates; report.

### Task 3: Overview page (list, readiness, assemble)

**Consumes:** Task 1 repository; `CourseBuilderRepository.listCourses()`.

**Files:** `presentation/cubit/mock_overview_cubit.dart` + `_state.dart`, `presentation/screens/mock_overview_screen.dart`, `presentation/widgets/` (readiness card, shortage list, forms list, assemble dialog), `presentation/mock_copy.dart`; router constants + `GoRoute` in `lib/core/router/app_router.dart`; fifth entry in `teacher_bottom_navigation.dart` (`teacherDestinations` + `teacherDestinationIndex`); DI block in `injection.dart`. Tests under `test/features/teacher/mock/presentation/`.

**Produces:**
- `AppRoutes.teacherMockExams = '/teacher/mock-exams'`, `static String teacherMockForm(int setNo, int formNo)`.
- `sealed class MockOverviewState` → `MockOverviewLoading`, `MockOverviewNoCourse`, `MockOverviewLoaded(courseId, overview, {busy = false, AppError? lastError, Shortage? lastShortage})`, `MockOverviewFailed(AppError)`.
- `MockOverviewCubit(TeacherMockRepository, CourseBuilderRepository)`: `load()`, `assemble(int setNo) → Future<Assembled?>` (returns the new form so the screen navigates; on `Shortage` stores it in state and reloads), `retry()`.
- `String mockErrorCopy(String code)`: `forbidden`, `invalid_input` ("This form no longer exists. Refresh the page."), `mock_form_published` ("This form is already published."), default.

- [ ] **Step 1: Failing tests** (Cubit, fakes): load picks the `SAT` course among `[EST, SAT]`; no SAT → `MockOverviewNoCourse` and no mock RPC call; load failure → `MockOverviewFailed`; assemble success → returns `Assembled` and reloads; assemble shortage → `lastShortage` set, returns null; assemble failure → `lastError` set, state stays loaded. Widget tests: ready vs shortage rendering, forms list shows status chip per form, tapping a form navigates to `teacherMockForm`, assemble dialog defaults to set 1 and offers "next set". Router test: a student is redirected away from `/teacher/mock-exams`.
- [ ] **Step 2:** Run → fail. **Step 3:** Implement. **Step 4:** Gates.
- [ ] **Step 5:** Golden (`@Tags(['golden'])`, in `test/goldens/features/teacher/teacher_golden_test.dart`): overview loaded, light and dark, 360 and 1280, plus the teacher nav bar at 360 with five items (no overflow). Generate baselines on Windows. Report.

### Task 4: Form detail page (review, preview, swap, delete, publish)

**Consumes:** Task 1 repository, Task 2 `TeacherQuestionPreview`, `QuestionEditorRepository.get(id)`.

**Files:** `presentation/cubit/mock_form_cubit.dart` + `_state.dart`, `presentation/screens/mock_form_screen.dart`, widgets (module section with 22 rows, swap sheet, preview panel/sheet); `GoRoute` for `/teacher/mock-exams/:setNo/:formNo`; DI factory. Tests.

**Produces:**
- `sealed class MockFormState` → `MockFormLoading`, `MockFormLoaded(form, {Set<String> stale = const {}, String? previewId, QuestionDraft? preview, List<MockCandidate>? candidates, String? swappingId, bool busy = false, AppError? lastError})`, `MockFormMissing` (server said `invalid_input` on load), `MockFormFailed(AppError)`.
- `MockFormCubit(TeacherMockRepository, QuestionEditorRepository, {required String courseId, required int setNo, required int formNo})` with `load()`, `openPreview(String id)`, `openSwap(String questionId)` (loads candidates), `swap(String newId)`, `publish()`, `delete() → Future<bool>` (true → screen goes back to the overview).
- The detail screen gets the course id the same way as the overview (shared lookup of the SAT course; put the lookup in a small domain use case or a method on `TeacherMockRepository` if the overview Cubit and this Cubit both need it — no duplication).

- [ ] **Step 1: Failing tests** (Cubit): load → loaded with 3 modules; load `invalid_input` → `MockFormMissing`; preview loads the draft for the tapped id; swap → calls swap then reloads, `stale` loses that id; publish `Published` → reloaded as published; publish `Stale` → `stale` = the ids, form stays draft; `mock_form_published` on swap/delete/publish → `lastError` + reload; delete → returns true. Widget tests: published form hides swap/delete/publish but shows preview; stale rows are marked; delete and publish ask for confirmation with `AppDialog` (Cancel does nothing); 360 px layout shows the preview as a bottom sheet, 1280 px as a side panel.
- [ ] **Step 2:** Run → fail. **Step 3:** Implement. **Step 4:** Gates.
- [ ] **Step 5:** Goldens: draft form detail, light/dark, 360/1280. Report.

### Task 5: Docs, review, PR, staging check (router)

- [ ] `docs/04-user-flows-and-screens.md` T-14 row: what exists now. `docs/STATUS.md`: lane A row.
- [ ] Run the gates myself; `/flutter-code-quality:review-gate`, then `/flutter-code-review`; offer `code-reviewer`; fix through the implementer; commit per task; CI green; mark ready and tell the owner.
- [ ] After merge and deploy — staging UI check in Chrome (owner signs in):
  1. In the staging SQL editor set the owner's profile `role = 'teacher'` (note the previous value first).
  2. Open `https://sat-staging.pages.dev/#/teacher/mock-exams` at 1280 and 360: readiness "Ready", assemble set 1, open the form, preview a question, swap one, publish. Then a second assemble shows the shortage list (the demo bank has one spare per cell).
  3. Clean up the forms created: there is no unpublish RPC, so delete them in the SQL editor (`delete from mock_forms where template_id = …`) — ask the owner first.
  4. **Set the role back to `student` and verify it with a select.**

## Verification

- `flutter analyze --fatal-infos` clean; `flutter test -j 2` green (goldens excluded on CI, run locally with the `golden` tag).
- CI `client` job green on the PR.
- Staging UI check above, including the role revert.

## Out of scope

Student mock hub and exam screen (Part 3), report (Part 4), blueprint editor, unpublish.
