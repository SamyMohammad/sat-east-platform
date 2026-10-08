# Claude Design prompts — Abdelrahman Elmenshawy (row 6, F-4)

Three sessions, in order. Paste **Shared context** at the start of every session, then that
session's prompt. Sources: PRODUCT.md, the shaped QuestionView brief (impeccable `shape`,
direction "The Teacher's Booklet", 2026-10-08), docs/02, 04, 08 §4 + §6, 10.

---

## Shared context (paste first in every session)

```markdown
# Context: Abdelrahman Elmenshawy — SAT & EST Math

## Product
A learning platform sold under the teacher's own name, **Abdelrahman Elmenshawy**. Two
self-paced courses: SAT Math (~40 topics) and EST Math (~45). Each topic is a locked path:
Video → Notes → Practice → Homework → Quiz; passing the quiz (≥75%) unlocks the next topic.
The final phase is a Bluebook-style adaptive mock exam with Desmos. Every answer feeds skill
analytics, so the student sees exactly which skill costs points.
What competitors cannot copy: the teacher's own method and worked solutions, a path you can't
skip, and diagnosis instead of random drills.
One Flutter codebase: web (primary), Android, iOS, one design language. UI copy is English only.

## Users
Students 15–18 anywhere in the world (many in Egypt and the Gulf). Phone in short bursts,
laptop for mock exams. They need: a clear next step, instant feedback that teaches, proof of
progress, exam-day confidence.

## Voice
Warm but demanding, like the teacher himself. Believes in the student, holds a high bar.
Feedback always names the next concrete step: "Close. Check the sign in step 2 and try again."
Never empty praise, never harsh.

## Visual direction — "The Teacher's Booklet"
The app is the teacher's own printed booklet (malzama), alive on screen. We refuse the category
default (rounded white cards + blue button that every prep app ships).
- The world lends ONLY type, palette, density and one signature move. Layout, navigation and
  controls stay standard and familiar (Material 3 widgets). Never a printed-paper costume:
  no paper texture, no cream ground, no handwriting font.
- Palette (starting values; tune for contrast, keep the roles):
  - page white #FFFFFF (never cream) · ink #1A1D24 (never pure black)
  - ballpoint blue #1F4FD6: primary, the blue pen students write in
  - red pen #D2343A: incorrect + teacher notes ONLY
  - highlighter #F6D743: marked for review
  - green tick #1E7F4F: correct
  - frame tint #EEF2F8: Rule / Worked-example boxes
  - warning orange for time running low, distinct from highlighter
  - Dark theme: same roles on a deep ink ground.
- Type: one workhorse sans with an Arabic sibling and tabular figures (Google Fonts, e.g. a
  Noto Sans + Noto Sans Arabic class pairing). The ONLY serif on screen is the math: equations
  render with KaTeX fonts (flutter_math_fork, Computer Modern look; fixed, cannot change), so
  the UI face must sit well beside it.
- Booklet grammar: exercise numbering "4.2 · Ex 7"; explanations in boxed "Rule" and
  "Worked example" frames on the frame tint; 1px rules are the only dividers; no shadowed
  cards; hierarchy by scale contrast (stem large, chrome labels small).
- Signature move — **the teacher's margin**: feedback appears as a red-pen margin note in the
  teacher's voice, beside the question on laptop, directly under the answer on phone. Set in
  the UI font in red, never a handwriting face.

## Hard constraints
- Do NOT copy College Board / Bluebook branding, logos, colours or artwork. Mirror exam
  functions only.
- No gamification: no badges, confetti, mascots, streak fireworks.
- Never invent scores, results, testimonials or student counts. Sample questions are original.
- Flutter limits: no blur/backdrop-filter effects, no heavy shadows (web performance).
  Icons: Material Symbols Rounded.
- Accessibility: WCAG AA; status never colour-only (icon + label); touch targets ≥48 px;
  math readable at 200% text size; full keyboard path on web.
- Content (explanations, AI replies) may mix Arabic, English and math: support right-to-left
  paragraphs inside an LTR screen.
- Breakpoints: phone ≤600 (design at 360), tablet 600–1024 (768), laptop ≥1024 (1280).
```

