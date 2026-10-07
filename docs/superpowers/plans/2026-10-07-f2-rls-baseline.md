# F-2 row 3 — RLS baseline Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Open exactly the access in `docs/06` §4 to `anon`, students and the teacher, close the four row-2b traps, and make "public table without RLS + policy" fail the test suite.

**Architecture:** Two migrations: `f2_rls_helpers` (3 `security definer` helpers) and `f2_rls_policies` (grants, a teacher-all policy loop, explicit student/anon policies, FK indexes). Tests use vendored `supabase_test_helpers` 0.0.6. A PowerShell script proves `private` is unreachable over REST.

**Tech Stack:** Supabase CLI (Postgres 17), pgTAP, `supabase_test_helpers` 0.0.6 (usebasejump, commit `d90a51f`), PowerShell 5.1.

**Spec:** `docs/superpowers/specs/2026-10-07-f2-rls-baseline-design.md` + `docs/06` §4 (committed `f11e01b` on `feat/F-2-rls-baseline`). After approval copy this plan to `docs/superpowers/plans/2026-10-07-f2-rls-baseline.md` and commit it with Task 1.

## Context
Row 3 of `docs/15` §1, last part of F-2. Row 2b shipped 42 locked tables. Every later story needs students, anon visitors and the teacher to reach exactly their data. Agreed in brainstorm 2026-10-07: full matrix in `docs/06` §4.

## Global Constraints
- Every SQL file follows `supabase/templates/` + the checklist in `supabase/templates/README.md`.
- Policies use `to authenticated` / `to anon`, compare with `(select auth.uid())`, wrap row-independent helpers in `(select …)`; UPDATE policies have `using` and `with check`.
- Helpers: `language sql stable security definer set search_path = ''`, fully-qualified names, `revoke … from public, anon` then `grant execute … to authenticated`.
- **Grant model:** the teacher is an `authenticated` user, so `authenticated` gets full DML on every public table; RLS is the student gate. Column grants narrow it where the matrix says so (`profiles` update, `notifications` update, `orders` select), and `audit_log` is select-only. Consequence (accepted): the teacher also cannot read `orders.raw_payload` or update `profiles.role` through the API; use the dashboard.
- Tests: `begin; … rollback;`, one behaviour per assertion, names prefixed `NFR-08:`. Fixtures are inserted as `postgres` before `tests.authenticate_as`.
- Commits end with a blank line + `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- `03_schema_tables` is unchanged; `04_schema_locked` is replaced by `04_rls_gate` (planned, not a deletion to pass a build).

## Review Focus
1. A student sets `role = 'teacher'` on their own profile → `42501` (Task 2 test 08).
2. A student reads answers of an in-progress quiz → 0 rows (Task 2 test 11).
3. A student reads `orders.raw_payload` → `42501` (Task 2 test 11).
4. A free-preview topic that is still unpublished → invisible to non-enrolled students (Task 1 test 07, Task 2 test 10).
5. An enrollment that is `active` but past `expires_at`, or `suspended` → no access (Task 1 test 07, Task 2 test 10).
6. (Reviewer judges, no test) Students can select every `topic_assets` column, including `storage_path` and `video_provider_id` (R2 prefix). The matrix says "metadata, no URLs". Decide whether these columns need a column grant.

---

### Task 1: Test helpers + RLS helper functions

**Files:**
- Create: `supabase/tests/000_setup_test_helpers.test.sql` (vendored, no rollback, so it persists for later files)
- Create: `supabase/tests/07_rls_helpers.test.sql`
- Create: `supabase/migrations/<ts>_f2_rls_helpers.sql` (`supabase migration new f2_rls_helpers < /dev/null`)
- Create: `docs/superpowers/plans/2026-10-07-f2-rls-baseline.md` (copy of this plan)

**Interfaces:**
- Produces: `public.is_teacher() returns boolean`; `public.has_access(p_course_id uuid) returns boolean`; `public.has_access_topic(p_topic_id uuid) returns boolean`; `tests.create_supabase_user(text)`, `tests.get_supabase_uid(text)`, `tests.authenticate_as(text)`, `tests.clear_authentication()`.

- [ ] **Step 1: Vendor the helpers.** Build the file from the pinned upstream (drop its first two lines, the `\echo … \quit` guard):

```bash
OUT=supabase/tests/000_setup_test_helpers.test.sql
{
  echo "-- Vendored supabase_test_helpers 0.0.6 (MIT) — github.com/usebasejump/supabase-test-helpers @ d90a51f."
  echo "-- Runs first and is NOT rolled back, so tests.* exists for every later test file. Local/CI only."
  echo "create extension if not exists pgtap with schema extensions;"
  gh api repos/usebasejump/supabase-test-helpers/contents/supabase_test_helpers--0.0.6.sql \
    -H "Accept: application/vnd.github.raw" | tail -n +3
  echo ""
  echo "select plan(1);"
  echo "select ok(to_regprocedure('tests.authenticate_as(text)') is not null, 'supabase_test_helpers loaded');"
  echo "select * from finish();"
} > "$OUT"
```

- [ ] **Step 2: Write `supabase/tests/07_rls_helpers.test.sql`**

```sql
-- F-2 / NFR-08 — docs/06 §4 helpers: is_teacher, has_access, has_access_topic.
begin;
create extension if not exists pgtap with schema extensions;
select plan(10);

