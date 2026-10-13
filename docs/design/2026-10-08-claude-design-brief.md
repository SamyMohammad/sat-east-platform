# Claude Design prompts — Abdelrahman Elmenshawy (row 6, F-4)

Twelve sessions covering every screen in docs/04 §2. Run them in order: 1–3 set the system and
QuestionView; 4–9 are the student and public screens; 10–12 the teacher area. Paste **Shared
context** at the start of every session, then that session's prompt. From session 4 on, also
attach the outputs of session 1 (tokens + components) so every screen reuses them. Sources: PRODUCT.md, the shaped QuestionView brief (impeccable `shape`,
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

---

## Session 4 — Learning path: home, courses, course map, topic

```markdown
# Session 4: the learning path (S-12, S-13, S-14, S-15, S-18, S-23)

Use the Session 1 system. Student screens inside the app shell. Design at 360 and 1280
(course map also 768). This is where the booklet idea is strongest: the course is the booklet's
table of contents.

## S-12 Home
- "Continue where you left off" card leads: topic name, current step, one primary button.
- Next step in plain words ("Homework 4.2 — 20 questions, about 30 min").
- Upcoming live session (local time), study-day streak (quiet, no fireworks), access expiry
  only when fewer than 14 days are left.
- First-run state (no progress yet) and expired-access state.

## S-13 My courses
- SAT and EST cards: progress (topics passed / total), access until <date>, Continue.
- Not-enrolled course: "Start free topic" + "View course" (only the web build shows price/buy).

## S-14 Course map — the booklet's contents page
- Units → topics as a numbered contents list ("Unit 2 · Linear equations", "2.3 Systems").
- Topic states: passed (green tick + quiz score), current (ballpoint blue, shows the step in
  progress), locked (muted, lock icon + "Pass the 2.2 quiz to unlock"), free preview tag.
- Per-topic progress across the 5 steps as a compact 5-segment mark.
- Mock phase entry at the end: locked until all topics are passed or 30 days before the test.
- Long list (40–45 topics): sticky unit headers on phone, two-column contents at 1280.

## S-15 Topic page — the chapter
- Header: "2.3 Systems of equations", skills covered, estimated time.
- 5-step stepper: Video → Notes → Practice → Homework → Quiz, each with its completion rule
  ("Watched 62% of 80%", "Practised 7 of 10", "Score 18/20", "Pass mark 75%").
- Exactly one primary action: the next step. Locked steps say what unlocks them.
- Teacher override and free preview shown as quiet tags.

## S-18 Practice setup
- Filters: subtopic (multi-select), difficulty (E / M / H). Count of available questions. Start.
- Empty result: "No questions match these filters" + reset.

## S-23 Quiz failed → review set
- Score vs pass mark, missed skills listed, review set (questions on those skills).
- Cooldown countdown to retake ("Retake opens in 11:42 — finish the review set first").
- The teacher's margin note sets the next step, warm but demanding.

## Deliverables
All six screens at 360 and 1280 (S-14 also 768), with locked / current / passed / empty /
expired states.
```

---

## Session 5 — Content: video, notes, AI tutor, mistake notebook

```markdown
# Session 5: content and help (S-16, S-17, S-26, S-25)

## S-16 Video player
- Player with chapters (one per subtopic), progress toward the 80% rule, speed, captions slot.
- Moving watermark (student name + ID) over the video: visible but not obstructive.
- Below: subtopic chapter list, "Next: Notes" once 80% is reached.
- States: loading, buffering, offline, "this video is protected" error.

## S-17 Notes viewer (PDF)
- Paged viewer, page counter, zoom, chapter jump. Watermark on every page.
- No download, print or share controls anywhere.
- Opening the notes completes the step: show it quietly.

## S-26 AI tutor panel
- Bound to one answered question: the question is pinned at the top.
- Chat in the teacher's voice; answers may be Arabic, English or mixed with math
  (show one RTL Arabic reply with an inline equation).
- "Still confused? Ask Mr. Abdelrahman" escalation; daily limit indicator.
- Never available during an active quiz or mock: show the disabled rule.
- Phone: full-screen sheet. Laptop: side panel next to the question.

## S-25 Mistake notebook
- Every wrong answer; filter by topic / skill / error type (concept / careless / time).
- Re-attempt in QuestionView; a question leaves after 2 correct re-attempts ("1 of 2").
- Calm empty state, no confetti.

## Deliverables
Each screen at 360 and 1280, with loading / empty / error states.
```

---

## Session 6 — Results and skills

```markdown
# Session 6: results and analytics (S-21, S-24)

## S-21 Result report (homework / quiz)
- Score and pass/fail against the pass mark, in plain words.
- Per-skill breakdown (bars), time per question (bar length, over 2× the average flagged),
  slow-but-correct flags.
- "Review answers" opens QuestionView review mode. One next-step button (next topic or
  review set).
- The teacher's margin note names the one thing to fix.

## S-24 Skills
- Mastery 0–100 per skill, grouped by domain; weak skills first with a "Practise this" action.
- Trend over time (simple line), honest when data is thin ("Answer 10 more questions to see a
  trend").
- Charts: accessible colours, labels on data, no colour-only meaning.

## Deliverables
Both screens at 360 and 1280: strong result, failed result, thin-data state.
```

---

## Session 7 — Mock phase around the exam

```markdown
# Session 7: mock phase (S-27, S-28, S-30, S-31)

The exam screen itself is Session 2. These are the screens around it.

## S-27 Mock hub
- Locked state: "Unlocks when all topics are passed or 30 days before your test (in 12 days)".
- Mock list (taken / available), suggested plan for the final month, score history chart,
  "Log an official score".

## S-28 Pre-exam
- Rules, duration (2 modules × 22 questions × 35 min), tools tour (timer hide, navigator,
  mark, eliminator, reference sheet, Desmos), device tip (laptop or tablet recommended).
- Start button with a clear "the timer starts now" confirmation.

## S-30 Module break
- Module 1 submitted, short break, "Module 2 starts when you're ready". No score yet.

## S-31 Mock score report
- Estimated score **range** (e.g. 610–670) with the note "estimate — official scoring uses a
  different, unpublished model". Correct per module, per-domain and per-skill accuracy,
  time chart with over-2× flags, marked questions, wrong answers with explanations.
- "Start drill set" (10–15 questions on the 3 weakest skills).

## Deliverables
All four at 360 and 1280. Numbers are illustrative; label them as sample data.
```

---

## Session 8 — Account, purchase and settings

```markdown
# Session 8: account and commerce (S-03, S-10, S-11, S-33, S-34, S-35, S-32)

## S-03 Sign up / sign in / reset password
- Email + password and Google. Clear errors. Reset by email.

## S-10 Onboarding
- Name (used in the watermark — say so), phone, country, school, grade, target test and test
  date per course. Explain that access lasts until the test date + 14 days (minimum 60 days).

## S-11 Device limit
- "You can use 2 devices." Device list (name, last used), remove one, changes left
  ("1 change left this month").

## S-33 Checkout / orders / receipts — WEB BUILD ONLY
- Course, price in the student's currency (EGP in Egypt, USD elsewhere), coupon field,
  SAT + EST bundle, pay by card or wallet. Activation code entry as an alternative.
- Order history and receipts.
- Mobile apps show NO prices, buy buttons or purchase links: design the mobile not-enrolled
  state with only "Enter activation code" and sign-in.

## S-34 Profile & settings
- Profile fields, test date, devices, password, theme (light / dark), text size.

## S-35 Notifications
- Topic unlocked, live session reminder, announcements, teacher replies. Read / unread.

## S-32 Live sessions
- Upcoming sessions in local time with join link; recordings list.

## Deliverables
Each at 360 and 1280; checkout on web only; error and empty states.
```

---

## Session 9 — Public site (Persuade mode)

```markdown
# Session 9: public pages (S-01, S-02, S-04)

Unlike the app screens, these pages persuade: more room for brand expression, same system.

## S-01 Landing
- Hero: the teacher's name as the brand and the promise ("every topic learned, practised,
  tested and diagnosed — then rehearsed under exam conditions").
- How it works: the locked 5-step path. What makes it different: the teacher's own method,
  skill diagnosis, Bluebook-style mocks with Desmos.
- Courses (SAT, EST), teacher bio, FAQ, free-topic call to action.
- NO invented testimonials, scores or student counts: leave clearly labelled placeholder slots
  for real results and for the teacher's photo.

## S-02 Course page
- Syllabus by unit/topic (the booklet contents again), free topic call to action, price in the
  local currency, access-window explanation, buy (web).

## S-04 Legal
- Terms, Privacy, Refund policy in a readable long-form layout.

## Deliverables
Landing and course page at 360 and 1440; legal at 360 and 1280.
```

---

## Session 10 — Teacher: dashboard and students

```markdown
# Session 10: teacher area A (T-01, T-09, T-10, T-11, T-12)

Laptop first (design at 1280 and 1440); tablet usable; dense data. Same system at admin density.

## T-01 Dashboard
- KPIs (active students, homework submission rate, quiz pass rate, sales), alerts (stuck,
  inactive 5+ days, reported questions, AI escalations).

## T-09 Completion matrix
- Students × topic steps (video %, notes, homework status/score, quiz). Filters: late, failing,
  inactive N days. Sticky header and first column. Export.

## T-10 Student detail
- Progress, attempts, devices (reset / revoke), enrolments (extend), override unlock, suspend.

## T-11 Class insights
- Hardest questions, most-chosen wrong option, students stuck on a topic for more than N days.

## T-12 AI escalations inbox
- Question + the student's message + the AI answer; reply, or add to the next live session.

## Deliverables
All five at 1280 (dashboard and matrix also 1440), with empty and loading states. Sample data
labelled as sample.
```

---

## Session 11 — Teacher: content

```markdown
# Session 11: teacher area B (T-02 to T-08)

## T-02 Course builder
- Tree: course → unit → topic → subtopic, drag to reorder, publish / unpublish, free preview flag.

## T-03 Topic editor
- Attach videos and notes, pool settings, publish checklist.

## T-04 Video upload
- Direct upload with progress, processing status, chapters per subtopic.

## T-05 Question bank browser
- Filters: topic, subtopic, skill, difficulty, status (draft → published → retired), pool.
  Dense table with LaTeX previews.

## T-06 Question editor
- Markdown + LaTeX with a live preview that shows exactly what QuestionView will render;
  choices, answer key, SPR accepted answers and tolerance, explanation, hint, distractor tags,
  skill tags.

## T-07 Import
- Upload JSON/CSV → validation report (errors per row) → commit.

## T-08 Review queue
- Needs-review items and student reports; fixing a key shows an auto re-grade confirmation.

## Deliverables
All at 1280; the editor also at 1440 with a side-by-side preview.
```

---

## Session 12 — Teacher: operations

```markdown
# Session 12: teacher area C (T-13 to T-17)

## T-13 Live sessions manager
- Schedule (title, time, course, Zoom/Meet link), attach recording, agenda from escalations.

## T-14 Mock templates and sets
- Blueprint config (domains, difficulty mix), generate a set, preview.

## T-15 Coupons and activation codes
- Create a coupon (% or fixed, expiry, max uses, course), generate code batches, usage.

## T-16 Announcements
- Compose to a course, preview, send, history.

## T-17 Settings
- Pass mark, cooldown, device limit and changes, access window, pool split, scale tables.
  Each value with a short explanation of its effect.

## Deliverables
All at 1280, with validation errors and confirm dialogs for risky changes.
```
