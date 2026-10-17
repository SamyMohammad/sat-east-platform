-- LRN-04 / L-7: targeted review after a failed quiz. From templates/test.sql.
begin;
create extension if not exists pgtap with schema extensions;
select plan(48);

select tests.create_supabase_user(u) from unnest(array[
  'review_main', 'review_cap', 'review_short', 'review_empty', 'review_blank',
  'review_never', 'review_pass', 'review_untagged', 'review_teacher']) u;
update public.settings set value = '12' where key = 'cooldown_h';
update public.profiles set role = 'teacher' where id = tests.get_supabase_uid('review_teacher');
insert into public.courses (id, code, title, slug, is_published) values
  ('00000000-0000-0000-0000-0000000021c1', 'SAT', 'Review Course', 'review-course', true);
insert into public.units (id, course_id, title, sort) values
  ('00000000-0000-0000-0000-0000000021a1', '00000000-0000-0000-0000-0000000021c1', 'U1', 1);
insert into public.topics (id, course_id, unit_id, title, slug, sort, is_published) values
  ('00000000-0000-0000-0000-0000000021d1', '00000000-0000-0000-0000-0000000021c1',
   '00000000-0000-0000-0000-0000000021a1', 'T1', 'review-t1', 1, true),
  ('00000000-0000-0000-0000-0000000021d2', '00000000-0000-0000-0000-0000000021c1',
   '00000000-0000-0000-0000-0000000021a1', 'T2', 'review-t2', 2, true);
insert into public.subtopics (id, topic_id, title) values
  ('00000000-0000-0000-0000-0000000021b1', '00000000-0000-0000-0000-0000000021d1', 'S1');
create function pg_temp.q(p_i int) returns uuid language sql immutable as $$
  select md5('lrn04-question-' || p_i)::uuid
$$;
create function pg_temp.skill(p_i int) returns uuid language sql immutable as $$
  select md5('lrn04-skill-' || p_i)::uuid
$$;
create function pg_temp.failed(p_user text) returns uuid language sql immutable as $$
  select md5('lrn04-failed-' || p_user)::uuid
$$;
insert into public.skills (id, code, name, domain)
select pg_temp.skill(i), 'LRN04-' || i, 'Skill ' || i, 'Algebra' from generate_series(1, 3) i;
insert into public.questions (id, topic_id, subtopic_id, type, difficulty, stem_md, hint_md, pool, status)
select pg_temp.q(i), '00000000-0000-0000-0000-0000000021d1', '00000000-0000-0000-0000-0000000021b1',
  'mcq', 'E', 'Practice ' || i, 'Hint', 'practice', 'published' from generate_series(1, 9) i;
insert into public.questions (id, topic_id, subtopic_id, type, difficulty, stem_md, pool, status)
select pg_temp.q(100 + i), '00000000-0000-0000-0000-0000000021d1', '00000000-0000-0000-0000-0000000021b1',
  'mcq', 'E', 'Quiz ' || i, 'quiz', 'published' from generate_series(1, 3) i;
insert into public.question_skills (question_id, skill_id)
select pg_temp.q(i), pg_temp.skill((i - 1) / 3 + 1) from generate_series(1, 9) i
union all select pg_temp.q(100 + i), pg_temp.skill(i) from generate_series(1, 3) i;
insert into public.question_choices (question_id, label, body_md)
select q.id, c.label, 'Choice ' || c.label from public.questions q
cross join (values ('A'), ('B'), ('C'), ('D')) c(label)
where q.topic_id = '00000000-0000-0000-0000-0000000021d1';
insert into private.question_keys (question_id, correct_answer, explanation_md)
select q.id, '{"choice":"B"}', 'Private explanation' from public.questions q
where q.topic_id = '00000000-0000-0000-0000-0000000021d1';
insert into public.enrollments (user_id, course_id, status, starts_at, expires_at)
select tests.get_supabase_uid(u), '00000000-0000-0000-0000-0000000021c1', 'active', now() - interval '1 day', now() + interval '30 days'
from unnest(array['review_main', 'review_cap', 'review_short', 'review_empty', 'review_blank',
  'review_never', 'review_pass', 'review_untagged']) u;