select tests.create_supabase_user('student_a');  -- active enrollment
select tests.create_supabase_user('student_b');  -- active but expired
select tests.create_supabase_user('student_c');  -- suspended
select tests.create_supabase_user('teacher');
update public.profiles set role = 'teacher' where id = tests.get_supabase_uid('teacher');

insert into public.courses (id, code, title, slug, is_published)
  values ('00000000-0000-0000-0000-0000000000c1', 'SAT', 'SAT Math', 'sat', true);
insert into public.topics (id, course_id, title, slug, is_published, is_free_preview) values
  ('00000000-0000-0000-0000-0000000000d1', '00000000-0000-0000-0000-0000000000c1', 'Paid', 'paid', true, false),
  ('00000000-0000-0000-0000-0000000000d2', '00000000-0000-0000-0000-0000000000c1', 'Free', 'free', true, true),
  ('00000000-0000-0000-0000-0000000000d3', '00000000-0000-0000-0000-0000000000c1', 'Draft', 'draft', false, true);
insert into public.enrollments (user_id, course_id, status, expires_at) values
  (tests.get_supabase_uid('student_a'), '00000000-0000-0000-0000-0000000000c1', 'active',    now() + interval '30 days'),
  (tests.get_supabase_uid('student_b'), '00000000-0000-0000-0000-0000000000c1', 'active',    now() - interval '1 day'),
  (tests.get_supabase_uid('student_c'), '00000000-0000-0000-0000-0000000000c1', 'suspended', now() + interval '30 days');

select tests.authenticate_as('teacher');
select ok(public.is_teacher(), 'NFR-08: is_teacher true for the teacher');

select tests.authenticate_as('student_a');
select ok(not public.is_teacher(), 'NFR-08: is_teacher false for a student');
select ok(public.has_access('00000000-0000-0000-0000-0000000000c1'), 'NFR-08: active enrollment has access');
select ok(public.has_access_topic('00000000-0000-0000-0000-0000000000d1'), 'NFR-08: enrolled student opens a paid topic');

select tests.authenticate_as('student_b');
select ok(not public.has_access('00000000-0000-0000-0000-0000000000c1'), 'NFR-08: expired enrollment has no access');
select ok(not public.has_access_topic('00000000-0000-0000-0000-0000000000d1'), 'NFR-08: expired student cannot open a paid topic');
select ok(public.has_access_topic('00000000-0000-0000-0000-0000000000d2'), 'NFR-08: anyone signed in opens a published free preview');
select ok(not public.has_access_topic('00000000-0000-0000-0000-0000000000d3'), 'NFR-08: an unpublished free preview stays closed');

select tests.authenticate_as('student_c');
select ok(not public.has_access('00000000-0000-0000-0000-0000000000c1'), 'NFR-08: suspended enrollment has no access');

select tests.clear_authentication();
select throws_ok($$ select public.has_access('00000000-0000-0000-0000-0000000000c1') $$, '42501', null,
                 'NFR-08: anon cannot call has_access');

select * from finish();
rollback;
```

- [ ] **Step 3: Run — expect failure.** `supabase db reset < /dev/null; supabase test db < /dev/null` → `000` PASS; `07` FAIL (`function public.is_teacher() does not exist`).

- [ ] **Step 4: Write the helpers migration**

```sql
-- F-2 row 3: RLS policy helpers (docs/06 §4, docs/16 §1 exception: they live in public because
-- policies run as the caller). Each reads only the caller's own data.

create function public.is_teacher()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.profiles
    where id = (select auth.uid()) and role = 'teacher'
  );
$$;

create function public.has_access(p_course_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.enrollments
    where user_id = (select auth.uid())
      and course_id = p_course_id
      and status = 'active'
      and now() < expires_at
  );
$$;

create function public.has_access_topic(p_topic_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.topics t
    where t.id = p_topic_id
      and t.is_published
      and (t.is_free_preview or public.has_access(t.course_id))
  );
$$;

