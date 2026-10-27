---
name: SAT/EST Math Platform
description: Calm, precise math practice for SAT and EST students. The category standard executed at full craft, in light and dark.
colors:
  background: "#FFFFFF"
  surface: "#F6F7F9"
  raised: "#FFFFFF"
  line: "#E3E6EC"
  line-strong: "#CDD2DB"
  ink: "#14171F"
  ink-secondary: "#555C6B"
  ink-tertiary: "#6A7283"
  brand: "#2F5BEA"
  on-brand: "#FFFFFF"
  brand-wash: "#EEF2FE"
  brand-line: "#B9C8F8"
  correct: "#137F49"
  correct-wash: "#E8F6EE"
  correct-line: "#9ED3B5"
  incorrect: "#C9392F"
  incorrect-wash: "#FDEEEC"
  incorrect-line: "#F2B4AE"
  warm: "#FFF7EB"
  warm-line: "#F1D9B5"
  warm-ink: "#8A5A12"
  warning: "#B25209"
  warning-wash: "#FCEFE1"
  danger: "#B3342B"
  on-danger: "#FFFFFF"
  danger-hover: "#962A22"
  scrim: "#14171F7A"
  shadow: "#14171F1A"
  exam-bar: "#14171F"
  on-exam-bar: "#E7EAF0"
  on-exam-bar-variant: "#A6ADBB"
  exam-bar-rule: "#3A4250"
  exam-bar-primary: "#7C9BFF"
  exam-bar-warning: "#F5A04D"
  hue-blue: "#2F5BEA"
  hue-teal: "#0E9F8E"
  hue-violet: "#7C5CE0"
  hue-amber: "#CE8200"
  hue-rose: "#E0567A"
  background-dark: "#0F1218"
  surface-dark: "#171B23"
  raised-dark: "#1E232D"
  line-dark: "#2A303C"
  line-strong-dark: "#3A4250"
  ink-dark: "#E7EAF0"
  ink-secondary-dark: "#A6ADBB"
  ink-tertiary-dark: "#828A9A"
  brand-dark: "#7C9BFF"
  on-brand-dark: "#0F1218"
  brand-wash-dark: "#1B2547"
  brand-line-dark: "#3D5390"
  correct-dark: "#4CC38A"
  correct-wash-dark: "#12301F"
  correct-line-dark: "#2B6949"
  incorrect-dark: "#FF7A70"
  incorrect-wash-dark: "#3A1A18"
  incorrect-line-dark: "#873E38"
  warm-dark: "#2E2416"
  warm-line-dark: "#665032"
  warm-ink-dark: "#F2C580"
  warning-dark: "#F5A04D"
  warning-wash-dark: "#3A2614"
  danger-dark: "#FF7A70"
  on-danger-dark: "#0F1218"
  danger-hover-dark: "#FF9189"
  scrim-dark: "#00000099"
  shadow-dark: "#00000033"
