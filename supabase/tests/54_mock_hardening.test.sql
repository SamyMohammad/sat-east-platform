-- MCK-03 hardening: run snapshot, start checks, null estimate, equal modules, resume after expiry,
-- two-number unlock rule, teacher-editable mock settings, mock_warn_s, student RLS probes.
-- From supabase/templates/test.sql. now() is fixed for the whole transaction.
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

select tests.create_supabase_user('h_a');   -- snapshot: live blueprint changed mid-run
select tests.create_supabase_user('h_b');   -- scale broken mid-run
select tests.create_supabase_user('h_c');   -- broken scale / margin at start
select tests.create_supabase_user('h_d');   -- form longer than the scale allows (set 2)
select tests.create_supabase_user('h_e');   -- M2E and M2H times differ
select tests.create_supabase_user('h_i');   -- M2E and M2H lengths differ (set 3)
select tests.create_supabase_user('h_f');   -- enrolment expires mid-mock
select tests.create_supabase_user('h_g');   -- expired, no mock
select tests.create_supabase_user('h_h');   -- unlock rule, warn_s, RLS probes
select tests.create_supabase_user('h_n');   -- not enrolled

update public.settings set value = '1000'::jsonb
where key in ('rate_start_per_min', 'rate_save_per_min', 'rate_submit_per_min');

