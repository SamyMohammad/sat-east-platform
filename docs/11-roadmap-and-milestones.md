# 11 — Roadmap & Milestones

Assumptions: **1 full-time developer**, 2-week sprints, teacher available ~5 h/week for reviews.
Estimates are ranges; re-plan after Phase 0 velocity is known. Content pipeline runs in parallel
from week 1 (it is the real critical path).

## Timeline overview

```
Week:      1  2  3  4  5  6  7  8  9 10 11 12 13 14 15 16 17 18 19 20 21 22
Phase 0   [====]
Phase 1         [========================]                               ← MVP: sell + learn (SAT)
Phase 2                                   [===========]                  ← analytics depth + AI
Phase 3                                               [==============]   ← mock exam engine
Content  [=========================================================...]  ← pipeline, continuous
Beta                                [==]  ← closed beta with 10–20 students
```

## Phase 0 — Foundations (weeks 1–2)
- Repo, flavors, CI/CD, Supabase dev/prod, migrations of the schema in 06, RLS baseline.
- Design system + `QuestionView` (LaTeX) prototype.
- **Spikes (1 day each):** VdoCipher on web/Android/iOS · Paymob test checkout + webhook · PDF viewer with watermark.
- Content: taxonomy (topics → subtopics → skills) approved by teacher; pilot pipeline on 1 topic.
- **Exit:** schema migrated, app shell deployed to staging, three spikes green, pilot topic's questions extracted.

## Phase 1 — MVP: sell & learn, SAT (weeks 3–12)
| Sprint | Scope |
|--------|-------|
| S1 | Auth, profile, device limit, catalogue, course page |
| S2 | Teacher course builder, video upload, notes upload, course map, topic stepper |
| S3 | Video player + progress, notes viewer, practice mode, question import + editor |
| S4 | Homework + quiz (attempt engine, server grading incl. SPR), unlock logic, reports |
| S5 | Payments (Paymob + codes + coupons), enrollments, access window, emails, completion matrix, live sessions, announcements |
- **Closed beta** (week 11–12) with the teacher's current students using activation codes.
- **Exit / launch criteria:** ≥ 10 topics with videos + notes + ≥ 100 approved questions each; purchase flow live; no P0 bugs; keys-never-leak test passing.

## Phase 2 — Analytics depth + AI tutor (weeks 13–16)
Skill mastery page, mistake notebook, class insights, Excel export, "watch explanation" deep links,
error-type tagging, AI tutor + escalation inbox, push notifications, Android/iOS store submission (ADR-006).

## Phase 3 — Mock exam engine (weeks 17–22)
Mock templates & form assembly, Bluebook-style exam screen, Desmos integration, routing & score
estimate, mock reports + drill sets, score history & official score logging, diagnostic mock,
renewal with fresh mock set. **Must be live ≥ 6 weeks before the first targeted test date.**

## Phase 4 — EST & extras
EST course content + EST mock template (format from teacher), bundle pricing, parent reports,
placement test, misconception insights, WhatsApp notifications.

## Milestones & dependencies

| Milestone | Target | Depends on |
|-----------|--------|-----------|
| M0 Spikes green | end wk 2 | VdoCipher account, Paymob test keys |
| M1 Taxonomy approved | end wk 2 | Teacher |
| M2 First 10 topics content-complete | wk 10 | Pipeline + teacher review + videos recorded |
| M3 Paymob live | wk 10 | Teacher's commercial papers (Q-03) — codes are the fallback |
| M4 SAT MVP public launch | wk 12 | M2, M3 |
| M5 Mock engine live | wk 22 | Desmos commercial plan (Q-05), ≥ 4 mock forms reviewed |
| M6 EST launch | after M5 | EST format + content |

## Sprint ritual (suggested)
- Sprint planning: pick stories from 03 by phase; definition of done = acceptance criteria met + tests + deployed to staging.
- Weekly 30-min check-in with teacher: demo, content review status, open questions (13).
