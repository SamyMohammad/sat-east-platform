# Visual redesign: category standard at full craft

Date: 2026-10-26 · Branch: `redesign/visual-world` · Status: draft for approval

## Intent

The app works but looks basic. The owner wants the whole client (student and teacher) moved to one
polished visual system now, before more UI piles up on the old "Booklet" look. The direction is the
**category standard executed at full craft**: Khan Academy's calm and math legibility, Brilliant's
polished feedback, Linear/Notion type and spacing discipline, and Duolingo's *structure* for the
Check moment (obvious next step, decisive feedback), none of its playful styling. Recorded in
`PRODUCT.md` → Brand Commitments.

Approved reference: `.impeccable/mocks/canon-example.html` (practice question, 1280 and 360 px,
before/after Check). Direction contract: `.impeccable/surfaces/presentation-screens-practice-screen-dart-*.md`.

## Goals

1. Every screen in `apps/client` uses the new system, in **light and dark**.
2. New design tokens replace Booklet tokens; no screen keeps old colours, radii or type.
3. Purposeful, creative motion at the moments that matter (below), honouring reduced motion.
4. Same behaviour, flows, copy and routes as today.

## Non-goals

- No behaviour, logic, data, routing or copy changes (copy only where a control's label must change
  to fit the new layout; list any such change in the PR).
- No student analytics/Skills screen (ANL-01, S-24). That is the next project, designed separately
  on top of this system.
- No new logo or brand illustration set.

## Anti-goals (a failure even if it works)

- Cold/corporate grey SaaS; childish/gamified (points, mascots, confetti storms); cluttered on a
  360 px phone; anything that looks like Bluebook.
- Status shown by colour alone. Motion that delays the student or plays when reduced motion is on.

## Constraints

- Repo rules in `CLAUDE.md` (layers, no codegen, `const`, controllers in `initState`, go_router only,
  DI in `injection.dart`, mixed-direction content).
- No new packages unless a phase brief justifies one (SDK animation APIs are enough for everything
  below). Keep `Noto Sans` + `Noto Sans Arabic` (already bundled) and `flutter_math_fork` for LaTeX.
- WCAG AA contrast in both themes; full keyboard path on web; 360 px and 1280 px checked.

## The system (decided)

**Colour, light:** background `#FFFFFF`; surface `#F6F7F9`; lines `#E3E6EC` / `#CDD2DB`; ink
`#14171F`, secondary `#555C6B`, tertiary `#8A91A0`; brand `#2F5BEA` (wash `#EEF2FE`, line `#B9C8F8`);
correct `#14834B` (wash `#E8F6EE`, line `#9ED3B5`); incorrect `#D2483E` (wash `#FDEEEC`, line
`#F2B4AE`); teacher/warm `#FFF7EB` / line `#F1D9B5` / ink `#8A5A12`.

**Colour, dark (my call, same roles):** background `#0F1218`; surface `#171B23`; raised `#1E232D`;
lines `#2A303C` / `#3A4250`; ink `#E7EAF0`, secondary `#A6ADBB`, tertiary `#7A8293`; brand `#7C9BFF`
(wash `#1B2547`); correct `#4CC38A` (wash `#12301F`); incorrect `#FF7A70` (wash `#3A1A18`); warm wash
`#2E2416`, ink `#F2C580`. Every text/ground pair verified ≥ 4.5:1 by the builder.

**Shape:** choices/cards 12 px, buttons/inputs 10 px, chips pill, focus ring 3 px brand-line.
**Type:** Noto Sans; stem 22/19 px (desktop/phone) weight 500; body 15–16; labels 12–13 semibold;
tabular numerals for counts, timers, scores.
**Spacing:** 4 px base scale (4, 8, 12, 16, 20, 24, 32, 48). Content column max 680–720 px.
**Elevation:** flat surfaces with 1 px lines; soft offset shadows only on the primary button, sheets,
dialogs and the feedback dock.
**Shell:** desktop = light-grey sidebar (232 px) with the brand name, current item as a white raised
pill; phone = bottom navigation as today, restyled.

Tokens live in `lib/core/theme/` as new `App*` classes (colours as a `ThemeExtension` with light and
dark instances, plus space, radius, type, motion). Booklet files and names are removed; shared
widgets named `booklet_*` are renamed to neutral names in the same move (my call: leaving "Booklet"
in names would mislead every future reader).

## Motion (my proposals as UX lead)

Motion tokens: 120 ms (press), 200 ms (state), 320 ms (enter), 500 ms (signature);
easing emphasised-decelerate `Cubic(0.05, 0.7, 0.1, 1)` for entrances, standard `Cubic(0.2, 0, 0, 1)`
for state changes. One shared helper reads `MediaQuery.disableAnimationsOf(context)` and collapses
every animation to its end state.

Signature moments, in priority order:

