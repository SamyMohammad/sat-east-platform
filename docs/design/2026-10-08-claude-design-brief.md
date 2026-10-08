# Design brief: Abdelrahman Elmenshawy — design system + QuestionView

Brief for Claude Design, row 6 of docs/15 §1 (F-4). Sources: docs/01, 02 (PRC, GRD, MCK), 04, 08 §4 + §6, 10 (NFR-14, NFR-17).

## 1. The product
A commercial learning platform for one American-Diploma math teacher, **Abdelrahman Elmenshawy**.
He sells two separate self-paced courses: **SAT Math** (~40 topics) and **EST Math** (~45 topics).
Each topic is a locked sequence: **Video → Notes (PDF) → Practice → Homework → Quiz**. Passing the
quiz (≥75%) unlocks the next topic. The final phase is a Bluebook-style adaptive mock exam with a
Desmos calculator. Every answer feeds skill analytics ("you lose points on linear inequalities").
One Flutter codebase: **web (primary), Android, iOS**. UI copy is **English only**.

## 2. Users
- **Student (primary), 15–18, Egypt and the Gulf.** Studies on a phone in short bursts and takes
  mocks on a laptop. Wants a clear next step, instant feedback, proof of progress and exam-day
  confidence.
- **Teacher (admin), works alone.** Uses a laptop. Out of scope for this brief, but the tokens must
  also work for dense admin tables later.

## 3. What to design now (scope)
1. **Design system foundations**: tokens, typography, components.
2. **Responsive app shell**: navigation container only, no real screens.
3. **QuestionView**: ONE shared question component used in 4 modes (practice, homework, quiz,
   mock exam) plus a post-submit review state. This is the core of the product. Design it in depth.

Out of scope: landing page, course map, video player, analytics, teacher area, and the AI tutor
chat (show only its entry button).

## 4. Brand & personality
- Brand: **Abdelrahman Elmenshawy**. The teacher's own name is the brand. Design a clean text
  wordmark from the name (no illustrated logo yet), plus a short form "A. Elmenshawy" or a
  monogram "AE" for small spaces (app icon, favicon, phone top bar). Keep the brand colour in one
  swappable token.
- Personality: **calm, focused, trustworthy, exam-serious.** A personal teacher brand: confident and
  premium, modern and clean for teenagers, not childish or gamified. Think "a quiet study desk with
  a teacher you trust", not "a game".
- **Do NOT copy College Board / Bluebook branding, logos, colours or artwork.** We mirror Bluebook's
  *functions* (timer, navigator, mark for review, eliminator), not its look.

## 5. Design system foundations
Deliver named tokens that map 1:1 to Flutter `ThemeData` + `ThemeExtension`:
- **Colour**: brand primary/secondary, surfaces (background, surface, raised, sunken), text
  (primary, secondary, disabled, on-primary), border/divider.
  - Semantic: success (correct), error (incorrect), warning (time running out), info.
  - Exam-specific: **marked-for-review** (distinct from warning), **eliminated choice**,
    **selected choice**, **focus ring**.
  - Light theme required. Also give dark theme values: students study at night.
  - All text pairs must pass **WCAG AA**. Correct/incorrect must never rely on colour alone
    (add an icon and a label).
- **Typography**: one UI typeface (Latin, plus a matching Arabic fallback, because content can contain
  Arabic). Scale: display, headline, title, body, label, caption.
  - Specify how **LaTeX math** sits inline with body text and as a block. Math scales with the
    user's text-size setting.
  - Use tabular figures for the timer and scores.
- **Spacing**: 4-pt grid. **Radius**, **elevation**, **motion** (durations and easing; subtle; respect
  reduced motion).
- **Components** (all states: default, hover, pressed, focused, disabled, loading, error):
  - Button: primary, secondary, tertiary, destructive, icon.
  - MCQ choice tile.
  - SPR input with Answer Preview.
  - Top exam bar with timer.
  - Question navigator: grid of numbered cells with answered / unanswered / marked / current states.
  - Chips/tags (difficulty E/M/H, skill tag).
  - Banner: info / warning / offline.
  - Dialog (submit confirm), bottom sheet, toast/snackbar, progress bar, step indicator.
  - Empty, loading (skeleton) and error-with-retry patterns.

## 6. Responsive app shell
Breakpoints: **phone ≤600 px** (design at 360), **tablet 600–1024** (design at 768),
**laptop ≥1024** (design at 1280).
- Phone: bottom navigation bar and the "AE" monogram in the top bar. Tablet: navigation rail.
  Laptop: left sidebar with the full wordmark.
- Destinations (placeholders): Home, Courses, Skills, Mock exams, Profile.
- While a quiz or mock is in progress the shell's navigation is **hidden**: full-screen focus mode.

## 7. QuestionView — the core component
One component; its **mode** decides which parts show. Same visual language everywhere, so a student
who learns it in practice already knows the exam.

### 7.1 Anatomy
- Header: question number ("Question 3 of 20"), difficulty chip, mark-for-review toggle where the
  mode allows it, timer slot.
- Stem: Markdown + **LaTeX** (inline and block), optional figure/graph image (zoomable on phone),
  optional table.
- Answer area: **MCQ** (4 choices A–D, each may contain LaTeX) **or** **SPR** (student-produced
  response).
- Footer: Back / Next, primary action (Check / Submit / Next), navigator trigger.
- Side tools (mode-dependent): hint, explanation, "Ask AI", reference sheet, Desmos calculator.