typography:
  display-score:
    fontFamily: "Lexend"
    fontSize: "57px"
    fontWeight: 400
    lineHeight: 1.12
  display-small:
    fontFamily: "Lexend"
    fontSize: "36px"
    fontWeight: 400
    lineHeight: 1.22
  headline-large:
    fontFamily: "Lexend"
    fontSize: "32px"
    fontWeight: 600
    lineHeight: 1.25
  headline-medium:
    fontFamily: "Lexend"
    fontSize: "28px"
    fontWeight: 600
    lineHeight: 1.29
  headline-small:
    fontFamily: "Lexend"
    fontSize: "24px"
    fontWeight: 600
    lineHeight: 1.33
  title-large:
    fontFamily: "Lexend"
    fontSize: "22px"
    fontWeight: 600
    lineHeight: 1.36
  title-medium:
    fontFamily: "Lexend"
    fontSize: "16px"
    fontWeight: 600
    lineHeight: 1.5
  title-small:
    fontFamily: "Lexend"
    fontSize: "14px"
    fontWeight: 600
    lineHeight: 1.43
  stem:
    fontFamily: "Lexend"
    fontSize: "22px"
    fontWeight: 500
    lineHeight: 1.5
    letterSpacing: "-0.22px"
  stem-compact:
    fontFamily: "Lexend"
    fontSize: "19px"
    fontWeight: 500
    lineHeight: 1.5
    letterSpacing: "-0.19px"
  body-large:
    fontFamily: "Lexend"
    fontSize: "16px"
    fontWeight: 400
    lineHeight: 1.5
  body-medium:
    fontFamily: "Lexend"
    fontSize: "15px"
    fontWeight: 400
    lineHeight: 1.6
  body-small:
    fontFamily: "Lexend"
    fontSize: "13px"
    fontWeight: 400
    lineHeight: 1.54
  label-large:
    fontFamily: "Lexend"
    fontSize: "13px"
    fontWeight: 600
    lineHeight: 1.54
  label-small:
    fontFamily: "Lexend"
    fontSize: "12px"
    fontWeight: 600
    lineHeight: 1.33
  count:
    fontFamily: "Lexend"
    fontSize: "13px"
    fontWeight: 600
    lineHeight: 1.54
    fontFeature: "\"tnum\""
  timer:
    fontFamily: "Lexend"
    fontSize: "20px"
    fontWeight: 600
    lineHeight: 1.2
    fontFeature: "\"tnum\""
rounded:
  none: "0px"
  control: "10px"
  card: "12px"
  overlay: "16px"
  pill: "999px"
spacing:
  s1: "4px"
  s2: "8px"
  s3: "12px"
  s4: "16px"
  s5: "20px"
  s6: "24px"
  s8: "32px"
  s12: "48px"
  s16: "64px"
components:
  button-primary:
    backgroundColor: "{colors.brand}"
    textColor: "{colors.on-brand}"
    typography: "{typography.label-large}"
    rounded: "{rounded.control}"
    padding: "8px 20px"
    height: "48px"
  button-primary-disabled:
    backgroundColor: "{colors.line}"
    textColor: "{colors.ink-tertiary}"
  button-secondary:
    backgroundColor: "transparent"
    textColor: "{colors.brand}"
    typography: "{typography.label-large}"
    rounded: "{rounded.control}"
    padding: "8px 20px"
    height: "48px"
  button-tertiary:
    backgroundColor: "transparent"
    textColor: "{colors.brand}"
    typography: "{typography.label-large}"
    rounded: "{rounded.control}"
    padding: "8px 12px"
    height: "48px"
  button-destructive:
    backgroundColor: "{colors.danger}"
    textColor: "{colors.on-danger}"
    typography: "{typography.label-large}"
    rounded: "{rounded.control}"
    padding: "8px 20px"
    height: "48px"
  button-destructive-hover:
    backgroundColor: "{colors.danger-hover}"
  choice-tile:
    backgroundColor: "{colors.background}"
    textColor: "{colors.ink}"
    typography: "{typography.body-medium}"
    rounded: "{rounded.card}"
    height: "56px"
  choice-tile-selected:
    backgroundColor: "{colors.brand-wash}"
    textColor: "{colors.ink}"
  choice-tile-correct:
    backgroundColor: "{colors.correct-wash}"
    textColor: "{colors.ink}"
  choice-tile-incorrect:
    backgroundColor: "{colors.incorrect-wash}"
    textColor: "{colors.ink}"
  input-field:
    backgroundColor: "{colors.background}"
    textColor: "{colors.ink}"
    typography: "{typography.body-medium}"
    rounded: "{rounded.control}"
  chip:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.ink}"
    typography: "{typography.label-large}"
    rounded: "{rounded.pill}"
    padding: "0 12px"
    height: "32px"
  chip-filter-selected:
    backgroundColor: "{colors.brand-wash}"
    textColor: "{colors.brand}"
  card:
    backgroundColor: "{colors.background}"
    textColor: "{colors.ink}"
    rounded: "{rounded.card}"
    padding: "24px"
  banner:
    backgroundColor: "{colors.brand-wash}"
    textColor: "{colors.ink}"
    typography: "{typography.label-large}"
    rounded: "{rounded.card}"
    padding: "8px 8px 8px 16px"
  dialog:
    backgroundColor: "{colors.raised}"
    textColor: "{colors.ink}"
    rounded: "{rounded.overlay}"
    padding: "24px"
    width: "400px"
  icon-tile:
    backgroundColor: "{colors.brand-wash}"
    textColor: "{colors.brand}"
    rounded: "{rounded.control}"
    size: "40px"
  shell-sidebar:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.ink-secondary}"
    typography: "{typography.label-small}"
    width: "232px"
  feedback-dock-correct:
    backgroundColor: "{colors.correct-wash}"
    textColor: "{colors.correct}"
  feedback-dock-incorrect:
    backgroundColor: "{colors.incorrect-wash}"
    textColor: "{colors.incorrect}"
  teacher-note:
    backgroundColor: "{colors.warm}"
    textColor: "{colors.ink}"
    rounded: "{rounded.card}"
