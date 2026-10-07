# 06 — Data Model (Postgres / Supabase)

Conventions: `uuid` PKs (`gen_random_uuid()`), `created_at timestamptz default now()`,
snake_case, enums as Postgres enums, soft-delete via `status`/`retired` not row deletion.
This is the **starting schema** — the first migration should implement it close to verbatim.

Rules the first migration applies where the sketches below leave them open (F-2, docs/15 §1 row 2b):
- **Foreign keys:** a FK to `profiles` for the user's own data is `on delete cascade`; a FK to
  content or catalogue rows (`courses`, `topics`, `questions` …) is `on delete restrict`,
  because content is retired via `status`, not deleted. Authorship references (`owner_id`,
  `created_by`, `redeemed_by`, `unlocked_by`, `actor`) are `on delete set null`. `orders.user_id`
  is `restrict`: an account with payment records is never hard-deleted.
  `attempt_answers (attempt_id, question_id)` references `attempt_questions`, so only questions
  in the frozen draw can be answered.
- **Not null:** FKs, enums, `created_at` and every column the sketch marks `not null` or uses as a
  key are `not null`. Optional columns (marked `null`, profile details, scores) stay nullable.
- **`updated_at`:** every table that has it gets a `before update` trigger
  (`private.set_updated_at()`).
- **Sign-up:** an `after insert` trigger on `auth.users` creates the `profiles` row. `full_name`
  comes from the sign-up metadata `full_name`, falling back to the e-mail's local part, then to 'Student' (phone sign-up). `role` is
  always the default `student`; it is never read from client metadata.
- **Locked until row 3:** row 2b ships tables only. RLS is on (hardening Layer 2) but there are no
  grants or policies yet, so the API sees nothing until the RLS baseline (row 3) adds them. Only `service_role` (Edge
  Functions) gets table grants now.

## 1. ERD (simplified)

```
profiles 1─* devices
profiles 1─* enrollments *─1 courses 1─* units 1─* topics 1─* subtopics
                                    courses 1─* prices
topics 1─* topic_assets (video | notes)          subtopics *─* skills
questions *─* question_courses           questions *─1 topics / subtopics
questions 1─* question_choices           questions *─* question_skills *─1 skills
profiles 1─* attempts 1─* attempt_answers *─1 questions
profiles 1─* topic_progress *─1 topics
profiles 1─* skill_mastery *─1 skills
mock_templates 1─* mock_forms (M1, M2E, M2H) ; attempts(kind=mock) ─ mock_forms
profiles 1─* ai_threads 1─* ai_messages ; ai_threads ─ escalations
orders 1─1 enrollments ; coupons ; activation_codes
live_sessions ; announcements ; notifications ; settings ; question_reports ; audit_log
```

## 2. Enums

```sql
create type user_role        as enum ('student','teacher','parent');
create type course_code      as enum ('SAT','EST');
create type question_type    as enum ('mcq','spr');
create type difficulty       as enum ('E','M','H');
create type question_status  as enum ('draft','solved','needs_review','approved','published','retired');
create type question_pool    as enum ('practice','quiz','mock_reserve');
create type attempt_kind     as enum ('practice','homework','quiz','review','mock_module','drill','diagnostic');
create type attempt_status   as enum ('in_progress','submitted','expired','abandoned');
create type step_kind        as enum ('video','notes','practice','homework','quiz');
create type enrollment_status as enum ('active','expired','refunded','suspended');
create type order_status     as enum ('pending','paid','failed','refunded');
create type error_type       as enum ('concept','careless','time');
```

## 3. Tables

### Identity & access
```sql
profiles(            -- 1:1 with auth.users
  id uuid pk references auth.users,
  role user_role not null default 'student',
  full_name text not null,          -- used in watermark
  phone text, country char(2), school text, grade text,
  timezone text, created_at timestamptz)

devices(
  id uuid pk, user_id uuid fk profiles,
  device_fingerprint text not null,  -- app-generated install id, stored in secure storage
  platform text, label text,
  last_seen_at timestamptz, revoked_at timestamptz,
  unique(user_id, device_fingerprint))

device_changes(user_id uuid, changed_at timestamptz)   -- enforces N changes / 30 days
```

