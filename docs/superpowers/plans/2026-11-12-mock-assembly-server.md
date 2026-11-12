# Mock form assembly server (MCK-03) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

## Context

The owner wants the SAT mock exam in place before the closed beta. The approved spec splits it into four parts; this plan is **Part 1: the server that assembles frozen mock forms from the question bank, plus demo data**. Nothing exists today beyond the empty tables `mock_templates`, `mock_forms`, `mock_results`. After this PR a teacher (through SQL for now, through the Part 2 screen later) can assemble a draft form, swap questions, publish it or delete it, and staging has enough `mock_reserve` demo questions to build one form.

**Goal:** Teacher-only RPCs that build, edit and freeze SAT mock forms from a blueprint, with a precise shortage report when the bank is too small.

**Architecture:** One migration adds a form status and a set of `security definer` RPCs. A blueprint is turned into a deterministic list of 22 slots per module, each slot being one cell (difficulty, domain, type); assembly fills every slot with a random unused eligible question from that cell. Shortage, swap and readiness all reason in cells, so they share the same private helpers.

**Tech Stack:** Postgres (plpgsql), pgTAP, Supabase CLI. No client code, no Edge Function.

**Spec:** `docs/superpowers/specs/2026-11-12-mock-sat-design.md` (Part 1). Base: `docs/08-exam-engine-spec.md` §2–§3.

## Global Constraints

- Every SQL file starts from `supabase/templates/` (`rpc.sql`, `setting.sql`, `test.sql`) and passes the checklist in `docs/16-supabase-playbook.md` §2.
- Every function: `security definer`, `set search_path = ''`, schema-qualified names, `auth.uid()` null → `raise exception 'not_authenticated'`, then `if not public.is_teacher() then raise exception 'forbidden'`.
- Every public RPC: `revoke execute ... from public, anon;` then `grant execute ... to authenticated;`. Private helpers get no grant.
- Errors are raised as `raise exception '<code>'` with a code from `docs/07` §9. Unknown ids raise `invalid_input` (there is no not-found code).
- No magic numbers: blueprint values come from the `settings` key `mock_blueprint_sat`.
- No answer key or explanation is returned by any RPC in this plan (teacher preview uses the existing `teacher_get_question`).
- Demo data lives in `supabase/seeds/demo/`, never in a migration. The local pgTAP database stays unseeded.
- English only in all content and seed data.
- Do not commit. The router commits, pushes and opens the PR. Never stage `.codex/`, `.impeccable/`, `.vscode/`, `.wrangler/`, `content/`.
- Local `supabase start` / `db reset` can exit 139 on this machine. Try `scripts/db-up.ps1` then `scripts/db-test.ps1`; if the stack will not start, report that plainly — CI's `db` job on the draft PR is the source of truth.

## Review Focus

1. **Bank changes while a form is a draft** (a question is retired, unpublished, moved out of `mock_reserve` or loses its single domain): publishing must not freeze a broken form → publish re-checks all 66 and returns the stale ids (Task 3).
2. **A question linked to no skill, or to skills in two domains**: never picked, counted in `no_domain` (Task 2).
3. **A blueprint whose numbers do not add up** (difficulty counts ≠ module count, shares ≠ 1): assembly refuses with `internal` instead of building a 21-question module (Task 1).
4. **Two teachers pressing "assemble" at once**: no shared question, no duplicate `form_no` → transaction-level advisory lock per template (Task 2; not testable in pgTAP, reviewer reads the code).
5. **Null or out-of-range arguments** (`p_set_no` null or < 1, null ids, a course that is not SAT): `invalid_input`, nothing written (Tasks 2–3).

## File Structure

| File | Responsibility |
|------|----------------|
| Create `supabase/migrations/20261112100000_mck03_mock_assembly.sql` | Form status columns, `mock_blueprint_sat` setting, private helpers, the seven teacher RPCs |
| Create `supabase/tests/50_mock_assembly.test.sql` | pgTAP for everything above |
| Create `supabase/seeds/demo/40_mock_reserve.sql` | Demo `mock_reserve` questions + skills for the four domains |
| Modify `supabase/seeds/demo/check.sql`, `supabase/seeds/demo/README.md` | Verify and document the mock demo bank |
| Modify `.github/workflows/ci.yml` (only if seed files are listed one by one in the "Demo seed: apply twice + check" and "Seed staging demo data" steps) | Apply the new seed file |
| Modify `docs/06-data-model.md`, `docs/07-backend-logic-and-api.md` (§1.1 RPC list, §9 codes), `docs/08-exam-engine-spec.md` §3 | Record status column, RPCs, new code, slot rule |
| Create `docs/superpowers/plans/2026-11-12-mock-assembly-server.md` | Copy of this plan (Task 0) |

