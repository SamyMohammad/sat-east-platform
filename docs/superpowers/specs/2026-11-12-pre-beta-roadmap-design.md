# Pre-beta roadmap — missing and deferred features

> Date: 2026-11-12 · Owner decisions from the brainstorm of 2026-11-11/12.
> This is an ordering document, not a build spec. Every project below gets its own
> brainstorm → spec → plan before any code (`docs/15-dev-workflow.md`).

## Intent

The closed-beta code (activation codes, no payments) is done and staging-checked. The owner
wants the beta to open with a fuller product: the mock exam, the AI tutor and every known
small gap closed first. Everything else waits until students are using the platform.

## Goals

- Closed beta first, **web only**. No store builds before the beta.
- Before the first beta student: SAT mock exam, Ask AI, and the small gaps listed in lane C.
- After the beta opens: payments and sign-up first, then the rest in the order below.

## Non-goals (for the beta)

- Android / iOS release work, mobile video, screen-capture blocking (SEC-03).
- EST mock (MCK-07), mock schedule, official-score logging (MCK-06), drill set, time-per-question chart.
- AI escalation to the teacher (AI-04) and the teacher cost dashboard.
- Paymob, coupons, emails, Google sign-in, live sessions, announcements, ANL-05, quiz spiral and blueprints.

## Anti-goals

- No recurring cost for the AI tutor in the beta. If the free allowance runs out, the tutor
  stops for the day; it never falls over to a paid model silently.
- No student prompt goes to a provider that trains on it or has humans review it.
- No Desmos embed in front of students before Desmos confirms commercial use in writing.

## Before the beta — three lanes

Up to three lanes at once, each in its own worktree (rules in `docs/STATUS.md`, "How we work").

| Lane | Projects, in order |
|------|--------------------|
| A | SAT mock exam: (1) assembly server, (2) teacher review screen, (3) exam engine + screen, (4) report |
| B | Ask AI → review-set screen (S-23) → regrade after a key fix |
| C | PostHog events (NFR-18) → staff course preview → move the free intro video off YouTube → `register-device` Edge Function |

The persistent answer outbox was on this list; it merged as R4a (#84).

### Lane A — SAT mock exam

Owner decisions:
- SAT only. Two adaptive modules, 22 questions and 35 minutes each (`docs/08` §1–§5).
- Build and staging-check against demo questions with one demo form. The teacher loads the
  real `mock_reserve` bank through the existing import before the beta (66 questions per form).
- Forms are assembled by the server from the blueprint, then reviewed by the teacher:
  swap a question, publish, freeze.
- Basic report: estimated score range, correct per module, accuracy per domain and per skill,
  wrong answers with explanations. It reuses the shared attempt report.
- A form unlocks by course progress: the number of finished topics needed for each form
  comes from `settings`.

Router's calls (not yet confirmed line by line by the owner):
- One attempt per form. The deadline is stored on the server at module start and keeps
  running if the student leaves.
- Routing to module 2 and scoring happen on the server only; scale tables `sat_scale_easy`
  and `sat_scale_hard` live in `settings`.
- The screen reuses `QuestionView` and the quiz exam bar, and adds the answer eliminator,
  the reference sheet, the end-of-module review page and the module transition screen.
- AI tutor, notes and app navigation are hidden during an active module (AI-03).
- Phones are allowed with a banner recommending a laptop or tablet.
- The calculator slot stays empty until the Desmos decision; the mock does not wait for it.
- Verify the format numbers against the current College Board specification during the spec.

### Lane B — Ask AI, review set, regrade

Ask AI (ADR-005, `docs/07` §6) — owner decisions:
- Fully free. Primary provider Cloudflare Workers AI, fallback Groq, both behind the one
  `ai-tutor` Edge Function so the provider can change without a client release.
- A small per-student daily cap and a platform-wide daily budget, both from `settings`.
  When either is used up the student sees a clear "back tomorrow" message.
- Shown after an answer everywhere: practice after the reveal, and the homework, quiz and
  mock reports. Hidden during any active quiz or mock, enforced by the server.
- No escalation to the teacher in the beta. Every message and its token count is logged.

Known limits (research 2026-11-11, several provider pages could not be verified):
- Cloudflare's free allowance is 10,000 neurons a day, roughly 100–160 tutor messages a day
  for the whole platform. Free covers a small beta only.
- Gemini's unpaid tier was rejected: prompts are used for training and read by reviewers.

Open before the build (router does these in the Ask AI spec, and returns to the owner if
either fails):
1. Read Cloudflare's and Groq's data-use terms for the free tier.
2. Test explanation quality on a sample of real questions with worked solutions.

Review-set screen (S-23): the server side exists (lane 2b, #36); this is the client screen.

Regrade after a key fix — owner decision: regrade in the student's favour only. Affected
quiz, homework and mock attempts are regraded on the server; a score can go up, never down;
a student who now passes gets the next topic unlocked; nothing already unlocked is locked again.

### Lane C — small gaps

- **PostHog events:** the NFR-18 list as written, no PII. (Router's call.)
- **Staff course preview:** teachers and admins open any course read-only without an
  enrolment and without recording progress. (Router's call.)
- **Free intro video:** owner decision — YouTube is removed. The intro video is published
  through the protected player like every other video, and the server stops accepting
  YouTube assets. It counts against the 9 GB video cap.
- **`register-device` Edge Function:** build it; App Check stays off for the web beta.
  (Router's call.)

### Deferred inside the beta scope — Desmos

Desmos is wanted on every question (practice, homework, quiz, mock). It is on hold: the
commercial terms and the key price could not be verified (the Desmos terms pages did not
load; the demo key is deprecated for production). The owner writes to Desmos first.
GeoGebra needs a special licence for commercial use. The only guaranteed free route is our
own calculator on JSXGraph (MIT), which is a large build and not the calculator students
meet on test day. Decide when Desmos answers.

## Owner tasks (not code)

- Write to Desmos (`desmos.com/my-api`): key, commercial use in a paid test-prep product, price.
- Restore `sat-prod`, move it to Pro and add the secrets (`docs/setup/prod.md`).
- Teacher: skill taxonomy, first real topics, and the `mock_reserve` question bank.
- Create the Cloudflare Workers AI token and the Groq key as Edge Function secrets when the
  Ask AI spec asks for them.

## After the beta opens

1. Payments and sign-up: Paymob (blocked on Q-03), coupons, Resend emails, Google sign-in.
2. Teacher tools: live sessions, announcements, completion matrix (ANL-05). *(order is the router's guess)*
3. Assessment quality: quiz spiral and difficulty blueprint, homework E/M/H blueprint. *(guess)*
4. Mobile: managed video provider decision (R2), Android signing, iOS flavors, SEC-03. *(guess)*
5. Desmos, whenever the licence is settled.

The production-readiness items (R0–R4 in `docs/STATUS.md`) keep their own track.

## Left to each project's spec

Data model, RPC names, error codes, settings keys, screen details and PR split. This document
fixes only scope and order.
