# F-4 — Design system + QuestionView (row 6) — design

Story: F-4. Source design: `docs/design/claude-design-export/` ("The Teacher's Booklet"), coverage in `docs/design/claude-design-coverage.md`.
Rules in play: CLAUDE.md rule 1 (no answer keys on client), 5 (no magic numbers), 6 (one `QuestionView`), 8 (mixed Arabic/English).

## Goal
Flutter design system (tokens → `ThemeData` + `ThemeExtension`, shared components, app shell) and the one shared `QuestionView` for practice, homework, quiz, mock and review, matching the export, so the four features that depend on it can be built on it.

## Scope
In: theme (light + dark tokens and components), shared components, `AppShell`, `MathText`, `QuestionView` (all 5 modes), a gallery page showing every mode/state from static sample data.
Out: Cubits, data layer, Supabase, Desmos (ADR-004, placeholder button only), feature screens, per-screen dark mockups.
Dark: tokens + components only (matches the design, which mocks dark only for tokens, components, S-34).

## 1. Theme and tokens (`lib/core/theme/`)
- `app_theme.dart`: builds light and dark `ThemeData`.
- `booklet_colors.dart`: `ThemeExtension` for roles Material lacks (frame tint, ink disabled, green tick, highlighter, warning, info + containers, exam-bar colors, scrim). Read via `context.booklet`.
- `booklet_type.dart`: `TextTheme` per `Foundations` (displaySmall 40/48, headlineSmall 28/36, titleLarge 20/28, bodyLarge 18/28 stems, bodyMedium 16/24, labelLarge 14/20, labelSmall 12/16 caps) + timer (20/24, tabular) + Arabic (16/28) + mono styles.
- `booklet_tokens.dart`: const spacing (4-pt scale, touch target 48), radius (0/2/4/8), motion (100/180/280 ms, easings), elevation (flat; one shadow for dialog/sheet/snackbar; none in dark).
- `ColorScheme` is built by hand from the `Foundations` hex table (not `fromSeed`; current placeholder seed `0xFF1E5EFF` is replaced; brand primary is `#1F4FD6`).
- Fonts bundled as assets (Noto Sans, Noto Sans Arabic, Noto Sans Mono, Material Symbols Rounded). No `google_fonts` (9.0.0 needs Dart ^3.13; runtime fetch also hurts offline/CSP).
- Motion respects `MediaQuery.disableAnimationsOf`.
- No hard-coded colors or sizes in widgets.

### Resolved design inconsistencies
| Topic | Decision |
|---|---|
| Hover/pressed/dark-selected colors | Use `Foundations` hex table, not `color-mix` formulas |
| Arabic line height | 28 |
| Timer size | 20/24 everywhere |
| Review average / flag | avg 1:30, flag over 180 s ("Over 2x average") |
| Eliminate / Mark / Hide targets | 48 px (brief rule) |
| Eliminate shortcut | `Shift+A–D` |
| Reading column | 720 in `QuestionView`, 640 elsewhere |
| Desmos | placeholder button only |

## 2. Shared components (`lib/shared/widgets/`)
All take data and callbacks from outside; no Cubit/Supabase inside. States come from `WidgetState` and the theme.
- Buttons: primary, secondary, tertiary, destructive, icon (48 px); loading, inline error.
- Inputs: `ChoiceTile` (all MCQ states incl. eliminated, practice/review correct/incorrect), `SprInput`, `SprKeypad`.
- Feedback: banner (info/warning/offline), dialog, bottom sheet, snackbar, progress, static skeleton (no shimmer), empty state, error + retry.
- Tags: chips (difficulty, skill, filter).
- `AppShell`: bottom nav ≤600, rail ≤1024, sidebar above; focus mode (quiz/mock) hides nav. Integrates with `go_router` `StatefulShellRoute` under `core/router/`; F-4 delivers the container, features wire destinations.
- `CustomPainter` for dashed borders, 180 ms strike-through, focus ring with 2 px offset.
- A11y: 48 px targets, `Semantics` radiogroup, `liveRegion` for "5 minutes left" and save status. Web shortcuts via `Shortcuts`/`Actions` (A–D select, Shift+A–D eliminate, M mark, arrows).

## 3. Math and QuestionView
### `MathText` (`lib/core/math_render/`)
- Parses `\(...\)`, `\[...\]`, `**bold**` into spans: text, inline math (`WidgetSpan` via `flutter_math_fork`), block math (horizontal scroll, min height 64).
- Math is an LTR isolate inside RTL text; punctuation glues to the formula; size 1.21 em of surrounding text, honors `textScaler`.
- `||` wrap markers: each chunk atomic, laid out with `Wrap`.
- Paragraph direction from first strong letter (rule 8).
- Invalid LaTeX renders the source text; never throws.
- First plan task is a web spike (360 px, long stem). If it fails, swap the engine to `gpt_markdown`; `MathText` is the only interface, nothing else changes.