---

# Design System: SAT/EST Math Platform

Source of truth is code: `apps/client/lib/core/theme/` (`app_palette.dart`, `app_colors.dart`, `app_tokens.dart`, `app_type.dart`, `app_motion.dart`, `app_icons.dart`, `app_hues.dart`, `app_theme.dart`). The frontmatter mirrors it; if they disagree, the Dart wins and this file is stale. Rendered evidence: goldens under `apps/client/test/goldens/`.

## Overview

**Creative North Star: "The Category Standard, at Full Craft"**

Khan Academy's calm and math legibility, Brilliant's polished feedback, Linear/Notion type and spacing discipline, and Duolingo's decisive Check structure without its playful styling. White ground, one cool off-white surface, near-black ink, one confident blue. The question and its feedback own the screen; chrome stays quiet.

Density is relaxed and phone-first: 48px touch targets, 56px choice rows, a 680-720px content column on desktop. Depth comes from 1px lines and tonal surfaces, with soft shadows reserved for surfaces that act (primary button, sheets, dialogs, the feedback dock). Motion is short and purposeful, and every animation collapses to its end state under reduced motion. Light and dark themes share the same roles; every screen ships in both.

Confirmed rejections (from the approved spec): cold grey SaaS, gamified chrome (points, mascots, confetti), exam-software imitation (Bluebook), clutter at 360px.

**Key Characteristics:**
- One brand blue for selection and primary action; green and coral only for verdicts.
- Status is always icon + word, never colour alone.
- Lexend everywhere, tabular numerals for counts, timers and scores; LaTeX via `flutter_math_fork` at 1.21x the surrounding text.
- Flat surfaces separated by 1px lines; shadows only on acting surfaces.
- Lucide icons through one semantic `AppIcons` map.
- unDraw illustrations recoloured to the brand at runtime, never inside the question area.

## Colors

A white, near-neutral system with a single cool blue accent, two verdict colours, and a warm tint reserved for the teacher's voice. Always read colours through `context.appColors` (`AppColors` ThemeExtension); never hard-code a hex in a widget. Every role has a light and a `-dark` value.

### Primary
- **Confident Blue** (`brand`): primary action, selection, progress fill, focus. Pairs with `brand-wash` (selected fills, filter chip on) and `brand-line` (focus ring, selected-choice halo).

### Secondary
- **Verdict Green** (`correct`, `correct-wash`, `correct-line`): correct answers and success banners only.
- **Verdict Coral** (`incorrect`, `incorrect-wash`, `incorrect-line`): wrong answers, field errors, error banners.
- **Danger Red** (`danger`, `danger-hover`): destructive buttons only (delete, discard). Distinct from `incorrect`, which judges answers.
- **Warning Amber** (`warning`, `warning-wash`): time warnings and caution banners.

### Tertiary
- **Teacher Warm** (`warm`, `warm-line`, `warm-ink`): the teacher's line in the feedback dock, the hint panel, margin notes and teacher notes.
- **Subject Hues** (`SubjectHue`: blue, teal, violet, amber, rose; each with a wash and a dark pair): course card cover bands, `IconTile`, `TopicNumberTile`, unit headers. Cycled by unit order with `SubjectHue.forIndex(i)`. Text on a hue wash is always `ink`.
- **Exam Bar** (`exam-bar` family): the dark timed-exam header. It is the same in light and dark themes.

