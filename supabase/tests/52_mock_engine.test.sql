-- MCK-03 Task 2: mock engine (hub, start, session, route, gap, deadline, result, mastery, RLS, grants).
-- From supabase/templates/test.sql. Note: now() is fixed for the whole test transaction, so time moves
-- by editing started_at / gap_until as postgres.
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

select tests.create_supabase_user('mk2_a');   -- main student, enrolled
select tests.create_supabase_user('mk2_b');   -- enrolment expires mid-mock
select tests.create_supabase_user('mk2_c');   -- not enrolled

update public.settings set value = '1000'::jsonb
where key in ('rate_start_per_min', 'rate_save_per_min', 'rate_submit_per_min');

insert into public.courses (code, title, slug) values ('SAT', 'Mock SAT', 'mock-sat') on conflict (code) do nothing;
update public.courses set is_published = true where code = 'SAT';
create temp table ctx (k text primary key, v jsonb);
grant all on ctx to authenticated;
insert into ctx values ('course', to_jsonb((select id::text from public.courses where code = 'SAT')));
create function pg_temp.course() returns uuid language sql stable as $$ select (v #>> '{}')::uuid from ctx where k = 'course' $$;
create function pg_temp.uid(p text) returns uuid language sql stable as $$ select tests.get_supabase_uid(p) $$;

-- Ten published topics, none passed yet.
insert into public.topics (id, course_id, title, slug, sort, is_published)
select ('52000000-0000-0000-0000-0000000001' || lpad(g::text, 2, '0'))::uuid, pg_temp.course(),
       'Topic ' || g, 'mk2-topic-' || g, g, true
from generate_series(1, 10) g;
insert into public.subtopics (id, topic_id, title)
values ('52000000-0000-0000-0000-000000000200', '52000000-0000-0000-0000-000000000101', 'Sub');

-- Four skills, one per domain; twelve mock questions: q1..q12, skill = (i-1) mod 4.
insert into public.skills (id, code, name, domain) values
  ('52000000-0000-0000-0000-000000000301', 'TEST.MK2.ALG', 'Alg', 'Algebra'),
  ('52000000-0000-0000-0000-000000000302', 'TEST.MK2.ADV', 'Adv', 'Advanced Math'),
  ('52000000-0000-0000-0000-000000000303', 'TEST.MK2.PSD', 'Psda', 'PSDA'),
  ('52000000-0000-0000-0000-000000000304', 'TEST.MK2.GEO', 'Geo', 'Geometry & Trig');
-- q1,q2 (and q5,q6, q9,q10) are mcq with key B; the others are spr with key 1.
insert into public.questions (id, topic_id, subtopic_id, type, difficulty, stem_md, pool, status)
select ('52000000-0000-0000-0000-0000000004' || lpad(g::text, 2, '0'))::uuid,
       '52000000-0000-0000-0000-000000000101', '52000000-0000-0000-0000-000000000200',
       case when g % 4 in (1, 2) then 'mcq' else 'spr' end::public.question_type, 'M', 'Stem ' || g,
       'mock_reserve', 'published'
from generate_series(1, 12) g;
insert into public.question_choices (question_id, label, body_md)
select q.id, l.label, 'Choice ' || l.label
from public.questions q, (values ('A'), ('B'), ('C'), ('D')) l(label)
where q.type = 'mcq' and q.id::text like '52000000-0000-0000-0000-0000000004%';
insert into private.question_keys (question_id, correct_answer, explanation_md)
select q.id, case when q.type = 'mcq' then '{"choice":"B"}'::jsonb else '{"accepted":["1"],"tolerance":0}'::jsonb end, 'Why'
from public.questions q where q.id::text like '52000000-0000-0000-0000-0000000004%';
insert into public.question_skills (question_id, skill_id)
select q.id, ('52000000-0000-0000-0000-0000000003' || lpad((((right(q.id::text, 2)::int - 1) % 4) + 1)::text, 2, '0'))::uuid
from public.questions q where q.id::text like '52000000-0000-0000-0000-0000000004%';

-- Template (adaptive, found by mock_template_for) and forms. Form 3 is a draft; numbers 1, 2, 4 are playable.
insert into public.mock_templates (id, course_id, name, adaptive, blueprint) values
  ('52000000-0000-0000-0000-000000000500', pg_temp.course(), 'SAT Math', true,
   '{"modules":{"M1":{"time_s":600},"M2E":{"time_s":600},"M2H":{"time_s":600}},"routing":{"threshold_correct_m1":3}}');
insert into public.mock_forms (template_id, set_no, form_no, module, question_ids, status)
select '52000000-0000-0000-0000-000000000500', 1, f.no, m.module,
       (select array_agg(('52000000-0000-0000-0000-0000000004' || lpad(g::text, 2, '0'))::uuid order by g)
        from generate_series(m.lo, m.lo + 3) g),
       case when f.no = 3 then 'draft' else 'published' end
from (values (1), (2), (3), (4)) f(no),
     (values ('M1', 1), ('M2E', 5), ('M2H', 9)) m(module, lo);
-- A form of another set must never show up for set 1 students.
insert into public.mock_forms (template_id, set_no, form_no, module, question_ids, status)
select '52000000-0000-0000-0000-000000000500', 2, 9, m.module, array['52000000-0000-0000-0000-000000000401'::uuid], 'published'
from (values ('M1'), ('M2E'), ('M2H')) m(module);

insert into public.enrollments (user_id, course_id, status, starts_at, expires_at, mock_set_no) values
  (pg_temp.uid('mk2_a'), pg_temp.course(), 'active', now() - interval '1 day', now() + interval '30 days', 1),
  (pg_temp.uid('mk2_b'), pg_temp.course(), 'active', now() - interval '1 day', now() + interval '30 days', 1);

create function pg_temp.pass(p_user text, p_n int) returns void language sql as $$
  insert into public.topic_progress (user_id, topic_id, quiz_passed_at)
  select pg_temp.uid(p_user), t.id, now() from public.topics t
  where t.course_id = pg_temp.course() and t.slug like 'mk2-topic-%' order by t.sort limit p_n
  on conflict (user_id, topic_id) do update set quiz_passed_at = excluded.quiz_passed_at $$;
create function pg_temp.q(p int) returns uuid language sql immutable as
  $$ select ('52000000-0000-0000-0000-0000000004' || lpad(p::text, 2, '0'))::uuid $$;
create function pg_temp.states(p jsonb) returns text language sql immutable as
  $$ select string_agg(f ->> 'state', ',' order by (f ->> 'k')::int) from jsonb_array_elements(p -> 'forms') f $$;
create function pg_temp.gid(p text) returns uuid language sql stable as $$ select (v ->> 'group_id')::uuid from ctx where k = p $$;
create function pg_temp.aid(p text) returns uuid language sql stable as $$ select (v ->> 'attempt_id')::uuid from ctx where k = p $$;
grant execute on function pg_temp.course(), pg_temp.q(int), pg_temp.states(jsonb), pg_temp.gid(text),
  pg_temp.aid(text) to authenticated;

-- ===== Unlock gating ===========================================================================
select tests.authenticate_as('mk2_a');
insert into ctx select 'hub0', public.get_mock_hub(pg_temp.course());
select is((select v -> 'passed_topics' from ctx where k = 'hub0'), '0'::jsonb, 'MCK-03: hub starts at 0 passed topics');
select is((select jsonb_array_length(v -> 'forms') from ctx where k = 'hub0'), 3,
  'MCK-03: hub lists published forms only (draft and other set ignored)');
select is((select string_agg(f ->> 'form_no', ',' order by (f ->> 'k')::int) from ctx, jsonb_array_elements(v -> 'forms') f where k = 'hub0'),
  '1,2,4', 'MCK-03: form k ignores the draft and the gap in form_no');
select is((select string_agg(f ->> 'need', ',' order by (f ->> 'k')::int) from ctx, jsonb_array_elements(v -> 'forms') f where k = 'hub0'),
  '3,6,10', 'MCK-03: need comes from mock_unlock_topics');
select is(pg_temp.states((select v from ctx where k = 'hub0')), 'locked,locked,locked', 'MCK-03: all locked at 0 passed');
select is((select v -> 'active_group' from ctx where k = 'hub0'), 'null'::jsonb, 'MCK-03: no active group yet');
select throws_ok($$ select public.start_mock(pg_temp.course()) $$, 'P0001', 'mock_locked',
  'MCK-03: start_mock while locked raises mock_locked');

reset role;
select pg_temp.pass('mk2_a', 2);
select tests.authenticate_as('mk2_a');
select throws_ok($$ select public.start_mock(pg_temp.course()) $$, 'P0001', 'mock_locked',
  'MCK-03: 2 passed topics do not unlock form 1');
reset role;
select pg_temp.pass('mk2_a', 3);
select tests.authenticate_as('mk2_a');
select is(pg_temp.states(public.get_mock_hub(pg_temp.course())), 'available,locked,locked',
  'MCK-03: 3 passed topics unlock form 1 only');

-- ===== Start, resume, payload ==================================================================
insert into ctx select 'm1', public.start_mock(pg_temp.course());
select is((select v ->> 'stage' from ctx where k = 'm1'), 'module', 'MCK-03: start_mock returns a module');
select is((select (v ->> 'module_no')::int from ctx where k = 'm1'), 1, 'MCK-03: first module is module 1');
select is((select jsonb_array_length(v -> 'questions') from ctx where k = 'm1'), 4, 'MCK-03: module has its form questions');
select is((select (v ->> 'time_limit_s')::int from ctx where k = 'm1'), 600, 'MCK-03: time limit comes from the blueprint');
select ok((select v ? 'deadline' and v ? 'server_now' and v ? 'warn_s' and v ? 'client_seq' and v ? 'answers' and v ? 'group_id'
           from ctx where k = 'm1'), 'MCK-03: payload mirrors the quiz payload');
select is((select (v -> 'questions' -> 0 ->> 'id')::uuid from ctx where k = 'm1'), pg_temp.q(1), 'MCK-03: questions keep form order');
select ok((select not (v::text ~* '(correct|explanation|accepted)') from ctx where k = 'm1'),
  'MCK-03: payload carries no keys or explanations');
select is(public.start_mock(pg_temp.course()) ->> 'attempt_id', (select v ->> 'attempt_id' from ctx where k = 'm1'),
  'MCK-03: start_mock resumes the unfinished mock');
select is((select jsonb_array_length(v) from (select public.get_mock_hub(pg_temp.course()) -> 'forms' v) x), 3, 'MCK-03: hub still lists 3 forms');
select is(public.get_mock_hub(pg_temp.course()) ->> 'active_group', (select v ->> 'group_id' from ctx where k = 'm1'),
  'MCK-03: hub reports the active group');
select is(pg_temp.states(public.get_mock_hub(pg_temp.course())), 'in_progress,locked,locked', 'MCK-03: form 1 is in progress');
reset role;
select is((select count(*)::int from public.question_exposure where user_id = pg_temp.uid('mk2_a')), 4,
  'MCK-03: exposure written for the module questions');
select is((select count(*)::int from public.attempts where user_id = pg_temp.uid('mk2_a') and kind = 'mock_module'), 1,
  'MCK-03: one M1 attempt row after two start_mock calls');
select throws_ok($$ insert into public.attempts (user_id, kind, course_id, mock_attempt_group, mock_form_id, module_no)
  select user_id, kind, course_id, gen_random_uuid(), mock_form_id, 1 from public.attempts where kind = 'mock_module' $$,
  '23505', null, 'MCK-03: one M1 attempt per student and form');

-- ===== Save answers (M1): eliminated persisted, no M1 data readable ===========================
select tests.authenticate_as('mk2_a');
select is(public.save_answer(pg_temp.aid('m1'), pg_temp.q(1), 'B', 1000, false, array['A'], 1), '{"ok": true}'::jsonb,
  'MCK-03: save_answer works on a mock module');
select is(public.save_answer(pg_temp.aid('m1'), pg_temp.q(2), 'B', 1000, true, array['A', 'C'], 1), '{"ok": true}'::jsonb, 'MCK-03: save q2');
select is(public.save_answer(pg_temp.aid('m1'), pg_temp.q(3), '1', 1000, false, null, 1), '{"ok": true}'::jsonb, 'MCK-03: save q3');
select is(public.save_answer(pg_temp.aid('m1'), pg_temp.q(4), '9', 1000, false, null, 1), '{"ok": true}'::jsonb, 'MCK-03: save q4 (wrong)');
select is(public.save_answer(pg_temp.aid('m1'), pg_temp.q(1), 'C', 1000, false, null, 1) ->> 'stale', 'true',
  'MCK-03: a stale client_seq is ignored');
select is((select a -> 'eliminated' from jsonb_array_elements(public.get_mock_session(pg_temp.gid('m1')) -> 'answers') a
           where (a ->> 'question_id')::uuid = pg_temp.q(2)), '["A", "C"]'::jsonb, 'MCK-03: eliminated choices persist');
select is((select a -> 'marked' from jsonb_array_elements(public.get_mock_session(pg_temp.gid('m1')) -> 'answers') a
           where (a ->> 'question_id')::uuid = pg_temp.q(2)), 'true'::jsonb, 'MCK-03: marked flag persists');
select is((select count(*)::int from public.attempt_answers), 0, 'MCK-03: RLS hides in-progress mock answers');
select throws_ok($$ select public.save_answer(pg_temp.aid('m1'), pg_temp.q(5), 'B', 1, false, null, 1) $$, 'P0001', 'invalid_input',
  'MCK-03: a question outside the module is invalid_input');

-- ===== Submit M1: only the next stage comes back ==============================================
insert into ctx select 'sub1', public.submit_attempt(pg_temp.aid('m1'));
select is((select v ->> 'stage' from ctx where k = 'sub1'), 'gap', 'MCK-03: submitting M1 returns the gap stage');
select is((select v - 'stage' - 'group_id' - 'gap_until' - 'server_now' from ctx where k = 'sub1'), '{}'::jsonb,
  'MCK-03: M1 submit reveals no route, score or key');
select is(public.submit_attempt(pg_temp.aid('m1')) ->> 'stage', 'gap', 'MCK-03: submitting M1 twice is harmless');
select is((select count(*)::int from public.attempt_answers), 0, 'MCK-03: submitted M1 answers stay hidden before M2 ends');
select is((select count(*)::int from public.attempts where kind = 'mock_module'), 0, 'MCK-03: mock attempt rows (route, score) are hidden');
select is(public.get_mock_session(pg_temp.gid('m1')) ->> 'stage', 'gap', 'MCK-03: session is the gap');
select ok(not (public.get_mock_session(pg_temp.gid('m1'))::text ~ '(route|score|M2H|M2E)'), 'MCK-03: gap session reveals no route or score');
select is(public.start_mock(pg_temp.course()) ->> 'stage', 'gap', 'MCK-03: start_mock during the gap returns the gap');
reset role;
select is((select meta ->> 'route' from public.attempts where id = pg_temp.aid('m1')), 'M2H', 'MCK-03: 3 correct routes to M2H');
select is((select (meta ->> 'gap_until')::timestamptz - submitted_at from public.attempts where id = pg_temp.aid('m1')),
  interval '120 seconds', 'MCK-03: gap_until = submit time + mock_gap_s');
select is((select count(*)::int from public.skill_mastery where user_id = pg_temp.uid('mk2_a')), 0, 'MCK-03: no mastery after M1');
select is((select count(*)::int from public.mock_results), 0, 'MCK-03: no result after M1');
select tests.authenticate_as('mk2_b');
select throws_ok($$ select public.get_mock_session(pg_temp.gid('m1')) $$, 'P0001', 'invalid_input', 'MCK-03: other students cannot read the session');
select throws_ok($$ select public.submit_attempt(pg_temp.aid('m1')) $$, 'P0001', 'invalid_input', 'MCK-03: other students cannot submit it');
select throws_ok($$ select public.start_mock_module2(pg_temp.gid('m1')) $$, 'P0001', 'invalid_input', 'MCK-03: other students cannot start its M2');

-- ===== Early M2 start is idempotent ===========================================================
select tests.authenticate_as('mk2_a');
insert into ctx select 'm2', public.start_mock_module2(pg_temp.gid('m1'));
select is((select (v ->> 'module_no')::int from ctx where k = 'm2'), 2, 'MCK-03: start_mock_module2 starts module 2');
select is((select jsonb_array_length(v -> 'questions') from ctx where k = 'm2'), 4, 'MCK-03: module 2 has its questions');
select is((select (v -> 'questions' -> 0 ->> 'id')::uuid from ctx where k = 'm2'), pg_temp.q(9), 'MCK-03: M2H questions come from the M2H form');
select is(public.start_mock_module2(pg_temp.gid('m1')) ->> 'attempt_id', (select v ->> 'attempt_id' from ctx where k = 'm2'),
  'MCK-03: early start is idempotent');
select is(public.get_mock_session(pg_temp.gid('m1')) ->> 'attempt_id', (select v ->> 'attempt_id' from ctx where k = 'm2'),
  'MCK-03: session now shows module 2');
reset role;
select is((select count(*)::int from public.attempts where mock_attempt_group = pg_temp.gid('m1') and module_no = 2), 1, 'MCK-03: one M2 row');
select is((select f.module from public.attempts a join public.mock_forms f on f.id = a.mock_form_id where a.id = pg_temp.aid('m2')),
  'M2H', 'MCK-03: M2 row points at the M2H form');
select is((select started_at from public.attempts where id = pg_temp.aid('m2')), now(), 'MCK-03: early M2 starts now');
select throws_ok($$ select public.submit_attempt(gen_random_uuid()) $$, 'P0001', 'invalid_input', 'MCK-03: unknown attempt is invalid_input');

-- ===== Finish M2: result math, mastery once ===================================================
select tests.authenticate_as('mk2_a');
select public.save_answer(pg_temp.aid('m2'), pg_temp.q(9), 'B', 1000, false, null, 1);
select public.save_answer(pg_temp.aid('m2'), pg_temp.q(10), 'B', 1000, false, array['D'], 1);
select public.save_answer(pg_temp.aid('m2'), pg_temp.q(11), '1', 1000, false, null, 1);
insert into ctx select 'sub2', public.submit_attempt(pg_temp.aid('m2'));
select is((select v ->> 'stage' from ctx where k = 'sub2'), 'finished', 'MCK-03: submitting M2 finishes the mock');
select ok((select v ? 'result_id' from ctx where k = 'sub2'), 'MCK-03: finish returns the result id');
select is(public.submit_attempt(pg_temp.aid('m2')) ->> 'stage', 'finished', 'MCK-03: submitting M2 twice is harmless');
select is(public.get_mock_session(pg_temp.gid('m1')) ->> 'stage', 'finished', 'MCK-03: session is finished');
select is((select count(*)::int from public.attempt_answers), 8, 'MCK-03: all 8 answers are readable after M2 ends');
select is((select count(*)::int from public.attempts where kind = 'mock_module'), 2, 'MCK-03: both attempt rows are readable after M2 ends');
select is((select route from public.mock_results where group_id = pg_temp.gid('m1')), 'M2H', 'MCK-03: result route');
select is((select raw_m1 || '/' || raw_m2 from public.mock_results where group_id = pg_temp.gid('m1')), '3/3', 'MCK-03: result raw scores');
select is((select est_low || '-' || est_high from public.mock_results where group_id = pg_temp.gid('m1')), '290-350',
  'MCK-03: estimate = hard table[6] = 320 +/- 30');
select is((select domain_breakdown from public.mock_results where group_id = pg_temp.gid('m1')),
  '[{"domain":"Advanced Math","correct":2,"total":2},{"domain":"Algebra","correct":2,"total":2},
    {"domain":"Geometry & Trig","correct":0,"total":2},{"domain":"PSDA","correct":2,"total":2}]'::jsonb,
  'MCK-03: domain breakdown');
