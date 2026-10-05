# 03 — Backlog: Epics & User Stories

Sizes: **S** ≤ 1 day · **M** 2–3 days · **L** 4–5 days · **XL** split before sprint.
Phase refers to [11-roadmap-and-milestones.md](11-roadmap-and-milestones.md).
Req = requirement IDs in [02-prd.md](02-prd.md).

---

## EP-0 Foundations (Phase 0)

| ID | Story / task | Size | Req |
|----|--------------|------|-----|
| F-1 | Flutter monorepo: `apps/client` (web+mobile, role-based), `packages/core`, flavors dev/staging/prod | M | — |
| F-2 | Supabase projects (dev, prod), migrations in repo, seed script | M | — |
| F-3 | CI: analyze, test, build web; deploy web to hosting on `main` | M | — |
| F-4 | Design system: theme tokens, typography, math rendering widget (LaTeX), responsive layout shell | L | — |
| F-5 | Error tracking (Sentry) + product analytics events skeleton | S | — |

## EP-1 Accounts & Devices (Phase 1)

| ID | User story | Size | Req |
|----|-----------|------|-----|
| A-1 | As a student, I want to sign up with email or Google so that I can start the free topic. | M | AUTH-01 |
| A-2 | As a student, I want to set my target test and test date so that my plan and access window are correct. | S | AUTH-02, PAY-07 |
| A-3 | As a student logging in on a third device, I want to see and remove an old device so that I can continue legitimately. | L | AUTH-04 |
| A-4 | As the teacher, I want to see and reset a student's devices so that I can help genuine students and stop sharing. | M | AUTH-05 |
| A-5 | As a student, I want to reset my password by email. | S | AUTH-06 |

## EP-2 Catalogue & Payments (Phase 1)

| ID | User story | Size | Req |
|----|-----------|------|-----|
| P-1 | As a visitor, I want a course page with syllabus, price and free topic so that I can decide to buy. | M | PAY-01 |
| P-2 | As a student, I want to pay by card or wallet in my currency so that I get access immediately. | L | PAY-02, PAY-04 |
| P-3 | As the system, I create the enrolment only from a verified, idempotent webhook. | M | PAY-03 |
| P-4 | As a student, I want to apply a coupon. | S | PAY-05 |
| P-5 | As the teacher, I want to generate activation codes so that offline/cash payers can enrol. | M | PAY-06 |
| P-6 | As a student, I want a receipt and order history. | S | PAY-10 |
| P-7 | As a returning student, I want to renew for a new test date at a discount and get new mocks. | M | PAY-08 |

## EP-3 Content Management — Teacher (Phase 1)

| ID | User story | Size | Req |
|----|-----------|------|-----|
| C-1 | As the teacher, I want to create and reorder topics and subtopics so that the course mirrors my syllabus. | M | CRS-01, ADM-01 |
| C-2 | As the teacher, I want to upload a video and have it attached to a subtopic so that students can watch it securely. | L | ADM-02, SEC-01 |
| C-3 | As the teacher, I want to upload notes PDFs and my book so that students read them in-app only. | M | ADM-02, CRS-05 |
| C-4 | As the teacher, I want to bulk-import reviewed questions with a validation report. | L | QB-05 |
| C-5 | As the teacher, I want to edit a question with live LaTeX preview. | L | QB-06 |
| C-6 | As the teacher, I want a review queue for flagged/reported questions. | M | QB-04, QB-08 |
| C-7 | As the teacher, I want to change pass mark, cooldown, device limit and pool split in settings. | S | ADM-06 |

## EP-4 Learning Flow — Student (Phase 1)

| ID | User story | Size | Req |
|----|-----------|------|-----|
| L-1 | As a student, I want a course map showing locked/unlocked/completed topics so that I know my next step. | M | LRN-01, LRN-07 |
| L-2 | As a student, I want to watch the topic video with progress saved. | M | SEC-01, LRN-02 |
| L-3 | As a student, I want to read notes in-app with my name watermarked. | M | SEC-02 |
| L-4 | As a student, I want to practise by subtopic and difficulty with instant feedback, hints and explanations. | L | PRC-01 |
| L-5 | As a student, I want to do homework, change answers until I submit, and see my graded report. | L | PRC-02, GRD-* |
| L-6 | As a student, I want a timed quiz that unlocks the next topic when I pass. | L | PRC-03, LRN-03 |
| L-7 | As a student who failed a quiz, I want a review set on my weak skills before retaking with new questions. | M | LRN-04 |
| L-8 | As a student, I want my answers autosaved so a lost connection doesn't cost me. | M | PRC-05 |
| L-9 | As the teacher, I want to unlock a topic for a specific student. | S | LRN-05 |

