# SAT / EST Math Platform — Project Documentation

> Single source of truth for planning and building the platform.
> Status: **v0.1 — Draft for developer planning** · Date: 2026-10-05
> Roles covered: Product Owner · Project Manager · Solution Architect

## What we are building (one paragraph)

A commercial, single-teacher learning platform where an American-Diploma math teacher sells
two separate self-paced courses — **SAT Math** (~40 topics) and **EST Math** (~45 topics).
Each topic follows a locked sequence: **Video → Notes (PDF) → Practice → Homework (auto-graded) → Quiz**,
and passing the quiz unlocks the next topic. Every answer feeds a skill-level analytics engine that
shows the student their weak points and shows the teacher who is behind. The final stage is a
**Bluebook-style adaptive mock exam** phase with an embedded **Desmos** calculator. An **AI tutor**
answers student questions grounded in the teacher's own worked solutions. Runs on mobile, tablet
and laptop; UI is English-only.

## Reading order

| # | Document | Owner hat | Read when |
|---|----------|-----------|-----------|
| 01 | [Product Vision & Scope](01-product-vision.md) | PO | First — the "why" and the boundaries |
| 02 | [PRD — Functional Requirements](02-prd.md) | PO | Before estimating anything |
| 03 | [Backlog — Epics & User Stories](03-backlog-user-stories.md) | PO / PM | Sprint planning |
| 04 | [User Flows & Screen Inventory](04-user-flows-and-screens.md) | PO / UX | Before design & routing |
| 05 | [System Architecture](05-system-architecture.md) | Architect | Before writing code |
| 06 | [Data Model](06-data-model.md) | Architect | Before the first migration |
| 07 | [Backend Logic & API](07-backend-logic-and-api.md) | Architect | While building features |
| 08 | [Exam Engine Spec (Bluebook simulator)](08-exam-engine-spec.md) | Architect / PO | Phase 3 |
| 09 | [Content Pipeline (question bank ingestion)](09-content-pipeline.md) | Architect / PO | Phase 1 — runs in parallel with dev |
| 10 | [Non-Functional Requirements](10-non-functional-requirements.md) | Architect | Before infra setup |
| 11 | [Roadmap & Milestones](11-roadmap-and-milestones.md) | PM | Planning & tracking |
| 12 | [Testing Strategy](12-testing-strategy.md) | Architect | Phase 0 setup |
| 13 | [Risks & Open Questions](13-risks-and-open-questions.md) | PM | Weekly review |
| 14 | [Glossary](14-glossary.md) | All | Whenever a term is unclear |
| 15 | [Developer Workflow](15-dev-workflow.md) | Dev | Daily — how to build each story |
| 16 | [Supabase Playbook](16-supabase-playbook.md) | Architect / Dev | Before any SQL; drawbacks → mitigations |
| ADR | [Architecture Decision Records](adr/) | Architect | When questioning a tech choice |
| — | [SQL / Edge Function templates](../supabase/templates/README.md) | Dev | Start every new SQL file here (CLAUDE.md rule 10) + review checklist |
| — | [Implementation plans](superpowers/plans/) | Dev | Per-story plans from `/superpowers:writing-plans` |

There is also a [`CLAUDE.md`](../CLAUDE.md) at the repo root with conventions for AI-assisted coding.

## Status legend used across the docs

- **Decided** — confirmed by the teacher (stakeholder). Do not change without asking.
- **Proposed** — recommended by the PO/architect, not yet confirmed. Build so it can change
  (config, feature flag), and track it in [13-risks-and-open-questions.md](13-risks-and-open-questions.md).
- **TBD** — blocking unknown; see open questions.

## Key decisions at a glance

| Area | Decision | Status |
|------|----------|--------|
| Courses | SAT and EST are separate products, bought independently | Decided |
| Pricing model | One-time fixed price per course | Decided |
| Access duration | Until the student's chosen test date + 14 days, min 60 days; discounted renewal with fresh mocks | Proposed |
| Free sample | Topic 1 of each course free (video, notes, quiz) | Proposed |
| Pacing | Self-paced, sequential unlock via quiz pass | Decided (self-paced implied by global audience) |
| Audience | Any student, Egypt and abroad | Decided |
| Devices | Mobile, tablet, laptop | Decided |
| UI language | English only | Decided |
| Client | Flutter (web + Android + iOS), one codebase | Decided |
| Backend | Supabase (Postgres, Auth, Storage, Edge Functions) | Decided |
| Video hosting | MVP: encrypted HLS on Cloudflare R2 + watermark overlay; upgrade: VdoCipher DRM | Proposed — ADR-002 |
| Payments | Paymob (cards incl. international, wallets) | Proposed — ADR-003 |
| Calculator | Desmos API — paid commercial plan required | Proposed — ADR-004 |
| AI tutor | LLM grounded in teacher-approved solutions; escalates to teacher | Proposed — ADR-005 |
| Human staff | Teacher works alone — no assistant | Decided |
| Live sessions | 1–2/week, recorded and posted | Decided |
| Community | External Telegram/WhatsApp group at launch | Proposed |
