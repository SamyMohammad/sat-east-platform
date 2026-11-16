-- MCK-01 Task 1: mock settings, scale tables, estimate, mock_runs, unlock, hub. From supabase/templates/test.sql.
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

insert into public.courses (code, title, slug) values ('SAT', 'Mock SAT', 'mock-sat')
on conflict (code) do nothing;

create function pg_temp.sc(p_key text) returns jsonb language sql stable as
  $$ select value from public.settings where key = p_key $$;

-- Settings and teacher spec ----------------------------------------------------------------------
select results_eq($$ select key, value from public.settings
    where key in ('mock_unlock_first_topics', 'mock_unlock_step_topics', 'mock_gap_s', 'mock_warn_s', 'mock_score_margin')
    order by key $$,
  $$ values ('mock_gap_s', '120'::jsonb), ('mock_score_margin', '30'::jsonb), ('mock_unlock_first_topics', '3'::jsonb),
            ('mock_unlock_step_topics', '3'::jsonb), ('mock_warn_s', '300'::jsonb) $$,
  'MCK-01: mock settings exist with their defaults');
select results_eq($$ select key, grp, min, max from private.teacher_setting_spec() where grp = 'Mock' order by sort $$,
  $$ values ('mock_unlock_first_topics', 'Mock', 0, 50), ('mock_unlock_step_topics', 'Mock', 0, 50),
            ('mock_gap_s', 'Mock', 0, 900), ('mock_warn_s', 'Mock', 0, 1800), ('mock_score_margin', 'Mock', 0, 100) $$,
  'MCK-01: mock settings are in the teacher spec with their ranges');
select is((select count(*)::int from private.teacher_setting_spec() where key like 'sat\_scale%'), 0,
  'MCK-01: scale tables are not teacher-editable');

-- Scale tables ---------------------------------------------------------------------------------------
select is(jsonb_array_length(pg_temp.sc('sat_scale_hard')), 45, 'MCK-01: hard scale has 45 entries');
select is(jsonb_array_length(pg_temp.sc('sat_scale_easy')), 45, 'MCK-01: easy scale has 45 entries');
select ok(private.mock_scale_ok(pg_temp.sc('sat_scale_hard')), 'MCK-01: seeded hard scale is valid');
select ok(private.mock_scale_ok(pg_temp.sc('sat_scale_easy')), 'MCK-01: seeded easy scale is valid');
select is(pg_temp.sc('sat_scale_hard') -> 44, '800'::jsonb, 'MCK-01: hard scale tops out at 800');
select is(pg_temp.sc('sat_scale_easy') -> 44, '620'::jsonb, 'MCK-01: easy scale tops out at 620');
select is(pg_temp.sc('sat_scale_hard') -> 0, '200'::jsonb, 'MCK-01: hard scale starts at 200');
select is(pg_temp.sc('sat_scale_easy') -> 0, '200'::jsonb, 'MCK-01: easy scale starts at 200');
select is(private.mock_scale_ok(pg_temp.sc('sat_scale_hard') - 44), false, 'MCK-01: 44 entries are rejected');
select is(private.mock_scale_ok(pg_temp.sc('sat_scale_hard') || '800'::jsonb), false, 'MCK-01: 46 entries are rejected');
select is(private.mock_scale_ok(jsonb_set(pg_temp.sc('sat_scale_hard'), '{0}', '190')), false, 'MCK-01: a value of 190 is rejected');
select is(private.mock_scale_ok(jsonb_set(pg_temp.sc('sat_scale_hard'), '{44}', '805')), false, 'MCK-01: a value of 805 is rejected');
select is(private.mock_scale_ok(jsonb_set(pg_temp.sc('sat_scale_hard'), '{1}', '215')), false, 'MCK-01: a non-multiple of 10 is rejected');
select is(private.mock_scale_ok(jsonb_set(pg_temp.sc('sat_scale_hard'), '{10}', '300')), false, 'MCK-01: a decreasing pair is rejected');
select is(private.mock_scale_ok(jsonb_set(pg_temp.sc('sat_scale_hard'), '{5}', '"270"')), false, 'MCK-01: a string entry is rejected');
select is(private.mock_scale_ok('{}'::jsonb), false, 'MCK-01: an object is rejected');
select is(private.mock_scale_ok('null'::jsonb), false, 'MCK-01: json null is rejected');
select is(private.mock_scale_ok(null), false, 'MCK-01: sql null is rejected');