## EP-5 Grading & Analytics (Phase 1 core, Phase 2 depth)

| ID | User story | Size | Req |
|----|-----------|------|-----|
| G-1 | As the system, I grade MCQ and SPR server-side with equivalence rules. | L | GRD-01..03 |
| G-2 | As a student, I want a report after homework/quiz with per-skill breakdown and time per question. | M | ANL-02 |
| G-3 | As the teacher, I want a matrix of every student × topic step so I see who did homework. | L | ANL-05 |
| G-4 | As the teacher, I want filters: late, failing, inactive 5+ days. | M | ANL-05 |
| G-5 | As a student, I want a skills page showing mastery and weak skills. (Phase 2) | L | ANL-01 |
| G-6 | As a student, I want a mistake notebook I can re-attempt. (Phase 2) | M | PRC-06 |
| G-7 | As the teacher, I want class insights: hardest questions, most-chosen wrong answer, stuck students. (Phase 2) | M | ANL-06 |
| G-8 | As a student, I want "watch the explanation" to jump to the right video minute. (Phase 2) | S | PRC-07 |
| G-9 | As the teacher, I want to export the matrix to Excel. (Phase 2) | S | ANL-07 |

## EP-6 AI Tutor (Phase 2)

| ID | User story | Size | Req |
|----|-----------|------|-----|
| T-1 | As a student, I want to ask the AI about a question I've answered and get an explanation based on my teacher's solution. | L | AI-01, AI-02 |
| T-2 | As a student, I want to escalate to the teacher if I'm still confused. | M | AI-04 |
| T-3 | As the teacher, I want an inbox of escalations I can answer or add to the next live session. | M | AI-04, LIVE-03 |
| T-4 | As the teacher, I want daily caps and a cost view. | S | AI-05 |

## EP-7 Notifications & Live (Phase 1–2)

| ID | User story | Size | Req |
|----|-----------|------|-----|
| N-1 | As a student, I get email receipts and reminders. (Phase 1) | M | NTF-01 |
| N-2 | As the teacher, I want to post an announcement to a course. (Phase 1) | S | NTF-02 |
| N-3 | As a student, I want push notifications for new unlocks and live sessions. (Phase 2) | M | NTF-01 |
| N-4 | As the teacher, I want to schedule live sessions and attach recordings. (Phase 1) | M | LIVE-01, LIVE-02 |

## EP-8 Mock Exam Engine (Phase 3)

| ID | User story | Size | Req |
|----|-----------|------|-----|
| M-1 | As the system, I assemble a mock (M1 + M2-easy + M2-hard) from unseen `mock_reserve` questions per blueprint. | L | MCK-03 |
| M-2 | As a student, I want a Bluebook-like exam screen with timer, navigator, mark for review, eliminator, reference sheet. | XL→split | MCK-02 |
| M-3 | As a student, I want Desmos inside the exam. | L | MCK-02 |
| M-4 | As the system, I route Module 2 by Module 1 performance. | M | MCK-01 |
| M-5 | As a student, I want an estimated score range and domain breakdown after the mock. | M | MCK-04 |
| M-6 | As a student, I want an auto-generated drill set on the skills I missed. | M | MCK-04 |
| M-7 | As a student, I want a score history chart and to log official scores. | M | MCK-06 |
| M-8 | As a student, I want a diagnostic mock at the start. | S | MCK-05 |
| M-9 | As an EST student, I want an EST-format mock. | L | MCK-07 |

## EP-9 Later (Phase 4 / P2)

Parent accounts & weekly report (AUTH-07, ANL-08) · Placement test (LRN-06) · WhatsApp notifications (NTF-03) ·
Distractor-tag misconception insights (QB-02, ANL-04) · Suspicious-activity detection (SEC-04).