### Neutral
- **Paper White** (`background`): scaffold, cards, inputs, dock at rest.
- **Cool Off-White** (`surface`): shell sidebar/rail/bottom nav, chips, offline banner.
- **Raised** (`raised`): dialogs, sheets, the selected nav pill.
- **Hairline** (`line`) / **Firm Line** (`line-strong`): dividers and card borders / input and secondary-control borders.
- **Ink** (`ink`), **Ink Secondary** (`ink-secondary`), **Ink Tertiary** (`ink-tertiary`): body text, supporting text and inactive icons, hints and disabled text.
- **Scrim** / **Shadow**: modal barrier / the single shadow colour.

### Named Rules
**The One Blue Rule.** Blue means "act here" or "you chose this". Don't use it for decoration, headings or status.

**The Icon-And-Word Rule.** Every status (correct, incorrect, warning, offline, locked, saved) shows a Lucide icon and a word. Colour reinforces the meaning; it never carries it alone.

**The Teacher's Voice Rule.** Warm fill and warm ink are the teacher's voice only. They never mark a verdict. (The warning banner borrows `warm-line` for its border; that is the one shared use.)

**The Hue Is Identity Rule.** Subject hues identify units and topics. They never signal progress, mastery or correctness.

The spec draft listed different values for tertiary ink, correct, incorrect and amber. The build values above are normative.

## Typography

**Display, body and label font:** Lexend (bundled, weights 300-700, `AppFonts.sans`).
**Math:** `flutter_math_fork` through `MathText`, scaled by `AppType.mathScale` (1.21) so LaTeX matches the optical size of Lexend.

**Character:** Lexend's wide, open forms read well at small sizes and suit long practice sessions. Semibold (600) labels and titles over regular (400) body give hierarchy without heavy contrast.

### Hierarchy
- **Display score** (400, 57px): quiz result score only. `displaySmall` (36px) is used for the practice summary figure.
- **Headline** (600, 32 / 28 / 24px): screen greeting and course page title / screen titles / card titles (`headlineSmall` on `CourseCard`).
- **Title** (600, 22 / 16 / 14px): section heads, list-row titles, dock verdict.
- **Stem** (`AppType.stem`, 500, 22px desktop; `stemCompact` 19px phone, line height 1.5, tracking -1%): question stems only.
- **Body** (400, 16 / 15 / 13px): `bodyMedium` 15px is the default reading size, used for choices and copy. Keep it in the 680px reading column.
- **Label** (600, 13 / 12px): buttons, chips, nav labels, field labels (13px, always floating above the value).
- **Count / Timer** (600, 13px / 20px, tabular figures): "7 / 10", scores, clocks.

### Named Rules
**The Tabular Numbers Rule.** Any number that changes in place (counts, timers, scores, topic numbers) uses `AppType.count`, `AppType.timer` or `FontFeature.tabularFigures()`.

**The Sentence Case Rule.** Labels and headings are sentence case. The system has no uppercase or tracked-caps style.

## Layout

Spacing is a 4px scale (`AppSpace` s1-s16: 4, 8, 12, 16, 20, 24, 32, 48, 64). Use `AppSpace` constants; no raw numbers.

Breakpoints (`AppLayout.forWidth`): **compact** at 600px and below, **medium** from 601 to 1023px, **expanded** at 1024px and up. Verify every screen at 360px and 1280px.

- **Shell:** expanded shows a 232px `surface` sidebar with a 1px right line and the current destination as a `raised` pill with a `line` border. Medium shows an 80px rail. Compact shows bottom navigation. Headers are 56px (compact) or 64px.
- **Content column:** reading content max 680px (`readingColumn`); QuestionView max 720px (`questionColumn`), centred.
- **Cards:** 24px padding, 16px internal gap. Dialogs use 24px sides.
- **Touch:** every interactive target is at least 48px (`AppSize.touchTarget`). Choices, SPR fields and keypad keys are 56px (`largeControl`).

## Elevation & Depth