---

## Session 1 — Brand, tokens, components

```markdown
# Session 1: brand + design system foundations

Design the foundations only. No full screens yet.

## 1. Brand
- Text wordmark "Abdelrahman Elmenshawy" (no illustrated logo). Short form "A. Elmenshawy".
  Monogram "AE" for app icon, favicon and the phone top bar.
- The brand colour lives in one swappable token (ballpoint blue).

## 2. Tokens (light + dark), named to map 1:1 to Flutter ThemeData + ThemeExtension
- Colour roles: page, surface, frame tint, ink (primary/secondary/disabled), on-primary,
  rule/divider, primary (ballpoint blue), red pen, green tick, highlighter, warning, info,
  focus ring, selected, eliminated.
- Type scale: display, headline, title, body (large/regular), label, caption, timer digits
  (tabular). Show inline math in body text and a block equation, at 100% and 200% text size.
- Spacing (4-pt), radius (small, booklet-like, not pill-round), elevation (near-flat),
  motion (durations + easing; subtle; reduced-motion variant).
- Deliver tokens as a table with names like `color.ink.primary`, `type.body.regular`.

## 3. Components (every state: default, hover, pressed, focused, disabled, loading, error)
- Buttons: primary, secondary, tertiary, destructive, icon.
- **MCQ choice tile**: default, hover, focused, selected, eliminated (strike-through, dimmed,
  restorable), correct, incorrect, "your answer" vs "correct answer", disabled. Letter A–D as
  a booklet-style label. Choices may contain LaTeX and wrap to two lines.
- **SPR input** with live Answer Preview (stacked fraction) and neutral validation hints.
- **Custom SPR keypad** (phone): 0–9 . / − ⌫, docked at the bottom.
- **Teacher's margin note**: red-pen note, compact and expanded.
- **Explanation frames**: "Rule" and "Worked example" boxes with block math.
- Exam top bar with timer; **time budget bar** (fixed length, fills, cannot overflow).
- Question navigator cell: unanswered, answered, marked (highlighter), current,
  answered + marked; in review: correct, incorrect, unanswered.
- Chips (difficulty E/M/H, skill tag), banners (info / warning / offline), dialog, bottom sheet,
  snackbar, progress bar, skeleton, empty state, error with retry.

## 4. App shell (container only)
- Phone 360: bottom navigation + "AE" in the top bar. Tablet 768: navigation rail.
  Laptop 1280: left sidebar with the full wordmark.
- Destinations: Home, Courses, Skills, Mock exams, Profile.
- Focus mode (quiz/mock in progress): navigation hidden.

## Deliverables
Brand sheet · token sheet (light + dark) · type scale with math · component sheet with all
states · shell at 360 / 768 / 1280.
```

---

## Session 2 — QuestionView: practice + mock

