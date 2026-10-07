# 15 — Developer Workflow (Flutter + Supabase + Claude Code)

How the solo developer turns the specs in this folder into shipped, tested code — every day,
every story, with the AI skills installed on this machine. Read 00→14 once; use this file daily.

---

## 0. Before writing any code — send the teacher this list (week 1)

The real critical path is not code. These block milestones and take weeks, so start them on day 1.

| # | Ask the teacher | Blocks | Ref |
|---|-----------------|--------|-----|
| 1 | Commercial register / tax card → start **Paymob** onboarding now | M3 (Paymob live) | Q-03, ADR-003 |
| 2 | Accept the **video protection trade-off** (free encrypted HLS, web-download risk) or fund VdoCipher | Phase 0 spike | ADR-002 |
| 3 | Monthly budget (video, Desmos, LLM, Supabase, email) | Plans to buy | Q-04 |
| 4 | Confirm device limit (2 devices, 2 changes / 30 days) | Sprint S1 | Q-14 |
| 5 | Approve **taxonomy** (topics → subtopics → skill codes) as `content/taxonomy.csv` | M1, all analytics | 09 §4 |
| 6 | Pick a **pilot topic** + say which PDFs are teacher-owned vs third-party | Content pipeline | Q-10, 09 §7 |
| 7 | Video segmentation: one video per subtopic? | Sprint S2 | Q-12 |
| 8 | Brand name + domain | Launch | Q-01 |

**Do not** start the Desmos trial yet — it lasts 90 days; start it near Phase 3 (ADR-004).

Track answers in `13-risks-and-open-questions.md`; review it in the weekly 30-min teacher check-in.

---

## 1. Phase 0 checklist (weeks 1–2) — in order

Ordered by "what everything else depends on". Each line = one branch + one PR.

