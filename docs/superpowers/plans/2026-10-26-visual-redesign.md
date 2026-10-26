# Visual Redesign Implementation Plan

> **For agentic workers:** Executed phase-by-phase via `codex-delegate` (Codex implements, tests first; Claude reviews, runs gates, commits). Sonnet `implementer` fallback per global CLAUDE.md. Steps use checkbox syntax.

**Goal:** Move the whole Flutter client to the approved "category standard at full craft" system, light + dark, with purposeful motion and a System/Light/Dark switch, without changing behaviour.

**Architecture:** New `App*` tokens + `AppColors` ThemeExtension (light/dark) + `AppMotion` replace Booklet in `lib/core/theme/`. A temporary shim keeps old Booklet names compiling and pointing at new values, so phase 1 restyles everything at once; later phases move each area off the shim and rebuild its widgets to the new look; phase 7 deletes the shim. Motion uses SDK APIs only.

**Tech Stack:** Flutter 3.44.1, flutter_bloc, go_router, get_it, hive_ce, flutter_math_fork. No new packages.

**Spec:** `C:\Users\Lenovo\sat-east-redesign\docs\superpowers\specs\2026-10-26-visual-redesign-design.md` (approved). Reference mock: `.impeccable/mocks/canon-example.html`. Direction contract: `.impeccable/surfaces/presentation-screens-practice-screen-dart-*.md`. Plan copied to `docs/superpowers/plans/2026-10-26-visual-redesign.md` on approval.

## Context

The client "works but looks basic". The owner chose the category standard (Khan Academy / Brilliant / Linear-Notion / Duolingo structure) over invented worlds, approved the practice mock, and asked to convert the entire project now, with dark mode, creative motion, and a theme toggle. Analytics (ANL-01 Skills screen) is the next, separate project built on this system.

## Global Constraints

- Work in worktree `C:\Users\Lenovo\sat-east-redesign`, branch `redesign/visual-world`. Codex never commits.
- No behaviour/logic/data/route/copy changes except the theme switch (Task 3.2) and the presentation-only unlock signal (Task 4.2).
- Colours, radii, type, spacing, motion: exactly the values in the spec's "The system" and "Motion" sections.
- Fonts stay `NotoSans` / `NotoSansArabic`; LaTeX via `flutter_math_fork`.
- Every animation collapses to its end state when `MediaQuery.disableAnimationsOf(context)` is true.
- Status is never colour alone (icon + word). Verdicts announced with `Semantics(liveRegion: true)`.
- CLAUDE.md B-rules: Cubit, no codegen, `const`, controllers in `initState`/`dispose`, DI only in `injection.dart`, go_router only.
- Gates per phase (from `apps/client/`): `dart format --output=none --set-exit-if-changed .` · `flutter analyze --fatal-infos` · `flutter test --exclude-tags golden` · `flutter test test/goldens --tags golden` (Windows; update with `--update-goldens`, then eyeball every changed PNG).
- Owner checkpoint after every phase: screenshots light + dark at 360 and 1280 px from the running app (`flutter run -d chrome --dart-define-from-file=env/dev.json`, design gallery for QuestionView states). Fixes land before the next phase.

## Review Focus

1. **Mixed RTL/LTR content in dark mode** (Arabic explanation + LaTeX in the teacher line): must render, wrap and keep contrast. Test: Task 2.2 golden `feedback_dock_dark_360_arabic`.
2. **Text scale 2.0 at 360 px** on the Check dock and choice rows: no overflow. Test: Task 2.2 goldens `_text2x` variants + `tester.takeException()` null.
3. **Reduced motion**: Check sequence, unlock, count-up and route transitions land on the final frame immediately. Tests in Tasks 1.1, 2.2, 3.3, 4.2, 5.1.
4. **Rapid input during animation** (double-tap Check, pressing Next mid-transition, key spam A–D): no duplicate submits, no stale verdict. Test: Task 2.2 `check_double_tap_submits_once`.
5. **Theme switch persistence across restart and when the Hive box is empty/corrupt**: falls back to System, never crashes. Test: Task 3.2.