### Catalogue & commerce
```sql
courses(id uuid pk, code course_code unique, title text, slug text unique,
  description text, owner_id uuid fk profiles, is_published bool, sort int)

prices(id uuid pk, course_id fk, currency char(3), amount_minor int,
  kind text check (kind in ('full','renewal','bundle')), active bool)

coupons(id uuid pk, code text unique, course_id uuid null, percent_off int null,
  amount_off_minor int null, currency char(3) null, max_uses int, used_count int,
  expires_at timestamptz, active bool)

orders(id uuid pk, user_id fk, course_id fk, price_id fk, coupon_id fk null,
  amount_minor int, currency char(3), status order_status,
  gateway text, gateway_order_id text, gateway_txn_id text unique,
  raw_payload jsonb, created_at, paid_at)

activation_codes(id uuid pk, code text unique, course_id fk, created_by fk,
  redeemed_by uuid null, redeemed_at timestamptz null, note text)

enrollments(id uuid pk, user_id fk, course_id fk, order_id uuid null,
  activation_code_id uuid null, status enrollment_status,
  target_test_date date, starts_at timestamptz, expires_at timestamptz,
  mock_set_no int default 1,         -- renewal increments → fresh mocks
  unique(user_id, course_id))
```

### Course structure & content
```sql
units(id uuid pk, course_id fk, title text, sort int)
topics(id uuid pk, course_id fk, unit_id fk null, title text, slug text,
  sort int, is_free_preview bool, is_published bool)
subtopics(id uuid pk, topic_id fk, title text, sort int)

topic_assets(id uuid pk, topic_id fk, subtopic_id uuid null,
  kind text check (kind in ('video','notes','book')),
  title text, sort int,
  video_provider_id text null, duration_s int null,  -- R2 prefix now; VdoCipher id after upgrade
  storage_path text null, page_count int null)

video_chapters(id uuid pk, asset_id fk, subtopic_id fk, start_s int, label text)
private.video_keys(asset_id uuid pk fk topic_assets, key bytea not null,  -- AES-128 HLS key (ADR-002)
  r2_prefix text not null, created_at timestamptz)                  -- served only via video-otp

skills(id uuid pk, code text unique,  -- e.g. ALG.LIN.PARALLEL_PERP
  name text, domain text,              -- Algebra | Advanced Math | PSDA | Geometry & Trig
  course_scope course_code[])
subtopic_skills(subtopic_id fk, skill_id fk, primary key(subtopic_id, skill_id))
```

### Question bank
```sql
questions(
  id uuid pk, external_ref text unique,     -- e.g. SAT-T05-0123 from pipeline
  topic_id fk, subtopic_id fk,
  type question_type, difficulty difficulty,
  stem_md text not null,                    -- Markdown + $LaTeX$
  image_paths text[],
  hint_md text,
  desmos_friendly bool default false,
  pool question_pool, status question_status,
  source text, source_page int,
  version int default 1, created_at, updated_at)

private.question_keys(                      -- non-exposed schema; NO student access at all
  question_id uuid pk fk questions,
  correct_answer jsonb not null,            -- mcq: {"choice":"B"}; spr: {"accepted":["1/2","0.5"],"tolerance":0}
  explanation_md text,                      -- teacher-approved worked solution (also AI tutor grounding)
  misconceptions jsonb,                     -- {"A":"sign error","C":"solved for 2x"}  (P1)
  solved_by text,                           -- 'teacher' | 'ai_double_agree' | 'ai_teacher_fixed'
  updated_at timestamptz)

question_courses(question_id fk, course_id fk, primary key(...))
question_choices(id uuid pk, question_id fk, label char(1), body_md text)
question_skills(question_id fk, skill_id fk, primary key(...))
question_reports(id uuid pk, question_id fk, user_id fk, reason text,
  status text, created_at)
```

> **Security:** answer keys, explanations and misconceptions live only in `private.question_keys`.
> The `private` schema is not exposed by the API, so no policy mistake can leak it (16 §1). They reach students only through `SECURITY DEFINER` RPCs:
> `check_practice_answer` (practice) and `submit_attempt` / `get_attempt_review` (after submission).