Existing things to reuse (do not re-implement): `public.is_teacher()` (`20261007003700_f2_rls_helpers.sql`), `public.teacher_get_question(p_id uuid)` for previews (`20261024100000_lane3c2_question_editor.sql`), `private.demo_upsert_question(...)` (`supabase/seeds/demo/00_structure.sql:105`), test helpers `tests.create_supabase_user / get_supabase_uid / authenticate_as / clear_authentication`, fixture style of `supabase/tests/35_question_editor.test.sql:7-19`.

## The slot rule (the one algorithm the tests do not fully determine)

For a module with `count = N` and difficulty counts `E, M, H`:

1. **Difficulty:** slots `1..E` are E, the next `M` are M, the rest H. (This is also "difficulty ascending within module".)
2. **Domain counts:** `n_d = floor(share_d × N)`; hand out the remaining `N − Σ n_d` one each to the domains with the largest fractional part, ties by domain name ascending.
3. **Domain of slot i** (i from 1): the domain with the largest `n_d × i / N − already_assigned_d`, ties by domain name ascending.
4. **Type:** `s = round(N × spr_ratio)` (half up). Slot i is `spr` when `floor(i × s / N) > floor((i − 1) × s / N)`, else `mcq`.

With the seeded blueprint every module gives: domains Advanced Math 8, Algebra 8, Geometry & Trig 3, PSDA 3; six SPR slots at 4, 8, 11, 15, 19, 22; slots 1–4 are Advanced Math, Algebra, Geometry & Trig, PSDA.

**Router call — the rule fixes a cell recipe, not only marginal counts.** For N = 22 the domain order is AM, Alg, G, P, AM, Alg, AM, Alg, AM, Alg, G, P, AM, Alg, AM, Alg, G, AM, Alg, P, AM, Alg, so the SPR slots always land on P, Alg, G, AM, Alg, Alg. Task 1 must compute and the plan copy must record the resulting per-form table (domain × difficulty × type → count, summed over M1 + M2E + M2H: 19 non-empty cells, pinned by a `results_eq` in `50_mock_assembly.test.sql`; domain totals Advanced Math 24, Algebra 24, Geometry & Trig 9, PSDA 9). The teacher builds the `mock_reserve` bank against that table; the overview RPC exposes it as `need_per_form`.

**Domain strings.** Eligibility needs `skills.domain` to equal a blueprint key exactly: `Algebra`, `Advanced Math`, `PSDA`, `Geometry & Trig`. `docs/09` §4 defines only code prefixes (`ALG.`, `ADV.`, `PSD.`, `GEO.`), not domain names, so Task 3's docs step adds to `docs/09` §4: "SAT skills must use these exact `domain` values". No mapping table in this PR.

A **cell** is (domain, difficulty, type). A question is **eligible** for a template when: `pool = 'mock_reserve'`, `status = 'published'`, its topic belongs to the template's course, the distinct `skills.domain` values over all its `question_skills` are exactly one value and that value is a key of `blueprint.domains`, and its id is in no `mock_forms.question_ids` of the same template (draft or published).

---

### Task 0: Branch, worktree, plan copy (router)

