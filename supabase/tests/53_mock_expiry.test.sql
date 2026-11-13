-- MCK-03 Task 3: cron expiry of mock modules. From supabase/templates/test.sql.
-- now() is fixed for the whole test transaction, so time moves by editing timestamps.
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

select tests.create_supabase_user('mk3_a');   -- M1 overdue, gap not ended
select tests.create_supabase_user('mk3_b');   -- gap ended, no M2
select tests.create_supabase_user('mk3_c');   -- M2 overdue
select tests.create_supabase_user('mk3_d');   -- M1 still running

update public.settings set value = '30'::jsonb where key = 'save_grace_s';
insert into public.courses (code, title, slug) values ('SAT', 'Mock SAT', 'mock-sat') on conflict (code) do nothing;
create temp table ctx (k text primary key, v uuid);
insert into ctx select 'course', id from public.courses where code = 'SAT';
create function pg_temp.course() returns uuid language sql stable as $$ select v from ctx where k = 'course' $$;
create function pg_temp.uid(p text) returns uuid language sql stable as $$ select tests.get_supabase_uid(p) $$;

insert into public.topics (id, course_id, title, slug, sort, is_published)
values ('53000000-0000-0000-0000-000000000101', pg_temp.course(), 'T', 'mk3-topic', 1, true);
insert into public.subtopics (id, topic_id, title)
values ('53000000-0000-0000-0000-000000000200', '53000000-0000-0000-0000-000000000101', 'Sub');
insert into public.questions (id, topic_id, subtopic_id, type, difficulty, stem_md, pool, status)
select ('53000000-0000-0000-0000-0000000004' || lpad(g::text, 2, '0'))::uuid,
       '53000000-0000-0000-0000-000000000101', '53000000-0000-0000-0000-000000000200',
       'mcq', 'M', 'Stem ' || g, 'mock_reserve', 'published'
from generate_series(1, 12) g;
insert into private.question_keys (question_id, correct_answer, explanation_md)
select q.id, '{"choice":"B"}'::jsonb, 'Why' from public.questions q where q.id::text like '53000000-0000-0000-0000-0000000004%';
insert into public.mock_templates (id, course_id, name, adaptive, blueprint) values
  ('53000000-0000-0000-0000-000000000500', pg_temp.course(), 'SAT Math', true,
   '{"modules":{"M1":{"time_s":600},"M2E":{"time_s":600},"M2H":{"time_s":600}},"routing":{"threshold_correct_m1":3}}');
insert into public.mock_forms (template_id, set_no, form_no, module, question_ids, status)
select '53000000-0000-0000-0000-000000000500', 1, 1, m.module,
       (select array_agg(('53000000-0000-0000-0000-0000000004' || lpad(g::text, 2, '0'))::uuid order by g)
        from generate_series(m.lo, m.lo + 3) g), 'published'
from (values ('M1', 1), ('M2E', 5), ('M2H', 9)) m(module, lo);

create function pg_temp.form(p_module text) returns uuid language sql stable as
  $$ select id from public.mock_forms where template_id = '53000000-0000-0000-0000-000000000500' and module = p_module $$;
create function pg_temp.grp(p text) returns uuid language sql immutable as
  $$ select ('53000000-0000-0000-0000-0000000009' || lpad(p, 2, '0'))::uuid $$;
create function pg_temp.m(p_group int, p_no int) returns uuid language sql stable as
  $$ select id from public.attempts where mock_attempt_group = pg_temp.grp(p_group::text) and module_no = p_no $$;

-- A: M1 started 700 s ago (limit 600 + grace 30 passed); gap would end 20 s from now.
select private.mock_create_module(pg_temp.uid('mk3_a'), pg_temp.course(), pg_temp.grp('1'), pg_temp.form('M1'), 1, now() - interval '700 seconds');
-- B: M1 finished long ago, gap ended 10 s ago, no M2.
select private.mock_create_module(pg_temp.uid('mk3_b'), pg_temp.course(), pg_temp.grp('2'), pg_temp.form('M1'), 1, now() - interval '1000 seconds');
select private.finish_mock_module(pg_temp.m(2, 1), now() - interval '130 seconds');
-- C: M1 finished, M2 started 700 s ago.
select private.mock_create_module(pg_temp.uid('mk3_c'), pg_temp.course(), pg_temp.grp('3'), pg_temp.form('M1'), 1, now() - interval '2000 seconds');
select private.finish_mock_module(pg_temp.m(3, 1), now() - interval '1400 seconds');
select private.mock_create_m2((select a from public.attempts a where a.id = pg_temp.m(3, 1)), now() - interval '700 seconds');
-- D: M1 started 100 s ago, nothing due.
select private.mock_create_module(pg_temp.uid('mk3_d'), pg_temp.course(), pg_temp.grp('4'), pg_temp.form('M1'), 1, now() - interval '100 seconds');

select is((select meta ->> 'route' from public.attempts where id = pg_temp.m(2, 1)), 'M2E', 'MCK-03: fixture B routed');
select is((select count(*)::int from public.attempts where mock_attempt_group = pg_temp.grp('2') and module_no = 2), 0, 'MCK-03: fixture B has no M2 yet');
select ok((select (meta ->> 'gap_until')::timestamptz <= now() from public.attempts where id = pg_temp.m(2, 1)), 'MCK-03: fixture B gap has ended');

