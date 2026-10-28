-- PRC-03: submitted quiz review and topic-pass key visibility. From templates/test.sql.
begin;
create extension if not exists pgtap with schema extensions;
select plan(40);

select tests.create_supabase_user('attempt_owner');
select tests.create_supabase_user('attempt_other');
select tests.create_supabase_user('attempt_teacher');
update public.profiles set role = 'teacher' where id = tests.get_supabase_uid('attempt_teacher');
update public.settings set value = '75' where key = 'pass_mark';
insert into public.courses (id, code, title, slug, is_published) values
  ('00000000-0000-0000-0000-0000000022c1', 'SAT', 'Attempt Review Course', 'attempt-review-course', true);
insert into public.topics (id, course_id, title, slug, sort, is_published) values
  ('00000000-0000-0000-0000-0000000022d1', '00000000-0000-0000-0000-0000000022c1', 'T1', 'attempt-review-t1', 1, true);
insert into public.subtopics (id, topic_id, title) values
  ('00000000-0000-0000-0000-0000000022b1', '00000000-0000-0000-0000-0000000022d1', 'S1');
insert into public.skills (id, code, name, domain) values
  ('00000000-0000-0000-0000-0000000022a1', 'AR-A', 'Algebra', 'Algebra'),
  ('00000000-0000-0000-0000-0000000022a2', 'AR-F', 'Fractions', 'Algebra');
insert into public.questions (id, topic_id, subtopic_id, type, difficulty, stem_md, pool, status) values
  ('00000000-0000-0000-0000-0000000022e1', '00000000-0000-0000-0000-0000000022d1',
   '00000000-0000-0000-0000-0000000022b1', 'mcq', 'E', 'MCQ stem', 'quiz', 'published'),
  ('00000000-0000-0000-0000-0000000022e2', '00000000-0000-0000-0000-0000000022d1',
   '00000000-0000-0000-0000-0000000022b1', 'spr', 'M', 'SPR stem', 'quiz', 'published'),
  ('00000000-0000-0000-0000-0000000022e3', '00000000-0000-0000-0000-0000000022d1',
   '00000000-0000-0000-0000-0000000022b1', 'mcq', 'E', 'Blank stem', 'quiz', 'published');
insert into public.question_choices (question_id, label, body_md)
select q.id, c.label, 'Choice ' || c.label from public.questions q
cross join (values ('D'), ('B'), ('A'), ('C')) c(label)
where q.topic_id = '00000000-0000-0000-0000-0000000022d1' and q.type = 'mcq';
insert into public.question_skills (question_id, skill_id) values
  ('00000000-0000-0000-0000-0000000022e1', '00000000-0000-0000-0000-0000000022a1'),
  ('00000000-0000-0000-0000-0000000022e2', '00000000-0000-0000-0000-0000000022a2'),
  ('00000000-0000-0000-0000-0000000022e2', '00000000-0000-0000-0000-0000000022a1');
insert into private.question_keys (question_id, correct_answer, explanation_md) values
  ('00000000-0000-0000-0000-0000000022e1', '{"choice":"B"}', 'MCQ explanation'),
  ('00000000-0000-0000-0000-0000000022e2', '{"accepted":["1/2","0.5"],"tolerance":0}', 'SPR explanation'),
  ('00000000-0000-0000-0000-0000000022e3', '{"choice":"C"}', 'Blank explanation');
insert into public.enrollments (user_id, course_id, status, starts_at, expires_at)
select tests.get_supabase_uid(u), '00000000-0000-0000-0000-0000000022c1', 'active', now() - interval '1 day', now() + interval '30 days'
from unnest(array['attempt_owner', 'attempt_other']) u;
insert into public.attempts (id, user_id, kind, course_id, topic_id, status, started_at, time_limit_s)
select f.id::uuid, tests.get_supabase_uid(f.student), f.kind::public.attempt_kind,
  '00000000-0000-0000-0000-0000000022c1', '00000000-0000-0000-0000-0000000022d1',
  f.status::public.attempt_status, now() - interval '3 hours', 600