---

## Phase 1: Foundation

### Task 1.1: App tokens, colours, motion, themes + Booklet shim

**Files:**
- Create: `lib/core/theme/app_tokens.dart` (`AppSpace`, `AppRadius`, `AppSize`, `AppStroke`, `AppLayout`), `lib/core/theme/app_colors.dart` (`AppColors extends ThemeExtension<AppColors>`, `AppSchemes.light/dark`, `extension AppThemeContext on BuildContext { AppColors get appColors; }`), `lib/core/theme/app_type.dart` (`AppFonts`, `AppType.textTheme()` full M3 scale incl. `stem` 22/19 w500, tabular `count`), `lib/core/theme/app_motion.dart`.
- Modify: `lib/core/theme/app_theme.dart` (build from new tokens: buttons 10 px/48 px tall, choices 12 px, inputs 10 px, chips pill, focus ring 3 px brand-line, sheets/dialogs 16 px with soft offset shadow, NavigationBar/NavigationRail/BottomSheet/SnackBar/Progress themes, light + dark).
- Modify (shim): `booklet_tokens.dart`, `booklet_colors.dart`, `booklet_type.dart` become thin forwards to the new values (same public names, `@Deprecated('Use App*')`, values mapped by role). `context.booklet` keeps working.
- Test: `test/core/theme/app_colors_test.dart`, `test/core/theme/app_motion_test.dart`.

**Interfaces (Produces):**
- `AppColors` fields: `background, surface, raised, line, lineStrong, ink, inkSecondary, inkTertiary, brand, onBrand, brandWash, brandLine, correct, correctWash, correctLine, incorrect, incorrectWash, incorrectLine, warm, warmLine, warmInk, warning, warningWash, scrim, shadow` + exam-bar roles carried over (`examBar, onExamBar, onExamBarVariant, examBarRule, examBarPrimary, examBarWarning`); `static const light`, `static const dark`.
- `AppMotion`: `press 120ms, state 200ms, enter 320ms, signature 500ms`, `stagger 40ms`, curves `emphasized = Cubic(0.05,0.7,0.1,1)`, `standard = Cubic(0.2,0,0,1)`; `static Duration resolve(BuildContext, Duration)` → `Duration.zero` when animations disabled; `static bool reduced(BuildContext)`.

- [ ] Step 1: Write failing tests: `app_colors_test`: `contrast_meets_AA_light` / `contrast_meets_AA_dark` iterate a table of (text, ground) pairs (ink/background, inkSecondary/surface, onBrand/brand, correct/correctWash, incorrect/incorrectWash, warmInk/warm, …) asserting WCAG ratio ≥ 4.5 (≥ 3.0 for large-text pairs listed explicitly); `lerp_is_total`. `app_motion_test`: `resolve_returns_zero_when_disable_animations`, `resolve_returns_duration_otherwise`.
- [ ] Step 2: Run, expect FAIL (types missing).
- [ ] Step 3: Implement files above with spec values.
- [ ] Step 4: Run all gates; regenerate all goldens (`--update-goldens`); eyeball: app now white/blue/Noto everywhere.
- [ ] Step 5: Owner checkpoint (first look of the whole app). Commit `feat(redesign): app tokens, light/dark themes, motion, booklet shim`.

## Phase 2: Shared widgets and QuestionView

### Task 2.1: Shared primitives off the shim

**Files:** rebuild visuals (no API changes) in `lib/shared/widgets/`: `loading_button`, `booklet_banner`→`app_banner`, `booklet_chip`→`app_chip`, `booklet_dialog`→`app_dialog`, `booklet_overlays`→`app_overlays`, `booklet_progress`→`app_progress` (segmented 6 px bar, segment fill animates `AppMotion.state`), `booklet_skeleton`→`app_skeleton` (shimmer, static when reduced), `booklet_status_frame`→`app_status_frame`, `empty_state`, `error_retry`, `feedback_label`, `focus_ring`, `spr_input*`, `spr_keypad*`. Renames update every import (class names `Booklet*`→`App*`).
**Tests:** existing widget tests stay green; add `app_progress_test: segment_fill_animates_and_respects_reduced_motion`, `loading_button_test: press_scale_0_98` (fake time).
- [ ] Failing tests → implement → gates + goldens → commit `feat(redesign): shared primitives`.