select is((select count(*)::int from public.mock_results), 1, 'MCK-03: one result row');
reset role;
select is((select sum(attempts)::int from public.skill_mastery where user_id = pg_temp.uid('mk2_a')), 8, 'MCK-03: mastery applied once per answer');
select is((select count(*)::int from public.skill_mastery where user_id = pg_temp.uid('mk2_a') and attempts = 2), 4, 'MCK-03: two per skill');
select is((select score_raw || '/' || score_total from public.attempts where id = pg_temp.aid('m2')), '3/4', 'MCK-03: M2 row scores');
select tests.authenticate_as('mk2_a');
select public.submit_attempt(pg_temp.aid('m2'));
reset role;
select is((select sum(attempts)::int from public.skill_mastery where user_id = pg_temp.uid('mk2_a')), 8, 'MCK-03: a second submit does not re-apply mastery');

-- ===== Form order, second mock via M2E, gap auto-start ========================================
select tests.authenticate_as('mk2_a');
select is(pg_temp.states(public.get_mock_hub(pg_temp.course())), 'finished,locked,locked', 'MCK-03: form 1 finished');
reset role;
select pg_temp.pass('mk2_a', 6);
select tests.authenticate_as('mk2_a');
select is(pg_temp.states(public.get_mock_hub(pg_temp.course())), 'finished,available,locked', 'MCK-03: 6 topics unlock form 2');
insert into ctx select 'n1', public.start_mock(pg_temp.course());
reset role;
select is((select f.form_no from public.attempts a join public.mock_forms f on f.id = a.mock_form_id where a.id = pg_temp.aid('n1')), 2,
  'MCK-03: start_mock picks the lowest unstarted available form');
