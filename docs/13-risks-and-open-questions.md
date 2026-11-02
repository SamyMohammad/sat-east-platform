# 13 — Risks & Open Questions

## 1. Open questions (owner = who must answer)

| ID | Question | Owner | Blocking? | Default if unanswered |
|----|----------|-------|-----------|------------------------|
| Q-01 | Brand / platform name and domain | Teacher | Before launch (wk 10) | **Name answered 2026-10-08: "Abdelrahman Elmenshawy"** (teacher name = brand). Domain still open |
| Q-02 | Target launch — which SAT test date? | Teacher | Planning | Plan per 11 · **Owner 2026-10-29: "the last trial"; meaning unclear, re-ask which SAT date.** |
| Q-03 | Commercial register / tax card for Paymob onboarding? | Teacher | Before M3 | Activation codes only · **Answered 2026-10-29: no register/tax card yet; start with activation codes.** |
| Q-04 | Monthly operating budget (video, Desmos, LLM, Supabase, email) | Teacher | Before Phase 0 spikes | Start on smallest plans · **Answered 2026-10-29: smallest plans, scale with students.** |
| Q-05 | Desmos commercial plan price & approval | Teacher → Desmos | Before Phase 3 | Mock engine without calculator is not acceptable — blocks M5 · **Answered 2026-10-29: developer contacts Desmos and reports the price.** |
| Q-06 | Confirm proposed access model (test date + 14 days, min 60 days, discounted renewal with new mocks) | Teacher | Before S5 | Build configurable as proposed · **Answered 2026-10-29: confirmed (test date + 14 days, min 60, discounted renewal).** |
| Q-07 | Confirm free Topic 1 per course | Teacher | Before S5 | Yes · **Answered 2026-10-29: yes, first topic of each course is free.** |
| Q-08 | EST exam format (sections, counts, timing, calculator policy, scoring) | Teacher | Phase 4 | — · **Owner 2026-10-29: 50 questions in 75 minutes; lessons somewhat harder; take the syllabus from official EST sources. Sections, calculator and scoring still to confirm.** |
| Q-09 | Prices (EGP, USD), bundle discount, refund policy | Teacher | Before S5 | — · **Owner 2026-10-29: 2500 EGP; refund allowed "after 24 hours of use" (clarify: within 24 h?). USD price and bundle discount still open.** |
| Q-10 | Which question sources are teacher-owned vs third-party publisher books? | Teacher | Before any import | Only teacher-owned published · **Answered 2026-10-29: publish teacher-owned questions only.** |
| Q-11 | Pass mark, homework size, practice minimum, cooldown | Teacher | Before S4 | 75%, 20 Qs, 10 Qs, 12 h · **Answered 2026-10-29: confirmed 75%, 20, 10, 12 h.** |
| Q-12 | Video length/segmentation: one video per subtopic (10–20 min)? Are existing videos already recorded per topic? | Teacher | Before S2 | Per subtopic · **Answered 2026-10-29: one video per subtopic, 10–20 min.** |
| Q-13 | Do we need parent accounts at launch? | Teacher | No | Phase 4 · **Answered 2026-10-29: later (Phase 4).** |
| Q-14 | Device limit: 2 devices, 2 changes / 30 days? | Teacher | Before S1 | Yes · **Answered 2026-10-29: 2 devices, 2 changes / 30 days.** |
| Q-15 | Who does content review if double-solve disagreement rate is high? | Teacher | Pilot result | Teacher reviews flagged only · **Answered 2026-10-29: teacher reviews flagged disagreements only.** |
| Q-16 | Notes PDF: one file per topic or per subtopic? | Teacher | Before first notes upload | One per topic · **Answered 2026-10-29: one file per topic.** |
| Q-17 | Teacher's book on the platform, and when? | Teacher | Before launch | Defer until the book is sent · **Unanswered.** |

## 2. Risk register

| ID | Risk | Likelihood | Impact | Mitigation |
|----|------|-----------|--------|------------|
| R-01 | Answer keys/explanations take far longer than the app (16k questions, no keys) | High | High | Pipeline from week 1; launch with 100–150 Qs/topic; double-solve to cut review load |
| R-02 | Wrong answer keys published → trust loss | Med | High | Double-solve + sampling; "report a problem"; re-grade on key fix (GRD-04) |
| R-03 | Copyright claim over third-party questions | Med | High | Rights gate in pipeline (09 §7); original items only from third-party style |
| R-04 | Content leaks (screen recording, account sharing) | High | Med | Encrypted HLS, moving watermark with identity, device limit, FLAG_SECURE; web download possible for technical users (ADR-002) → re-evaluate after beta, upgrade to DRM if leaks appear |
| R-05 | App Store rejection over digital purchases | Med | Med | ADR-006: web purchases, access-only apps, demo account |
| R-06 | Paymob onboarding delayed (papers) | Med | Med | Activation codes from day one |
| R-07 | Desmos cost too high / delayed approval | Med | High (mocks) | Contact early; budget it in Q-04 |
| R-08 | Score estimate perceived as inaccurate | Med | Med | Show ranges + disclaimer; calibrate with logged official scores |
| R-09 | Solo developer bandwidth / single point of failure | High | High | Strict phase scope, docs (this folder), CI, no gold-plating |
| R-10 | AI tutor gives a wrong explanation | Low–Med | Med | Grounding on approved solutions; escalation; logs reviewed weekly |
| R-11 | Teacher review time becomes the bottleneck | High | High | Weekly review quota agreed; prioritise topics in syllabus order |
| R-12 | Minors' data / privacy complaints | Low | Med | Minimal data, clear privacy policy, deletion on request |
| R-13 | Exam format changes by College Board | Low | Med | Blueprint is data, not code |