insert into public.courses (code, title, slug) values ('SAT', 'Mock SAT', 'mock-sat') on conflict (code) do nothing;
update public.courses set is_published = true where code = 'SAT';
create temp table ctx (k text primary key, v jsonb);
grant all on ctx to authenticated;
insert into ctx values ('course', to_jsonb((select id::text from public.courses where code = 'SAT')));
create function pg_temp.course() returns uuid language sql stable as $$ select (v #>> '{}')::uuid from ctx where k = 'course' $$;
create function pg_temp.uid(p text) returns uuid language sql stable as $$ select tests.get_supabase_uid(p) $$;
create function pg_temp.q(p int) returns uuid language sql immutable as
  $$ select ('54000000-0000-0000-0000-0000000004' || lpad(p::text, 2, '0'))::uuid $$;
create function pg_temp.gid(p text) returns uuid language sql stable as $$ select (v ->> 'group_id')::uuid from ctx where k = p $$;
create function pg_temp.aid(p text) returns uuid language sql stable as $$ select (v ->> 'attempt_id')::uuid from ctx where k = p $$;
create function pg_temp.states(p jsonb) returns text language sql immutable as
  $$ select string_agg(f ->> 'state', ',' order by (f ->> 'k')::int) from jsonb_array_elements(p -> 'forms') f $$;
grant execute on function pg_temp.course(), pg_temp.q(int), pg_temp.gid(text), pg_temp.aid(text), pg_temp.states(jsonb) to authenticated;

insert into public.topics (id, course_id, title, slug, sort, is_published)
select ('54000000-0000-0000-0000-0000000001' || lpad(g::text, 2, '0'))::uuid, pg_temp.course(),
       'Topic ' || g, 'h-topic-' || g, g, true
from generate_series(1, 10) g;
insert into public.subtopics (id, topic_id, title)
values ('54000000-0000-0000-0000-000000000200', '54000000-0000-0000-0000-000000000101', 'Sub');
insert into public.skills (id, code, name, domain) values
  ('54000000-0000-0000-0000-000000000301', 'TEST.H.ALG', 'Alg', 'Algebra');
-- 25 mcq questions, key B, one skill.
insert into public.questions (id, topic_id, subtopic_id, type, difficulty, stem_md, pool, status)
select pg_temp.q(g), '54000000-0000-0000-0000-000000000101', '54000000-0000-0000-0000-000000000200',
       'mcq', 'M', 'Stem ' || g, 'mock_reserve', 'published'
from generate_series(1, 25) g;
insert into private.question_keys (question_id, correct_answer, explanation_md)
select q.id, '{"choice":"B"}'::jsonb, 'Why' from public.questions q where q.id::text like '54000000-0000-0000-0000-0000000004%';
insert into public.question_skills (question_id, skill_id)
select q.id, '54000000-0000-0000-0000-000000000301' from public.questions q where q.id::text like '54000000-0000-0000-0000-0000000004%';

insert into public.mock_templates (id, course_id, name, adaptive, blueprint) values
  ('54000000-0000-0000-0000-000000000500', pg_temp.course(), 'SAT Math', true,
   '{"modules":{"M1":{"time_s":600},"M2E":{"time_s":600},"M2H":{"time_s":600}},"routing":{"threshold_correct_m1":3}}');
create temp table t_orig as select blueprint from public.mock_templates where id = '54000000-0000-0000-0000-000000000500';
create temp table t_scale as select key, value from public.settings where key in ('sat_scale_hard', 'sat_scale_easy', 'sat_scale_margin');
grant all on t_orig, t_scale to authenticated;
-- set 1: forms 1-3 published, 4 questions per module (M1 q1-4, M2E q5-8, M2H q9-12).
insert into public.mock_forms (template_id, set_no, form_no, module, question_ids, status)
select '54000000-0000-0000-0000-000000000500', 1, f.no, m.module,
       (select array_agg(pg_temp.q(g) order by g) from generate_series(m.lo, m.lo + 3) g), 'published'
from (values (1), (2), (3)) f(no), (values ('M1', 1), ('M2E', 5), ('M2H', 9)) m(module, lo);
-- set 2: one form of 25 + 20 + 20 questions (45 > the scale's max raw 44).
insert into public.mock_forms (template_id, set_no, form_no, module, question_ids, status)
select '54000000-0000-0000-0000-000000000500', 2, 1, m.module,
       (select array_agg(pg_temp.q(g) order by g) from generate_series(1, m.n) g), 'published'
from (values ('M1', 25), ('M2E', 20), ('M2H', 20)) m(module, n);
-- set 3: M2E has 4 questions, M2H has 3 (a student could tell the route from the length).
insert into public.mock_forms (template_id, set_no, form_no, module, question_ids, status)
select '54000000-0000-0000-0000-000000000500', 3, 1, m.module,
       (select array_agg(pg_temp.q(g) order by g) from generate_series(m.lo, m.lo + m.n - 1) g), 'published'
from (values ('M1', 1, 4), ('M2E', 5, 4), ('M2H', 9, 3)) m(module, lo, n);

insert into public.enrollments (user_id, course_id, status, starts_at, expires_at, mock_set_no)
select pg_temp.uid(u.n), pg_temp.course(), 'active', now() - interval '1 day', now() + interval '30 days', u.s
from (values ('h_a', 1), ('h_b', 1), ('h_c', 1), ('h_d', 2), ('h_e', 1), ('h_i', 3), ('h_f', 1), ('h_g', 1), ('h_h', 1)) u(n, s);

create function pg_temp.pass(p_user text, p_n int) returns void language sql as $$
  insert into public.topic_progress (user_id, topic_id, quiz_passed_at)
  select pg_temp.uid(p_user), t.id, now() from public.topics t
  where t.course_id = pg_temp.course() and t.slug like 'h-topic-%' order by t.sort limit p_n
  on conflict (user_id, topic_id) do update set quiz_passed_at = excluded.quiz_passed_at $$;
select pg_temp.pass(u, 3) from unnest(array['h_a', 'h_b', 'h_c', 'h_d', 'h_e', 'h_i', 'h_f']) u;
select pg_temp.pass('h_g', 3);

-- ===== 4/5. Unlock rule: two numbers; mock settings are teacher-editable ========================
select is((select value from public.settings where key = 'mock_unlock_first_topics'), '3'::jsonb, 'MCK-09: first form needs 3 topics by default');
select is((select value from public.settings where key = 'mock_unlock_step_topics'), '3'::jsonb, 'MCK-09: each later form needs 3 more by default');
select is((select count(*)::int from public.settings where key = 'mock_unlock_topics'), 0, 'MCK-09: the unlock list setting is gone');
select is((select value from public.settings where key = 'mock_warn_s'), '300'::jsonb, 'MCK-03: mock_warn_s defaults to 300');
select results_eq($$ select key, grp, min, max from private.teacher_setting_spec() where grp = 'Mock' order by sort $$,
  $$ values ('mock_unlock_first_topics', 'Mock', 0, 50), ('mock_unlock_step_topics', 'Mock', 0, 50),
            ('mock_gap_s', 'Mock', 0, 900), ('mock_warn_s', 'Mock', 0, 1800), ('sat_scale_margin', 'Mock', 0, 100) $$,
  'MCK-03: the five mock settings are in the teacher spec');
select is((select count(*)::int from private.teacher_setting_spec() where key in ('sat_scale_easy', 'sat_scale_hard')), 0,
  'MCK-03: scale tables stay migration-only');
select is((select array_agg(private.mock_unlock_need(k) order by k) from generate_series(1, 4) k), array[3, 6, 9, 12],
  'MCK-09: need(k) = first + (k - 1) * step');
select is(private.mock_unlock_need(0), 3, 'MCK-09: need below 1 counts as form 1');
update public.settings set value = '2'::jsonb where key = 'mock_unlock_first_topics';
update public.settings set value = '5'::jsonb where key = 'mock_unlock_step_topics';
select is((select array_agg(private.mock_unlock_need(k) order by k) from generate_series(1, 3) k), array[2, 7, 12],
  'MCK-09: need follows the edited numbers');
update public.settings set value = '-1'::jsonb where key = 'mock_unlock_step_topics';
select throws_ok($$ select private.mock_unlock_need(2) $$, 'P0001', 'mock_settings_invalid', 'MCK-09: a negative step is mock_settings_invalid');
update public.settings set value = '"x"'::jsonb where key = 'mock_unlock_step_topics';
select throws_ok($$ select private.mock_unlock_need(2) $$, 'P0001', 'mock_settings_invalid', 'MCK-09: a non-number step is mock_settings_invalid');
update public.settings set value = '3'::jsonb where key in ('mock_unlock_first_topics', 'mock_unlock_step_topics');

select tests.authenticate_as('h_h');
select is((select string_agg(f ->> 'need', ',' order by (f ->> 'k')::int) from jsonb_array_elements(public.get_mock_hub(pg_temp.course()) -> 'forms') f),
  '3,6,9', 'MCK-09: the hub shows first + (k - 1) * step');
select is(pg_temp.states(public.get_mock_hub(pg_temp.course())), 'locked,locked,locked', 'MCK-09: 0 passed topics: all locked');
reset role;
select pg_temp.pass('h_h', 3);
select tests.authenticate_as('h_h');
select is(pg_temp.states(public.get_mock_hub(pg_temp.course())), 'available,locked,locked', 'MCK-09: 3 passed: form 1 available');
reset role;
select pg_temp.pass('h_h', 6);
select tests.authenticate_as('h_h');
select is(pg_temp.states(public.get_mock_hub(pg_temp.course())), 'available,available,locked', 'MCK-09: 6 passed: forms 1 and 2 available');
reset role;
select pg_temp.pass('h_h', 3);
delete from public.topic_progress where user_id = pg_temp.uid('h_h') and topic_id not in (
  select id from public.topics where slug in ('h-topic-1', 'h-topic-2', 'h-topic-3'));

-- mock_warn_s feeds warn_s of mock modules (not quiz_warn_s)
update public.settings set value = '111'::jsonb where key = 'quiz_warn_s';
update public.settings set value = '222'::jsonb where key = 'mock_warn_s';
select tests.authenticate_as('h_h');
insert into ctx select 'h1', public.start_mock(pg_temp.course());
select is((select v -> 'warn_s' from ctx where k = 'h1'), '222'::jsonb, 'MCK-03: warn_s of a mock module is mock_warn_s');
reset role;
update public.settings set value = '300'::jsonb where key in ('quiz_warn_s', 'mock_warn_s');

-- ===== 6. A student reads nothing that reveals the route or the module 1 result ================
select tests.authenticate_as('h_h');
select is((select count(*)::int from public.mock_forms), 0, 'MCK-03: a student cannot read mock_forms (question_ids)');
select is((select count(*)::int from public.mock_templates), 0, 'MCK-03: a student cannot read mock_templates');
select is((select count(*)::int from public.attempts where kind = 'mock_module'), 0, 'MCK-03: no mock attempt row (form, meta, score) while the mock runs');
select is((select count(*)::int from public.attempt_questions where attempt_id = pg_temp.aid('h1')), 0,
  'MCK-03: attempt_questions of a mock module are not readable');
select is((select count(*)::int from public.attempt_answers), 0, 'MCK-03: no mock answers while the mock runs');
select throws_ok($$ select public.get_attempt_review(pg_temp.aid('h1')) $$, 'P0001', 'invalid_input',
  'MCK-03: get_attempt_review refuses a mock module in progress');
select public.save_answer(pg_temp.aid('h1'), pg_temp.q(1), 'B', 1, false, null, 1);
select public.save_answer(pg_temp.aid('h1'), pg_temp.q(2), 'B', 1, false, null, 1);
select public.save_answer(pg_temp.aid('h1'), pg_temp.q(3), 'B', 1, false, null, 1);
select is(public.submit_attempt(pg_temp.aid('h1')) ->> 'stage', 'gap', 'MCK-03: module 1 submitted');
select is((select count(*)::int from public.attempts where kind = 'mock_module'), 0, 'MCK-03: no mock attempt row in the gap');
select is((select count(*)::int from public.attempt_questions where attempt_id = pg_temp.aid('h1')), 0,
  'MCK-03: no attempt_questions in the gap');
select is((select count(*)::int from public.attempt_answers), 0, 'MCK-03: no module 1 answers in the gap');
select throws_ok($$ select public.get_attempt_review(pg_temp.aid('h1')) $$, 'P0001', 'invalid_input',
  'MCK-03: get_attempt_review refuses a submitted module 1 before the mock ends');
select is((select count(*)::int from public.mock_results), 0, 'MCK-03: no result row before the mock ends');
reset role;

-- ===== 1a. The run uses its blueprint snapshot, not the live template ===========================
select tests.authenticate_as('h_a');
insert into ctx select 'a1', public.start_mock(pg_temp.course());
reset role;
select is((select meta -> 'blueprint' from public.attempts where id = pg_temp.aid('a1')), (select blueprint from t_orig),
  'MCK-03: start_mock snapshots the template blueprint into the module 1 attempt');
update public.mock_templates
set blueprint = jsonb_set(jsonb_set(jsonb_set(jsonb_set(blueprint, '{routing,threshold_correct_m1}', '99'),
  '{modules,M1,time_s}', '999'), '{modules,M2E,time_s}', '999'), '{modules,M2H,time_s}', '999')
where id = '54000000-0000-0000-0000-000000000500';
select tests.authenticate_as('h_a');
select public.save_answer(pg_temp.aid('a1'), pg_temp.q(1), 'B', 1, false, null, 1);
select public.save_answer(pg_temp.aid('a1'), pg_temp.q(2), 'B', 1, false, null, 1);
select public.save_answer(pg_temp.aid('a1'), pg_temp.q(3), 'B', 1, false, null, 1);
select is(public.submit_attempt(pg_temp.aid('a1')) ->> 'stage', 'gap', 'MCK-03: module 1 closes after the live blueprint changed');
insert into ctx select 'a2', public.start_mock_module2(pg_temp.gid('a1'));
reset role;
select is((select meta ->> 'route' from public.attempts where id = pg_temp.aid('a1')), 'M2H', 'MCK-03: routing uses the snapshot threshold (3), not the live one (99)');
select is((select time_limit_s from public.attempts where id = pg_temp.aid('a2')), 600, 'MCK-03: module 2 time limit comes from the snapshot');
update public.mock_templates set blueprint = '{}'::jsonb where id = '54000000-0000-0000-0000-000000000500';
select tests.authenticate_as('h_a');
select public.save_answer(pg_temp.aid('a2'), pg_temp.q(9), 'B', 1, false, null, 1);
select is(public.submit_attempt(pg_temp.aid('a2')) ->> 'stage', 'finished', 'MCK-03: module 2 finishes with the live blueprint destroyed');
reset role;
select is((select route || ' ' || raw_m1 || '/' || raw_m2 from public.mock_results where group_id = pg_temp.gid('a1')), 'M2H 3/1',
  'MCK-03: the snapshot run stored its result');
update public.mock_templates set blueprint = (select blueprint from t_orig) where id = '54000000-0000-0000-0000-000000000500';

-- ===== 1c. A scale broken mid-run still lets the run finish, without a range ======================
select tests.authenticate_as('h_b');
insert into ctx select 'b1', public.start_mock(pg_temp.course());
select public.save_answer(pg_temp.aid('b1'), pg_temp.q(1), 'B', 1, false, null, 1);
select public.save_answer(pg_temp.aid('b1'), pg_temp.q(2), 'B', 1, false, null, 1);
select public.save_answer(pg_temp.aid('b1'), pg_temp.q(3), 'B', 1, false, null, 1);
select public.submit_attempt(pg_temp.aid('b1'));
insert into ctx select 'b2', public.start_mock_module2(pg_temp.gid('b1'));
reset role;
update public.settings set value = '"x"'::jsonb where key = 'sat_scale_hard';
select tests.authenticate_as('h_b');
select public.save_answer(pg_temp.aid('b2'), pg_temp.q(9), 'B', 1, false, null, 1);
select is(public.submit_attempt(pg_temp.aid('b2')) ->> 'stage', 'finished', 'MCK-03: a broken scale at finish time still finishes the mock');
select is(public.get_mock_session(pg_temp.gid('b1')) ->> 'stage', 'finished', 'MCK-03: the session reads finished (no raise)');
reset role;
select results_eq($$ select route, raw_m1, raw_m2, est_low, est_high from public.mock_results where group_id = pg_temp.gid('b1') $$,
  $$ values ('M2H', 3, 1, null::int, null::int) $$, 'MCK-03: the result has scores and a null range');
select is((select score_raw || '/' || score_total from public.attempts where id = pg_temp.aid('b2')), '1/4', 'MCK-03: module 2 is scored');
select is((select sum(attempts)::int from public.skill_mastery where user_id = pg_temp.uid('h_b')), 8, 'MCK-03: mastery is applied');
update public.settings s set value = t.value from t_scale t where s.key = t.key;

-- ===== 1b / 2. start_mock refuses bad data before inserting anything ===============================
update public.settings set value = '"x"'::jsonb where key = 'sat_scale_hard';
select tests.authenticate_as('h_c');
select throws_ok($$ select public.start_mock(pg_temp.course()) $$, 'P0001', 'internal', 'MCK-03: start with a broken scale is internal');
reset role;
update public.settings s set value = t.value from t_scale t where s.key = t.key;
update public.settings set value = '-1'::jsonb where key = 'sat_scale_margin';
select tests.authenticate_as('h_c');
select throws_ok($$ select public.start_mock(pg_temp.course()) $$, 'P0001', 'internal', 'MCK-03: start with an invalid margin is internal');
reset role;
update public.settings s set value = t.value from t_scale t where s.key = t.key;
update public.mock_templates set blueprint = jsonb_set(blueprint, '{modules,M2E,time_s}', '500') where id = '54000000-0000-0000-0000-000000000500';
select tests.authenticate_as('h_c');
select throws_ok($$ select public.start_mock(pg_temp.course()) $$, 'P0001', 'internal', 'MCK-03: M2E and M2H with different times are internal at start');
reset role;
update public.mock_templates set blueprint = (select blueprint from t_orig) where id = '54000000-0000-0000-0000-000000000500';
select is((select count(*)::int from public.attempts where user_id = pg_temp.uid('h_c')), 0, 'MCK-03: a refused start leaves no attempt');
select is((select count(*)::int from public.question_exposure where user_id = pg_temp.uid('h_c')), 0, 'MCK-03: a refused start leaves no exposure');
select tests.authenticate_as('h_d');
select throws_ok($$ select public.start_mock(pg_temp.course()) $$, 'P0001', 'internal', 'MCK-03: a form longer than the scale allows is internal');
select tests.authenticate_as('h_i');
select throws_ok($$ select public.start_mock(pg_temp.course()) $$, 'P0001', 'internal', 'MCK-03: M2E and M2H with different lengths are internal');
reset role;
select is((select count(*)::int from public.attempts where user_id in (pg_temp.uid('h_d'), pg_temp.uid('h_i'))), 0, 'MCK-03: nothing inserted for either refused form');
select tests.authenticate_as('h_c');
insert into ctx select 'c1', public.start_mock(pg_temp.course());
select is((select v ->> 'stage' from ctx where k = 'c1'), 'module', 'MCK-03: the same student starts normally once the data is valid');
reset role;

-- ===== 2. Equal modules in the blueprint validator ================================================
create function pg_temp.bp() returns jsonb language sql stable as $$ select value from public.settings where key = 'mock_blueprint_sat' $$;
select is(private.mock_blueprint_ok(pg_temp.bp()), true, 'MCK-03: the seeded blueprint is still valid');
select is(private.mock_blueprint_ok(jsonb_set(pg_temp.bp(), '{modules,M2E,time_s}', '2000')), false, 'MCK-03: different M2E / M2H time_s is rejected');
select is(private.mock_blueprint_ok(jsonb_set(jsonb_set(pg_temp.bp(), '{modules,M2E,count}', '21'), '{modules,M2E,difficulty,E}', '9')), false,
  'MCK-03: different M2E / M2H counts are rejected');

-- ===== 3. Resume after the enrolment expired ====================================================
select tests.authenticate_as('h_f');
insert into ctx select 'f1', public.start_mock(pg_temp.course());
reset role;
update public.enrollments set expires_at = now() - interval '1 day' where user_id = pg_temp.uid('h_f');
select tests.authenticate_as('h_f');
select is(public.get_mock_hub(pg_temp.course()) ->> 'active_group', pg_temp.gid('f1')::text, 'MCK-03: an expired student still gets the hub, with the active group');
select is(pg_temp.states(public.get_mock_hub(pg_temp.course())), 'in_progress,locked,locked', 'MCK-03: the running form shows in progress after expiry');
reset role;
update public.enrollments set status = 'suspended', expires_at = now() + interval '30 days' where user_id = pg_temp.uid('h_f');
select tests.authenticate_as('h_f');
select is(public.get_mock_hub(pg_temp.course()) ->> 'active_group', pg_temp.gid('f1')::text, 'MCK-03: a suspended student with a running mock still gets the hub');
select is(public.save_answer(pg_temp.aid('f1'), pg_temp.q(1), 'B', 1, false, null, 1), '{"ok": true}'::jsonb, 'MCK-03: the running mock still saves');
reset role;
update public.enrollments set status = 'expired' where user_id = pg_temp.uid('h_g');
select tests.authenticate_as('h_g');
select throws_ok($$ select public.get_mock_hub(pg_temp.course()) $$, 'P0001', 'access_expired', 'MCK-03: no running mock and a non-active enrolment is access_expired');
select tests.authenticate_as('h_n');
select throws_ok($$ select public.get_mock_hub(pg_temp.course()) $$, 'P0001', 'not_enrolled', 'MCK-03: no enrolment is not_enrolled');
reset role;

select * from finish();
rollback;