select tests.authenticate_as('mk2_a');
select public.save_answer(pg_temp.aid('n1'), pg_temp.q(1), 'B', 1000, false, null, 1);
select public.submit_attempt(pg_temp.aid('n1'));
reset role;
select is((select meta ->> 'route' from public.attempts where id = pg_temp.aid('n1')), 'M2E', 'MCK-03: 1 correct routes to M2E');
-- The gap ended 10 s ago: the next call starts module 2 at gap_until.
update public.attempts set meta = meta || jsonb_build_object('gap_until', now() - interval '10 seconds')
where id = pg_temp.aid('n1');
select tests.authenticate_as('mk2_a');
insert into ctx select 'n2', public.get_mock_session(pg_temp.gid('n1'));
select is((select (v ->> 'module_no')::int from ctx where k = 'n2'), 2, 'MCK-03: a finished gap auto-starts module 2');
reset role;
select is((select f.module from public.attempts a join public.mock_forms f on f.id = a.mock_form_id where a.id = pg_temp.aid('n2')),
  'M2E', 'MCK-03: auto-started M2 uses the M2E form');
select is((select started_at from public.attempts where id = pg_temp.aid('n2')), now() - interval '10 seconds',
  'MCK-03: auto-started M2 starts at gap_until');

-- Deadline: M2 overdue past grace is finished at its deadline by the next read.
update public.attempts set started_at = now() - interval '700 seconds' where id = pg_temp.aid('n2');
select tests.authenticate_as('mk2_a');
select throws_ok($$ select public.save_answer(pg_temp.aid('n2'), pg_temp.q(5), 'B', 1, false, null, 1) $$, 'P0001', 'deadline_passed',
  'MCK-03: save after deadline + grace raises deadline_passed');