from (values
  ('00000000-0000-0000-0000-000000002201', 'attempt_owner', 'quiz', 'in_progress'),
  ('00000000-0000-0000-0000-000000002202', 'attempt_other', 'quiz', 'in_progress'),
  ('00000000-0000-0000-0000-000000002203', 'attempt_owner', 'quiz', 'in_progress'),
  ('00000000-0000-0000-0000-000000002204', 'attempt_owner', 'practice', 'submitted'),
  ('00000000-0000-0000-0000-000000002205', 'attempt_owner', 'quiz', 'expired'),
  ('00000000-0000-0000-0000-000000002206', 'attempt_owner', 'quiz', 'abandoned'),
  ('00000000-0000-0000-0000-000000002207', 'attempt_owner', 'quiz', 'in_progress')
) f(id, student, kind, status);
-- Position deliberately differs from UUID order.
insert into public.attempt_questions (attempt_id, question_id, position)
select a.id, q.id::uuid, q.pos from public.attempts a
cross join (values
  ('00000000-0000-0000-0000-0000000022e3', 1),
  ('00000000-0000-0000-0000-0000000022e1', 2),
  ('00000000-0000-0000-0000-0000000022e2', 3)
) q(id, pos)
where a.id in ('00000000-0000-0000-0000-000000002201', '00000000-0000-0000-0000-000000002202', '00000000-0000-0000-0000-000000002207');
insert into public.attempt_answers (attempt_id, question_id, answer, time_ms, answered_at) values
  ('00000000-0000-0000-0000-000000002201', '00000000-0000-0000-0000-0000000022e1', '{"value":"A"}', 1234, now() - interval '2 hours'),
  ('00000000-0000-0000-0000-000000002201', '00000000-0000-0000-0000-0000000022e2', '{"value":".5"}', 2345, now() - interval '2 hours');
insert into public.attempt_answers (attempt_id, question_id, answer, time_ms, answered_at)
select aq.attempt_id, aq.question_id,
  jsonb_build_object('value', case aq.question_id
    when '00000000-0000-0000-0000-0000000022e1'::uuid then 'B'
    when '00000000-0000-0000-0000-0000000022e2'::uuid then '.5' else 'C' end), 1000, now()
from public.attempt_questions aq where aq.attempt_id in ('00000000-0000-0000-0000-000000002202', '00000000-0000-0000-0000-000000002207');
select private.finish_quiz('00000000-0000-0000-0000-000000002201', now() - interval '2 hours');
select private.finish_quiz('00000000-0000-0000-0000-000000002202', now() - interval '1 hour');
-- Reports retain the pass mark used at grading, even after a settings change.
update public.settings set value = '99' where key = 'pass_mark';

create temp table attempt_review_ctx (k text primary key, v jsonb);
grant select, insert on attempt_review_ctx to authenticated;
create function pg_temp.question(p_k text, p_id uuid) returns jsonb language sql as $$
  select q from attempt_review_ctx, jsonb_array_elements(v -> 'questions') q where k = p_k and (q ->> 'id')::uuid = p_id
$$;
grant execute on function pg_temp.question(text, uuid) to authenticated;

select is(has_function_privilege('authenticated', 'public.get_attempt_review(uuid)', 'execute'), true,
  'SEC: get_attempt_review granted to authenticated');
select is(has_function_privilege('anon', 'public.get_attempt_review(uuid)', 'execute'), false,
  'SEC: get_attempt_review not granted to anon');
select tests.clear_authentication();
set local role anon;
select throws_ok($$ select public.get_attempt_review(null) $$, '42501', null, 'SEC: anon cannot execute get_attempt_review');
reset role;
set local role authenticated;
select throws_ok($$ select public.get_attempt_review(null) $$, 'P0001', 'not_authenticated', 'PRC-03: anonymous session gets not_authenticated');
reset role;
select tests.authenticate_as('attempt_owner');
select throws_ok($$ select public.get_attempt_review(null) $$, 'P0001', 'invalid_input', 'PRC-03: null attempt is invalid');
select throws_ok($$ select public.get_attempt_review('00000000-0000-0000-0000-000000002299') $$,
  'P0001', 'invalid_input', 'PRC-03: unknown attempt is invalid');
select throws_ok($$ select public.get_attempt_review('00000000-0000-0000-0000-000000002203') $$,
  'P0001', 'attempt_not_submitted', 'PRC-03: in_progress quiz is not reviewable');
select throws_ok($$ select public.get_attempt_review('00000000-0000-0000-0000-000000002204') $$,
  'P0001', 'invalid_input', 'PRC-03: non-quiz attempt is invalid');
select throws_ok($$ select public.get_attempt_review('00000000-0000-0000-0000-000000002205') $$,
  'P0001', 'attempt_not_submitted', 'PRC-03: an ungraded expired row is not reviewable');
select throws_ok($$ select public.get_attempt_review('00000000-0000-0000-0000-000000002206') $$,
  'P0001', 'attempt_not_submitted', 'PRC-03: abandoned quiz is not reviewable');