-- Estimate -------------------------------------------------------------------------------------------
select results_eq($$ select * from private.mock_estimate('M2H', 44) $$, $$ values (770, 800) $$, 'MCK-01: M2H 44 is 770-800');
select results_eq($$ select * from private.mock_estimate('M2E', 44) $$, $$ values (590, 650) $$, 'MCK-01: M2E 44 is 590-650');
select results_eq($$ select * from private.mock_estimate('M2H', 0) $$, $$ values (200, 230) $$, 'MCK-01: M2H 0 clamps low to 200');
select results_eq($$ select * from private.mock_estimate('M2E', 22) $$, $$ values (380, 440) $$,
  'MCK-01: M2E 22 is the easy-table value 410 plus or minus the margin');
select throws_ok($$ select * from private.mock_estimate('M3', 10) $$, 'P0001', 'internal', 'MCK-01: bad route is internal');
select throws_ok($$ select * from private.mock_estimate(null, 10) $$, 'P0001', 'internal', 'MCK-01: null route is internal');
select throws_ok($$ select * from private.mock_estimate('M2H', 45) $$, 'P0001', 'internal', 'MCK-01: raw 45 is internal');
select throws_ok($$ select * from private.mock_estimate('M2H', -1) $$, 'P0001', 'internal', 'MCK-01: raw -1 is internal');
select throws_ok($$ select * from private.mock_estimate('M2H', null) $$, 'P0001', 'internal', 'MCK-01: null raw is internal');
update public.settings set value = (value - 44) where key = 'sat_scale_hard';
select throws_ok($$ select * from private.mock_estimate('M2H', 10) $$, 'P0001', 'internal', 'MCK-01: an invalid scale table is internal');
select lives_ok($$ select * from private.mock_estimate('M2E', 10) $$, 'MCK-01: the other route still works');
update public.settings set value = '"x"'::jsonb where key = 'sat_scale_hard';
select throws_ok($$ select * from private.mock_estimate('M2H', 10) $$, 'P0001', 'internal', 'MCK-01: a non-array scale is internal');
update public.settings set value = '10'::jsonb where key = 'mock_score_margin';
select results_eq($$ select * from private.mock_estimate('M2E', 44) $$, $$ values (610, 630) $$, 'MCK-01: the margin is read from settings');

-- mock_runs ----------------------------------------------------------------------------------------
select ok((select relrowsecurity from pg_class where oid = 'private.mock_runs'::regclass), 'MCK-01: mock_runs has RLS enabled');
select is((select count(*)::int from pg_policies where schemaname = 'private' and tablename = 'mock_runs'), 0,
  'MCK-01: mock_runs has no policy');
select ok(not has_table_privilege('authenticated', 'private.mock_runs', 'select')
  and not has_table_privilege('anon', 'private.mock_runs', 'select')
  and not has_table_privilege('authenticated', 'private.mock_runs', 'insert'),
  'MCK-01: API roles have no grants on mock_runs');
select ok(exists (select 1 from pg_indexes where schemaname = 'private' and tablename = 'mock_runs'
  and indexdef like '%(user_id)%' and indexdef like '%finished_at IS NULL%'), 'MCK-01: partial index on unfinished runs');
select ok(not has_function_privilege('authenticated', 'private.mock_scale_ok(jsonb)', 'execute')
  and not has_function_privilege('authenticated', 'private.mock_estimate(text,integer)', 'execute')
  and not has_function_privilege('authenticated', 'private.mock_form_unlock(uuid,uuid)', 'execute')
  and not has_function_privilege('anon', 'private.mock_form_unlock(uuid,uuid)', 'execute'),
  'MCK-01: private helpers are not executable by API roles');

-- Fixture --------------------------------------------------------------------------------------------
select tests.create_supabase_user('mk1_student');
select tests.create_supabase_user('mk1_other');
select tests.create_supabase_user('mk1_noenrol');
create temp table t_ids as select
  (select id from public.courses where code = 'SAT') as course_id,
  tests.get_supabase_uid('mk1_student') as uid,
  tests.get_supabase_uid('mk1_other') as other_uid,
  private.mock_template_for((select id from public.courses where code = 'SAT')) as tpl;
grant select on t_ids to authenticated;

insert into public.topics (course_id, title, slug, sort, is_published)
select (select course_id from t_ids), 'MK1 topic ' || g, 'mk1-topic-' || g, g, true from generate_series(1, 8) g;

insert into public.enrollments (user_id, course_id, status, expires_at, mock_set_no)
select uid, course_id, 'active', now() + interval '30 days', 1 from t_ids;
insert into public.enrollments (user_id, course_id, status, expires_at, mock_set_no)
select other_uid, course_id, 'active', now() + interval '30 days', 2 from t_ids;

