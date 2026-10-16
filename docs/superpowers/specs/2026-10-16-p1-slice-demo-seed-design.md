# Phase 1 vertical slice — overview + part 1: staging demo seed — design

Status: approved 2026-10-16. Roadmap: `docs/11` Phase 1; stories `docs/03` EP-1, EP-4. Tier **M** for part 1 (data + CI + pgTAP, no client code).

## Slice goal
One complete thread on `staging`: a student signs in, opens a course, sees its topics, practises, takes the quiz, passes, and the next topic unlocks. The point is to prove the whole system end to end (auth, RLS, server grading, unlock) before the rest of Phase 1.

**Thin by decision (2026-10-16):**
- Email/password login only: no Google, video, notes, homework or payment.
- Access comes from a demo enrollment, not a purchase.
- Content is demo seed data, because the pilot topic depends on the teacher.

## Slice parts (each its own spec → plan → PR, in this order)
| # | Part | Scope | Exists today |
|---|------|-------|--------------|
| 1 | **Demo seed (this spec)** | Demo course + questions + keys on staging, auto-enrolment of students | schema |
| 2 | Login | email sign-up / sign-in / sign-out, `register_device`, go_router auth guard | `register_device`, `device_status` |
| 3 | Course map | course page + topic list (locked / open / completed) | `get_course_page`; topic status missing |
| 4 | Practice | `check_practice_answer` (with `reveal`, spec F-4 §6), practice Cubit, `QuestionView` | `QuestionView`; RPC missing |
| 5 | Quiz + unlock | `start_quiz` / `submit_attempt` (server timer + grading), unlock on pass, quiz Cubit, time-up | `QuestionView` quiz mode; RPCs missing |

## Part 1 — demo seed

### Decisions
| Topic | Decision |
|---|---|
| Delivery | One idempotent file, `supabase/seeds/demo.sql`. It is applied locally by `db reset` and to staging by CI. It never reaches prod, because no prod pipeline includes it. |
| Content | Original demo questions written by Claude. Each is marked `source = 'demo'`. Nothing is copied from College Board. |
| Test student | No password in the public repo. The seed enrolls every existing student, and a staging-only trigger enrolls each new student at sign-up. |

### 1. Data (`supabase/seeds/demo.sql`)
- **Fixed UUIDs** (a readable `00000000-0000-4000-8000-…` scheme), with `insert … on conflict (id) do update`. Running it twice changes nothing.
- **Course:** code `SAT`, title "SAT Math (Demo)", published. It has one unit, "Algebra (Demo)".
- **Topics** (published, `sort` 1–3):
  1. Linear equations (`is_free_preview = true`);
  2. Linear inequalities;
  3. Systems of linear equations.

  Each topic has one subtopic and 1–2 skills.
- **Questions per topic:** 12 in the `practice` pool and 12 in the `quiz` pool. 72 in total.
  - Status `published`, linked to the course in `question_courses`.
  - About 75 % MCQ (4 choices, A–D) and 25 % SPR.
  - Difficulty mix per pool: 4 E / 5 M / 3 H.
  - `hint_md` on every practice question.
- **Keys** live in `private.question_keys`:
  - `correct_answer` uses the documented shapes (`docs/06` §148, `private.grade_spr`): MCQ `{"choice":"B"}`, SPR `{"accepted":["2/3","0.666","0.667"],"tolerance":0}`.
  - `explanation_md` is on every question. At least 6 explanations include an Arabic paragraph (rule 8).
  - `misconceptions` holds a map from a wrong MCQ label to a short note, on about half of the MCQs.
  - `solved_by = 'teacher'`.
- **Enrolments:**
  - Every `profiles` row with `role = 'student'` gets an `active` enrolment in the demo course, with `expires_at = now() + interval '1 year'`.
  - `on conflict (user_id, course_id) do nothing`.
- **Staging-only trigger:**
  - `private.demo_enroll_new_student()` is a `security definer` function with a pinned `search_path`.
  - It runs `after insert on public.profiles` and enrolls the new student in the demo course.
  - It is created in the seed file with `create or replace` and `drop trigger if exists`, so it never exists in prod.
- **Not seeded:** `topic_progress` (unlock is part 5), videos, notes, homework, prices, and orders.

### 2. Delivery
- **Local:** `supabase/config.toml` `[db.seed] sql_paths = ["./seed.sql", "./seeds/*.sql"]`, so `scripts/db-reset.ps1` loads it.
- **Staging:** the CI `deploy` job runs `supabase db push --include-seed`. The plan must verify with CLI 2.117.0 that:
  - this applies `seeds/*.sql` to the remote;
  - a changed seed file is re-applied, and an unchanged one is skipped.

  Fallback, if that doesn't hold: a CI step that runs `psql` on the file against the staging connection, built from the existing `STAGING_DB_PASSWORD` secret. No new secrets.
- **Prod:** no prod pipeline exists yet. A note in the seed header and in `docs/STATUS.md` says that a prod deploy must not use `--include-seed`.

### 3. Tests (`supabase/tests/`, pgTAP, run by `scripts/db-test.ps1` and CI `db`)
- **Idempotence:** running the seed a second time keeps every count the same.
- **Counts:** 3 published topics. Per topic, 12 practice + 12 quiz questions, all `published`, each with exactly one `private.question_keys` row.
- **Key validity:**
  - every MCQ key label exists in its `question_choices`;
  - every SPR answer parses with `private.spr_parse`;
  - every MCQ has exactly 4 choices.
- **Enrolment:** inserting a new student profile (through the auth user path, as the existing RLS tests do) creates an active demo enrolment. Existing students are enrolled after the seed runs.
- **Rule 1:** `anon` and `authenticated` cannot select from `private.question_keys`. Reuse the existing private-schema check pattern.
- The local `db reset` path loads the seed with no errors.

## Done when
- `scripts/db-test.ps1` and CI `db` are green, and the seed loads on a local `db reset`.
- After merge, the staging deploy applies the seed:
  - 3 demo topics and 72 questions are visible on staging (checked with a read-only query);
  - a new sign-up on staging gets the demo enrolment once part 2's sign-up exists. Until then, a student created in the Supabase dashboard is enough.
- `docs/STATUS.md` is updated.

## Deltas from planning (2026-10-16)
- **Delivery:** CI runs `supabase db query --linked --file` for each `supabase/seeds/demo/[0-9]*.sql` on every main deploy. It does not use `--include-seed`: the CLI never re-executes a changed seed file, it only refreshes the hash.
- **Not in `config.toml` `sql_paths`:** the existing tests insert their own `SAT` course (`courses.code` is unique). Local use goes through `scripts/db-seed-demo.ps1`. CI applies the seed twice to the local stack after the pgTAP suite, then runs `supabase/seeds/demo/check.sql` (assertions) instead of new pgTAP tests.
- **Course code:** the demo course uses `code = 'SAT'`. Rename or remove it when the real SAT course lands on staging.
- **Count:** 72 questions (3 × (12 + 12)).