| # | Task | Why first | Story / Req |
|---|------|-----------|-------------|
| 1 | **Scaffold repo**: `apps/client` (flutter create, flavors dev/staging/prod, go_router, get_it, flutter_bloc, supabase_flutter, hive_ce), `supabase init`, `.gitignore`, `analysis_options.yaml` (very_good_analysis or strict lints), `scripts/db-*.ps1` | Nothing exists yet | F-1, 16 §6 |
| 2 | **Hardening migration first** (16 §1): `private` schema, auto-RLS event trigger, revoke-execute-by-default. Then **SQL templates + review checklist** in `supabase/templates/` (16 §2) | Every later SQL file copies these | F-2 |
| 2b | **Schema migration** from `06-data-model.md` (enums + all tables, `private.question_keys`, `private.rate_limits`) + `settings` seed with defaults from Q-11 | Every feature reads it | F-2 |
| 3 | **RLS baseline + pgTAP tests** with `supabase_test_helpers`: policies, `is_teacher()`, `has_access()`, test "`private` not reachable via API", CI gate "no public table without RLS + policy" | Non-negotiable rule #1 & #3 | F-2, NFR-07/08 |
| 4 | **SPR grader, test-first** (SQL function + Dart mirror for the input preview). Both read one fixture file `supabase/tests/fixtures/spr_cases.json` built from `08` §6 and `12` §2 | Pure logic, perfect first TDD task, highest trust risk | GRD-02, 16 §2 |
| 5 | **CI** (GitHub Actions): `dart format`, `flutter analyze`, `flutter test`, `supabase test db`, `supabase db lint`, secret-grep on web build, build web. **Staging** (free Supabase project): deploy migrations + EFs on `main`, daily keep-alive cron | Gates every later PR | F-3, 16 §7 |
| 6 | ⏸ **UI checkpoint — design with Claude Design first**, then **Design system + `QuestionView`** prototype (LaTeX via `flutter_math_fork`, MCQ + SPR input, 360/768/1280) | Shared by 4 features (rule #6) | F-4 |
| 7 | **Spike: encrypted HLS** — ffmpeg AES-128 HLS on Cloudflare R2, signed key URL from a local Edge Function, `hls.js` on web + `video_player` on Android/iOS, moving watermark overlay (1 day, throwaway branch) | Highest platform risk; proves the free option | ADR-002 |
| 8 | **Spike: Paymob** test checkout + HMAC webhook in an Edge Function (1 day) | Money path | ADR-003 |
| 9 | **Spike: PDF viewer** (`pdfrx`) + watermark overlay + signed URL (1 day) | Content protection | SEC-02 |
| 10 | Sentry (client + EFs) + PostHog `AnalyticsService` skeleton; Firebase project for FCM + App Check (monitor mode) | Cheap now, painful later | F-5, ADR-008 |

Later sprints pick up the rest of the playbook: Outbox sync (S4, 16 §3), rate limits + Turnstile (S1/S3, 16 §5), materialized views + `submit_attempt` perf test (S4/S5, 16 §10).

**Phase 0 exit:** schema migrated, app shell deployed to staging, three spikes green, pilot topic extracted.

---

## 2. The per-story loop (use for every story in `03-backlog-user-stories.md`)

```
 1 PICK      → 2 BRAINSTORM → 3 PLAN → 4 BRANCH → 5 BACKEND → 6 FLUTTER → 7 VERIFY → 8 REVIEW → 9 SHIP
 (story+IDs)   (always)       (spec)   (git)      (SQL/EF+    (TDD)        (gate)     (agent)   (PR)
                                                 tests)
```

| Step | What you do | How (in Claude Code) |
|------|-------------|----------------------|
| **1. Pick** | Take the next story of the current sprint (`11` §Phase 1 table). Note its requirement IDs (e.g. `L-6` → `PRC-03, LRN-03`) and acceptance criteria from `02`. | `Implement story L-6 (PRC-03, LRN-03). Read docs/02, 07 §2–3 first.` |
| **2. Brainstorm** *(every story)* | Before planning, review the story for anything to change or add: missing cases, better UX, spec gaps. **Size it to the story:** new UI or logic gets a full session; a task the spec already defines in detail (e.g. a schema "close to verbatim") gets a quick pass on open points only. **Every change or addition is written into the docs first** (`02` / `06` / `07` / new ADR), so the docs stay the source of truth and the plan argues from them. | `/superpowers:brainstorming` → design doc. Add `/grilling` afterwards when the design is still shaky. |
| **3. Plan** | Turn the story into small tasks: migration → RPC/EF → tests → repo → cubit → screen. | Plan mode on, then `/superpowers:writing-plans` — saves a plan file you approve. Check every library API the plan relies on with **context7** first. |
| **4. Branch** | `feat/L-6-quiz-unlock` from `main`. | Ask Claude, or the `git-expert` agent |
| **5. Backend** | Copy a template from `supabase/templates/`, then migration in `supabase/migrations/`, RLS + pgTAP test in `supabase/tests/`, RPC or Edge Function. Check it with the review checklist (`16` §2). Grading/unlock/money logic is **server-side only**. | `/supabase:supabase` skill (+ **context7** for supabase-js / Deno APIs in Edge Functions) → then `supabase db reset` + `supabase test db` |
| **6. Flutter** | Scaffold the feature (data/domain/presentation), cubit with sealed states, screen. Write the test first. | `/flutter-feature` (scaffold) · `/flutter-code-quality:state-management` · `/superpowers:test-driven-development` · `test-writer` agent for bloc/widget tests · **context7** before using any package API (bloc, go_router, supabase_flutter, get_it) |
| **7. Verify** | Format, analyze (infos fatal), tests, forbidden patterns. Run on web at 360 + 1280 px. | `/flutter-code-quality:review-gate` · `/flutter-code-quality:responsive-adaptive` · `/superpowers:verification-before-completion` |
| **8. Review** | Independent review: architecture, security (keys never leak!), performance. | `code-reviewer` agent · `/security-review` for auth/payment/RLS stories |
| **9. Ship** | Commit, PR titled with the IDs: `PRC-03 LRN-03: timed quiz unlocks next topic`. Claude pushes and opens the PR. Merge when CI is green. Update the graph. | `/caveman:caveman-commit` or `git-expert` agent · `gh pr create` / `gh pr checks --watch` (gh CLI, already authenticated) · `pr-reviewer` agent · `graphify update .` |

**Ship:** Claude handles all git (branch, commit, push, `gh pr create`, `gh pr checks --watch`) after the safety checks. You review and merge the PR.

**Definition of done** (from `11`): acceptance criteria met + tests + deployed to staging.

### When things break
| Situation | Use |
|-----------|-----|
| Bug, crash, failing test | `/superpowers:systematic-debugging` or `debugger` agent |
| Hard / intermittent / slow | `/diagnosing-bugs` |
| Design question for a module's API | `/codebase-design` · `/design-an-interface` |
| New tech decision | `/engineering:architecture` → new `docs/adr/ADR-00N` |
| Throwaway UI or logic experiment | `/prototype` |
| Library docs (Flutter packages, Supabase), version migration, package-specific errors | context7 MCP (`resolve-library-id` → `query-docs`) |
| CI failure on a PR | `gh run view --log-failed` → `debugger` agent |

---

## 3. Sprint rhythm (2 weeks, solo)

| When | Do |
|------|-----|
| Sprint day 1 | `/product-management:sprint-planning` with the stories from `11` for this sprint. Write sprint goal in `docs/sprints/S<n>.md`. |
| Daily | 1–2 stories through the loop above. End of day: `/engineering:standup` for a log. |
| Weekly | 30-min teacher demo + open questions (`13`). Content pipeline status. |
| Sprint end | Deploy to staging, run the E2E happy paths in `12` §3, update `13` risks, re-estimate. |

---

## 4. Rules Claude must follow (already in `CLAUDE.md`, repeated because they matter)

1. Answer keys never reach the client before submission.
2. Grading, unlocking, scoring, payments, enrollment, devices → server-side.
3. Every table: RLS + policies + a pgTAP test.
4. Secrets only in Edge Function secrets.
5. Tunables from `settings`, never hard-coded.
6. One `QuestionView` for practice/homework/quiz/mock.
7. Purchase UI only in the web build (`ENABLE_PURCHASE`).
8. English UI; mixed RTL/LTR content supported.

Architecture choices for the client: see **ADR-007** (Cubit/Bloc, get_it, `supabase_flutter`,
`apps/client` layout).