select is(public.get_mock_session(pg_temp.gid('n1')) ->> 'stage', 'finished', 'MCK-03: an overdue module 2 is finished on read');
reset role;
select is((select submitted_at - started_at from public.attempts where id = pg_temp.aid('n2')), interval '600 seconds',
  'MCK-03: overdue module is submitted at its deadline');
select is((select route || ' ' || raw_m1 || '/' || raw_m2 || ' ' || est_low || '-' || est_high from public.mock_results where group_id = pg_temp.gid('n1')),
  'M2E 1/0 200-240', 'MCK-03: easy result clamps low to 200 (table[1] = 210)');

-- ===== Overdue M1 whose gap also ended: both modules close at once ===============================
select pg_temp.pass('mk2_a', 10);
select tests.authenticate_as('mk2_a');
select is(pg_temp.states(public.get_mock_hub(pg_temp.course())), 'finished,finished,available', 'MCK-03: 10 topics unlock form 4');
insert into ctx select 'p1', public.start_mock(pg_temp.course());
reset role;
update public.attempts set started_at = now() - interval '700 seconds' where id = pg_temp.aid('p1');
select tests.authenticate_as('mk2_a');
select throws_ok($$ select public.save_answer(pg_temp.aid('p1'), pg_temp.q(1), 'B', 1, false, null, 1) $$, 'P0001', 'deadline_passed',
  'MCK-03: M1 save after deadline + grace raises deadline_passed');
