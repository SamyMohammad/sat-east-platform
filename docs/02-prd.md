# 02 — PRD: Functional Requirements

Priority: **P0** = launch blocker · **P1** = fast follow · **P2** = future, design for it now.
Each requirement has an ID used in the backlog (03) and tests (12).

---

## Module AUTH — Accounts & Access

| ID | Requirement | Pri |
|----|-------------|-----|
| AUTH-01 | Sign up / sign in with email + password and Google. Phone (OTP) optional later. | P0 |
| AUTH-02 | Profile: full name (used in watermark), phone, country, school, grade, target test + test date per course. | P0 |
| AUTH-03 | Roles: `student`, `teacher` (admin). Single teacher account; `parent` role P2. | P0 |
| AUTH-04 | **Device limit**: max 2 active devices per student (configurable). Logging in on a 3rd device requires removing one; removal limited (e.g. 2 changes / 30 days). | P0 |
| AUTH-05 | Teacher can view, reset and revoke a student's devices and suspend an account. | P0 |
| AUTH-06 | Password reset via email. | P0 |
| AUTH-07 | Parent account linked to student, read-only progress view + weekly email. | P2 |

**Decisions (2026-10-08, AUTH-01):**
- Email confirmation is **on** in staging and prod (off in local dev). It needs a real SMTP sender
  before beta.
- Google sign-in code ships with A-1. The button stays hidden until the Google OAuth client is set
  up (`docs/setup/auth.md`).

**Acceptance (AUTH-04)**
- Given a student with 2 registered devices, when they log in on a third, then they see their device list and must remove one before continuing; the removed device's session is invalidated within 1 minute.
- A device change beyond the monthly allowance is blocked with a "contact your teacher" message.

## Module PAY — Catalogue, Purchase, Enrolment

| ID | Requirement | Pri |
|----|-------------|-----|
| PAY-01 | Public catalogue + course landing page (description, syllabus, free topic, price). | P0 |
| PAY-02 | Checkout via payment gateway: cards (local + international), mobile wallets. | P0 |
| PAY-03 | Enrolment is created **only** from a verified gateway webhook (never from the client). | P0 |
| PAY-04 | Prices per currency (EGP / USD) chosen by student country. | P0 |
| PAY-05 | Coupons: % or fixed, expiry, max uses, course-scoped. | P0 |
| PAY-06 | Activation codes (teacher generates codes for cash / InstaPay / offline payments). | P0 |
| PAY-07 | Access window = target test date + grace days, with minimum duration (Proposed; all values in config). | P0 |
| PAY-08 | Renewal purchase at discounted price extends access and unlocks a new mock set. | P1 |
| PAY-09 | Bundle (SAT + EST) price. | P1 |
| PAY-10 | Receipts by email; order history for student; sales report for teacher. | P0 |
| PAY-11 | Refund handling is manual (teacher marks refunded → access revoked). | P1 |

**Acceptance (PAY-03)**
- Given a successful payment, when the gateway's signed webhook arrives, then exactly one enrolment is created (idempotent on transaction id) and the student sees the course within 10 seconds.
- A forged or unsigned callback creates nothing and is logged.

## Module CRS — Course Structure & Content

| ID | Requirement | Pri |
|----|-------------|-----|
| CRS-01 | Hierarchy: Course → Unit (optional grouping) → Topic → Subtopic. | P0 |
| CRS-02 | A topic contains: ≥1 video (one per subtopic recommended, 10–20 min), notes PDF(s), practice set, homework, quiz. | P0 |
| CRS-03 | Teacher can create/reorder/publish/unpublish units, topics, subtopics. | P0 |
| CRS-04 | Video chapters (timestamps) per subtopic, used for "watch the explanation" deep links. | P1 |
| CRS-05 | Teacher's book attached to course as protected PDF. | P0 |
| CRS-06 | A topic can be flagged `is_free_preview`. | P0 |

## Module LRN — Learning Flow & Unlock