### Task 2.2: QuestionView restyle + the Check moment

**Files:** `lib/shared/widgets/choice_tile.dart`, `question_view/question_view.dart`, `parts/{choice_list,question_header,question_body,question_footer,exercise_header,hint_panel,framed_panel,margin_note,worked_example,question_navigator,homework_navigator,exam_bar,quiz_question_header,submit_dialog,save_status_label,spr_answer_area}.dart`, `quiz_time_up_dialog.dart`, `practice_feedback.dart` rendering. Create `parts/feedback_dock.dart` (bottom dock: idle = Check button; verdict = tinted correct/incorrect, icon + title + teacher line + worked step + actions; `Semantics(liveRegion: true)`).
**Motion (spec §Motion 1, 3, 6):** dock tint + verdict rise 320 ms emphasized; correct: check stroke draw + 1.0→1.02→1.0 pulse; wrong: damped shake 2 cycles 6 px on picked choice, then correct choice outline draws; teacher line +120 ms; question change = shared-axis horizontal slide + fade 320 ms (`AnimatedSwitcher` keyed by question id); hint panel size+fade; exam clock single pulse at warning threshold.
**Interfaces:** `FeedbackDock({required PracticeFeedback? feedback, required VoidCallback? onCheck, required List<Widget> actions})`; no change to `QuestionView`'s public constructor or modes.
**Tests (names):** `check_sequence_order` (fake clock: tint → verdict → teacher line), `check_reduced_motion_shows_final_state`, `check_double_tap_submits_once`, `verdict_announced_live_region`, `wrong_answer_shows_icon_and_word_not_colour_only`; goldens per existing `qv_*` entry in light **and** dark at 360/1280 + `feedback_dock_{light,dark}_360[_text2x|_arabic]`.
- [ ] Failing tests → implement → gates + goldens → gallery screenshots → owner checkpoint → commit `feat(redesign): QuestionView and Check moment`.

## Phase 3: Shell, navigation, auth, theme switch

### Task 3.1: App shell + route transitions
**Files:** `lib/shared/widgets/app_shell/*` (desktop 232 px light-grey sidebar, brand name, current item = raised white pill; compact bottom nav restyled; header), `focus_mode_scaffold.dart`, `app_splash.dart`, `lib/core/router/app_router.dart` (switch `builder:` → `pageBuilder:` with `CustomTransitionPage`; create `lib/core/router/transitions.dart`: `fadeThroughPage`, `sharedAxisPage`, both reduced-motion aware).
**Tests:** `transitions_test: reduced_motion_has_zero_duration`; shell goldens light/dark 360/768/1280 regenerated. Existing router tests green.
### Task 3.2: Theme mode switch
**Files:** create `lib/core/theme/theme_mode_store.dart` (wraps `Box<String>` `'settings'`, key `'themeMode'`, values `system|light|dark`), `lib/core/theme/theme_mode_cubit.dart` (`ThemeModeCubit extends Cubit<ThemeMode>`, `load()`, `set(ThemeMode)`); modify `lib/main.dart` (open `'settings'` box, pass to `configureDependencies`), `lib/core/di/injection.dart` (store lazy singleton, cubit lazy singleton since app-wide), `lib/app.dart` (`BlocBuilder<ThemeModeCubit, ThemeMode>` → `themeMode:`), `account_screen.dart` (new "Appearance" `SegmentedButton` System/Light/Dark outside the account `BlocBuilder`, so it shows while loading/error).
**Tests:** `theme_mode_cubit_test`: `defaults_to_system_when_empty`, `defaults_to_system_when_value_unknown`, `set_persists_and_emits`, `load_reads_persisted`; widget test `appearance_control_switches_theme`.
### Task 3.3: Auth + onboarding screens
**Files:** `lib/features/auth/presentation/screens/*` (sign-in, sign-up, check inbox, forgot/set password, device gate, account), `lib/features/activation/presentation/screens/activate_screen.dart`, `lib/core/router/placeholder_screen.dart`.
**Tests:** existing green; goldens for sign-in light/dark 360/1280.
- [ ] Per task: failing tests → implement → gates + goldens → commit. Phase end: owner checkpoint.