select is(public.submit_attempt(pg_temp.aid('p1')) ->> 'stage', 'gap', 'MCK-03: submit after the deadline closes M1 at its deadline');
reset role;
select is((select submitted_at - started_at from public.attempts where id = pg_temp.aid('p1')), interval '600 seconds',
  'MCK-03: M1 is submitted at its deadline, not now');
update public.attempts set started_at = now() - interval '2000 seconds', submitted_at = now() - interval '1400 seconds',
  meta = meta || jsonb_build_object('gap_until', now() - interval '1280 seconds')
where id = pg_temp.aid('p1');
select tests.authenticate_as('mk2_a');
select is(public.get_mock_session(pg_temp.gid('p1')) ->> 'stage', 'finished', 'MCK-03: an ended gap and overdue M2 finish together');
reset role;
select is((select est_low || '-' || est_high || ' ' || raw_m1 || '/' || raw_m2 from public.mock_results where group_id = pg_temp.gid('p1')),
  '200-230 0/0', 'MCK-03: empty mock scores raw 0');
select tests.authenticate_as('mk2_a');
select throws_ok($$ select public.start_mock(pg_temp.course()) $$, 'P0001', 'mock_none_available',
  'MCK-03: all forms finished raises mock_none_available');
select is(pg_temp.states(public.get_mock_hub(pg_temp.course())), 'finished,finished,finished', 'MCK-03: hub shows three finished forms');