| ID | Requirement | Pri |
|----|-------------|-----|
| LRN-01 | Topic steps in fixed order: Video → Notes → Practice → Homework → Quiz. A step unlocks when the previous one's completion rule is met. | P0 |
| LRN-02 | Completion rules (all configurable per course): Video = watched ≥ 80%; Notes = opened; Practice = ≥ N questions attempted (default 10); Homework = submitted; Quiz = score ≥ pass mark (default 75%). | P0 |
| LRN-03 | Passing a topic's quiz unlocks the next topic. | P0 |
| LRN-04 | Failing the quiz opens a **targeted review set** on the skills missed; retake is allowed after completing it, with a cooldown (default 12h) and newly drawn questions. | P0 |
| LRN-05 | Teacher override: unlock any topic/step for a student. | P0 |
| LRN-06 | Placement test that can unlock already-mastered topics. | P2 |
| LRN-07 | "Continue where you left off" on the home screen. | P0 |

## Module QB — Question Bank

| ID | Requirement | Pri |
|----|-------------|-----|
| QB-01 | Question fields: stem (Markdown + LaTeX), images, type (`mcq`, `spr`), choices, correct answer(s), explanation, hint, course(s), topic, subtopic, skill tags, difficulty (E/M/H), `desmos_friendly`, source, status. | P0 |
| QB-02 | Per-choice **distractor tag** (the misconception behind a wrong choice). | P1 |
| QB-03 | Question **pools** per topic: `practice`, `homework`, `quiz`, `mock_reserve`; default split 60/—/20/20 of the bank (homework drawn from practice-pool questions not shown in practice). Configurable. | P0 |
| QB-04 | Lifecycle: `draft → solved → needs_review → approved → published → retired`. Only `published` reaches students. | P0 |
| QB-05 | Bulk import from JSON/CSV produced by the content pipeline (09), with validation report. | P0 |
| QB-06 | Teacher editor with live LaTeX preview; review queue for flagged items. | P0 |
| QB-07 | A question may belong to both SAT and EST courses (no duplication). | P1 |
| QB-08 | Student "report a problem with this question" → teacher queue. | P0 |

## Module PRC — Practice, Homework, Quiz

| ID | Requirement | Pri |
|----|-------------|-----|
| PRC-01 | **Practice**: one question at a time, filter by subtopic + difficulty, immediate feedback, hint, explanation. Unlimited. | P0 |
| PRC-02 | **Homework**: fixed set per student per topic (default 20 Qs), no hints, answers editable until submit, single submission, auto-graded on submit, then full review with explanations. | P0 |
| PRC-03 | **Quiz**: timed (default 1.5 min/question), randomly drawn from quiz pool by blueprint (difficulty mix), includes 2–3 **spiral** questions from earlier topics, no feedback until submit. | P0 |
| PRC-04 | Time spent per question recorded for every attempt. | P0 |
| PRC-05 | Autosave answers; resume after disconnect (homework, quiz, mock). | P0 |
| PRC-06 | Mistake notebook: every wrong answer saved; student can re-attempt; removed after 2 correct re-attempts. | P1 |
| PRC-07 | "Watch the explanation" button on a wrong answer → video at subtopic timestamp. | P1 |

## Module GRD — Grading

| ID | Requirement | Pri |
|----|-------------|-----|
| GRD-01 | MCQ: exact choice match. | P0 |
| GRD-02 | SPR: numeric equivalence — accept equivalent fractions/decimals (`1/2`, `.5`, `0.5`), multiple accepted answers, tolerance where the teacher specifies; reject mixed numbers. Rules in 08 §6. | P0 |
| GRD-03 | Grading runs **server-side**; correct answers are never sent to the client before submission (homework/quiz/mock). | P0 |
| GRD-04 | Teacher can correct an answer key; affected attempts are re-graded and analytics recomputed. | P1 |

## Module ANL — Analytics

| ID | Requirement | Pri |
|----|-------------|-----|
| ANL-01 | Student skill mastery per skill tag (0–100), weak skills list, trend over time. | P0 |
| ANL-02 | Post-homework / post-quiz report: score, per-skill breakdown, time per question, slow-but-correct flags. | P0 |
| ANL-03 | Error type: student self-tags a wrong answer as *concept / careless / time*. | P1 |
| ANL-04 | Misconception insight from distractor tags. | P1 |
| ANL-05 | Teacher **completion matrix**: students × topic steps (video %, notes, homework status/score, quiz) with filters (late, failing, inactive N days). | P0 |
| ANL-06 | Teacher class insights: hardest questions, most chosen wrong option, students stuck on a topic > N days. | P0 |
| ANL-07 | CSV/Excel export of matrix and scores. | P1 |
| ANL-08 | Weekly parent report. | P2 |