select ok(exists (select 1 from pg_indexes where indexname = 'attempts_mock_in_progress_idx'
                  and indexdef like '%mock_module%' and indexdef like '%in_progress%'),
  'MCK-03: partial index for in-progress mock modules exists');

select is(private.expire_overdue_attempts(), 3, 'MCK-03: cron advances the three students with due work');

-- A: overdue M1 finished at its deadline, route set, gap still open.
select is((select status::text from public.attempts where id = pg_temp.m(1, 1)), 'submitted', 'MCK-03: cron finishes overdue M1');
select is((select submitted_at - started_at from public.attempts where id = pg_temp.m(1, 1)), interval '600 seconds',
  'MCK-03: overdue M1 is submitted at its deadline');
select is((select meta ->> 'route' from public.attempts where id = pg_temp.m(1, 1)), 'M2E', 'MCK-03: overdue M1 gets its route');
select is((select (meta ->> 'gap_until')::timestamptz - submitted_at from public.attempts where id = pg_temp.m(1, 1)),
  interval '120 seconds', 'MCK-03: overdue M1 gets its gap');
select is((select count(*)::int from public.attempts where mock_attempt_group = pg_temp.grp('1') and module_no = 2), 0,
  'MCK-03: M2 waits until the gap ends');
-- B: M2 auto-started at gap_until.
select is((select count(*)::int from public.attempts where mock_attempt_group = pg_temp.grp('2') and module_no = 2), 1,
  'MCK-03: cron auto-starts M2 after the gap');
select is((select a2.started_at from public.attempts a2 where a2.id = pg_temp.m(2, 2)),
  (select (a1.meta ->> 'gap_until')::timestamptz from public.attempts a1 where a1.id = pg_temp.m(2, 1)),
  'MCK-03: auto-started M2 begins at gap_until');
select is((select f.module from public.attempts a join public.mock_forms f on f.id = a.mock_form_id where a.id = pg_temp.m(2, 2)),
  'M2E', 'MCK-03: auto-started M2 uses the routed form');
select is((select status::text from public.attempts where id = pg_temp.m(2, 2)), 'in_progress', 'MCK-03: auto-started M2 is in progress');
-- C: overdue M2 finished, result written.
select is((select status::text from public.attempts where id = pg_temp.m(3, 2)), 'submitted', 'MCK-03: cron finishes overdue M2');
select is((select submitted_at - started_at from public.attempts where id = pg_temp.m(3, 2)), interval '600 seconds',
  'MCK-03: overdue M2 is submitted at its deadline');
select is((select count(*)::int from public.mock_results where group_id = pg_temp.grp('3')), 1, 'MCK-03: cron writes the mock result');
select is((select route || ' ' || raw_m1 || '/' || raw_m2 from public.mock_results where group_id = pg_temp.grp('3')), 'M2E 0/0',
  'MCK-03: cron result has route and raw scores');
-- D: untouched.
select is((select status::text from public.attempts where id = pg_temp.m(4, 1)), 'in_progress', 'MCK-03: a module still running is left alone');

-- Idempotent: nothing left to do.
select is(private.expire_overdue_attempts(), 0, 'MCK-03: a second cron run does nothing');
select is((select count(*)::int from public.mock_results), 1, 'MCK-03: no duplicate results');

-- Cron takes the same advisory key as the mock RPCs (a busy student is skipped via pg_try_advisory_xact_lock).
select ok(exists (select 1 from pg_locks where locktype = 'advisory' and pid = pg_backend_pid()
                  and ((classid::bigint << 32) | objid::bigint) = private.mock_lock_key(pg_temp.uid('mk3_a'))),
  'MCK-03: cron locked the student with the mock_lock key');
select is(private.mock_lock_key(pg_temp.uid('mk3_a')), hashtextextended('mock:' || pg_temp.uid('mk3_a')::text, 0),
  'MCK-03: mock_lock_key is the documented key');

-- Regression: an overdue quiz is still finished by the same entry point.
insert into public.attempts (id, user_id, kind, course_id, topic_id, started_at, time_limit_s)
values ('53000000-0000-0000-0000-000000000901', pg_temp.uid('mk3_d'), 'quiz', pg_temp.course(),
        '53000000-0000-0000-0000-000000000101', now() - interval '1 hour', 60);
insert into public.attempt_questions (attempt_id, question_id, position)
values ('53000000-0000-0000-0000-000000000901', '53000000-0000-0000-0000-000000000401', 1);
select is(private.expire_overdue_attempts(), 1, 'MCK-03: cron still finishes an overdue quiz');
select is((select status::text from public.attempts where id = '53000000-0000-0000-0000-000000000901'), 'submitted',
  'MCK-03: overdue quiz is submitted');

select ok(not has_function_privilege('authenticated', 'private.expire_overdue_attempts()', 'execute')
  and not has_function_privilege('anon', 'private.expire_overdue_attempts()', 'execute')
  and not has_function_privilege('authenticated', 'private.mock_lock_key(uuid)', 'execute')
  and not has_function_privilege('authenticated', 'private.mock_lock(uuid)', 'execute'),
  'MCK-03: expiry and lock helpers are not executable by authenticated or anon');

select * from finish();
rollback;