-- ===== Enrolment expiring mid-mock, has_active_exam ============================================
reset role;
select is(private.has_active_exam(pg_temp.uid('mk2_b')), false, 'MCK-03: no active exam before starting');
select pg_temp.pass('mk2_b', 3);
select tests.authenticate_as('mk2_b');
insert into ctx select 'b1', public.start_mock(pg_temp.course());
reset role;
select is(private.has_active_exam(pg_temp.uid('mk2_b')), true, 'MCK-03: active exam while M1 is in progress');
update public.enrollments set expires_at = now() - interval '1 day' where user_id = pg_temp.uid('mk2_b');
select tests.authenticate_as('mk2_b');
select is(public.save_answer(pg_temp.aid('b1'), pg_temp.q(1), 'B', 1, false, null, 1), '{"ok": true}'::jsonb,
  'MCK-03: save_answer works after the enrolment expired');
select is(public.submit_attempt(pg_temp.aid('b1')) ->> 'stage', 'gap', 'MCK-03: M1 submits after the enrolment expired');
reset role;
select is(private.has_active_exam(pg_temp.uid('mk2_b')), true, 'MCK-03: active exam during the gap');
select tests.authenticate_as('mk2_b');
select is(public.start_mock_module2(pg_temp.gid('b1')) ->> 'module_no', '2', 'MCK-03: M2 starts after the enrolment expired');
select is(public.submit_attempt((select (v ->> 'attempt_id')::uuid from (select public.get_mock_session(pg_temp.gid('b1')) v) s)) ->> 'stage',
  'finished', 'MCK-03: M2 finishes after the enrolment expired');
