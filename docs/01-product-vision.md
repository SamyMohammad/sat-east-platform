# 01 — Product Vision & Scope

## 1. Problem statement

American-Diploma students preparing for the SAT and EST need far more structured practice than
live classes can provide, and they need to know *exactly* which skills are costing them points.
Today the teacher's material (videos, notes, ~400 questions per topic, past EST exams) lives in
PDFs and recordings with no auto-grading, no tracking and no exam simulation. The teacher cannot
see who did their homework, students cannot practise in real exam conditions with Desmos, and the
material cannot be sold to students outside the teacher's city or country.
Without a platform, the teacher's reach is capped by his own hours.

## 2. Vision

> The most structured way to prepare for SAT and EST Math: every topic learned, practised,
> tested and diagnosed — then rehearsed under real exam conditions.

## 3. Personas

### P1 — Student ("Youssef", 16)
- American-Diploma Grade 11, in Egypt or the Gulf; targets SAT Math 700+ or a high EST score.
- Studies on his phone in short bursts; takes mocks on a laptop.
- Pain: does many questions but doesn't know *why* he loses points; procrastinates without deadlines.
- Needs: clear next step, instant feedback, proof of progress, exam-day confidence.

### P2 — Teacher / Admin (course owner)
- Single teacher, works alone, no assistant. Records videos, owns notes and question banks.
- Pain: no visibility into homework completion; repetitive student questions; content leaks.
- Needs: a dashboard of who is behind, low-effort content upload, protection, an AI that handles
  routine questions, and reports that sell the course.

### P3 — Parent (secondary, read-only, P2 priority)
- Usually the payer. Wants to know the money is being used.
- Needs: simple progress report (topics done, homework, mock scores).

## 4. Goals (outcomes, measurable)

| # | Goal | Metric | Target (first 6 months after launch) |
|---|------|--------|--------------------------------------|
| G1 | Students actually progress | % of enrolled students who pass ≥ 10 topic quizzes | ≥ 60% |
| G2 | Homework discipline | Homework submission rate on unlocked topics | ≥ 75% |
| G3 | Visible improvement | Median improvement between diagnostic mock and last mock | ≥ +60 points (SAT scale) |
| G4 | Teacher time saved | % of student questions resolved by AI tutor without escalation | ≥ 70% |
| G5 | Revenue | Paid conversions from free-topic sign-ups | ≥ 15% (hypothesis — revisit after first cohort) |

These are hypotheses for a new product with no baseline; revisit after the first trial cycle.

## 5. Scope — in (v1)

- Course catalogue, purchase, enrolment (SAT and EST separately).
- Topic learning flow: Video → Notes → Practice → Homework → Quiz → unlock next.
- Question bank tagged by course, topic, subtopic, skill, difficulty, type.
- Auto-grading for MCQ and grid-in (Student-Produced Response) with equivalent-answer handling.
- Student analytics: skill mastery, weak points, mistake notebook, time per question.
- Teacher dashboard: per-topic completion matrix, homework status, class-wide hardest questions.
- Content protection: encrypted video (DRM as upgrade path — ADR-002) with student watermark, in-app-only PDF viewer, device limit.
- AI tutor grounded in stored solutions, with escalation to teacher.
- Mock exam phase: Bluebook-style adaptive SAT mock with Desmos, reference sheet, review tools;
  EST mock on its own template.
- Live session schedule + recordings.
- Content ingestion pipeline for the teacher's PDFs (offline tooling, not a public feature).

## 6. Non-goals (v1)

| Non-goal | Why |
|----------|-----|
| Multi-teacher marketplace / multi-tenant SaaS | Built for one teacher's brand; adds auth/billing complexity for no current need |
| Reading & Writing sections of the SAT | Teacher is a math teacher; architecture keeps "section" generic for later |
| In-platform chat/community | External Telegram/WhatsApp group is free and good enough at launch |
| Built-in live streaming | Use Zoom/Google Meet links; we only schedule and host recordings |
| Subscription billing | Decided: one-time price per course |
| Reproducing College Board / third-party publisher questions | Copyright risk; original or teacher-owned content only |
| Arabic UI | Decided: English-only UI |

## 7. Business model

- **One-time price per course** (SAT, EST), optional bundle discount for both.
- Display price in EGP for Egypt, USD for international (Paymob settles in EGP — see ADR-003).
- **Access window (Proposed):** student picks their target test date at purchase; access lasts until
  that date + 14 days, with a minimum of 60 days. Renewal for another test date at a discount
  (e.g. 40–50%) unlocks a fresh set of mock exams the student has not seen.
- **Free sample (Proposed):** Topic 1 of each course fully free to drive conversion.
- Coupons for promotions and the teacher's offline students.

## 8. Constraints

- One developer (Flutter-strong), teacher has no technical staff.
- Teacher works alone: every feature must minimise his manual effort.
- ~16,000 SAT questions + EST bank arrive **without answer keys** → solving/explanations pipeline is on the critical path (see 09).
- Desmos commercial use requires a paid plan.
- App-store rules on selling digital content in-app (see ADR-006).
- Students are mostly minors (under 18) → privacy and parental-consent considerations.