insert into public.topic_progress (user_id, topic_id, practice_count)
select tests.get_supabase_uid(u), '00000000-0000-0000-0000-0000000021d1', private.setting_int('practice_min')
from unnest(array['review_main', 'review_cap', 'review_short', 'review_empty', 'review_blank',
  'review_never', 'review_pass', 'review_untagged']) u;
insert into public.attempts (id, user_id, kind, course_id, topic_id, started_at, time_limit_s)
select pg_temp.failed(u), tests.get_supabase_uid(u), 'quiz', '00000000-0000-0000-0000-0000000021c1',
  '00000000-0000-0000-0000-0000000021d1', now() - interval '2 hours', 60
from unnest(array['review_main', 'review_cap', 'review_short', 'review_empty', 'review_blank', 'review_pass', 'review_untagged']) u;
insert into public.attempt_questions (attempt_id, question_id, position)
select a.id, pg_temp.q(100 + i), i from public.attempts a cross join generate_series(1, 3) i
where a.topic_id = '00000000-0000-0000-0000-0000000021d1';
-- Two missed skills; the all-blank student deliberately has no saved answers.
insert into public.attempt_answers (attempt_id, question_id, answer, answered_at)
select a.id, pg_temp.q(100 + i), jsonb_build_object('value', case when i = 3 then 'B' else 'A' end), now() - interval '1 hour'
from public.attempts a cross join generate_series(1, 3) i
where a.topic_id = '00000000-0000-0000-0000-0000000021d1' and a.user_id <> tests.get_supabase_uid('review_blank');
select private.finish_quiz(a.id, now() - interval '1 hour') from public.attempts a
where a.topic_id = '00000000-0000-0000-0000-0000000021d1';
update public.topic_progress set quiz_passed_at = now() - interval '30 minutes'
where user_id = tests.get_supabase_uid('review_pass');
insert into public.question_exposure (user_id, question_id) values
  (tests.get_supabase_uid('review_main'), pg_temp.q(1)),
  (tests.get_supabase_uid('review_main'), pg_temp.q(4));

create temp table review_ctx (k text primary key, v jsonb);
grant select, insert on review_ctx to authenticated;
create function pg_temp.att(p_k text) returns uuid language sql as $$
  select (v ->> 'attempt_id')::uuid from review_ctx where k = p_k