reset role;
select is(private.has_active_exam(pg_temp.uid('mk2_b')), false, 'MCK-03: no active exam after the result');
select tests.authenticate_as('mk2_b');
select throws_ok($$ select public.get_mock_hub(pg_temp.course()) $$, 'P0001', 'access_expired', 'MCK-03: hub needs an active enrolment');
select throws_ok($$ select public.start_mock(pg_temp.course()) $$, 'P0001', 'access_expired', 'MCK-03: starting a new mock needs an active enrolment');

-- Not enrolled.
select tests.authenticate_as('mk2_c');
select throws_ok($$ select public.get_mock_hub(pg_temp.course()) $$, 'P0001', 'not_enrolled', 'MCK-03: hub for a stranger is not_enrolled');
select throws_ok($$ select public.start_mock(pg_temp.course()) $$, 'P0001', 'not_enrolled', 'MCK-03: start_mock for a stranger is not_enrolled');
select throws_ok($$ select public.start_mock(null) $$, 'P0001', 'invalid_input', 'MCK-03: null course is invalid_input');
select throws_ok($$ select public.get_mock_session(null) $$, 'P0001', 'invalid_input', 'MCK-03: null group is invalid_input');

-- ===== Regression: quiz paths still gated, quiz counts as an active exam ========================
reset role;
insert into public.attempts (id, user_id, kind, course_id, topic_id, time_limit_s)
values ('52000000-0000-0000-0000-000000000900', pg_temp.uid('mk2_c'), 'quiz', pg_temp.course(),
        '52000000-0000-0000-0000-000000000101', 900);