1. **The Check moment (practice, homework review, quiz review).** The dock tints from white to the
   verdict colour and the verdict row rises in (320 ms). Correct: the choice's check icon draws its
   stroke, the choice settles with a 1.0 → 1.02 → 1.0 pulse, and the progress segment fills. Wrong:
   the picked choice does one short damped shake (2 cycles, 6 px), then the correct choice's outline
   draws around it. The teacher's line fades in last (+120 ms).
2. **Topic unlock (quiz passed ≥ pass mark).** On the result screen the score counts up, the pass
   badge lands; back on the course map the next topic's lock opens (shackle lifts, 500 ms) and the
   path line draws from the finished topic to the new one. This is the "locked mastery path" made
   visible: the one celebratory moment, earned, never confetti.
3. **Question to question.** Shared-axis horizontal slide + fade (320 ms) between questions; the
   progress bar segment animates; the previous answer never flashes.
4. **Quiz result and homework report.** Staged reveal: score count-up (tabular), then per-skill bars
   grow left-to-right with a 40 ms stagger.
5. **Navigation.** Fade-through between top-level destinations; shared-axis for drill-down
   (catalogue → course → topic). Implemented with go_router `CustomTransitionPage`.
6. **Micro-interactions.** Press scale 0.98 on choices and buttons; hint panel expands with size +
   fade; skeleton shimmer for loading (replaces spinners where a layout is known); exam clock turns
   warning colour with a single soft pulse at the warning threshold (no repeated blinking).

## Scope: every surface

Student: sign-in, sign-up, check inbox, forgot/set password, device gate, account, activate,
catalogue, course page, course map (`/courses`), topic, practice, quiz, quiz result, app shell
(sidebar + bottom nav + header), focus-mode scaffold, splash, placeholder screens (skills, mock
exams, profile), every shared widget (`QuestionView` and parts, choice tile, SPR input and keypad,
banners, chips, dialogs, overlays, progress, skeleton, status frame, empty state, error retry,
loading button, feedback label). Teacher: teacher shell, course builder. Dev: design gallery
(restyled so it remains the review surface for every QuestionView state).

## Delivery (my call)

Phases on the same branch, each one Codex task, reviewed and committed before the next:

1. Tokens + `AppTheme` light/dark + motion helper + renames; app compiles, everything uses new tokens.
2. Shared widgets and `QuestionView` (all modes) + the Check moment.
3. App shell, navigation transitions, auth and onboarding screens.
4. Catalogue, course page, course map (with unlock animation), topic.
5. Quiz, quiz result (staged reveal), practice summary.
6. Teacher shell and course builder; design gallery.
7. Finish review (impeccable reviewer), golden refresh, `DESIGN.md` written from the built system.

Tests: behaviour tests stay green unchanged; golden images (61 today) are regenerated per phase and
each changed golden is eyeballed in review. Motion gets widget tests for the reduced-motion path
(animations off → end state immediately) and with a fake clock for the Check sequence order.

## Owner decisions after the builder check

- **Theme switch:** System / Light / Dark choice on the account screen, default System, persisted on
  the device (Hive, already a dependency). This is the one small behaviour addition in scope; it
  lands in phase 3 with tests.
- **Approval checkpoints:** no mocks for the remaining screens. After each phase the owner reviews
  light and dark screenshots from the running app (360 and 1280 px) and comments; fixes go into the
  same phase before the next one starts.

## Calls made after the builder check (my calls, flagged for review)

- **Topic unlock signal:** allowed as a presentation-only signal. The course-map cubit compares the
  unlocked set before and after a refresh and marks the newly unlocked topic for one animation. No
  schema, RPC or route changes. The "path" is a vertical connector drawn between the existing topic
  rows, not a new map layout.
- **Token migration:** phase 1 adds the `App*` tokens and themes and keeps a temporary shim that maps
  old Booklet names to the new values, so the app restyles at once with a small diff. Each later
  phase moves its files off the shim; phase 7 deletes the shim and every `booklet` name.
- **Goldens:** every existing golden is regenerated in light; dark goldens are added for the
  QuestionView states, the app shell and one screen per phase. Goldens are generated on the same
  platform CI uses (the builder confirms which before phase 1).
- **Warm (teacher) colour:** used only for the teacher's line in the feedback dock, the hint panel,
  and teacher notes. Never for status.
- **Accessibility of motion:** the verdict is announced through a live region (`Semantics`
  `liveRegion`) at the same moment the dock changes; shake and pulse are never the only signal.
- **Contrast:** `#2F5BEA` with white text is about 5.4:1 (passes AA); the builder re-verifies every
  pair in both themes with a unit test over the token table.

## Left to the builder

Exact component internals, file splits, which Material widgets to theme vs. wrap, dark-mode
fine-tuning within the stated roles, skeleton shapes per screen.