select tests.authenticate_as('attempt_other');
select throws_ok($$ select public.get_attempt_review('00000000-0000-0000-0000-000000002201') $$,
  'P0001', 'forbidden', 'PRC-03: another student cannot review the owner attempt');
select throws_ok($$ select public.get_attempt_review('00000000-0000-0000-0000-000000002203') $$,
  'P0001', 'forbidden', 'PRC-03: ownership is checked before submission status');
insert into attempt_review_ctx values ('passed_other', public.get_attempt_review('00000000-0000-0000-0000-000000002202'));
select tests.authenticate_as('attempt_owner');
insert into attempt_review_ctx values ('failed', public.get_attempt_review('00000000-0000-0000-0000-000000002201'));
select is((select v #> '{summary,keys_visible}' from attempt_review_ctx where k = 'failed'), 'false'::jsonb,
  'PRC-03: another student passing does not expose keys to the failed owner');
select ok(not exists (select 1 from attempt_review_ctx, jsonb_array_elements(v -> 'questions') q
  where k = 'failed' and (q ? 'key' or q ? 'explanation_md')), 'PRC-03: failed review omits key and explanation fields entirely');
select is((select count(*)::int from attempt_review_ctx, jsonb_array_elements(v -> 'questions') q
  where k = 'failed' and q ?& array['is_correct', 'my_answer', 'skills']), 3,
  'PRC-03: failed review includes correctness, own answers and skills');
select is(pg_temp.question('failed', '00000000-0000-0000-0000-0000000022e1') ->> 'my_answer', 'A', 'PRC-03: MCQ keeps the saved answer');
select is(pg_temp.question('failed', '00000000-0000-0000-0000-0000000022e1') -> 'is_correct', 'false'::jsonb,
  'PRC-03: incorrect MCQ is marked wrong');
select is(pg_temp.question('failed', '00000000-0000-0000-0000-0000000022e2') ->> 'my_answer', '.5',
  'PRC-03: SPR keeps the saved answer text');
select is(pg_temp.question('failed', '00000000-0000-0000-0000-0000000022e2') -> 'is_correct', 'true'::jsonb,
  'PRC-03: equivalent SPR is marked correct');
select is(pg_temp.question('failed', '00000000-0000-0000-0000-0000000022e3') -> 'my_answer', 'null'::jsonb,
  'PRC-03: blank answer has my_answer null');
select is(pg_temp.question('failed', '00000000-0000-0000-0000-0000000022e3') -> 'is_correct', 'false'::jsonb,
  'PRC-03: blank answer is marked wrong');
select is((select array_agg((q ->> 'id')::uuid order by pos) from attempt_review_ctx,
  jsonb_array_elements(v -> 'questions') with ordinality a(q, pos) where k = 'failed'),
  array['00000000-0000-0000-0000-0000000022e3', '00000000-0000-0000-0000-0000000022e1', '00000000-0000-0000-0000-0000000022e2']::uuid[],
  'PRC-03: review questions follow frozen position order');
select is(pg_temp.question('failed', '00000000-0000-0000-0000-0000000022e2') -> 'skills',
  '[{"code":"AR-A","name":"Algebra"},{"code":"AR-F","name":"Fractions"}]'::jsonb, 'PRC-03: review includes every tagged skill');
select is(pg_temp.question('failed', '00000000-0000-0000-0000-0000000022e3') -> 'skills', '[]'::jsonb,
  'PRC-03: an untagged question has an empty skill list');
select is(pg_temp.question('failed', '00000000-0000-0000-0000-0000000022e1') -> 'choices',
  '[{"label":"A","body_md":"Choice A"},{"label":"B","body_md":"Choice B"},{"label":"C","body_md":"Choice C"},{"label":"D","body_md":"Choice D"}]'::jsonb,
  'PRC-03: MCQ choices use the safe ordered shape');
select is(pg_temp.question('failed', '00000000-0000-0000-0000-0000000022e2') -> 'choices', '[]'::jsonb,
  'PRC-03: SPR choices are an empty array');
select is((pg_temp.question('failed', '00000000-0000-0000-0000-0000000022e1') ->> 'time_ms')::int, 1234,
  'PRC-03: recorded answer time is returned');
select tests.clear_authentication();
reset role;
select is((select (v -> 'summary') - 'skills' from attempt_review_ctx where k = 'failed'),
  (select (meta -> 'report') - 'next_topic' - 'retake_at' - 'skills' || jsonb_build_object('keys_visible', false)
   from public.attempts where id = '00000000-0000-0000-0000-000000002201'), 'PRC-03: summary matches the stored report');
select tests.authenticate_as('attempt_teacher');
select public.teacher_unlock_topic(tests.get_supabase_uid('attempt_owner'), '00000000-0000-0000-0000-0000000022d1');
select tests.authenticate_as('attempt_owner');
insert into attempt_review_ctx values ('unlocked', public.get_attempt_review('00000000-0000-0000-0000-000000002201'));
select is((select v #> '{summary,keys_visible}' from attempt_review_ctx where k = 'unlocked'), 'false'::jsonb,
  'PRC-03: teacher unlock is not a pass');
select ok(not exists (select 1 from attempt_review_ctx, jsonb_array_elements(v -> 'questions') q
  where k = 'unlocked' and (q ? 'key' or q ? 'explanation_md')), 'PRC-03: teacher unlock still omits all keys and explanations');
select is((select v #> '{summary,keys_visible}' from attempt_review_ctx where k = 'passed_other'), 'true'::jsonb,
  'PRC-03: passed topic exposes keys');
select is(pg_temp.question('passed_other', '00000000-0000-0000-0000-0000000022e1') -> 'key', '{"choice":"B"}'::jsonb,
  'PRC-03: passed review uses the MCQ choice key shape');
select is(pg_temp.question('passed_other', '00000000-0000-0000-0000-0000000022e2') -> 'key', '{"text":"1/2"}'::jsonb,
  'PRC-03: passed review uses the first accepted SPR form');
select is((select count(*)::int from attempt_review_ctx, jsonb_array_elements(v -> 'questions') q
  where k = 'passed_other' and q ?& array['key','explanation_md'] and q ->> 'explanation_md' is not null),
  3, 'PRC-03: passed review includes keys and explanations for every question');

select tests.clear_authentication();
reset role;
select private.finish_quiz('00000000-0000-0000-0000-000000002207', now());
select tests.authenticate_as('attempt_owner');
insert into attempt_review_ctx values ('later_pass', public.get_attempt_review('00000000-0000-0000-0000-000000002207'));
insert into attempt_review_ctx values ('old_failed', public.get_attempt_review('00000000-0000-0000-0000-000000002201'));
select is((select v #> '{summary,keys_visible}' from attempt_review_ctx where k = 'later_pass'), 'true'::jsonb,
  'PRC-03: owner passing later exposes keys');
select is((select v #> '{summary,keys_visible}' from attempt_review_ctx where k = 'old_failed'), 'true'::jsonb,
  'PRC-03: old failed attempt shows keys after a later pass');
select is((select v #> '{summary,passed}' from attempt_review_ctx where k = 'old_failed'), 'false'::jsonb,
  'PRC-03: old failed summary retains the original failed result');
select is((select count(*)::int from attempt_review_ctx, jsonb_array_elements(v -> 'questions') q
  where k = 'old_failed' and q ?& array['key','explanation_md']), 3, 'PRC-03: all old failed questions expose keys after the topic pass');
select is(pg_temp.question('old_failed', '00000000-0000-0000-0000-0000000022e1') -> 'key', '{"choice":"B"}'::jsonb,
  'PRC-03: old wrong answer now shows its key');
select tests.clear_authentication();
reset role;

-- Reconstruct skills live for an older report, including a missing answer row.
update public.attempts set meta = jsonb_set(meta, '{report}', (meta -> 'report') - 'skills')
where id = '00000000-0000-0000-0000-000000002201';
delete from public.attempt_answers where attempt_id = '00000000-0000-0000-0000-000000002201'
  and question_id = '00000000-0000-0000-0000-0000000022e3';
insert into public.skills (id, code, name, domain) values
  ('00000000-0000-0000-0000-0000000022a3', 'AR-Z', 'Algebra', 'Algebra');
insert into public.question_skills (question_id, skill_id) values
  ('00000000-0000-0000-0000-0000000022e3', '00000000-0000-0000-0000-0000000022a1'),
  ('00000000-0000-0000-0000-0000000022e3', '00000000-0000-0000-0000-0000000022a3');
select tests.authenticate_as('attempt_owner');
select is(public.get_attempt_review('00000000-0000-0000-0000-000000002201') #> '{summary,skills}',
  '[{"code":"AR-A","name":"Algebra","correct":1,"total":3},
    {"code":"AR-Z","name":"Algebra","correct":0,"total":1},
    {"code":"AR-F","name":"Fractions","correct":1,"total":1}]'::jsonb,
  'ANL-02: review_summary_has_skills_quiz');
select tests.clear_authentication();
reset role;

select * from finish();
rollback;