## Module MCK — Mock Exams (details in 08)

| ID | Requirement | Pri |
|----|-------------|-----|
| MCK-01 | SAT mock: 2 modules × 22 Qs × 35 min, adaptive Module 2 (easier/harder) by Module 1 performance. | P0 |
| MCK-02 | Bluebook-like UI: timer (hide/show), question navigator, mark for review, answer eliminator, reference sheet, Desmos graphing calculator. | P0 |
| MCK-03 | Mocks assembled from `mock_reserve` pool by blueprint; never repeat a question the student has seen. | P0 |
| MCK-04 | Estimated score **range** (200–800), per-domain breakdown, time analysis, auto-generated drill set on weak skills. | P0 |
| MCK-05 | Diagnostic mock at course start. | P1 |
| MCK-06 | Score history chart; student can log official scores (Bluebook practice tests, real test). | P1 |
| MCK-07 | EST mock on a separate configurable template (non-adaptive). | P0 for EST launch |
| MCK-08 | Mock schedule suggestion for the final month (e.g. 2 mocks/week + review days). | P1 |
| MCK-09 | Mock phase unlocks after all topics passed **or** 30 days before test date (configurable). | P0 |

## Module AI — AI Tutor

| ID | Requirement | Pri |
|----|-------------|-----|
| AI-01 | "Ask about this question" on any question after it has been answered/submitted. | P1 |
| AI-02 | Answers grounded **only** in the question's stored solution/explanation and the topic notes; refuses off-topic. | P1 |
| AI-03 | Never available during an active quiz or mock attempt. | P0 (when AI ships) |
| AI-04 | "Still confused" → escalation to teacher inbox; teacher replies or marks for next live session. | P1 |
| AI-05 | Daily message cap per student; cost dashboard for teacher. | P1 |
| AI-06 | Replies in English or Arabic matching the student. | P1 |

## Module SEC — Content Protection

| ID | Requirement | Pri |
|----|-------------|-----|
| SEC-01 | Protected video streaming (MVP: AES-128 encrypted HLS with short-lived keys; upgrade: DRM — ADR-002) with dynamic watermark (student name + phone/ID). | P0 |
| SEC-02 | PDFs viewed in-app only via short-lived signed URLs; watermark overlay on every page; no download/print UI. | P0 |
| SEC-03 | Mobile apps block screenshots/screen recording (Android `FLAG_SECURE`; iOS capture detection + blur). | P0 |
| SEC-04 | Suspicious activity flags: many devices, abnormal concurrent sessions, many countries. | P1 |

## Module NTF — Notifications

| ID | Requirement | Pri |
|----|-------------|-----|
| NTF-01 | Push + email: purchase receipt, new topic unlocked, live session reminder, inactivity nudge (5 days). | P0 (email) / P1 (push) |
| NTF-02 | Teacher broadcast announcement to a course. | P0 |
| NTF-03 | WhatsApp notifications. | P2 |

## Module LIVE — Live Sessions

| ID | Requirement | Pri |
|----|-------------|-----|
| LIVE-01 | Teacher schedules a session (title, time, course, Zoom/Meet link). Shown in student's local time zone. | P0 |
| LIVE-02 | Recording uploaded to video host and attached to the session afterwards. | P0 |
| LIVE-03 | Questions escalated from AI tutor can be bundled into a session agenda. | P1 |

## Module ADM — Teacher Admin (CMS)

| ID | Requirement | Pri |
|----|-------------|-----|
| ADM-01 | Course/topic/subtopic CRUD, ordering, publish. | P0 |
| ADM-02 | Upload video (to host via direct upload), notes PDF, book. | P0 |
| ADM-03 | Question bank browser, editor, import, review queue, reports queue. | P0 |
| ADM-04 | Student list, profile, progress, devices, enrolments, manual enrol/extend. | P0 |
| ADM-05 | Coupons, activation codes, prices. | P0 |
| ADM-06 | Settings: pass mark, cooldowns, device limit, pool split, access window rules. | P0 |
| ADM-07 | Sales & enrolment dashboard. | P1 |

---

## Global acceptance rules
- Every student-facing screen works at 360 px width (phone) and ≥ 1280 px (laptop).
- No answer key, explanation or `correct` flag reaches the client for an unsubmitted homework/quiz/mock.
- All teacher configuration values live in DB settings, not hard-coded.