$$;
create function pg_temp.first_q(p_k text) returns uuid language sql as $$
  select (v #>> '{questions,0,id}')::uuid from review_ctx where k = p_k
$$;
grant execute on function pg_temp.q(int), pg_temp.skill(int), pg_temp.failed(text), pg_temp.att(text), pg_temp.first_q(text) to authenticated;

select is(private.setting_int('review_per_skill'), 2, 'LRN-04: review_per_skill defaults to 2');
select is(private.setting_int('review_max'), 10, 'LRN-04: review_max defaults to 10');
select is(has_function_privilege('authenticated', 'public.start_review(uuid)', 'execute'), true, 'SEC: start_review granted to authenticated');
select is(has_function_privilege('anon', 'public.start_review(uuid)', 'execute'), false, 'SEC: start_review not granted to anon');
select is(has_function_privilege('authenticated', 'private.review_status(uuid,uuid)', 'execute'), false, 'SEC: review_status is private');
select tests.clear_authentication();
set local role authenticated;
select throws_ok($$ select public.start_review(null) $$, 'P0001', 'not_authenticated', 'SEC: start_review requires a session');
reset role;
select tests.authenticate_as('review_main');
select throws_ok($$ select public.start_review(null) $$, 'P0001', 'invalid_input', 'LRN-04: null review topic is invalid');
select is(public.get_topic('00000000-0000-0000-0000-0000000021d1') #>> '{quiz,state}', 'review_needed',
  'LRN-04: failed quiz enters review_needed');
select is((public.get_topic('00000000-0000-0000-0000-0000000021d1') #>> '{quiz,available_at}')::timestamptz,
  now() + interval '11 hours',
  'LRN-04: review_needed still exposes running cooldown');
select throws_ok($$ select public.start_quiz('00000000-0000-0000-0000-0000000021d1') $$,
  'P0001', 'review_needed', 'LRN-04: start_quiz raises review_needed');
insert into review_ctx values ('main', public.start_review('00000000-0000-0000-0000-0000000021d1'));
select is((select (v ->> 'rep_target')::int from review_ctx where k = 'main'), 4,
  'LRN-04: start_review draws review_per_skill per missed skill');
select is((select v -> 'answered' from review_ctx where k = 'main'), '[]'::jsonb, 'LRN-04: a new review has no final answers');
select is((select v::text ~* '"(key|correct_answer|explanation_md|hint_md|misconception_md|is_correct)"' from review_ctx where k = 'main'), false,
  'LRN-04: start_review exposes no grading or hint content');
select is(public.start_review('00000000-0000-0000-0000-0000000021d1'),
  (select v from review_ctx where k = 'main'), 'LRN-04: start_review resumes the same attempt and questions');
select tests.clear_authentication();
reset role;
select is((select kind::text from public.attempts where id = pg_temp.att('main')), 'review', 'LRN-04: review attempt has review kind');
select is((select meta ->> 'source_attempt_id' from public.attempts where id = pg_temp.att('main')),
  pg_temp.failed('review_main')::text, 'LRN-04: review records its source failed quiz');
select is((select count(*)::int from public.attempt_questions aq join public.questions q on q.id = aq.question_id
  where aq.attempt_id = pg_temp.att('main') and q.pool = 'practice' and q.status = 'published'
    and exists (select 1 from public.question_skills qs where qs.question_id = q.id and qs.skill_id in (pg_temp.skill(1), pg_temp.skill(2)))),
  4, 'LRN-04: all review questions are published practice questions on missed skills');
select results_eq($$ select qs.skill_id, count(*)::int from public.attempt_questions aq
  join public.question_skills qs on qs.question_id = aq.question_id where aq.attempt_id = pg_temp.att('main')
  group by qs.skill_id order by qs.skill_id $$,
  $$ select pg_temp.skill(i), 2 from generate_series(1, 2) i order by 1 $$, 'LRN-04: two questions are drawn per missed skill');
select is((select count(*)::int from public.attempt_questions where attempt_id = pg_temp.att('main')
  and question_id in (pg_temp.q(1), pg_temp.q(4))), 0, 'LRN-04: unseen questions are preferred');
select is((select count(*)::int from public.question_exposure x join public.attempt_questions aq on aq.question_id = x.question_id
  where aq.attempt_id = pg_temp.att('main') and x.user_id = tests.get_supabase_uid('review_main')), 4,
  'LRN-04: review draw records exposure');

-- A request can start before the quiz submission it waits on; source identity controls resume.
update public.attempts set started_at = now() - interval '2 hours' where id = pg_temp.att('main');
select tests.authenticate_as('review_main');
select is(public.start_review('00000000-0000-0000-0000-0000000021d1') ->> 'attempt_id', pg_temp.att('main')::text,
  'LRN-04: matching source resumes even if the review transaction began before the failure');
select tests.clear_authentication();
reset role;

update public.settings set value = '3' where key = 'review_max';
select tests.authenticate_as('review_cap');
insert into review_ctx values ('cap', public.start_review('00000000-0000-0000-0000-0000000021d1'));
select is((select jsonb_array_length(v -> 'questions') from review_ctx where k = 'cap'), 3, 'LRN-04: review is capped at review_max');
select tests.clear_authentication();
reset role;
update public.settings set value = '10' where key = 'review_max';
update public.questions set status = 'draft' where id in (pg_temp.q(2), pg_temp.q(3), pg_temp.q(4), pg_temp.q(5), pg_temp.q(6));
select tests.authenticate_as('review_short');
insert into review_ctx values ('short', public.start_review('00000000-0000-0000-0000-0000000021d1'));
select is((select jsonb_array_length(v -> 'questions') from review_ctx where k = 'short'), 4, 'LRN-04: short pool filled from topic practice pool');
select tests.clear_authentication();
reset role;
select is((select count(*)::int from public.attempt_questions aq join public.question_skills qs on qs.question_id = aq.question_id
  where aq.attempt_id = pg_temp.att('short') and qs.skill_id = pg_temp.skill(3)), 3,
  'LRN-04: fill uses other skills when the targeted pool is short');
update public.questions set status = 'draft' where topic_id = '00000000-0000-0000-0000-0000000021d1' and pool = 'practice';
select tests.authenticate_as('review_empty');
select throws_ok($$ select public.start_review('00000000-0000-0000-0000-0000000021d1') $$,
  'P0001', 'pool_exhausted', 'LRN-04: empty practice pool raises pool_exhausted');
select tests.clear_authentication();
reset role;
update public.questions set status = 'published' where topic_id = '00000000-0000-0000-0000-0000000021d1' and pool = 'practice';
select tests.authenticate_as('review_blank');
insert into review_ctx values ('blank', public.start_review('00000000-0000-0000-0000-0000000021d1'));
select is((select jsonb_array_length(v -> 'questions') from review_ctx where k = 'blank'), 6,
  'LRN-04: all-blank fail counts every quiz question skill as missed');
select tests.clear_authentication();
reset role;
select is((select count(distinct qs.skill_id)::int from public.attempt_questions aq
  join public.question_skills qs on qs.question_id = aq.question_id where aq.attempt_id = pg_temp.att('blank')),
  3, 'LRN-04: all-blank review covers all three skills');

-- No tags on the missed quiz questions: fall back to the topic pool.
delete from public.question_skills where question_id in (pg_temp.q(101), pg_temp.q(102));
select tests.authenticate_as('review_untagged');
insert into review_ctx values ('untagged', public.start_review('00000000-0000-0000-0000-0000000021d1'));
select is((select (v ->> 'rep_target')::int from review_ctx where k = 'untagged'), 2,
  'LRN-04: untagged misses fall back to topic practice');
select tests.clear_authentication();
reset role;
insert into public.question_skills (question_id, skill_id) values (pg_temp.q(101), pg_temp.skill(1)), (pg_temp.q(102), pg_temp.skill(2));
select tests.authenticate_as('review_never');
select throws_ok($$ select public.start_review('00000000-0000-0000-0000-0000000021d1') $$,
  'P0001', 'invalid_input', 'LRN-04: never failed means review is not required');
select tests.authenticate_as('review_pass');
select throws_ok($$ select public.start_review('00000000-0000-0000-0000-0000000021d1') $$,
  'P0001', 'invalid_input', 'LRN-04: passed topic means review is not required');
select isnt(public.get_topic('00000000-0000-0000-0000-0000000021d1') #>> '{quiz,state}', 'review_needed',
  'LRN-04: passing later clears review_needed');
select tests.authenticate_as('review_teacher');
select public.teacher_unlock_topic(tests.get_supabase_uid('review_main'), '00000000-0000-0000-0000-0000000021d1');
select public.teacher_unlock_topic(tests.get_supabase_uid('review_main'), '00000000-0000-0000-0000-0000000021d2');
select tests.authenticate_as('review_main');
select is(public.get_topic('00000000-0000-0000-0000-0000000021d1') #>> '{quiz,state}', 'review_needed',
  'LRN-04: teacher unlock does not skip review');
select is(public.get_topic('00000000-0000-0000-0000-0000000021d1') #> '{quiz,review}',
  jsonb_build_object('required', true, 'attempt_id', pg_temp.att('main'), 'answered', 0, 'total', 4),
  'LRN-04: get_topic exposes quiz.review progress');
select is(public.check_practice_answer(pg_temp.att('main'), pg_temp.first_q('main'), 'A', 1) ->> 'try', '1',
  'LRN-04: check_practice_answer serves review attempts');
select is(public.start_review('00000000-0000-0000-0000-0000000021d1') -> 'answered', '[]'::jsonb,
  'LRN-04: a wrong first try is not a final answer');
select is(public.check_practice_answer(pg_temp.att('main'), pg_temp.first_q('main'), 'C', 1),
  '{"is_correct":false,"try":2,"key":{"choice":"B"},"explanation_md":"Private explanation"}'::jsonb,
  'LRN-04: second wrong review try reveals the key');
select is(public.start_review('00000000-0000-0000-0000-0000000021d1') -> 'answered', jsonb_build_array(pg_temp.first_q('main')),
  'LRN-04: resume returns final question ids');
select tests.clear_authentication();
reset role;
select is((select status::text from public.attempts where id = pg_temp.att('main')), 'in_progress',
  'LRN-04: a partially answered review remains in progress');
select tests.authenticate_as('review_main');
select public.check_practice_answer(pg_temp.att('main'), (q ->> 'id')::uuid, 'B', 1)
from review_ctx, jsonb_array_elements(v -> 'questions') q where k = 'main' and (q ->> 'id')::uuid <> pg_temp.first_q('main');
select is(public.check_practice_answer(pg_temp.att('main'), pg_temp.first_q('main'), 'C', 1),
  '{"is_correct":false,"try":2,"key":{"choice":"B"},"explanation_md":"Private explanation"}'::jsonb,
  'LRN-04: submitted review replays final feedback after a lost response');
select throws_ok($$ select public.check_practice_answer(pg_temp.att('main'), pg_temp.first_q('main'), 'D', 1) $$,
  'P0001', 'invalid_input', 'LRN-04: submitted review rejects a new try');
select is(public.get_topic('00000000-0000-0000-0000-0000000021d1') #>> '{quiz,state}', 'cooldown',
  'LRN-04: completed review falls through to cooldown');
select throws_ok($$ select public.start_review('00000000-0000-0000-0000-0000000021d1') $$,
  'P0001', 'invalid_input', 'LRN-04: submitted review is not required again');
select tests.clear_authentication();
reset role;
select is((select status::text from public.attempts where id = pg_temp.att('main')), 'submitted',
  'LRN-04: last final answer submits the review');
select is((select submitted_at from public.attempts where id = pg_temp.att('main')), now(), 'LRN-04: review submission uses server time');
select is((select practice_count from public.topic_progress where user_id = tests.get_supabase_uid('review_main')
  and topic_id = '00000000-0000-0000-0000-0000000021d1'), private.setting_int('practice_min'),
  'LRN-04: review answers do not change practice_count');
update public.topic_progress set quiz_last_failed_at = now() - interval '13 hours' where user_id = tests.get_supabase_uid('review_main');
select tests.authenticate_as('review_main');
select is(public.get_topic('00000000-0000-0000-0000-0000000021d1') #>> '{quiz,state}', 'available',
  'LRN-04: completed review after cooldown makes quiz available');
insert into review_ctx values ('practice', public.get_practice_questions('00000000-0000-0000-0000-0000000021d1'));
select public.check_practice_answer(pg_temp.att('practice'), pg_temp.first_q('main'), 'B', 1);
select tests.clear_authentication();
reset role;
select is((select practice_count from public.topic_progress where user_id = tests.get_supabase_uid('review_main')
  and topic_id = '00000000-0000-0000-0000-0000000021d1'), private.setting_int('practice_min') + 1,
  'LRN-04: a question first answered in review still counts in practice');
update public.settings set value = '0' where key = 'rate_start_per_min';
select tests.authenticate_as('review_main');
select throws_ok($$ select public.start_review('00000000-0000-0000-0000-0000000021d1') $$,
  'P0001', 'rate_limited', 'SEC: start_review rate limited');
select tests.clear_authentication();
reset role;

select * from finish();
rollback;