select is(private.has_active_exam(pg_temp.uid('mk2_c')), true, 'MCK-03: an in-progress quiz is an active exam');
select tests.authenticate_as('mk2_c');
select throws_ok($$ select public.save_answer('52000000-0000-0000-0000-000000000900', pg_temp.q(1), 'B', 1, false, null, 1) $$,
  'P0001', 'not_enrolled', 'MCK-03: quiz save_answer still checks access');
select throws_ok($$ select public.submit_attempt('52000000-0000-0000-0000-000000000900') $$,
  'P0001', 'not_enrolled', 'MCK-03: quiz submit_attempt still checks access');
reset role;
update public.attempts set status = 'abandoned' where id = '52000000-0000-0000-0000-000000000900';
select is(private.has_active_exam(pg_temp.uid('mk2_c')), false, 'MCK-03: a closed quiz is not an active exam');

-- ===== Grants ==================================================================================
select ok(has_function_privilege('authenticated', 'public.get_mock_hub(uuid)', 'execute')
  and has_function_privilege('authenticated', 'public.start_mock(uuid)', 'execute')
  and has_function_privilege('authenticated', 'public.get_mock_session(uuid)', 'execute')
  and has_function_privilege('authenticated', 'public.start_mock_module2(uuid)', 'execute'),
  'MCK-03: mock RPCs are executable by authenticated');
select ok(not has_function_privilege('anon', 'public.get_mock_hub(uuid)', 'execute')
  and not has_function_privilege('anon', 'public.start_mock(uuid)', 'execute')
  and not has_function_privilege('anon', 'public.get_mock_session(uuid)', 'execute')
  and not has_function_privilege('anon', 'public.start_mock_module2(uuid)', 'execute'),
  'MCK-03: mock RPCs are not executable by anon');
select ok(not exists (
  select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'private'
    and p.proname in ('mock_lock', 'mock_enrolment', 'mock_passed_topics', 'mock_forms_for', 'mock_create_module',
                      'mock_create_m2', 'finish_mock_module', 'mock_tick', 'has_active_exam', 'mock_stage',
                      'mock_module_payload', 'mock_session')
    and (has_function_privilege('authenticated', p.oid, 'execute') or has_function_privilege('anon', p.oid, 'execute'))),
  'MCK-03: private mock helpers are not executable by authenticated or anon');
select ok(has_function_privilege('authenticated', 'public.save_answer(uuid,uuid,text,integer,boolean,text[],integer)', 'execute')
  and has_function_privilege('authenticated', 'public.submit_attempt(uuid)', 'execute')
  and not has_function_privilege('anon', 'public.save_answer(uuid,uuid,text,integer,boolean,text[],integer)', 'execute')
  and not has_function_privilege('anon', 'public.submit_attempt(uuid)', 'execute'),
  'MCK-03: save_answer and submit_attempt keep their grants');
select tests.clear_authentication();
set local role anon;
select throws_ok($$ select public.get_mock_hub(gen_random_uuid()) $$, '42501', null, 'MCK-03: anon cannot call get_mock_hub');
reset role;

select * from finish();
rollback;