The system is flat at rest. Surfaces separate by tone (`background` / `surface` / `raised`) and 1px `line` borders. Cards have elevation 0 with a `line` border. App bars never elevate on scroll. Material surface tint is disabled everywhere.

### Shadow Vocabulary
- **Primary lift**: a 1px drop in `shadow` plus a 6px blur at 2px offset in `brand` at 25% alpha. Only on enabled primary `LoadingButton`s.
- **Bottom sheet lift**: 16px blur, offset upward (-2 to -4px), in `shadow`. Used by the feedback dock once a verdict is showing, and by the teacher save bar.
- **Overlay**: Material elevation 2 with `shadow` colour on dialogs and bottom sheets, over a `scrim` barrier.

### Named Rules
**The Acting Surface Rule.** Only surfaces that ask for action get a shadow: the primary button, the verdict dock, the save bar, dialogs and sheets. Cards, tiles, chips and nav stay flat.

## Shapes

There are three corner radii plus the pill. **Control** (10px) is for buttons, inputs, icon tiles, nav pills and snackbars. **Card** (12px) is for cards, choices, banners and nav indicators. **Overlay** (16px) is for dialogs and bottom-sheet tops. **Pill** is for chips and progress bars. Nothing is square-cornered except full-bleed bars (shell header, exam bar, dock).

Borders are 1px (`AppStroke.thin`). Strong state borders are 2px. The current navigator cell uses 2.5px. The focus ring is 3px in `brand-line`. Dashed outlines (4/3) mark eliminated choices.

## Components

Reuse before building. Everything below lives in `apps/client/lib/shared/widgets/`.

### Buttons (`LoadingButton`)
- **Shape:** gently rounded (10px), at least 48px tall, 20px horizontal padding (12px for tertiary), `labelLarge` text.
- **Variants:** `primary` (filled `brand`, primary lift shadow), `secondary` (1px `brand` outline, brand text), `tertiary` (text only, brand), `destructive` (filled `danger`, darkens to `danger-hover` on hover).
- **States:** press scales to 0.98 over 120ms. Disabled is a `line` fill with `ink-tertiary` text. Loading shows a 20px spinner and keeps the button's size. Focus is the 3px `brand-line` ring. Errors render as icon + text under the button in a live region.
- Use `LoadingButton` for app actions. Raw `FilledButton`/`TextButton` only pick up the theme defaults.

### Choice tiles (`ChoiceTile`)
- 12px radius, 56px minimum height, letter badge (30px) + `MathText` content.
- **Selected:** `brand-wash` fill, brand border, and a 3px `brand-line` halo at 45% alpha.
- **Correct / incorrect:** verdict wash + border, an icon and the word ("Correct") at the trailing edge. The revealed correct answer ("Correct answer") gets its outline drawn around it. Eliminated choices take a dashed `line` border on `surface`, struck-through text at 60% opacity.

### QuestionView + FeedbackDock (signature)
One shared `QuestionView` renders practice, homework, quiz and mock (`QuestionViewMode`). New question surfaces add a mode; they never fork the widget.
- **Anatomy:** header with close, segmented progress (6px, 4px gaps) and a tabular count. Then a skill line + difficulty chip above the stem, then choices or the SPR input/keypad, then the hint and worked-example panels.
- **The Check moment:** the sticky dock holds a full-width Check on compact and a right-aligned Check (180px min) on wider screens. On verdict, the dock tints from `background` to the verdict wash (320ms, emphasized). The verdict row rises in with an icon and "Correct" / "Not quite" (title size at weight 700) in a `liveRegion`. The teacher's line follows on the warm panel. Dock actions are re-themed so the primary button takes the verdict colour.
- **Exam bar:** quiz and mock use the dark `exam-bar` header with a tabular timer. At the warning threshold the clock turns `exam-bar-warning` with a single soft pulse.

### Chips (`AppChip`)
- Pill (32px visual), `surface` fill, 1px `line` border, `labelLarge` ink text, padded to a 48px target. Kinds: `difficulty`, `skill`, `filter`.
- **Filter selected:** `brand-wash` fill, `brand` border and text, checkmark.