- [ ] **Precondition:** the owner merges #85 (roadmap) and #86 (mock spec), so the spec is on `main`. If they are still open, base the worktree on `origin/docs/mock-spec` instead and rebase on `main` after they merge.
- [ ] Create worktree `C:/Users/Lenovo/sat-wt-mock` on branch `feat/MCK-03-mock-assembly` from `origin/main` (`git -c core.longpaths=true worktree add`).
- [ ] Copy this plan to `docs/superpowers/plans/2026-11-12-mock-assembly-server.md`, commit (message ends with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`), push, open a **draft** PR titled `feat(mock): MCK-03 mock form assembly server` so CI runs pgTAP.

### Task 1: Form status, blueprint setting, slots

**Files:** Create the migration and the test file.

**Interfaces — Produces:**
- `public.mock_forms.status text not null default 'draft' check (status in ('draft','published'))`, `public.mock_forms.published_at timestamptz`.
- Setting `mock_blueprint_sat` = the JSON in `docs/08` §3 verbatim (insert with `on conflict (key) do nothing`; not added to `private.teacher_setting_spec()`).
- `private.mock_blueprint_ok(p_blueprint jsonb) returns boolean` — true only when modules `M1`, `M2E`, `M2H` exist, each `count > 0`, `time_s > 0`, `E + M + H = count`, domain shares are positive and sum to 1 (tolerance 0.001), `0 ≤ spr_ratio ≤ 1`, `routing.threshold_correct_m1` between 0 and `M1.count`.
- `private.mock_module_slots(p_blueprint jsonb, p_module text) returns table (slot_no int, difficulty <enum of questions.difficulty>, domain text, qtype <enum of questions.type>)` — the slot rule above; raises `internal` when `mock_blueprint_ok` is false or the module is missing.
- `private.mock_template_for(p_course_id uuid) returns uuid` — returns the course's template, creating it (name `SAT Math`, `adaptive = true`, blueprint copied from the setting) on first use; raises `invalid_input` when the course does not exist or its code is not `SAT`. Add a unique index on `mock_templates (course_id)` where `adaptive` so it can never create two.

- [ ] **Step 1: Write failing tests** in `50_mock_assembly.test.sql` (seed profiles as postgres, fixture style of test 35):
  - `mock_forms` has columns `status` (default `draft`) and `published_at`; existing insert in `09_rls_catalogue.test.sql` still passes untouched.
  - setting `mock_blueprint_sat` exists and `mock_blueprint_ok` is true for it.
  - `mock_module_slots(bp,'M1')`: 22 rows; E/M/H = 7/9/6; `M2E` = 10/9/3; `M2H` = 3/9/10.
  - every module: domain counts Advanced Math 8, Algebra 8, Geometry & Trig 3, PSDA 3; SPR slots exactly `{4,8,11,15,19,22}`; slots 1–4 domains as listed above; difficulty never decreases with `slot_no`; two calls return identical rows.
  - `mock_blueprint_ok` false for: `M1.difficulty` summing to 21; shares summing to 0.9; missing `M2H`. `mock_module_slots` on such a blueprint throws `internal`.
  - `mock_template_for`: first call creates one row with the setting's blueprint, second call returns the same id; unknown course id and an `EST` course throw `invalid_input`.
- [ ] **Step 2:** Run `scripts/db-test.ps1` (or note the local stack failure). Expected: the new test file fails.
- [ ] **Step 3:** Implement the migration pieces listed under Produces.
- [ ] **Step 4:** Run `scripts/db-test.ps1` and `supabase db lint`. Expected: all green, no new lint findings.
- [ ] **Step 5:** Report (no commit).

### Task 2: Eligibility, shortage, assemble, read

**Interfaces — Consumes:** Task 1 helpers.

**Produces:**
- `private.mock_eligible(p_template_id uuid) returns table (question_id uuid, domain text, difficulty, qtype)` — the eligibility rule above.
- `private.mock_no_domain_count(p_template_id uuid) returns int` — published `mock_reserve` questions of the course that fail only the single-domain rule.
- `private.mock_shortage(p_template_id uuid) returns jsonb` — array of `{"domain","difficulty","type","needed","available","modules":{"M1":n,"M2E":n,"M2H":n}}`, one entry per cell where `available < needed` for **one more form** (need summed over the three modules); `[]` when a form can be built. Ordered by domain, difficulty, type.
- `public.teacher_assemble_mock_form(p_course_id uuid, p_set_no int) returns jsonb`
  - success: `{"ok":true,"set_no":n,"form_no":n}`; inserts three `mock_forms` rows (`M1`,`M2E`,`M2H`, status `draft`), `question_ids` in slot order; `form_no` = max in (template, set) + 1, starting at 1.
  - shortage: `{"ok":false,"missing":<mock_shortage>,"no_domain":n}`, nothing inserted (returned, not raised).
  - `p_set_no` null or < 1 → `invalid_input`. Takes `pg_advisory_xact_lock` keyed on the template id before reading the bank. Picks randomly inside a cell.
- `public.teacher_mock_overview(p_course_id uuid) returns jsonb` — `{"template":{"id","name","blueprint"},"need_per_form":[{"domain","difficulty","type","count"}],"forms":[{"set_no","form_no","status","published_at"}],"next_form":{"missing":<mock_shortage>,"no_domain":n}}`, forms ordered by set, form.
- `public.teacher_get_mock_form(p_course_id uuid, p_set_no int, p_form_no int) returns jsonb` — `{"set_no","form_no","status","published_at","modules":[{"module","questions":[{"slot_no","id","external_ref","type","difficulty","domain","stem_md"}]}]}`, modules in order M1, M2E, M2H; unknown form → `invalid_input`. No key, no explanation, no choices.

- [ ] **Step 1: Write failing tests.** Fixture: a helper block that inserts, with `generate_series`, exactly the cell need of two forms plus one spare per cell for the test SAT course (skills with the four blueprint domains; questions `published`, `mock_reserve`, one skill each). Then:
  - student calling each RPC → `forbidden`; anon cannot execute them (`function_privs_are` or `throws_ok` after `tests.clear_authentication()`; remember `reset role;` before any privileged step afterwards).
  - assemble → `ok` true, `form_no` 1, three draft rows, 22 ids each, 66 distinct ids, per-module E/M/H counts 7/9/6, 10/9/3, 3/9/10, the question in slot i matches slot i's cell for every module, all ids `mock_reserve` + `published`.
  - second assemble → `form_no` 2 and no id shared with form 1; a different `p_set_no` starts again at `form_no` 1 and still shares no id.
  - not picked: a `draft` question, a `retired` one, a `practice`-pool one, one from another course, one with no skill, one with skills in two domains, one whose only skill has domain `Test`. The last three are counted in `no_domain` (= 3).
  - shortage: delete spares until one cell is one short of a third form → `ok` false, `missing` has exactly that cell with correct `needed`, `available` and `modules`, and `mock_forms` row count is unchanged.
  - `p_set_no` 0 and null → `invalid_input`; non-SAT course → `invalid_input`.
  - `teacher_mock_overview` lists both forms as `draft` and `next_form.missing` equals `private.mock_shortage`.
  - `teacher_get_mock_form` returns 3 modules × 22 questions in slot order and its JSON text contains none of `correct_answer`, `explanation`, `choices`; unknown `form_no` → `invalid_input`.
- [ ] **Step 2:** Run tests, expect the new cases to fail.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** `scripts/db-test.ps1` + `supabase db lint` green.
- [ ] **Step 5:** Report (no commit).

### Task 3: Swap, delete draft, publish, docs

**Interfaces — Consumes:** `private.mock_eligible`, the form rows from Task 2.

**Produces:**
- `public.teacher_mock_swap_candidates(p_course_id uuid, p_set_no int, p_form_no int, p_question_id uuid) returns jsonb` — array of `{"id","external_ref","stem_md"}`: eligible questions in the same cell as `p_question_id`, ordered by `external_ref`. `p_question_id` not in the form → `invalid_input`.
- `public.teacher_swap_mock_question(p_course_id uuid, p_set_no int, p_form_no int, p_old_id uuid, p_new_id uuid) returns jsonb` — replaces `p_old_id` in place (same module, same slot) and returns `{"ok":true}`. `p_new_id` must be eligible and in the same cell, else `invalid_input`.
- `public.teacher_delete_mock_draft(p_course_id uuid, p_set_no int, p_form_no int) returns jsonb` — deletes the three rows, `{"ok":true}`.
- `public.teacher_publish_mock_form(p_course_id uuid, p_set_no int, p_form_no int) returns jsonb` — re-checks every question (still `published`, still `mock_reserve`, still single-domain and in its slot's cell). All good → sets `status = 'published'` and one `published_at` on the three rows, returns `{"ok":true}`. Otherwise returns `{"ok":false,"stale":[ids]}` and changes nothing.
- New error code **`mock_form_published`**: raised by swap, delete and publish when the form is already published. Add it to `docs/07` §9.

- [ ] **Step 1: Write failing tests:**
  - candidates for a slot are exactly the unused eligible questions of that cell, and exclude questions used in another form.
  - swap with a same-cell candidate: the id at that slot changes, the other 65 stay, the old question is eligible again.
  - swap rejected with `invalid_input`: candidate from another cell; candidate already in another form; candidate already in this form; `p_old_id` not in the form; null ids.
  - publish: `ok` true, three rows `published` with one identical non-null `published_at`.
  - after publish: swap, delete and publish again each throw `mock_form_published`; the 66 questions stay ineligible for new forms.
  - stale publish: on a second draft, set one question's `status` to `retired` (as postgres) → `ok` false, `stale` = that id, form still `draft`; swap it out, publish → `ok` true.
  - delete draft: rows gone, its questions eligible again, the next assemble reuses that `form_no` only if it was the highest (max + 1 rule).
  - students and anon cannot call any of the four.
- [ ] **Step 2:** Run, expect failures.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** `scripts/db-test.ps1` + `supabase db lint` green.
- [ ] **Step 5: Docs.** `docs/06-data-model.md`: `mock_forms.status`, `published_at`; fix `attempts(kind=mock)` → `mock_module`. `docs/07`: the seven RPCs in §1.1 with their return shapes, `mock_form_published` in §9, and move `assemble-mock` out of the Edge Function table (it is an RPC now). `docs/08` §3: the slot rule, the per-form cell table and the `mock_blueprint_sat` setting; §2: draft → publish. `docs/09` §4: the four exact SAT `domain` strings. Report (no commit).

### Task 4: Demo mock bank on staging

**Files:** `supabase/seeds/demo/40_mock_reserve.sql`, `check.sql`, `README.md`, `ci.yml` if needed.

**Interfaces — Consumes:** `private.demo_upsert_question(...)`, `private.mock_shortage`, `private.mock_template_for`.

- [ ] **Step 1:** Read `00_structure.sql` and one topic file to copy the conventions (fixed UUIDs, `external_ref`, idempotent upserts).
- [ ] **Step 2:** Write `40_mock_reserve.sql`:
  - four demo skills, one per blueprint domain (reuse an existing `Algebra` demo skill if one fits), `course_scope '{SAT}'`;
  - for every cell, the need of **one form plus one spare**, generated in a loop from a small set of parameterised English templates per domain (e.g. Algebra: solve a linear equation; Advanced Math: evaluate or factor a quadratic; PSDA: percent or mean; Geometry & Trig: area, perimeter or angle), with the key computed from the parameters. MCQ: four distinct choices, the correct letter varying; SPR: a numeric key. Math in `\( \)`, never `$`. Each question has a worked explanation, `pool 'mock_reserve'`, `status 'published'`, one skill, deterministic UUID and `external_ref` (`DEMO-MOCK-…`), attached to an existing demo topic/subtopic.
  - idempotent: applying the file twice changes nothing.
- [ ] **Step 3:** Extend `check.sql`: `private.mock_shortage(private.mock_template_for(<demo course id>)) = '[]'`, no duplicate stems among the mock questions, every MCQ key is one of its choices.
- [ ] **Step 4:** Make sure both CI steps apply the new file (edit `ci.yml` only if files are enumerated). Update the seed README counts.
- [ ] **Step 5:** Run the seed twice + `check.sql` against a local database if the stack runs; otherwise report and rely on CI's "Demo seed: apply twice + check". Report (no commit).

### Task 5: Review, PR, staging check (router)

- [ ] After each task: run the gates myself, `git diff --stat`, read the changed hunks against the task, send fixes back to the same implementer, then commit and push (CI `db` job must be green before the next task).
- [ ] Final: `code-reviewer` agent on the branch; update `docs/STATUS.md`; mark the PR ready and tell the owner explicitly.
- [ ] After merge and the staging deploy: one `begin … rollback` script in the staging SQL editor (set `request.jwt.claims` to the owner's account with the role flipped to teacher inside the transaction) that runs overview → assemble → get form → swap → publish and checks the results. Nothing persists.

## Verification

- `scripts/db-test.ps1`: `50_mock_assembly.test.sql` and every existing test pass (especially `03`, `04`, `06`, `09`).
- `supabase db lint` and `supabase db advisors`: nothing new.
- `scripts/api-private-check.ps1`: `private` still unreachable over REST.
- CI on the draft PR: `db` job green, including "Demo seed: apply twice + check".
- Staging rollback script above passes after deploy.

## Out of scope (later parts of the spec)

Teacher screen (Part 2), unlock setting, engine RPCs, exam screen, scale tables, report, the "active exam" helper for Ask AI.