```markdown
# Session 2: QuestionView — practice and mock exam

Use the Session 1 system. QuestionView is ONE shared component; its mode decides which parts
show. Design two modes now, each at 360 and 1280 (mock also at 768).

## Anatomy
- Header: exercise number ("4.2 · Ex 7"), "Question 3 of 20", difficulty chip, mark toggle
  (where allowed), timer slot.
- Stem: Markdown + LaTeX (inline + block), optional figure (zoomable on phone) or table.
- Answer: MCQ (A–D) or SPR (input + preview; custom keypad on phone).
- Footer: Back / Next, primary action, navigator trigger.

## Content ranges to show
- Stem from one line to a 150-word word problem; one with a figure, one with a block equation.
- **Wide equation at 360**: wraps at operators where possible, otherwise scrolls horizontally
  inside its own block with an edge fade; never shrinks below body size.

## Practice mode
- No timer shown. Progress: "Rep 7 of 10 — Homework unlocks at 10".
- Check → correct: green tick + "Worked example" frame.
- Wrong, first miss: margin note "Not quite. Look at how the sign changes in step 2." + hint
  opens; the student tries again.
- Wrong, second miss: correct answer marked, full worked example, margin note with the next step.
- Actions: Hint, Ask AI (entry button only), Watch explanation video, Report this question.
- Empty state: "No questions match these filters".

## Mock exam mode (module of 22 questions, 35 min)
- Dark-ink top bar: section + module name · time budget bar + clock with Hide/Show · tools:
  ABC eliminator, mark for review, reference sheet, Desmos.
- 1280: reading column ~720 px; Desmos as a draggable/resizable panel on the right that never
  covers the answer area. 360: tools open as full-screen sheets; warning banner "For the best
  experience use a laptop or tablet".
- Bottom bar: "Question 5 of 22" opens the navigator popup; Back / Next.
- Module review page before submit (answered / unanswered / marked).
- 5-minute warning; time up → auto-submit. Timer keeps running if the student leaves; Exit
  shows a confirm that says so. Resume banner: "Resumed — 12:40 left".
- Keyboard on web: A–D select, E eliminator, M mark, ←/→ navigate.

## Sample content (original, use as-is)
- MCQ: If \(3x - 7 = 2x + 5\), what is the value of \(x\)?  A) 2  B) 12  C) −2  D) −12
- MCQ, block math: Which expression is equivalent to \(\dfrac{x^2 - 9}{x + 3}\) for
  \(x \neq -3\)?  A) \(x - 3\)  B) \(x + 3\)  C) \(x - 9\)  D) \(x^2 - 3\)
- SPR: A line passes through \((0, 1)\) and \((3, 3)\). What is its slope? (preview `2/3`
  as a stacked fraction)
- SPR with figure: right triangle with legs 6 and 8; length of the hypotenuse?
- Arabic worked example inside an LTR screen:
  «نطرح \(2x\) من الطرفين فنحصل على \(x - 7 = 5\)، ثم نضيف 7 للطرفين فيكون \(x = 12\).»

## Deliverables
Practice: correct, first miss, second miss, empty — at 360 and 1280.
Mock: question (MCQ + SPR with keypad), navigator popup, review page, 5-min warning, Desmos open,
exit confirm — at 360, 768 and 1280.
```

---

## Session 3 — QuestionView: homework, quiz, review, states

```markdown
# Session 3: QuestionView — homework, quiz, review + states sheet

Same component and system as Sessions 1–2. Only what changes per mode.

## Homework (20 questions)
- No timer, no hints. Navigator always visible on 768/1280 as a side panel, a sheet on 360.
- Answers editable until submit. Autosave status: "Saved" / "Saving…" / "Offline — will sync".
- Submit → confirm dialog listing unanswered questions. Single submission.

## Quiz (~10–15 questions)
- Total time = 1.5 min × number of questions, shown as the time budget bar; 5-min warning.
- Eliminator + mark for review; no feedback until submit.

## Review (after submit, any mode)
- Your answer vs correct answer, teacher's margin note, worked example, skill tag.
- Time per question drawn as bar length; questions over 2× the average flagged.
- Navigator coloured correct / incorrect / unanswered.
- Actions: Ask AI, Add to mistake notebook, Report this question.

## States sheet
Loading skeleton · unanswered · answered · marked · eliminated · time warning · time up
(auto-submit) · saving / saved / offline · save failed + retry · resumed · submit confirm ·
phone-in-mock warning · practice empty filter.

## Deliverables
Homework at 360 / 768 / 1280 · quiz at 360 / 1280 · review at 360 / 1280 · states sheet ·
short interaction + motion notes (eliminator, mark, timer warning, Answer Preview, margin note).
```