### 7.2 MCQ choice tile
- States: default, hover, focused (keyboard), selected, **eliminated** (strike-through, dimmed,
  restorable), correct, incorrect, "your answer" vs "correct answer" in review, disabled.
- Answer eliminator: a small toggle per choice, enabled by an "ABC" tool switch in the top bar
  (exam/quiz). Eliminating the selected choice clears the selection.
- The whole tile is the tap target, at least 48×48 px. Keyboard: A–D or arrows + Enter.

### 7.3 SPR input + Answer Preview
- A short text box for numeric answers. Max **5 characters** (6 if negative; `.`, `/` and `-`
  count). Allowed: digits, one `.`, one `/`, one leading `-`.
- Live **Answer Preview** under the box: renders `7/2` as a stacked fraction, `.5` as 0.5, `-3/4` as
  a negative fraction.
- Inline validation hints (neutral tone, not error-red while typing):
  - "Mixed numbers aren't allowed — enter 7/2 or 3.5"
  - "Too many characters"
  - "Only numbers, . and / are allowed"
  - "Can't divide by zero"
- A collapsible "How to enter your answer" help with these rules.
- The client never shows whether the answer is correct before submit in homework/quiz/mock.

### 7.4 Modes (design each one)
| Mode | Timer | Feedback | Tools | Navigation | Primary action |
|---|---|---|---|---|---|
| **Practice** | none shown | immediate after "Check": correct/incorrect + explanation | Hint, Explanation, Ask AI, "Watch explanation video" | one question at a time | Check → Next question |
| **Homework** (20 Q) | none | none until submit | none (no hints) | navigator, answers editable, autosave indicator ("Saved" / "Saving…" / "Offline — will sync") | Submit (confirm dialog listing unanswered) |
| **Quiz** (~10–15 Q) | countdown (1.5 min/Q total), 5-min warning | none until submit | eliminator, mark for review | navigator | Submit |
| **Mock exam** (module of 22 Q, 35 min) | countdown with **Hide/Show**, 5-min warning, auto-submit at 0 | none | eliminator, mark for review, **reference sheet**, **Desmos** (draggable/resizable panel on laptop, full-screen sheet on phone) | navigator popup + **module review page** before submit | Next → Review → Submit module |
| **Review** (after submit) | shows time spent per Q | your answer vs correct, explanation, skill tag | Ask AI, add to mistake notebook | navigator coloured by correct/incorrect | Next / Back to report |

### 7.5 States to show
Loading (skeleton), unanswered, answered, marked, time warning, time up (auto-submit), saving,
save failed (retry), offline banner, reconnect/resume ("Resumed — 12:40 left"), submit
confirmation, and the phone-in-mock warning banner ("For the best experience use a laptop or
tablet").

### 7.6 Mixed-direction content
Questions are English with LaTeX. Explanations and AI replies **may contain Arabic mixed with
English and math**. Show one explanation sample with an Arabic paragraph that contains an inline
equation, laid out right-to-left inside an otherwise LTR screen.

### 7.7 Layout per breakpoint
- **360**: single column, question full screen, sticky bottom action bar. Tools open as bottom
  sheets; the navigator is a sheet.
- **768**: single column with wider margins. The navigator can sit as a side panel in homework.
- **1280**: centred reading column (max ~720 px). The mock exam uses a top bar (section/module,
  timer, tools) + question area + bottom bar ("Question 5 of 22" navigator, Back/Next). The Desmos
  panel floats on the right without covering the answer area.

## 8. Sample content (original, use as-is)
- **MCQ:** If \(3x - 7 = 2x + 5\), what is the value of \(x\)?  A) 2  B) 12  C) −2  D) −12
- **MCQ with block math:** Which expression is equivalent to \(\dfrac{x^2 - 9}{x + 3}\) for
  \(x \neq -3\)?  A) \(x - 3\)  B) \(x + 3\)  C) \(x - 9\)  D) \(x^2 - 3\)
- **SPR:** A line passes through the points \((0, 1)\) and \((3, 3)\). What is the slope of the line?
  (Show the preview rendering `2/3` as a stacked fraction.)
- **SPR with a figure:** a right triangle with legs 6 and 8; "What is the length of the hypotenuse?"
- **Arabic explanation sample:** «نطرح \(2x\) من الطرفين فنحصل على \(x - 7 = 5\)، ثم نضيف 7 للطرفين فيكون \(x = 12\).»

## 9. Accessibility & quality bar
- WCAG AA contrast. Visible focus ring. Full keyboard path through the exam on web.
- Touch targets ≥48 px. Math stays readable at 200% text size.
- Status is never colour-only.
- Light, fast, no decorative heavy imagery (students on 4G; first paint < 4 s).

## 10. Deliverables
1. Brand: wordmark "Abdelrahman Elmenshawy", short form, "AE" monogram (app icon + favicon sizes).
2. Token sheet (light + dark) with names ready to map to Flutter `ThemeExtension`.
3. Type scale with math samples (inline + block).
4. Component sheet with every state from §5 and §7.2–7.3.
5. App shell at 360 / 768 / 1280.
6. QuestionView frames: each mode in §7.4 × 360 and 1280 (plus 768 for homework and mock), and a
   states sheet for §7.5.
7. Short notes on interaction and motion (eliminator, mark for review, timer warning, Answer
   Preview).