### Progress, attempts, analytics
```sql
topic_progress(user_id fk, topic_id fk,
  video_pct int, notes_opened_at timestamptz, practice_count int,
  homework_attempt_id uuid null, homework_score numeric null, homework_submitted_at timestamptz,
  quiz_best_score numeric, quiz_passed_at timestamptz, quiz_last_failed_at timestamptz,
  unlocked_at timestamptz, unlocked_by uuid null,     -- teacher override
  primary key(user_id, topic_id))

video_progress(user_id fk, asset_id fk, watched_ranges int4range[], pct int,
  last_position_s int, updated_at, primary key(user_id, asset_id))

attempts(id uuid pk, user_id fk, kind attempt_kind, course_id fk, topic_id uuid null,
  mock_attempt_group uuid null, mock_form_id uuid null, module_no int null,
  status attempt_status, started_at, submitted_at, time_limit_s int null,
  score_raw int, score_total int, score_pct numeric, meta jsonb)

attempt_questions(attempt_id fk, question_id fk, position int,
  primary key(attempt_id, question_id))       -- frozen draw

attempt_answers(attempt_id fk, question_id fk,
  answer jsonb, is_correct bool null, time_ms int, marked_for_review bool,
  client_seq int,                               -- outbox ordering; older writes ignored (16 §3)
  eliminated jsonb, error_type error_type null, answered_at,
  primary key(attempt_id, question_id))

question_exposure(user_id fk, question_id fk, first_seen_at,
  primary key(user_id, question_id))          -- drives "never repeat" for quizzes/mocks

skill_mastery(user_id fk, skill_id fk, mastery numeric,  -- 0..100, EWMA
  attempts int, correct int, avg_time_ms int, updated_at,
  primary key(user_id, skill_id))

mistake_notebook(user_id fk, question_id fk, added_at, correct_streak int,
  cleared_at timestamptz null, primary key(user_id, question_id))
```

### Mocks
```sql
mock_templates(id uuid pk, course_id fk, name text, adaptive bool,
  blueprint jsonb)            -- see 08 §3
mock_forms(id uuid pk, template_id fk, set_no int, form_no int,
  module text check (module in ('M1','M2E','M2H','EST1','EST2')),
  question_ids uuid[], created_at)
mock_results(id uuid pk, user_id fk, template_id fk, group_id uuid,
  route text, raw_m1 int, raw_m2 int, est_low int, est_high int,
  domain_breakdown jsonb, created_at)
official_scores(id uuid pk, user_id fk, course_id fk, source text, score int, taken_on date)
```

### AI, comms, ops
```sql
ai_threads(id uuid pk, user_id fk, question_id fk, attempt_id uuid null, created_at)
ai_messages(id uuid pk, thread_id fk, role text, content text, tokens_in int,
  tokens_out int, created_at)
escalations(id uuid pk, thread_id fk, status text, teacher_reply text,
  live_session_id uuid null, created_at, resolved_at)
live_sessions(id uuid pk, course_id fk, title text, starts_at timestamptz,
  duration_min int, join_url text, recording_asset_id uuid null)
announcements(id uuid pk, course_id fk, title text, body_md text, created_at)
notifications(id uuid pk, user_id fk, kind text, payload jsonb, read_at, created_at)
push_tokens(user_id fk, token text, platform text, primary key(user_id, token))
settings(key text pk, value jsonb, updated_at)   -- pass_mark, cooldown_h, device_limit, rate limits, ...
private.rate_limits(key text, window_start timestamptz, count int,
  primary key(key, window_start))                -- anti-scraping / AI cost caps (16 §5)
audit_log(id bigserial, actor uuid, action text, entity text, entity_id uuid,
  diff jsonb, created_at)
```

## 4. RLS policy matrix

Teacher: **all** on every table (one `for all … is_teacher()` policy), except `audit_log` (select
only; rows are written by `security definer` functions). Grants: `anon` gets select on the catalogue tables
only. `authenticated` gets DML on every table, because the teacher is an `authenticated` user; RLS
is the student gate. Column grants narrow `profiles` (update), `notifications` (update),
`orders` (select) and `topic_assets` (select), and `audit_log` is select-only. These column limits apply to the teacher too:
`orders.raw_payload`, `topic_assets` paths and `profiles.role` are read or changed only from the
dashboard or an Edge Function. Agreed in row 3 (docs/15 §1, 2026-10-07).