-- set 1: forms 1 and 3 published, 2 draft, 4 has only two published modules. set 2: form 1 published.
insert into public.mock_forms (template_id, set_no, form_no, module, question_ids, status, published_at)
select t.tpl, f.set_no, f.form_no, m.module, '{}', f.status, case when f.status = 'published' then now() end
from t_ids t,
     (values (1, 1, 'published'), (1, 2, 'draft'), (1, 3, 'published'), (2, 1, 'published')) f(set_no, form_no, status),
     (values ('M1'), ('M2E'), ('M2H')) m(module);
insert into public.mock_forms (template_id, set_no, form_no, module, question_ids, status, published_at)
select t.tpl, 1, 4, m.module, '{}', case when m.module = 'M2H' then 'draft' else 'published' end, now()
from t_ids t, (values ('M1'), ('M2E'), ('M2H')) m(module);

create function pg_temp.pass(p_n int) returns void language sql as $$
  delete from public.topic_progress where user_id = (select uid from t_ids);
  insert into public.topic_progress (user_id, topic_id, quiz_passed_at)
  select (select uid from t_ids), id, now()
  from (select id from public.topics where slug like 'mk1-topic-%' order by sort limit p_n) x;
$$;

-- mock_form_unlock -----------------------------------------------------------------------------------
select results_eq($$ select form_no, k, topics_needed from private.mock_form_unlock((select uid from t_ids), (select course_id from t_ids)) order by form_no $$,
  $$ values (1, 1, 3), (3, 2, 6) $$, 'MCK-01: unlock lists published forms of the set with rank and topics needed');
select results_eq($$ select form_no, k, topics_needed from private.mock_form_unlock((select other_uid from t_ids), (select course_id from t_ids)) $$,
  $$ values (1, 1, 3) $$, 'MCK-01: unlock only sees the student''s own set');
select is((select count(*)::int from private.mock_form_unlock((select uid from t_ids), (select course_id from t_ids)) where form_no in (2, 4)), 0,
  'MCK-01: drafts and partly published forms are not listed');
update public.settings set value = '2'::jsonb where key = 'mock_unlock_first_topics';
update public.settings set value = '5'::jsonb where key = 'mock_unlock_step_topics';
select results_eq($$ select topics_needed from private.mock_form_unlock((select uid from t_ids), (select course_id from t_ids)) order by form_no $$,
  $$ values (2), (7) $$, 'MCK-01: unlock follows first + (k-1) * step from settings');
update public.settings set value = '3'::jsonb where key in ('mock_unlock_first_topics', 'mock_unlock_step_topics');
select is((select count(*)::int from private.mock_form_unlock((select uid from t_ids), gen_random_uuid())), 0,
  'MCK-01: no enrolment for the course lists nothing');

-- get_mock_hub -----------------------------------------------------------------------------------------
create function pg_temp.hub() returns jsonb language sql as $$ select public.get_mock_hub((select course_id from t_ids)) $$;
create function pg_temp.states() returns text language sql as $$
  select string_agg((f ->> 'form_no') || ':' || (f ->> 'state') || ':' || (f ->> 'topics_needed'), ',' order by (f ->> 'form_no')::int)
  from jsonb_array_elements(pg_temp.hub() -> 'forms') f $$;

grant execute on function pg_temp.hub() to authenticated;
grant execute on function pg_temp.states() to authenticated;
select pg_temp.pass(0);
select tests.authenticate_as('mk1_student');
select is(pg_temp.hub() -> 'set_no', '1'::jsonb, 'MCK-01: hub reports the enrolment set');
select is(pg_temp.hub() -> 'topics_passed', '0'::jsonb, 'MCK-01: hub reports 0 passed topics');
select is(pg_temp.states(), '1:locked:3,3:locked:6', 'MCK-01: 0 passed -> both forms locked');
select is(jsonb_array_length(pg_temp.hub() -> 'forms'), 2, 'MCK-01: only published forms of the set appear');
select tests.clear_authentication();
reset role;
select pg_temp.pass(3);
select tests.authenticate_as('mk1_student');
select is(pg_temp.states(), '1:available:3,3:locked:6', 'MCK-01: 3 passed -> form 1 available');
select is(pg_temp.hub() -> 'topics_passed', '3'::jsonb, 'MCK-01: hub reports 3 passed topics');
select tests.clear_authentication();
reset role;
select pg_temp.pass(6);
select tests.authenticate_as('mk1_student');
select is(pg_temp.states(), '1:available:3,3:locked:6', 'MCK-01: 6 passed -> only the lowest form is available');
select is(pg_temp.hub() #> '{forms,0}', '{"form_no":1,"state":"available","topics_needed":3,"group_id":null,"est_low":null,"est_high":null}'::jsonb,
  'MCK-01: a not-started form has null group and estimate');