revoke execute on function public.is_teacher() from public, anon;
revoke execute on function public.has_access(uuid) from public, anon;
revoke execute on function public.has_access_topic(uuid) from public, anon;
grant execute on function public.is_teacher() to authenticated;
grant execute on function public.has_access(uuid) to authenticated;
grant execute on function public.has_access_topic(uuid) to authenticated;
```

- [ ] **Step 5: Run — expect pass.** `supabase db reset < /dev/null; supabase test db < /dev/null` → all files PASS (`04_schema_locked` still passes: no table grants yet).

- [ ] **Step 6: Commit**

```bash
git add docs/superpowers/plans/2026-10-07-f2-rls-baseline.md supabase/tests/000_setup_test_helpers.test.sql supabase/tests/07_rls_helpers.test.sql supabase/migrations/*_f2_rls_helpers.sql
git commit -m "feat(F-2): RLS helpers is_teacher, has_access, has_access_topic"
```

---

### Task 2: Grants, policies, indexes + access tests

**Files:**
- Delete: `supabase/tests/04_schema_locked.test.sql` (`git rm`)
- Create: `supabase/tests/04_rls_gate.test.sql`, `08_rls_identity.test.sql`, `09_rls_catalogue.test.sql`, `10_rls_content.test.sql`, `11_rls_learning.test.sql`
- Create: `supabase/migrations/<ts>_f2_rls_policies.sql`

**Interfaces:**
- Consumes: Task 1 helpers and `tests.*`.
- Produces: policies named `"<table>: <who> <what>"`; teacher policy on every public table except `audit_log` named `"<table>: teacher manages all"`.

- [ ] **Step 0: Align the docs with the grant model.**
  - In `docs/06` §4, replace `Grants match the policies: a table with no student/anon row below gets no grant to that role.` with this text: `Grants: \`anon\` gets select on the catalogue tables only. \`authenticated\` gets DML on every table, because the teacher is an \`authenticated\` user. RLS is the student gate. Column grants narrow \`profiles\` (update), \`notifications\` (update) and \`orders\` (select), and \`audit_log\` is select-only. These column limits apply to the teacher too: \`orders.raw_payload\` and \`profiles.role\` are changed only from the dashboard.`
  - In the spec's Decisions, add the same model as item 10.

- [ ] **Step 1: `git rm supabase/tests/04_schema_locked.test.sql` and write `04_rls_gate.test.sql`**

```sql
-- F-2 / NFR-08 — Layer 4 (docs/16 §1): every public table has RLS and a policy; nothing in private
-- is granted to API roles. Every story that adds a table must keep this green.
begin;
create extension if not exists pgtap with schema extensions;
select plan(4);

select is_empty($$
  select c.relname from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and c.relkind in ('r','p')
    and (not c.relrowsecurity
         or not exists (select 1 from pg_policies p
                        where p.schemaname = 'public' and p.tablename = c.relname))
$$, 'NFR-08: every public table has RLS enabled and at least one policy');

select is_empty($$
  select c.relname from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and c.relkind in ('v','m')
$$, 'NFR-08: no views or materialized views in public (they bypass RLS)');

select is_empty($$
  select c.relname from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'private' and c.relkind = 'r'
    and (has_table_privilege('anon', c.oid, 'select,insert,update,delete')
      or has_table_privilege('authenticated', c.oid, 'select,insert,update,delete'))
$$, 'NFR-08: anon and authenticated have no privileges on private tables');

select ok(has_table_privilege('service_role', 'public.profiles', 'select,insert,update,delete'),
          'NFR-08: service_role can use public tables (Edge Functions)');

select * from finish();
rollback;
```

- [ ] **Step 2: Write `08_rls_identity.test.sql`**

```sql
-- F-2 / NFR-08 — docs/06 §4 identity rows: profiles, devices, notifications, push_tokens, settings.
begin;
create extension if not exists pgtap with schema extensions;
select plan(13);

select tests.create_supabase_user('student_a');
select tests.create_supabase_user('student_b');
select tests.create_supabase_user('teacher');
update public.profiles set role = 'teacher' where id = tests.get_supabase_uid('teacher');

insert into public.devices (user_id, device_fingerprint) values
  (tests.get_supabase_uid('student_a'), 'fp-a'), (tests.get_supabase_uid('student_b'), 'fp-b');
insert into public.notifications (user_id, kind) values
  (tests.get_supabase_uid('student_a'), 'info'), (tests.get_supabase_uid('student_b'), 'info');

select tests.authenticate_as('student_a');
select is((select count(*)::int from public.profiles), 1, 'NFR-08: student sees only own profile');
select lives_ok($$ update public.profiles set full_name = 'A Two' where id = auth.uid() $$,
                'NFR-08: student updates own full_name');
select throws_ok($$ update public.profiles set role = 'teacher' where id = auth.uid() $$, '42501', null,
                 'NFR-08: student cannot change own role');
select is_empty($$ update public.profiles set full_name = 'x' where id <> auth.uid() returning id $$,
                'NFR-08: student cannot update another profile');
select is((select count(*)::int from public.devices), 1, 'NFR-08: student sees only own devices');
select lives_ok($$ update public.notifications set read_at = now() where user_id = auth.uid() $$,
                'NFR-08: student marks own notification read');
select throws_ok($$ update public.notifications set kind = 'x' $$, '42501', null,
                 'NFR-08: student can only update read_at');
select lives_ok($$ insert into public.push_tokens (user_id, token, platform) values (auth.uid(), 't-a', 'web') $$,
                'NFR-08: student registers own push token');
select throws_ok(format($$ insert into public.push_tokens (user_id, token, platform) values (%L, 't-b', 'web') $$,
                        tests.get_supabase_uid('student_b')), '42501', null,
                 'NFR-08: student cannot register a token for someone else');
select ok((select count(*) from public.settings) >= 9, 'NFR-08: student reads settings');

select tests.authenticate_as('teacher');
select ok((select count(*) from public.profiles) >= 3, 'NFR-08: teacher sees all profiles');

select tests.clear_authentication();
select throws_ok($$ select 1 from public.profiles $$, '42501', null, 'NFR-08: anon cannot read profiles');
select throws_ok($$ select 1 from public.settings $$, '42501', null, 'NFR-08: anon cannot read settings');

select * from finish();
rollback;
```

- [ ] **Step 3: Write `09_rls_catalogue.test.sql`**

```sql
-- F-2 / NFR-08 / PAY-01 — docs/06 §4 catalogue rows; question bank and mock forms stay closed.
begin;
create extension if not exists pgtap with schema extensions;
select plan(14);

select tests.create_supabase_user('student_a');
select tests.create_supabase_user('teacher');
update public.profiles set role = 'teacher' where id = tests.get_supabase_uid('teacher');

insert into public.courses (id, code, title, slug, is_published) values
  ('00000000-0000-0000-0000-0000000000c1', 'SAT', 'SAT Math', 'sat', true),
  ('00000000-0000-0000-0000-0000000000c2', 'EST', 'EST Math', 'est', false);
insert into public.units (course_id, title) values
  ('00000000-0000-0000-0000-0000000000c1', 'U1'), ('00000000-0000-0000-0000-0000000000c2', 'U2');
insert into public.topics (id, course_id, title, slug, is_published) values
  ('00000000-0000-0000-0000-0000000000d1', '00000000-0000-0000-0000-0000000000c1', 'Pub', 'pub', true),
  ('00000000-0000-0000-0000-0000000000d2', '00000000-0000-0000-0000-0000000000c1', 'Draft', 'draft', false),
  ('00000000-0000-0000-0000-0000000000d3', '00000000-0000-0000-0000-0000000000c2', 'Hidden', 'hidden', true);
insert into public.subtopics (id, topic_id, title) values
  ('00000000-0000-0000-0000-0000000000e1', '00000000-0000-0000-0000-0000000000d1', 'S1'),
  ('00000000-0000-0000-0000-0000000000e2', '00000000-0000-0000-0000-0000000000d2', 'S2');
insert into public.prices (course_id, currency, amount_minor, kind, active) values
  ('00000000-0000-0000-0000-0000000000c1', 'EGP', 100000, 'full', true),
  ('00000000-0000-0000-0000-0000000000c1', 'EGP', 90000, 'renewal', false),
  ('00000000-0000-0000-0000-0000000000c2', 'EGP', 80000, 'full', true);
insert into public.questions (id, topic_id, subtopic_id, type, difficulty, stem_md, pool, status)
  values ('00000000-0000-0000-0000-0000000000f1', '00000000-0000-0000-0000-0000000000d1',
          '00000000-0000-0000-0000-0000000000e1', 'mcq', 'E', 'x', 'practice', 'published');
insert into public.question_choices (question_id, label, body_md)
  values ('00000000-0000-0000-0000-0000000000f1', 'A', 'a');
insert into public.coupons (code, percent_off) values ('WELCOME', 10);
insert into public.mock_templates (id, course_id, name, blueprint)
  values ('00000000-0000-0000-0000-0000000000a9', '00000000-0000-0000-0000-0000000000c1', 'M', '{}');
insert into public.mock_forms (template_id, set_no, form_no, module, question_ids)
  values ('00000000-0000-0000-0000-0000000000a9', 1, 1, 'M1', '{}');

select tests.clear_authentication();
select is((select count(*)::int from public.courses), 1, 'NFR-08: anon sees only published courses');
select is((select count(*)::int from public.units), 1, 'NFR-08: anon sees units of published courses');
select is((select count(*)::int from public.topics), 1, 'NFR-08: anon sees published topics of published courses');
select is((select count(*)::int from public.subtopics), 1, 'NFR-08: anon sees subtopics of visible topics');
select is((select count(*)::int from public.prices), 1, 'NFR-08: anon sees active prices of published courses');
select throws_ok($$ select 1 from public.coupons $$, '42501', null, 'NFR-08: anon cannot read coupons');
select throws_ok($$ select 1 from public.questions $$, '42501', null, 'NFR-08: anon cannot read questions');

select tests.authenticate_as('student_a');
select is((select count(*)::int from public.courses), 1, 'NFR-08: student sees only published courses');
select is((select count(*)::int from public.questions), 0, 'NFR-08: student cannot read the question bank directly');
select is((select count(*)::int from public.question_choices), 0, 'NFR-08: student cannot read choices directly');
select is((select count(*)::int from public.coupons), 0, 'NFR-08: student cannot read coupons');
select is((select count(*)::int from public.mock_forms), 0, 'NFR-08: student cannot read mock forms');

select tests.authenticate_as('teacher');
select is((select count(*)::int from public.courses), 2, 'NFR-08: teacher sees unpublished courses');
select is((select count(*)::int from public.questions), 1, 'NFR-08: teacher reads the question bank');

select * from finish();
rollback;
```

- [ ] **Step 4: Write `10_rls_content.test.sql`**

```sql
-- F-2 / NFR-08 — docs/06 §4 content rows: assets, chapters, live sessions, announcements.
begin;
create extension if not exists pgtap with schema extensions;
select plan(9);

select tests.create_supabase_user('student_a');  -- enrolled
select tests.create_supabase_user('student_b');  -- not enrolled
select tests.create_supabase_user('student_c');  -- enrollment expired
select tests.create_supabase_user('teacher');
update public.profiles set role = 'teacher' where id = tests.get_supabase_uid('teacher');

insert into public.courses (id, code, title, slug, is_published)
  values ('00000000-0000-0000-0000-0000000000c1', 'SAT', 'SAT Math', 'sat', true);
insert into public.topics (id, course_id, title, slug, is_published, is_free_preview) values
  ('00000000-0000-0000-0000-0000000000d1', '00000000-0000-0000-0000-0000000000c1', 'Paid', 'paid', true, false),
  ('00000000-0000-0000-0000-0000000000d2', '00000000-0000-0000-0000-0000000000c1', 'Free', 'free', true, true),
  ('00000000-0000-0000-0000-0000000000d3', '00000000-0000-0000-0000-0000000000c1', 'Draft', 'draft', false, true);
insert into public.subtopics (id, topic_id, title)
  values ('00000000-0000-0000-0000-0000000000e1', '00000000-0000-0000-0000-0000000000d1', 'S1');
insert into public.topic_assets (id, topic_id, kind, title) values
  ('00000000-0000-0000-0000-0000000000b1', '00000000-0000-0000-0000-0000000000d1', 'video', 'Paid video'),
  ('00000000-0000-0000-0000-0000000000b2', '00000000-0000-0000-0000-0000000000d2', 'video', 'Free video'),
  ('00000000-0000-0000-0000-0000000000b3', '00000000-0000-0000-0000-0000000000d3', 'video', 'Draft video');
insert into public.video_chapters (asset_id, subtopic_id, start_s, label)
  values ('00000000-0000-0000-0000-0000000000b1', '00000000-0000-0000-0000-0000000000e1', 0, 'Intro');
insert into public.live_sessions (course_id, title, starts_at, duration_min)
  values ('00000000-0000-0000-0000-0000000000c1', 'Live', now() + interval '1 day', 60);
insert into public.announcements (course_id, title, body_md)
  values ('00000000-0000-0000-0000-0000000000c1', 'Hello', 'x');
insert into public.enrollments (user_id, course_id, status, expires_at) values
  (tests.get_supabase_uid('student_a'), '00000000-0000-0000-0000-0000000000c1', 'active', now() + interval '30 days'),
  (tests.get_supabase_uid('student_c'), '00000000-0000-0000-0000-0000000000c1', 'active', now() - interval '1 day');

select tests.authenticate_as('student_a');
select is((select count(*)::int from public.topic_assets), 2, 'NFR-08: enrolled student sees paid and free published assets');
select is((select count(*)::int from public.video_chapters), 1, 'NFR-08: enrolled student sees chapters');
select is((select count(*)::int from public.live_sessions), 1, 'NFR-08: enrolled student sees live sessions');
select is((select count(*)::int from public.announcements), 1, 'NFR-08: enrolled student sees announcements');

select tests.authenticate_as('student_b');
select is((select count(*)::int from public.topic_assets), 1, 'NFR-08: non-enrolled student sees free preview assets only');
select is((select count(*)::int from public.video_chapters), 0, 'NFR-08: non-enrolled student sees no paid chapters');
select is((select count(*)::int from public.announcements), 0, 'NFR-08: non-enrolled student sees no announcements');

select tests.authenticate_as('student_c');
select is((select count(*)::int from public.topic_assets), 1, 'NFR-08: expired enrollment loses paid assets');

select tests.authenticate_as('teacher');
select is((select count(*)::int from public.topic_assets), 3, 'NFR-08: teacher sees all assets');

select * from finish();
rollback;
```

- [ ] **Step 5: Write `11_rls_learning.test.sql`**

```sql
-- F-2 / NFR-07 / NFR-08 — docs/06 §4 learning rows: attempts, answers (rule 1), orders, AI, self-reported rows.
begin;
create extension if not exists pgtap with schema extensions;
select plan(14);

select tests.create_supabase_user('student_a');
select tests.create_supabase_user('student_b');
select tests.create_supabase_user('teacher');
update public.profiles set role = 'teacher' where id = tests.get_supabase_uid('teacher');

insert into public.courses (id, code, title, slug, is_published)
  values ('00000000-0000-0000-0000-0000000000c1', 'SAT', 'SAT Math', 'sat', true);
insert into public.topics (id, course_id, title, slug, is_published)
  values ('00000000-0000-0000-0000-0000000000d1', '00000000-0000-0000-0000-0000000000c1', 'T', 't', true);
insert into public.subtopics (id, topic_id, title)
  values ('00000000-0000-0000-0000-0000000000e1', '00000000-0000-0000-0000-0000000000d1', 'S');
insert into public.questions (id, topic_id, subtopic_id, type, difficulty, stem_md, pool) values
  ('00000000-0000-0000-0000-0000000000f1', '00000000-0000-0000-0000-0000000000d1', '00000000-0000-0000-0000-0000000000e1', 'mcq', 'E', 'x', 'quiz'),
  ('00000000-0000-0000-0000-0000000000f2', '00000000-0000-0000-0000-0000000000d1', '00000000-0000-0000-0000-0000000000e1', 'mcq', 'E', 'y', 'quiz');
insert into public.attempts (id, user_id, kind, course_id, status) values
  ('00000000-0000-0000-0000-0000000000a1', tests.get_supabase_uid('student_a'), 'quiz', '00000000-0000-0000-0000-0000000000c1', 'in_progress'),
  ('00000000-0000-0000-0000-0000000000a2', tests.get_supabase_uid('student_a'), 'quiz', '00000000-0000-0000-0000-0000000000c1', 'submitted'),
  ('00000000-0000-0000-0000-0000000000a3', tests.get_supabase_uid('student_b'), 'quiz', '00000000-0000-0000-0000-0000000000c1', 'submitted');
insert into public.attempt_questions (attempt_id, question_id, position) values
  ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000f1', 1),
  ('00000000-0000-0000-0000-0000000000a2', '00000000-0000-0000-0000-0000000000f2', 1),
  ('00000000-0000-0000-0000-0000000000a3', '00000000-0000-0000-0000-0000000000f1', 1);
insert into public.attempt_answers (attempt_id, question_id, answer, is_correct) values
  ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000f1', '{"choice":"A"}', true),
  ('00000000-0000-0000-0000-0000000000a2', '00000000-0000-0000-0000-0000000000f2', '{"choice":"B"}', false),
  ('00000000-0000-0000-0000-0000000000a3', '00000000-0000-0000-0000-0000000000f1', '{"choice":"C"}', false);
insert into public.prices (id, course_id, currency, amount_minor, kind)
  values ('00000000-0000-0000-0000-0000000000a7', '00000000-0000-0000-0000-0000000000c1', 'EGP', 100000, 'full');
insert into public.orders (user_id, course_id, price_id, amount_minor, currency, gateway, raw_payload) values
  (tests.get_supabase_uid('student_a'), '00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-0000000000a7', 100000, 'EGP', 'paymob', '{"card":"secret"}'),
  (tests.get_supabase_uid('student_b'), '00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-0000000000a7', 100000, 'EGP', 'paymob', '{}');
insert into public.ai_threads (id, user_id, question_id) values
  ('00000000-0000-0000-0000-0000000000b1', tests.get_supabase_uid('student_a'), '00000000-0000-0000-0000-0000000000f1'),
  ('00000000-0000-0000-0000-0000000000b2', tests.get_supabase_uid('student_b'), '00000000-0000-0000-0000-0000000000f1');
insert into public.ai_messages (thread_id, role, content) values
  ('00000000-0000-0000-0000-0000000000b1', 'user', 'help'),
  ('00000000-0000-0000-0000-0000000000b2', 'user', 'help');

select tests.authenticate_as('student_a');
select is((select count(*)::int from public.attempts), 2, 'NFR-08: student sees only own attempts');
select is((select count(*)::int from public.attempt_answers
           where attempt_id = '00000000-0000-0000-0000-0000000000a1'), 0,
          'NFR-07: answers of an in-progress attempt are hidden (rule 1)');
select is((select count(*)::int from public.attempt_answers), 1,
          'NFR-08: student sees answers of own submitted attempts only');
select throws_ok($$ select raw_payload from public.orders $$, '42501', null,
                 'NFR-08: student cannot read raw gateway payloads');
select is((select count(id)::int from public.orders), 1, 'NFR-08: student sees own orders');
select is((select count(*)::int from public.ai_messages), 1, 'NFR-08: student sees only own AI messages');
select throws_ok($$ insert into public.ai_messages (thread_id, role, content)
                    values ('00000000-0000-0000-0000-0000000000b1', 'assistant', 'fake') $$, '42501', null,
                 'NFR-08: student cannot write AI messages (ai-tutor EF only)');
select throws_ok($$ insert into public.attempts (user_id, kind, course_id)
                    values (auth.uid(), 'quiz', '00000000-0000-0000-0000-0000000000c1') $$, '42501', null,
                 'NFR-08: student cannot create attempts directly (RPC only)');
select lives_ok($$ insert into public.official_scores (user_id, course_id, score, taken_on)
                   values (auth.uid(), '00000000-0000-0000-0000-0000000000c1', 650, current_date) $$,
                'NFR-08: student records own official score');
select throws_ok(format($$ insert into public.official_scores (user_id, course_id, score, taken_on)
                           values (%L, '00000000-0000-0000-0000-0000000000c1', 800, current_date) $$,
                        tests.get_supabase_uid('student_b')), '42501', null,
                 'NFR-08: student cannot record a score for someone else');
select lives_ok($$ insert into public.question_reports (question_id, user_id, reason)
                   values ('00000000-0000-0000-0000-0000000000f1', auth.uid(), 'typo') $$,
                'NFR-08: student reports a question');

select tests.authenticate_as('teacher');
select is((select count(*)::int from public.attempt_answers), 3, 'NFR-08: teacher sees all answers');
select is((select count(id)::int from public.orders), 2, 'NFR-08: teacher sees all orders');
select throws_ok($$ insert into public.audit_log (action, entity) values ('x', 'y') $$, '42501', null,
                 'NFR-08: audit_log is read-only through the API');

select * from finish();
rollback;
```

- [ ] **Step 6: Run — expect failure.** `supabase test db < /dev/null` → `04_rls_gate` test 1 FAILS (tables without policy); `08`–`11` FAIL/ERROR with `42501 permission denied` (no grants yet).

- [ ] **Step 7: Write the policies migration** (`supabase migration new f2_rls_policies < /dev/null`)

```sql
-- F-2 row 3: RLS baseline (docs/06 §4). Teacher: all on every public table except audit_log.
-- Students/anon: only the rows below. Grants: authenticated gets full DML because the teacher is
-- an authenticated user; RLS is the student gate; column grants narrow profiles/notifications/orders.

-- 1. Grants
grant select on public.courses, public.units, public.topics, public.subtopics, public.prices to anon;

grant select, insert, update, delete on all tables in schema public to authenticated;
grant usage, select on all sequences in schema public to authenticated;

revoke insert, update on public.profiles from authenticated;  -- profiles come from the sign-up trigger
grant update (full_name, phone, country, school, grade, timezone) on public.profiles to authenticated;

revoke update on public.notifications from authenticated;
grant update (read_at) on public.notifications to authenticated;

revoke select on public.orders from authenticated;
grant select (id, user_id, course_id, price_id, coupon_id, amount_minor, currency, status, gateway,
              gateway_order_id, gateway_txn_id, created_at, paid_at)
  on public.orders to authenticated;

revoke insert, update, delete on public.audit_log from authenticated;

-- 2. Teacher manages all (one permissive policy per table)
do $$
declare
  t record;
begin
  for t in
    select c.relname
    from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind = 'r' and c.relname <> 'audit_log'
  loop
    execute format(
      'create policy %I on public.%I for all to authenticated '
      'using ((select public.is_teacher())) with check ((select public.is_teacher()))',
      t.relname || ': teacher manages all', t.relname);
  end loop;
end;
$$;

create policy "audit_log: teacher reads" on public.audit_log
  for select to authenticated using ((select public.is_teacher()));

-- 3. Public catalogue (PAY-01)
create policy "courses: published catalogue" on public.courses
  for select to anon, authenticated using (is_published);
create policy "units: published catalogue" on public.units
  for select to anon, authenticated
  using (exists (select 1 from public.courses c where c.id = course_id and c.is_published));
create policy "topics: published catalogue" on public.topics
  for select to anon, authenticated
  using (is_published and exists (select 1 from public.courses c where c.id = course_id and c.is_published));
create policy "subtopics: published catalogue" on public.subtopics
  for select to anon, authenticated
  using (exists (select 1 from public.topics t join public.courses c on c.id = t.course_id
                 where t.id = topic_id and t.is_published and c.is_published));
create policy "prices: active catalogue" on public.prices
  for select to anon, authenticated
  using (active and exists (select 1 from public.courses c where c.id = course_id and c.is_published));

-- 4. Student: own rows
create policy "profiles: student selects own" on public.profiles
  for select to authenticated using ((select auth.uid()) = id);
create policy "profiles: student updates own" on public.profiles
  for update to authenticated
  using ((select auth.uid()) = id) with check ((select auth.uid()) = id);

create policy "devices: student selects own" on public.devices
  for select to authenticated using ((select auth.uid()) = user_id);
create policy "enrollments: student selects own" on public.enrollments
  for select to authenticated using ((select auth.uid()) = user_id);
create policy "orders: student selects own" on public.orders
  for select to authenticated using ((select auth.uid()) = user_id);
create policy "attempts: student selects own" on public.attempts
  for select to authenticated using ((select auth.uid()) = user_id);
create policy "attempt_answers: student selects own submitted" on public.attempt_answers
  for select to authenticated
  using (exists (select 1 from public.attempts a
                 where a.id = attempt_id and a.user_id = (select auth.uid())
                   and a.status <> 'in_progress'));
create policy "topic_progress: student selects own" on public.topic_progress
  for select to authenticated using ((select auth.uid()) = user_id);
create policy "video_progress: student selects own" on public.video_progress
  for select to authenticated using ((select auth.uid()) = user_id);
create policy "skill_mastery: student selects own" on public.skill_mastery
  for select to authenticated using ((select auth.uid()) = user_id);
create policy "mistake_notebook: student selects own" on public.mistake_notebook
  for select to authenticated using ((select auth.uid()) = user_id);
create policy "mock_results: student selects own" on public.mock_results
  for select to authenticated using ((select auth.uid()) = user_id);

create policy "official_scores: student selects own" on public.official_scores
  for select to authenticated using ((select auth.uid()) = user_id);
create policy "official_scores: student inserts own" on public.official_scores
  for insert to authenticated with check ((select auth.uid()) = user_id);
create policy "question_reports: student selects own" on public.question_reports
  for select to authenticated using ((select auth.uid()) = user_id);
create policy "question_reports: student inserts own" on public.question_reports
  for insert to authenticated with check ((select auth.uid()) = user_id);

create policy "ai_threads: student selects own" on public.ai_threads
  for select to authenticated using ((select auth.uid()) = user_id);
create policy "ai_messages: student selects own" on public.ai_messages
  for select to authenticated
  using (exists (select 1 from public.ai_threads t where t.id = thread_id and t.user_id = (select auth.uid())));
create policy "escalations: student selects own" on public.escalations
  for select to authenticated
  using (exists (select 1 from public.ai_threads t where t.id = thread_id and t.user_id = (select auth.uid())));

create policy "notifications: student selects own" on public.notifications
  for select to authenticated using ((select auth.uid()) = user_id);
create policy "notifications: student marks own read" on public.notifications
  for update to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

create policy "push_tokens: student selects own" on public.push_tokens
  for select to authenticated using ((select auth.uid()) = user_id);
create policy "push_tokens: student inserts own" on public.push_tokens
  for insert to authenticated with check ((select auth.uid()) = user_id);
create policy "push_tokens: student deletes own" on public.push_tokens
  for delete to authenticated using ((select auth.uid()) = user_id);

-- 5. Student: access-gated content and shared reference data
create policy "topic_assets: student with topic access" on public.topic_assets
  for select to authenticated using (public.has_access_topic(topic_id));
create policy "video_chapters: student with topic access" on public.video_chapters
  for select to authenticated
  using (exists (select 1 from public.topic_assets a
                 where a.id = asset_id and public.has_access_topic(a.topic_id)));
create policy "live_sessions: student with course access" on public.live_sessions
  for select to authenticated using (public.has_access(course_id));
create policy "announcements: student with course access" on public.announcements
  for select to authenticated using (public.has_access(course_id));
create policy "skills: signed-in reads" on public.skills
  for select to authenticated using (true);
create policy "subtopic_skills: signed-in reads" on public.subtopic_skills
  for select to authenticated using (true);
create policy "settings: signed-in reads" on public.settings
  for select to authenticated using (true);

-- 6. Indexes for "select own" filters not already led by a PK/unique (docs/06 §4 traps)
create index orders_user_id_idx          on public.orders (user_id);
create index mock_results_user_id_idx    on public.mock_results (user_id);
create index official_scores_user_id_idx on public.official_scores (user_id);
create index question_reports_user_id_idx on public.question_reports (user_id);
create index ai_threads_user_id_idx      on public.ai_threads (user_id);
create index ai_messages_thread_id_idx   on public.ai_messages (thread_id);
create index escalations_thread_id_idx   on public.escalations (thread_id);
create index notifications_user_id_idx   on public.notifications (user_id);
```

- [ ] **Step 8: Run — expect pass.** `supabase db reset < /dev/null; supabase test db < /dev/null` → all files PASS. Any failure → superpowers:systematic-debugging (common suspects: `count(*)` on `orders` needs table-level select — tests use `count(id)`; `is_empty` with `update … returning`).

- [ ] **Step 9: Commit**

```bash
git add -A supabase/tests supabase/migrations/*_f2_rls_policies.sql docs/06-data-model.md docs/superpowers/specs/2026-10-07-f2-rls-baseline-design.md
git commit -m "feat(F-2): RLS baseline grants, policies and indexes per docs/06 §4"
```

---

### Task 3: API check, verify, review, ship

**Files:**
- Create: `scripts/api-private-check.ps1`
- Modify: `CLAUDE.md` Commands line (add the script), `docs/16-supabase-playbook.md` §1 Layer 1 (one line pointing to the script)

- [ ] **Step 1: Write `scripts/api-private-check.ps1`**

```powershell
# NFR-08 Layer 1 (docs/16 §1): the private schema is not reachable through the REST API.
# Run with the local stack up. Expects HTTP 406 (schema not exposed) for anon and service_role keys.
$status = supabase status -o json | ConvertFrom-Json
$failed = $false
foreach ($key in @($status.ANON_KEY, $status.SERVICE_ROLE_KEY)) {
  $headers = @{ apikey = $key; Authorization = "Bearer $key"; 'Accept-Profile' = 'private' }
  try {
    Invoke-WebRequest -UseBasicParsing -Uri "$($status.API_URL)/rest/v1/question_keys?select=*" -Headers $headers | Out-Null
    Write-Output 'FAIL: private.question_keys answered over REST'
    $failed = $true
  } catch {
    $code = [int]$_.Exception.Response.StatusCode
    if ($code -eq 406) { Write-Output 'PASS: private schema rejected (406)' }
    else { Write-Output "FAIL: expected 406, got $code"; $failed = $true }
  }
}
if ($failed) { exit 1 }
```

- [ ] **Step 2: Run it.** `powershell -File scripts/api-private-check.ps1` → two `PASS` lines, exit 0. Mutation check (proves it bites): temporarily set `Accept-Profile` to `public` and path `/rest/v1/settings` in a scratch copy → expect a non-406 `FAIL`; discard the copy.
- [ ] **Step 3: Docs.** `CLAUDE.md` Supabase commands: append ` · scripts/api-private-check.ps1`. `docs/16` §1 after the Layer 1 code block: `> Checked by \`scripts/api-private-check.ps1\` (expects 406 for \`Accept-Profile: private\`).`
- [ ] **Step 4:** `supabase db lint < /dev/null` clean; `supabase db advisors --local < /dev/null` no new findings.
- [ ] **Step 5: Commit** — `git add scripts/api-private-check.ps1 CLAUDE.md docs/16-supabase-playbook.md && git commit -m "test(F-2): REST check that private is not exposed"`
- [ ] **Step 6:** Walk the template checklist 1–9; final whole-branch review (`code-reviewer`, opus, with Review Focus); `/security-review` offered (RLS story).
- [ ] **Step 7:** `graphify update .`; push `feat/F-2-rls-baseline`; `gh pr create` titled `F-2 NFR-07 NFR-08: RLS baseline (row 3)`.

## Verification (end to end)
`supabase db reset; supabase test db` → files `000`, `00`–`03`, `04_rls_gate`, `05`–`11` green; `scripts/api-private-check.ps1` → 2× PASS; lint/advisors clean.

## Execution
Native (superpowers:executing-plans), as in row 2b — three sequential tasks over one schema; one whole-branch review at the end.
