# ADR-001: Flutter (web + mobile) with Supabase backend

**Status:** Accepted · **Date:** 2026-10-05 · **Deciders:** Developer, Teacher

## Context
One developer, strong in Flutter, must ship web + Android + iOS for students and an admin area for
the teacher. Backend must handle auth, relational data with strict per-user access, file storage,
webhooks and some server logic, with minimal ops.

## Decision
Single Flutter codebase for all clients (student + teacher areas, role-gated). Supabase for
Postgres, Auth, Storage, Edge Functions, cron, realtime.

## Options considered

### A: Flutter + Supabase (chosen)
| Dimension | Assessment |
|---|---|
| Complexity | Low–Med |
| Cost | Low (Pro tier year 1) |
| Scalability | Good for year-1 scale (Postgres) |
| Team familiarity | High |

Pros: one codebase; SQL + RLS fit relational LMS data; Edge Functions for secrets/webhooks; no servers to run.
Cons: Flutter web is heavier on first load and weaker for SEO; RLS mistakes are security bugs.

### B: Next.js web + Flutter mobile + Node/NestJS API
Pros: best web/SEO, flexible backend. Cons: two frontends + a backend to run for one developer — roughly double the build time.

### C: Off-the-shelf LMS (Thinkific/Teachable/Moodle)
Pros: fast. Cons: cannot do adaptive Bluebook simulation, skill analytics, or the unlock logic; platform fees.

## Trade-off analysis
Time-to-market for a solo developer dominates. SEO weakness is mitigated by a small static marketing
landing page (any static site builder) in front of the Flutter app.

## Consequences
- Easier: one UI codebase, shared QuestionView everywhere.
- Harder: SEO, first-load size on web (use deferred loading for teacher area and exam engine).
- Revisit: if web traffic/SEO becomes the main channel, move public pages to a static site.

## Known drawbacks & mitigations
Ten real Supabase weaknesses for this project (RLS mistakes, SQL learning curve, no offline sync,
no push/crash/analytics, no App Check, heavy local Docker, free-tier pausing, Edge Function limits,
SMS OTP cost, vertical scaling) each have a concrete mitigation in
[16-supabase-playbook.md](../16-supabase-playbook.md). None changes this decision.

## Action items
1. [ ] Create dev/prod Supabase projects; migrations in repo.
2. [ ] Static landing page separate from the app (`/` = marketing, `app.` = Flutter).
3. [ ] RLS test suite in CI (see 12).