| Table | Anon | Student |
|-------|------|---------|
| courses, units, topics, subtopics | select published (PAY-01 public catalogue) | same |
| prices | select active, course published | same |
| profiles | — | select own; update own `full_name, phone, country, school, grade, timezone` only |
| devices | — | select own (writes: `register-device` EF) |
| topic_assets, video_chapters | — | select metadata if `has_access_topic`; `storage_path` and `video_provider_id` are not granted (URLs via EF) |
| skills, subtopic_skills | — | select all (taxonomy) |
| enrollments | — | select own |
| orders | — | select own, every column except `raw_payload` |
| attempts | — | select own |
| attempt_answers | — | select own, only when the attempt is no longer `in_progress` (rule 1) |
| topic_progress, video_progress, skill_mastery, mistake_notebook, mock_results | — | select own |
| official_scores, question_reports | — | select + insert own |
| ai_threads, ai_messages, escalations | — | select own (writes: `ai-tutor` EF, so cost caps hold) |
| live_sessions, announcements | — | select if `has_access(course_id)` |
| notifications | — | select own; update `read_at` only |
| push_tokens | — | select + insert + delete own |
| settings | — | select |
| questions, question_choices, question_courses, question_skills, attempt_questions, question_exposure, mock_templates, mock_forms, coupons, activation_codes, device_changes, audit_log | — | **none** — RPC / EF only |
| private.* | — | **none** (schema not exposed) |

Helpers (in `public`, `security definer`, `stable`, `grant execute … to authenticated` — policies
run as the caller, 16 §1):
- `is_teacher()` — the caller's `profiles.role = 'teacher'`.
- `has_access(course_id)` — the caller has an enrollment with `status = 'active'` and
  `now() < expires_at`. The device check (`x-device-id`, 07 §8) is added by the device story (S1).
- `has_access_topic(topic_id)` — the topic and its course are published, and either `has_access`
  of the course or the topic is `is_free_preview`.

Traps closed by row 3 (from the row 2b review), each with a pgTAP test:
- `profiles.role` cannot be self-updated (column-level `update` grant).
- `attempt_answers` is unreadable while the attempt is `in_progress`.
- `orders.raw_payload` is not granted; `mock_forms` has no student access.
- Every `user_id` / `thread_id` FK used by a "select own" policy has an index.

## 5. Indexes (minimum)
- `attempt_answers(question_id)` for class insights
- `attempts(user_id, kind, topic_id)`
- `questions(topic_id, subtopic_id, pool, status, difficulty)`
- `question_exposure(user_id)` — covered by its primary key `(user_id, question_id)`
- `orders(gateway_txn_id)` unique
- `enrollments(user_id, course_id)` unique

## 6. `settings` defaults (seed)

Seeded with `on conflict (key) do nothing`, so a value the teacher has changed is never
overwritten. Defaults come from `13` Q-11 / Q-14 and `07`; the teacher can change them later.

| Key | Default | Source | Used by |
|-----|---------|--------|---------|
| `pass_mark` | 75 | Q-11 | quiz done (07 §2) |
| `homework_size` | 20 | Q-11 | homework draw (07 §3) |
| `practice_min` | 10 | Q-11 | practice done (07 §2) |
| `cooldown_h` | 12 | Q-11 | retry after a failed quiz (`cooldown_active`) |
| `video_done_pct` | 80 | 07 §2 | video done |
| `save_grace_s` | 30 | 07 §1 | `save_answer` after the deadline |
| `ai_daily_cap` | 20 | 07 §6 | AI tutor messages per day |
| `device_limit` | 2 | Q-14 | `register-device` (07 §8) |
| `device_changes_30d` | 2 | Q-14 | `register-device` |

Other tunables (quiz/review/drill sizes and mixes, rate limits, mock blueprints) are seeded by the
story that first reads them.