### `QuestionView` (`lib/shared/widgets/question_view/`)
```
QuestionView(
  mode: QuestionViewMode,   // sealed: practice | homework | quiz | mock | review
  question: QuestionData,   // stem, figure, choices | spr; NO answer key
  selection, eliminated, marked, sprText,
  feedback,                 // practice + review only
  timer, navigator,
  onSelect, onEliminate, onMark, onNext, onBack, onSubmit, ...
)
```
- No business logic; it decides only how to render per mode and breakpoint (phone vs wide). Feature Cubits supply state and callbacks.
- Chrome per mode: light header (practice, homework, review) or exam bar (quiz, mock); footer; navigator as popover (wide, quiz/mock), side panel (wide, homework/review) or sheet (phone).
- Shared parts: stem column (max 720), choices, SPR, teacher's margin note.
- Rule 1: `QuestionData` has no answer-key field. Feedback/explanations arrive only after `check_practice_answer` / `get_attempt_review`.
- Keypad shows on phone, mock, SPR only; other widths use hardware keyboard.
- Mode details follow the table in the design export (`QuestionView.dc.html`, `QuestionView States.dc.html`): practice (10 reps, check-then-next, hint), homework (20, save status, one submit), quiz (12, 18:00, no feedback), mock (22, 35:00, review-before-submit page, 5-min warning, time-up dialog, exit confirm), review (time bar, margin note, mistake-notebook action).

## 4. Testing
- Unit: `BookletColors`, `MathText` parser (success + failure, invalid LaTeX falls back).
- Widget: each component's key states; each `QuestionView` mode renders the right chrome and fires callbacks; `QuestionData` has no answer-key field.
- Golden: components and `QuestionView` at 360 and 1280 (light; dark for components), one 2.0 text-scale variant per component. Tagged `golden`, baselines generated on Windows, excluded on CI (`flutter test --exclude-tags golden`) because Linux font rasterisation differs.
- Deterministic: no real network or timers; clock injected. Written by `test-writer`.

## 5. Delivery (one small PR per step)
1. Math spike on web + bundle fonts.
2. Theme and tokens.
3. Components, in two PRs: A answer inputs (`ChoiceTile`, `SprInput`, `SprKeypad`), B buttons and feedback. Margin note, exam bar and navigator cell ship with `QuestionView`; explanation frames are deferred to the review/notes work.
4. `AppShell`.
5. `QuestionView`, all modes.
6. Gallery page (the "prototype" in `docs/15` row 6) from static sample data.

Definition of done: `dart format`, `flutter analyze --fatal-infos`, `flutter test` clean; gallery runs on Chrome at 360 and 1280 matching the design; CI green; deployed to staging (`docs/11`).

## Risks
- `flutter_math_fork` last released 2025-05; web performance unmeasured → spike first, fallback defined.
- Arabic font weight/size on web.
- Dashed borders, strike animation and focus ring need custom painting.
- Material Symbols variable-font axes (FILL, opsz) unverified in Flutter; fall back to fixed-weight icon font if needed.

## Open decisions (do not block the plan)
- Quiz pass mark in `Teacher Area A` mock text says 70%; spec value is `settings.pass_mark = 75`. Code reads settings.
- Stuck/inactive rules in teacher dashboards are design assumptions; confirm before those screens are built.

## Spike result (2026-10-13)
Verdict: PASS (accepted by the user with items 9–11 deferred). Flutter 3.44.1, flutter_math_fork 0.7.4.
1. Compatibility: resolves; adds flutter_svg 2.3.0 and small transitive packages.
2. Glyphs: fractions, roots, italics render on web (CanvasKit); 20 KaTeX TTFs bundled (~0.5 MB).
3. Baseline: inline `Math.tex` in a baseline `WidgetSpan` sits on the text line, no exception.
4. Arabic: math inside an Arabic sentence renders; paragraph RTL is `MathText`'s job.
5. Fallback: invalid TeX uses `onErrorFallback`, no error screen.
6. Text scaling: `Math.tex` follows `textScaler` by itself (17.4×28.1 at 1×, 34.7×56.2 at 2×).
7. Size: release `main.dart.js` 2.49 → 2.91 MB (+0.4 MB). `--wasm` build succeeds.
Deferred: 360 px visual check (covered by the Task 5 widget test at 360 / 2×), frame-time measurement (measure on the staging gallery), Android run.
