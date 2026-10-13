# Product

<!-- impeccable:product-schema 1 -->

## Platform

web

One Flutter codebase ships web (primary), Android and iOS with the **same** design language; it is
not adaptive per OS. The web build is the only purchase surface (ADR-006).

## Users

- **Student (primary), 15–18, American-Diploma, anywhere in the world** (many in Egypt and the
  Gulf). Prepares for SAT Math, sometimes EST Math. Studies on a phone in short bursts; takes mock
  exams on a laptop. Does many questions but doesn't know *why* they lose points, and procrastinates
  without structure. Needs a clear next step, instant feedback, proof of progress and exam-day
  confidence.
- **Teacher / admin: Abdelrahman Elmenshawy**, works alone on a laptop. Records videos, owns notes
  and question banks. Needs to see who is behind, upload content with little effort, protect it, and
  let the AI tutor handle routine questions.
- **Parent (secondary, read-only, later):** usually the payer; wants a simple progress report.

## Product Purpose

The most structured way to prepare for SAT Math (and EST Math): every topic learned, practised,
tested and diagnosed, then rehearsed under real exam conditions. Two courses (SAT ~40 topics, EST ~45),
sold separately for a one-time price.

Success: students actually progress (most pass ≥10 topic quizzes), do their homework, and improve
between the diagnostic mock and the last mock; the teacher spends less time answering routine questions.

## Positioning

Three things a generic prep site cannot copy:
1. **The teacher's own method.** His videos, notes and worked solutions. Even the AI tutor answers
   from his stored solutions, not generic AI.
2. **A locked mastery path.** Video → Notes → Practice → Homework → Quiz; passing the quiz unlocks
   the next topic. You can't skip; the discipline is the product.
3. **Diagnosis, not drills.** Every answer feeds skill analytics: the student sees exactly which skill
   costs points; the teacher sees who is behind.

EST coverage is a bonus, not the core claim.

## Operating Context

- Topic loop: Video (≥80% watched) → Notes (opened) → Practice (≥10 attempted) → Homework (20 Qs,
  single submission, auto-graded) → Quiz (timed, pass ≥75% unlocks next; fail → review set + cooldown).
- Mock phase: Bluebook-style adaptive SAT mock (2 modules × 22 Qs × 35 min) with Desmos and a
  reference sheet; score shown as an estimated range.
- One shared question component serves practice, homework, quiz and mock.
- Ask for help: from any answered question → AI tutor (grounded in the teacher's solution) →
  escalate to the teacher.
- Teacher works from a dashboard: completion matrix, review queue, class insights.

## Capabilities and Constraints

- Questions: MCQ and SPR (student-produced response). Stems and choices are Markdown + LaTeX,
  sometimes with figures or tables. SPR follows the official entry rules (max 5 chars, 6 if negative;
  no mixed numbers).
- Grading, unlocking and scoring are server-side; answer keys never reach the client before submit.
- UI copy is **English only**. Content (notes, explanations, AI replies) may mix Arabic, English and
  math; text must support mixed direction.
- Prices are shown in the student's market currency (EGP in Egypt, USD elsewhere); not EGP-only.
- Purchase UI exists only in the web build.
- Content protection: watermarked video and PDF, device limit, screenshot blocking on mobile.
- Must not reproduce College Board / Bluebook branding or third-party questions; we mirror exam
  *functions*, not their look.
- Undecided: domain (Q-01), access-window model (Q-06), wrong-answer behaviour in practice
  (retry vs reveal), custom SPR keypad on phones.

## Brand Commitments

- Name: **Abdelrahman Elmenshawy**. The teacher's own name is the brand (decided 2026-10-08).
- Voice: **warm but demanding.** Believes in the student and holds a high bar. Feedback names the
  next concrete step ("Close. Check the sign in step 2 and try again."), never empty praise and
  never harsh.
- No logo, colours, photos or video assets exist yet.

## Evidence on Hand

None yet: no teacher photos, no existing visual identity, no real student results or testimonials.
Future work must not invent results, scores, testimonials or student counts. Sample questions must be
original (not College Board or publisher items).

## Product Principles

1. **The next step is always obvious.** A student should never wonder what to do now.
2. **Feedback teaches.** Every result points to a skill and a next action, in the teacher's voice.
3. **Exam conditions are rehearsed, not imitated.** Same functions as the real test, our own look.
4. **Math legibility beats decoration.** Equations must read cleanly at every size and text scale.
5. **Honest progress.** Show real data only; never fake proof or inflate achievement.

## Accessibility & Inclusion

WCAG AA contrast; LaTeX scales with the user's text size; full keyboard path through the exam on
web; status never shown by colour alone; mixed RTL/LTR content in explanations and AI replies. Many
students use mid-range phones on 4G: first paint < 4 s on web.