## Phase 4: Catalogue and learning path

### Task 4.1: Catalogue, course page, topic
**Files:** `lib/features/catalogue/presentation/**`, `lib/features/topic/presentation/**`. Skeletons replace spinners where layout is known.
### Task 4.2: Course map + unlock moment
**Files:** `lib/features/course_map/presentation/{cubit,screens,widgets}/**` incl. `topic_row.dart`, `continue_card`.
**Signal (presentation only):** `CourseMapCubit` keeps the previous loaded map; on reload, topics whose `TopicStatus` went `locked → open` are exposed as `CourseMapLoaded.justUnlocked: Set<String>` (cleared after the first emit is consumed via `acknowledgeUnlock()`). No domain/data changes.
**Motion:** lock shackle lifts (500 ms), vertical connector draws from the completed topic row to the newly opened one, row fades to open state.
**Tests:** `course_map_cubit_test`: `reload_marks_newly_unlocked_topic`, `first_load_marks_nothing`, `acknowledge_clears`; widget `unlock_reduced_motion_shows_open_state`; goldens map light/dark.
- [ ] Per task: failing tests → implement → gates + goldens → commit. Phase end: owner checkpoint.

## Phase 5: Quiz flow

### Task 5.1: Quiz screen, quiz result, practice summary
**Files:** `lib/features/quiz/presentation/**` (screen, `quiz_result_screen.dart`, `QuizStatusContent`), `lib/features/practice/presentation/widgets/practice_summary.dart`, `practice_screen.dart`.
**Motion:** result staged reveal: score count-up (tabular, 500 ms), pass badge lands, per-skill bars grow with 40 ms stagger (if per-skill data exists in `QuizReport`; otherwise score only).
**Tests:** `quiz_result_count_up_reaches_final_score`, `quiz_result_reduced_motion_shows_final`; goldens pass/fail light/dark.
- [ ] Failing tests → implement → gates + goldens → owner checkpoint → commit.

## Phase 6: Teacher + gallery

### Task 6.1: Teacher shell, course builder, design gallery
**Files:** `lib/features/teacher/**`, `lib/features/design_gallery/presentation/**` (gallery gains a light/dark toggle so every QuestionView state can be reviewed in both).
**Tests:** existing green; builder golden light/dark 1280.
- [ ] Implement → gates + goldens → owner checkpoint → commit.

## Phase 7: Remove shim, finish

### Task 7.1: Delete Booklet
- [ ] Delete `booklet_tokens.dart`, `booklet_colors.dart`, `booklet_type.dart`; `rg -i booklet apps/client/lib apps/client/test` returns nothing; all gates + goldens green. Commit.
### Task 7.2: Finish review + DESIGN.md
- [ ] Capture desktop/mobile light/dark screenshots into `.impeccable/review/`; spawn `impeccable-finish-reviewer` (fresh) with spec, contract, mock, screenshots; one fix batch + verdict pass max.
- [ ] Spawn `impeccable-documenter` → `DESIGN.md` + `.impeccable/design.json` from the built system.
- [ ] `/flutter-code-quality:review-gate` → `/flutter-code-review` → offer `code-reviewer` → `git-expert` PR to `main` (title references the spec; body lists any copy changes and the theme-switch behaviour addition).

## Verification (end to end)

- CI-equivalent gates green on the branch; goldens green on Windows with every changed PNG reviewed.
- Manual in Chrome at 360 and 1280, light and dark and System: sign in → catalogue → course map → topic → practice (right + wrong Check) → quiz → result (pass → map unlock animation) → account theme switch persists after reload; repeat with OS "reduce motion" on.
- Keyboard-only pass through practice (A–D, Enter) and the quiz.