### Cards / containers
- `CourseCard`: Material `Card` (12px, `line` border, no shadow) with an 8px subject-hue cover band, `IconTile`, `headlineSmall` title, 24px padding, optional `LoadingButton`.
- `IconTile` / `TopicNumberTile`: 40px square, 10px radius, hue wash with the hue-coloured 20px icon or the ink tabular topic number. These lead list rows and cards.

### Inputs / fields
- `AppFieldBorder`: full rounded outline (10px). The label always floats inside the box above the value (13px semibold `ink-secondary`), never notched into the border.
- Borders are `line-strong` at rest, a 3px `brand-line` focus ring, `incorrect` on error, and `line` when disabled. The fill is `background`.

### Banners (`AppBanner`)
- 12px radius, 56px minimum, a role wash with a matching line, a 20px icon + ink message in a live region, and an optional tertiary action. Kinds: info (brand), success (correct), warning (warning / warm-line), offline (surface), error (incorrect).

### Dialogs, progress, skeleton
- `AppDialog`: `raised`, 16px radius, 1px `line` border, 400px width, 24px padding.
- `AppProgress`: pill track in `line`, `brand` fill, animated over 200ms, labelled for semantics.
- `AppSkeleton`: `line` bars at card/control radii with a 500ms shimmer sweep. Use it in place of a spinner when the layout is known.

### Navigation (`app_shell/`)
- `surface` sidebar/rail/bottom bar. The selected item is a `raised` pill with a `line` border, a brand icon and an ink label at weight 700. Unselected items use `ink-secondary`.
- Theme mode: System / Light / Dark on the account screen, default System, persisted on the device (`ThemeModeCubit`).

### Icons and illustration
- Icons: Lucide only, through semantic names in `AppIcons` (`AppIcons.correct`, `AppIcons.hint`...). Add a name there; never use `Icons.*` or Lucide directly in features. Sizes: 18 (status), 20 (default, `iconSmall`), 32 (status icon).
- `AppIllustration`: ten named unDraw SVGs, 200px by default. The unDraw accent `#6C63FF` maps to `brand`, and in dark mode the neutrals map to `ink`/`line`/`surface` roles. Use them for empty, success, error and onboarding moments, never in the question or answer area. They are decorative and excluded from semantics.

### Motion (`AppMotion`)
- Durations: press 120ms, state 200ms, enter 320ms, signature 500ms, stagger 40ms. Curves: `emphasized` Cubic(0.05, 0.7, 0.1, 1) for entrances, `standard` Cubic(0.2, 0, 0, 1) for state changes.
- Every duration goes through `AppMotion.resolve(context, ...)`, which returns zero under reduced motion. Branch on `AppMotion.reduced(context)` to render end states directly.

## Do's and Don'ts

### Do:
- **Do** read colours from `context.appColors` and spacing, radius and sizes from `AppSpace` / `AppRadius` / `AppSize`. Check every new screen in light and dark at 360px and 1280px.
- **Do** pair every status with a Lucide icon and a word, and put verdicts and errors in a `Semantics(liveRegion: true)`.
- **Do** route every animation through `AppMotion.resolve` so it collapses to its end state when animations are disabled.
- **Do** render questions only through the shared `QuestionView`, and math only through `MathText` (`flutter_math_fork`).
- **Do** use tabular figures for any changing number.
- **Do** keep UI copy English and sentence case, and set `TextDirection.ltr` on content text.
- **Do** keep targets at least 48px and give choices, SPR fields and keypad keys 56px.

### Don't:
- **Don't** show status by colour alone, or use subject hues or warm fill for status.
- **Don't** add shadows to cards, chips, tiles or nav. Shadows belong to acting surfaces only.
- **Don't** use `brand` blue for decoration or headings, or `danger` to judge an answer.
- **Don't** add Material `Icons.*`, emoji or text glyphs as icons.
- **Don't** add gamified chrome (points, mascots, confetti) or exam-software imitation.
- **Don't** add uppercase kickers or eyebrow labels. The skill line above the stem is QuestionView anatomy, not a pattern for other titles.
- **Don't** place illustrations inside the question or answer area.