-- in_progress and finished (rows made as postgres: nothing creates runs yet).
select tests.clear_authentication();
reset role;
insert into private.mock_runs (group_id, user_id, course_id, template_id, set_no, form_no)
select '51000000-0000-0000-0000-000000000001', uid, course_id, tpl, 1, 1 from t_ids;
select tests.authenticate_as('mk1_student');
select is(pg_temp.states(), '1:in_progress:3,3:locked:6', 'MCK-01: unfinished run -> in_progress, nothing else available');
select is(pg_temp.hub() #>> '{forms,0,group_id}', '51000000-0000-0000-0000-000000000001', 'MCK-01: in_progress carries the group id');
select is(pg_temp.hub() #> '{forms,0,est_low}', 'null'::jsonb, 'MCK-01: in_progress has no estimate');
select tests.clear_authentication();
reset role;
update private.mock_runs set finished_at = now() where group_id = '51000000-0000-0000-0000-000000000001';
insert into public.mock_results (user_id, template_id, group_id, route, raw_m1, raw_m2, est_low, est_high)
select uid, tpl, '51000000-0000-0000-0000-000000000001', 'M2H', 15, 12, 640, 700 from t_ids;
select tests.authenticate_as('mk1_student');
select is(pg_temp.states(), '1:finished:3,3:available:6', 'MCK-01: finished form, next form available when unlocked');
select is(pg_temp.hub() #> '{forms,0}', '{"form_no":1,"state":"finished","topics_needed":3,"group_id":"51000000-0000-0000-0000-000000000001","est_low":640,"est_high":700}'::jsonb,
  'MCK-01: finished form carries group id and estimate');
select tests.clear_authentication();
reset role;
select pg_temp.pass(3);
select tests.authenticate_as('mk1_student');
select is(pg_temp.states(), '1:finished:3,3:locked:6', 'MCK-01: next form stays locked below its threshold');
-- a run of another set for the same form number does not count
select tests.clear_authentication();
reset role;
update private.mock_runs set set_no = 2 where group_id = '51000000-0000-0000-0000-000000000001';
select tests.authenticate_as('mk1_student');
select is(pg_temp.states(), '1:available:3,3:locked:6', 'MCK-01: runs of another set are ignored');
select tests.clear_authentication();
reset role;
update private.mock_runs set set_no = 1 where group_id = '51000000-0000-0000-0000-000000000001';

-- a changed set shows the new set
update public.enrollments set mock_set_no = 2 where user_id = (select uid from t_ids);
select tests.authenticate_as('mk1_student');
select is(pg_temp.hub() -> 'set_no', '2'::jsonb, 'MCK-01: hub follows a changed set');
select is(jsonb_array_length(pg_temp.hub() -> 'forms'), 1, 'MCK-01: new set lists its own forms');
select tests.clear_authentication();
reset role;
update public.enrollments set mock_set_no = 1 where user_id = (select uid from t_ids);

-- errors
select tests.authenticate_as('mk1_noenrol');
select throws_ok($$ select public.get_mock_hub((select course_id from t_ids)) $$, 'P0001', 'not_enrolled', 'MCK-01: no enrolment is not_enrolled');
select tests.authenticate_as('mk1_student');
select throws_ok($$ select public.get_mock_hub(null) $$, 'P0001', 'invalid_input', 'MCK-01: null course is invalid_input');
select throws_ok($$ select public.get_mock_hub(gen_random_uuid()) $$, 'P0001', 'not_enrolled', 'MCK-01: unknown course is not_enrolled');
select tests.clear_authentication();
reset role;
update public.enrollments set expires_at = now() - interval '1 day' where user_id = (select uid from t_ids);
select tests.authenticate_as('mk1_student');
select throws_ok($$ select public.get_mock_hub((select course_id from t_ids)) $$, 'P0001', 'access_expired', 'MCK-01: expired enrolment is access_expired');
select tests.clear_authentication();
reset role;
update public.enrollments set expires_at = now() + interval '30 days' where user_id = (select uid from t_ids);

-- permissions
set local role anon;
select throws_ok($$ select public.get_mock_hub(null) $$, '42501', null, 'MCK-01: anon cannot execute get_mock_hub');
reset role;
set local role authenticated;
select throws_ok($$ select public.get_mock_hub(null) $$, 'P0001', 'not_authenticated', 'MCK-01: no uid is not_authenticated');
select throws_ok($$ select count(*) from private.mock_runs $$, '42501', null, 'MCK-01: authenticated cannot read private.mock_runs');
reset role;

select * from finish();
rollback;
