-- PRC-03: shared grader, quiz settings and practice hardening.
begin;
create extension if not exists pgtap with schema extensions;
select plan(91);

select tests.create_supabase_user('quiz_student');

insert into public.courses (id, code, title, slug, is_published, sort) values
  ('00000000-0000-0000-0000-0000000017c1', 'SAT', 'Quiz Course', 'quiz-course', true, 1);
insert into public.units (id, course_id, title, sort) values
  ('00000000-0000-0000-0000-0000000017a1', '00000000-0000-0000-0000-0000000017c1', 'U1', 1);
insert into public.topics (id, course_id, unit_id, title, slug, sort, is_published, is_free_preview) values
  ('00000000-0000-0000-0000-0000000017d1', '00000000-0000-0000-0000-0000000017c1',
   '00000000-0000-0000-0000-0000000017a1', 'T1', 'quiz-t1', 1, true, true);
insert into public.subtopics (id, topic_id, title) values
  ('00000000-0000-0000-0000-0000000017b1', '00000000-0000-0000-0000-0000000017d1', 'S1');
insert into public.questions (id, topic_id, subtopic_id, type, difficulty, stem_md, pool, status) values
  ('00000000-0000-0000-0000-0000000017e1', '00000000-0000-0000-0000-0000000017d1',
   '00000000-0000-0000-0000-0000000017b1', 'mcq', 'E', 'MCQ', 'practice', 'published'),
  ('00000000-0000-0000-0000-0000000017e2', '00000000-0000-0000-0000-0000000017d1',
   '00000000-0000-0000-0000-0000000017b1', 'spr', 'E', 'SPR', 'practice', 'published'),
  ('00000000-0000-0000-0000-0000000017e3', '00000000-0000-0000-0000-0000000017d1',
   '00000000-0000-0000-0000-0000000017b1', 'spr', 'E', 'Missing key', 'quiz', 'draft');
insert into public.question_choices (question_id, label, body_md)
  select '00000000-0000-0000-0000-0000000017e1'::uuid, label, 'Choice ' || label
  from (values ('A'), ('B'), ('C'), ('D')) choices(label);
insert into private.question_keys (question_id, correct_answer, explanation_md) values
  ('00000000-0000-0000-0000-0000000017e1', '{"choice":"B"}', 'MCQ explanation'),
  ('00000000-0000-0000-0000-0000000017e2', '{"accepted":["1/2"],"tolerance":0}', 'SPR explanation');
insert into public.enrollments (user_id, course_id, status, starts_at, expires_at) values
  (tests.get_supabase_uid('quiz_student'), '00000000-0000-0000-0000-0000000017c1',
   'active', now() - interval '1 day', now() + interval '30 days');

select is(private.grade_answer('00000000-0000-0000-0000-0000000017e1', ' b '), true,
          'PRC-03: MCQ grading ignores case and surrounding whitespace');
select is(private.grade_answer('00000000-0000-0000-0000-0000000017e1', 'A'), false,
          'PRC-03: incorrect MCQ answer is false');
select is(private.grade_answer('00000000-0000-0000-0000-0000000017e2', ' .5 '), true,
          'PRC-03: SPR accepts an equivalent form with surrounding whitespace');
select is(private.grade_answer('00000000-0000-0000-0000-0000000017e2', 'abc'), false,
          'PRC-03: malformed SPR answer is false');
select is(private.grade_answer('00000000-0000-0000-0000-0000000017e1', null), false,
          'PRC-03: null answer is false');
select is(private.grade_answer('00000000-0000-0000-0000-0000000017e2', ''), false,
          'PRC-03: empty answer is false');
select is(private.grade_answer('00000000-0000-0000-0000-0000000017e1', '   '), false,
          'PRC-03: whitespace-only answer is false');
select throws_ok($$ select private.grade_answer('00000000-0000-0000-0000-0000000017e3', '1') $$,
                 'P0001', 'invalid_key', 'PRC-03: missing key raises invalid_key');
update private.question_keys set correct_answer = '{"accepted":"1/2"}'
  where question_id = '00000000-0000-0000-0000-0000000017e2';
select throws_ok($$ select private.grade_answer('00000000-0000-0000-0000-0000000017e2', '.5') $$,
                 'P0001', 'invalid_key', 'PRC-03: malformed SPR key raises invalid_key');
update private.question_keys set correct_answer = '{"accepted":["1/2"],"tolerance":0}'
  where question_id = '00000000-0000-0000-0000-0000000017e2';

select is((select value from public.settings where key = 'quiz_size'), '12'::jsonb,
          'PRC-03: quiz_size defaults to 12');
select is((select value from public.settings where key = 'quiz_time_per_q_s'), '90'::jsonb,
          'PRC-03: quiz_time_per_q_s defaults to 90');
select is((select value from public.settings where key = 'quiz_warn_s'), '300'::jsonb,
          'PRC-03: quiz_warn_s defaults to 300');

create temp table quiz_ctx (session jsonb);
grant select, insert on quiz_ctx to authenticated;
select tests.authenticate_as('quiz_student');
select throws_ok($$ select private.grade_answer('00000000-0000-0000-0000-0000000017e1', 'B') $$,
                 '42501', null, 'PRC-03: authenticated cannot execute private.grade_answer');
insert into quiz_ctx select public.get_practice_questions('00000000-0000-0000-0000-0000000017d1');

select tests.clear_authentication();
reset role;
update public.questions set pool = 'quiz' where id = '00000000-0000-0000-0000-0000000017e1';
update public.questions set status = 'draft' where id = '00000000-0000-0000-0000-0000000017e2';
select tests.authenticate_as('quiz_student');
select throws_ok($$ select public.check_practice_answer(
  (select (session ->> 'attempt_id')::uuid from quiz_ctx), '00000000-0000-0000-0000-0000000017e1', 'B', 1) $$,
  'P0001', 'invalid_input', 'PRC-03: question moved to quiz pool after draw raises invalid_input');
select throws_ok($$ select public.check_practice_answer(
  (select (session ->> 'attempt_id')::uuid from quiz_ctx), '00000000-0000-0000-0000-0000000017e2', '.5', 1) $$,
  'P0001', 'invalid_input', 'PRC-03: question unpublished after draw raises invalid_input');


-- Task 2 fixtures share only this file's course and transaction.
select tests.clear_authentication();
reset role;
select tests.create_supabase_user('quiz_other');
select tests.create_supabase_user('quiz_fail');
select tests.create_supabase_user('quiz_expiry');
insert into public.enrollments (user_id, course_id, status, starts_at, expires_at)
  select tests.get_supabase_uid(u), '00000000-0000-0000-0000-0000000017c1',
         'active', now() - interval '1 day', now() + interval '30 days'
  from unnest(array['quiz_other', 'quiz_fail', 'quiz_expiry']) u;
insert into public.topics (id, course_id, unit_id, title, slug, sort, is_published, is_free_preview) values
  ('00000000-0000-0000-0000-0000000017d2', '00000000-0000-0000-0000-0000000017c1', '00000000-0000-0000-0000-0000000017a1', 'T2', 'quiz-t2', 2, true, false),
  ('00000000-0000-0000-0000-0000000017d3', '00000000-0000-0000-0000-0000000017c1', '00000000-0000-0000-0000-0000000017a1', 'Small', 'quiz-small', 3, true, true),
  ('00000000-0000-0000-0000-0000000017d4', '00000000-0000-0000-0000-0000000017c1', '00000000-0000-0000-0000-0000000017a1', 'Empty', 'quiz-empty', 4, true, true);
insert into public.subtopics (id, topic_id, title) values
  ('00000000-0000-0000-0000-0000000017b3', '00000000-0000-0000-0000-0000000017d3', 'Small');
update public.questions set pool = 'practice', status = 'published'
  where id in ('00000000-0000-0000-0000-0000000017e1', '00000000-0000-0000-0000-0000000017e2');
create function pg_temp.q(p_i int) returns uuid language sql immutable as $$
  select md5('prc03-quiz-' || p_i)::uuid
$$;
insert into public.questions (id, topic_id, subtopic_id, type, difficulty, stem_md, pool, status)
  select pg_temp.q(i), '00000000-0000-0000-0000-0000000017d1', '00000000-0000-0000-0000-0000000017b1',
         'mcq', 'E', 'Quiz ' || i, 'quiz', 'published' from generate_series(1, 8) i;
insert into public.questions (id, topic_id, subtopic_id, type, difficulty, stem_md, pool, status)
  select pg_temp.q(i), '00000000-0000-0000-0000-0000000017d1', '00000000-0000-0000-0000-0000000017b1',
         'spr', 'M', 'Quiz ' || i, 'quiz', 'published' from generate_series(9, 15) i;
insert into public.questions (id, topic_id, subtopic_id, type, difficulty, stem_md, pool, status) values
  (pg_temp.q(16), '00000000-0000-0000-0000-0000000017d1', '00000000-0000-0000-0000-0000000017b1', 'mcq', 'E', 'Draft', 'quiz', 'draft'),
  (pg_temp.q(17), '00000000-0000-0000-0000-0000000017d3', '00000000-0000-0000-0000-0000000017b3', 'mcq', 'E', 'Small', 'quiz', 'published');
insert into public.question_choices (question_id, label, body_md)
  select q.id, l.label, 'Choice ' || l.label
  from public.questions q cross join (values ('A'), ('B'), ('C'), ('D')) l(label)
  where q.topic_id in ('00000000-0000-0000-0000-0000000017d1', '00000000-0000-0000-0000-0000000017d3')
    and q.type = 'mcq' and q.pool = 'quiz';
insert into private.question_keys (question_id, correct_answer, explanation_md)
  select pg_temp.q(i), '{"choice":"B"}', 'Private MCQ' from generate_series(1, 8) i;
insert into private.question_keys (question_id, correct_answer, explanation_md)
  select pg_temp.q(i), '{"accepted":["1/2"]}', 'Private SPR' from generate_series(9, 15) i;
insert into private.question_keys (question_id, correct_answer, explanation_md) values
  (pg_temp.q(17), '{"choice":"B"}', 'Private small');
update public.settings set value = '12' where key in ('quiz_size', 'cooldown_h');
update public.settings set value = '90' where key = 'quiz_time_per_q_s';
update public.settings set value = '300' where key = 'quiz_warn_s';
update public.settings set value = '75' where key = 'pass_mark';
update public.settings set value = '10' where key = 'practice_min';
update public.settings set value = '30' where key = 'save_grace_s';
create temp table ctx (k text primary key, v jsonb);
grant select, insert, update on ctx to authenticated;
create function pg_temp.att(p_k text) returns uuid language sql as $$
  select (v ->> 'attempt_id')::uuid from ctx where k = p_k
$$;
create function pg_temp.first_q(p_k text) returns uuid language sql as $$
  select (v #>> '{questions,0,id}')::uuid from ctx where k = p_k
$$;
create function pg_temp.fill(p_k text, p_n int) returns void language plpgsql as $$
declare v_q jsonb;
begin
  for v_q in select q from ctx, jsonb_array_elements(v -> 'questions') q
             where k = p_k order by q ->> 'type' desc, q ->> 'id' limit p_n loop
    perform public.save_answer(pg_temp.att(p_k), (v_q ->> 'id')::uuid,
      '{"mcq":" b ","spr":" .5 "}'::jsonb ->> (v_q ->> 'type'), 100, false, array[]::text[], 100);
  end loop;
end;
$$;
create function pg_temp.complete_review(p_user text, p_topic_id uuid)
returns void language sql set search_path = '' as $$
  insert into public.attempts (user_id, kind, course_id, topic_id, status, submitted_at)
  select tests.get_supabase_uid(p_user), 'review', t.course_id, t.id, 'submitted', pg_catalog.now()
  from public.topics t where t.id = p_topic_id
$$;
grant execute on function pg_temp.q(int), pg_temp.att(text), pg_temp.first_q(text), pg_temp.fill(text, int) to authenticated;

select tests.clear_authentication();
set local role anon;
select throws_ok($$ select public.get_topic(null) $$, '42501', null, 'PRC-03: anon cannot get_topic');
select throws_ok($$ select public.start_quiz(null) $$, '42501', null, 'PRC-03: anon cannot start_quiz');
select throws_ok($$ select public.save_answer(null, null, null, 0, false, null, 1) $$, '42501', null, 'PRC-03: anon cannot save_answer');
select throws_ok($$ select public.submit_attempt(null) $$, '42501', null, 'PRC-03: anon cannot submit_attempt');
reset role;
set local role authenticated;
select throws_ok($$ select public.get_topic(null) $$, 'P0001', 'not_authenticated', 'PRC-03: get_topic requires a session');
select throws_ok($$ select public.start_quiz(null) $$, 'P0001', 'not_authenticated', 'PRC-03: start_quiz requires a session');
select throws_ok($$ select public.save_answer(null, null, null, 0, false, null, 1) $$, 'P0001', 'not_authenticated', 'PRC-03: save_answer requires a session');
select throws_ok($$ select public.submit_attempt(null) $$, 'P0001', 'not_authenticated', 'PRC-03: submit_attempt requires a session');
select throws_ok($$ select private.quiz_state(null, null) $$, '42501', null, 'PRC-03: quiz_state is private');
select throws_ok($$ select private.finish_quiz(null, now()) $$, '42501', null, 'PRC-03: finish_quiz is private');
select throws_ok($$ select private.expire_quiz(null, null) $$, '42501', null, 'PRC-03: expire_quiz is private');
reset role;
select tests.authenticate_as('quiz_student');
select throws_ok($$ select public.get_topic(null) $$, 'P0001', 'invalid_input', 'PRC-03: null topic is invalid');
select throws_ok($$ select public.start_quiz(gen_random_uuid()) $$, 'P0001', 'invalid_input', 'PRC-03: unknown topic is invalid');
select throws_ok($$ select public.get_topic('00000000-0000-0000-0000-0000000017d2') $$, 'P0001', 'topic_locked', 'PRC-03: locked topic cannot be read');
select throws_ok($$ select public.start_quiz('00000000-0000-0000-0000-0000000017d2') $$, 'P0001', 'topic_locked', 'PRC-03: locked topic cannot start');
select is(public.get_topic('00000000-0000-0000-0000-0000000017d1') #>> '{quiz,state}', 'practice_needed', 'PRC-03: practice below threshold gates quiz');
select throws_ok($$ select public.start_quiz('00000000-0000-0000-0000-0000000017d1') $$, 'P0001', 'practice_needed', 'PRC-03: start below practice_min fails');
select tests.clear_authentication();
reset role;
insert into public.topic_progress (user_id, topic_id, practice_count)
  select tests.get_supabase_uid(u), t.id, 10 from unnest(array['quiz_student', 'quiz_fail', 'quiz_expiry']) u
  cross join public.topics t where t.course_id = '00000000-0000-0000-0000-0000000017c1';
update public.topic_progress set quiz_last_failed_at = now()
  where user_id = tests.get_supabase_uid('quiz_student') and topic_id = '00000000-0000-0000-0000-0000000017d1';
select pg_temp.complete_review('quiz_student', '00000000-0000-0000-0000-0000000017d1');
select tests.authenticate_as('quiz_student');
select is(public.get_topic('00000000-0000-0000-0000-0000000017d1') #>> '{quiz,state}', 'cooldown', 'PRC-03: recent failure enters cooldown');
select throws_ok($$ select public.start_quiz('00000000-0000-0000-0000-0000000017d1') $$, 'P0001', 'cooldown_active', 'PRC-03: cannot start inside cooldown');
select tests.clear_authentication();
reset role;
update public.topic_progress set quiz_last_failed_at = now() - interval '13 hours'
  where user_id = tests.get_supabase_uid('quiz_student');
insert into public.question_exposure (user_id, question_id)
  select tests.get_supabase_uid('quiz_student'), pg_temp.q(i) from generate_series(1, 12) i;
update public.settings set value = '3' where key = 'quiz_size';
select tests.authenticate_as('quiz_student');
select is(public.get_topic('00000000-0000-0000-0000-0000000017d1'),
  jsonb_build_object('id', '00000000-0000-0000-0000-0000000017d1', 'title', 'T1', 'slug', 'quiz-t1', 'sort_label', '1.1', 'status', 'open',
    'notes', '[]'::jsonb, 'notes_done', true,
    'practice', jsonb_build_object('count', 10, 'min', 10), 'quiz', jsonb_build_object('state', 'available', 'practice_count', 10, 'practice_min', 10, 'best_score_pct', null, 'passed', false,
      'review', jsonb_build_object('required', false, 'attempt_id', null, 'answered', 0, 'total', 0))),
  'PRC-03: topic shape and available state at practice_min after cooldown');
insert into ctx values ('unseen', public.start_quiz('00000000-0000-0000-0000-0000000017d1'));
select is((select array_agg((q ->> 'id')::uuid order by q ->> 'id') from ctx, jsonb_array_elements(v -> 'questions') q where k = 'unseen'),
  (select array_agg(pg_temp.q(i) order by pg_temp.q(i)::text) from generate_series(13, 15) i), 'PRC-03: quiz draws unseen questions first');
select is((select (v ->> 'time_limit_s')::int from ctx where k = 'unseen'), 270, 'PRC-03: time limit uses drawn count times settings');
select is((select (v ->> 'warn_s')::int from ctx where k = 'unseen'), 300, 'PRC-03: warning uses settings');
select is((select v ->> 'title' from ctx where k = 'unseen'), '1.1 T1', 'PRC-03: quiz title includes sort label');
select is((select v::text ~* '(correct_answer|explanation|hint|misconception|is_correct)' from ctx where k = 'unseen'), false, 'PRC-03: start payload has no grading content');
select is((select v ->> 'client_seq' from ctx where k = 'unseen'), '0', 'PRC-03: new session starts with sequence zero');
select is((select array_agg(key order by key) from ctx, jsonb_object_keys(v) key where k = 'unseen'),
  array['answers','attempt_id','client_seq','deadline','questions','server_now','time_limit_s','title','warn_s'],
  'PRC-03: session has exactly the contracted top-level fields');
select is((select array_agg(key order by key) from ctx, jsonb_object_keys(v #> '{questions,0}') key where k = 'unseen'),
  array['choices','difficulty','id','stem_md','type'], 'PRC-03: question has exactly the contracted fields');
select tests.clear_authentication();
reset role;
update public.topic_progress set practice_count = 0, quiz_last_failed_at = now()
  where user_id = tests.get_supabase_uid('quiz_student') and topic_id = '00000000-0000-0000-0000-0000000017d1';
select tests.authenticate_as('quiz_student');
select is(public.get_topic('00000000-0000-0000-0000-0000000017d1') #>> '{quiz,state}', 'in_progress',
  'PRC-03: in-progress state precedes practice and cooldown gates');
select tests.clear_authentication();
reset role;
update public.topic_progress set practice_count = 10, quiz_last_failed_at = null
  where user_id = tests.get_supabase_uid('quiz_student') and topic_id = '00000000-0000-0000-0000-0000000017d1';
select tests.authenticate_as('quiz_student');
select is(public.save_answer(pg_temp.att('unseen'), pg_temp.first_q('unseen'), '.5', -1, true, array['A'], 2), '{"ok":true}'::jsonb, 'PRC-03: saves answer and mark');
select is(public.save_answer(pg_temp.att('unseen'), pg_temp.first_q('unseen'), 'wrong', 50, false, null, 2), '{"ok":true,"stale":true}'::jsonb, 'PRC-03: equal sequence is stale');
select is(public.save_answer(pg_temp.att('unseen'), pg_temp.first_q('unseen'), 'wrong', 50, false, null, 1), '{"ok":true,"stale":true}'::jsonb, 'PRC-03: older sequence is stale');
insert into ctx values ('resume', public.start_quiz('00000000-0000-0000-0000-0000000017d1'));
select is((select v from ctx where k = 'resume'), (select jsonb_set(jsonb_set(v, '{client_seq}', '2'), '{answers}',
  jsonb_build_array(jsonb_build_object('question_id', pg_temp.first_q('unseen'), 'answer', '.5', 'marked', true))) from ctx where k = 'unseen'),
  'PRC-03: start resumes same attempt, deadline, answer, mark and max sequence');
select throws_ok($$ select public.save_answer(pg_temp.att('unseen'), pg_temp.first_q('unseen'), repeat('x',33), 0, false, null, 3) $$,
  'P0001', 'invalid_input', 'PRC-03: answer over 32 characters rejected');
select tests.clear_authentication();
reset role;
select is((select time_ms from public.attempt_answers where attempt_id = pg_temp.att('unseen')
  and question_id = pg_temp.first_q('unseen')), 0, 'PRC-03: negative time clamps to zero');
select tests.authenticate_as('quiz_student');
select is(public.save_answer(pg_temp.att('unseen'), pg_temp.first_q('unseen'), null, 9999999, false, array[]::text[], 3), '{"ok":true}'::jsonb, 'PRC-03: null clears saved answer');
select tests.clear_authentication();
reset role;
select is((select jsonb_build_object('answer', answer, 'time_ms', time_ms, 'marked', marked_for_review,
  'eliminated', eliminated, 'seq', client_seq, 'correct', is_correct) from public.attempt_answers
  where attempt_id = pg_temp.att('unseen') and question_id = pg_temp.first_q('unseen')),
  '{"answer":{"value":null},"time_ms":3600000,"marked":false,"eliminated":[],"seq":3,"correct":null}'::jsonb,
  'PRC-03: saves clamp time and keep correctness null');
select is((select count(*)::int from public.question_exposure where user_id = tests.get_supabase_uid('quiz_student') and question_id in (pg_temp.q(13),pg_temp.q(14),pg_temp.q(15))), 3, 'PRC-03: drawn questions record exposure');
select is((select array_agg(position order by position) from public.attempt_questions where attempt_id = pg_temp.att('unseen')), array[1,2,3], 'PRC-03: frozen positions are contiguous');
select tests.authenticate_as('quiz_other');
select throws_ok($$ select public.save_answer(pg_temp.att('unseen'), pg_temp.first_q('unseen'), 'B', 0, false, null, 4) $$, 'P0001', 'invalid_input', 'PRC-03: cannot save another student attempt');
select throws_ok($$ select public.submit_attempt(pg_temp.att('unseen')) $$, 'P0001', 'invalid_input', 'PRC-03: cannot submit another student attempt');
select tests.authenticate_as('quiz_student');
select throws_ok($$ select public.save_answer(pg_temp.att('unseen'), pg_temp.q(1), 'B', 0, false, null, 4) $$, 'P0001', 'invalid_input', 'PRC-03: cannot save question outside attempt');
select throws_ok($$ select public.submit_attempt((select (session ->> 'attempt_id')::uuid from quiz_ctx)) $$, 'P0001', 'invalid_input', 'PRC-03: non-quiz attempt cannot submit');
select public.submit_attempt(pg_temp.att('unseen'));
select tests.clear_authentication();
reset role;
update public.topic_progress set quiz_last_failed_at = null where user_id = tests.get_supabase_uid('quiz_student');
update public.settings set value = '12' where key = 'quiz_size';
select tests.authenticate_as('quiz_student');
insert into ctx values ('pass', public.start_quiz('00000000-0000-0000-0000-0000000017d1'));
select is((select jsonb_array_length(v -> 'questions') from ctx where k = 'pass'), 12, 'PRC-03: start draws quiz_size');
select is((select count(*)::int from ctx, jsonb_array_elements(v -> 'questions') q where k = 'pass'
  and (q ->> 'id')::uuid not in (select pg_temp.q(i) from generate_series(1,15) i)), 0, 'PRC-03: draw excludes practice and draft questions');
select pg_temp.fill('pass', 9);
insert into ctx values ('pass_report', public.submit_attempt(pg_temp.att('pass')));
select is((select v from ctx where k = 'pass_report'), jsonb_build_object('score_raw',9,'score_total',12,'score_pct',75,'pass_mark',75,'passed',true,
  'next_topic',jsonb_build_object('id','00000000-0000-0000-0000-0000000017d2','title','T2'),'retake_at',null), 'LRN-03: exactly 9 of 12 passes at pass_mark and returns next topic');
select is(public.submit_attempt(pg_temp.att('pass')), (select v from ctx where k = 'pass_report'), 'PRC-03: submit is idempotent');
select is(public.get_course_map('quiz-course') #>> '{units,0,topics,1,status}', 'open', 'LRN-03: pass opens next topic in course map');
select tests.clear_authentication();
reset role;
select is((select quiz_passed_at is not null and quiz_best_score = 75 from public.topic_progress where user_id = tests.get_supabase_uid('quiz_student') and topic_id = '00000000-0000-0000-0000-0000000017d1'), true, 'LRN-03: pass timestamp and best score stored');
select is((select count(*)::int from public.attempt_answers where attempt_id = pg_temp.att('pass') and is_correct), 9, 'PRC-03: submit grades saved MCQ and equivalent SPR');
select is((select count(*)::int from public.attempt_answers where attempt_id = pg_temp.att('pass') and is_correct = false), 3, 'PRC-03: unanswered questions are stored as wrong');
select tests.authenticate_as('quiz_fail');
insert into ctx values ('fail', public.start_quiz('00000000-0000-0000-0000-0000000017d1'));
select pg_temp.fill('fail', 8);
insert into ctx values ('fail_report', public.submit_attempt(pg_temp.att('fail')));
select is((select v - 'retake_at' from ctx where k = 'fail_report'), '{"score_raw":8,"score_total":12,"score_pct":66.67,"pass_mark":75,"passed":false,"next_topic":null}'::jsonb, 'PRC-03: 8 of 12 fails');
select is((select (v ->> 'retake_at')::timestamptz from ctx where k = 'fail_report'), now() + interval '12 hours', 'PRC-03: failure reports cooldown timestamp');
select is(public.get_course_map('quiz-course') #>> '{units,0,topics,1,status}', 'locked', 'LRN-03: failure leaves next topic locked');
select tests.clear_authentication();
reset role;
select is((select quiz_last_failed_at = now() and quiz_passed_at is null from public.topic_progress where user_id = tests.get_supabase_uid('quiz_fail') and topic_id = '00000000-0000-0000-0000-0000000017d1'), true, 'PRC-03: failure timestamp stored without pass');
select tests.authenticate_as('quiz_student');
insert into ctx values ('retake', public.start_quiz('00000000-0000-0000-0000-0000000017d1'));
select public.submit_attempt(pg_temp.att('retake'));
select is(public.get_topic('00000000-0000-0000-0000-0000000017d1') #>> '{quiz,passed}', 'true', 'LRN-03: failed retake keeps pass');
select is((public.get_topic('00000000-0000-0000-0000-0000000017d1') #>> '{quiz,best_score_pct}')::numeric, 75::numeric, 'LRN-03: failed retake keeps best score');
insert into ctx values ('small', public.start_quiz('00000000-0000-0000-0000-0000000017d3'));
select is((select jsonb_array_length(v -> 'questions') from ctx where k = 'small'), 1, 'PRC-03: small quiz pool draws all available');
select throws_ok($$ select public.start_quiz('00000000-0000-0000-0000-0000000017d4') $$, 'P0001', 'pool_exhausted', 'PRC-03: empty quiz pool fails');
select tests.clear_authentication();
reset role;
update public.attempts set started_at = now() - make_interval(secs => time_limit_s + 1) where id = pg_temp.att('small');
select tests.authenticate_as('quiz_student');
select is(public.save_answer(pg_temp.att('small'), pg_temp.first_q('small'), 'B', 1, false, null, 1),
  '{"ok":true}'::jsonb, 'PRC-03: saves allowed inside deadline grace');
select tests.clear_authentication();
reset role;
update public.attempts set started_at = now() - make_interval(secs => time_limit_s + 31) where id = pg_temp.att('small');
select tests.authenticate_as('quiz_student');
select throws_ok($$ select public.save_answer(pg_temp.att('small'), pg_temp.first_q('small'), 'B', 1, false, null, 1) $$, 'P0001', 'deadline_passed', 'PRC-03: save after deadline plus grace rejected');
select is(public.get_topic('00000000-0000-0000-0000-0000000017d3') #>> '{quiz,passed}', 'true',
  'PRC-03: topic call grades the expired small quiz after rejected save');
select tests.clear_authentication();
reset role;
select is((select status = 'submitted' and submitted_at = started_at + make_interval(secs => time_limit_s)
  from public.attempts where id = pg_temp.att('small')), true, 'PRC-03: expiry preserves answer saved during grace');
select tests.authenticate_as('quiz_expiry');
insert into ctx values ('expiry', public.start_quiz('00000000-0000-0000-0000-0000000017d1'));
select pg_temp.fill('expiry', 9);
select tests.clear_authentication();
reset role;
update public.attempts set started_at = now() - make_interval(secs => time_limit_s + 31) where id = pg_temp.att('expiry');
select tests.authenticate_as('quiz_expiry');
select is(public.get_topic('00000000-0000-0000-0000-0000000017d1') #>> '{quiz,passed}', 'true', 'LRN-03: get_topic lazily grades overdue saved answers');
select tests.clear_authentication();
reset role;
select is((select (status = 'submitted' and score_raw = 9 and submitted_at = started_at + make_interval(secs => time_limit_s)) from public.attempts where id = pg_temp.att('expiry')), true, 'PRC-03: lazy expiry stamps original deadline');
select tests.authenticate_as('quiz_expiry');
insert into ctx values ('expiry_start', public.start_quiz('00000000-0000-0000-0000-0000000017d1'));
select pg_temp.fill('expiry_start', 9);
select tests.clear_authentication();
reset role;
update public.attempts set started_at = now() - make_interval(secs => time_limit_s + 31) where id = pg_temp.att('expiry_start');
select tests.authenticate_as('quiz_expiry');
insert into ctx values ('after_expiry', public.start_quiz('00000000-0000-0000-0000-0000000017d1'));
select is(pg_temp.att('after_expiry') <> pg_temp.att('expiry_start'), true, 'PRC-03: start replaces an overdue passing attempt');
select tests.clear_authentication();
reset role;
select is((select status = 'submitted' and score_raw = 9 from public.attempts where id = pg_temp.att('expiry_start')), true,
  'PRC-03: successful start persists lazy grading of previous answers');
update public.attempts set started_at = now() - make_interval(secs => time_limit_s + 31) where id = pg_temp.att('after_expiry');
select pg_temp.complete_review('quiz_expiry', '00000000-0000-0000-0000-0000000017d1');
select tests.authenticate_as('quiz_expiry');
select throws_ok($$ select public.start_quiz('00000000-0000-0000-0000-0000000017d1') $$, 'P0001', 'cooldown_active', 'PRC-03: start expires overdue quiz before cooldown check');
select is(public.get_topic('00000000-0000-0000-0000-0000000017d1') #>> '{quiz,state}', 'cooldown',
  'PRC-03: successful get_topic expires overdue failed quiz into cooldown');
select tests.clear_authentication();
reset role;
select is((select status::text from public.attempts where id = pg_temp.att('after_expiry')), 'submitted', 'PRC-03: successful get_topic persists overdue failed quiz grading');
select is((select tp.quiz_last_failed_at from public.topic_progress tp
  where tp.user_id = tests.get_supabase_uid('quiz_expiry') and tp.topic_id = '00000000-0000-0000-0000-0000000017d1'),
  (select started_at + make_interval(secs => time_limit_s) from public.attempts where id = pg_temp.att('after_expiry')),
  'PRC-03: lazy failure progress timestamp is the original deadline');
select is((select (meta #>> '{report,retake_at}')::timestamptz from public.attempts where id = pg_temp.att('after_expiry')),
  (select started_at + make_interval(secs => time_limit_s) + make_interval(hours => private.setting_int('cooldown_h'))
   from public.attempts where id = pg_temp.att('after_expiry')),
  'PRC-03: lazy failure retake time is deadline plus cooldown_h');


-- Active attempts still require access for saves and manual submits.
select tests.authenticate_as('quiz_expiry');
insert into ctx values ('access', public.start_quiz('00000000-0000-0000-0000-0000000017d3'));
select public.save_answer(pg_temp.att('access'), pg_temp.first_q('access'), 'B', 1, false, null, 1);
select tests.clear_authentication();
reset role;
update public.enrollments set expires_at = now() - interval '1 minute'
  where user_id = tests.get_supabase_uid('quiz_expiry');
select tests.authenticate_as('quiz_expiry');
select throws_ok($$ select public.save_answer(pg_temp.att('access'), pg_temp.first_q('access'), 'A', 2, false, null, 2) $$,
  'P0001', 'access_expired', 'PRC-03: save rechecks access during quiz');
select throws_ok($$ select public.submit_attempt(pg_temp.att('access')) $$,
  'P0001', 'access_expired', 'PRC-03: manual submit rechecks access during quiz');
select tests.clear_authentication();
reset role;
-- A broken SPR key proves expiry is attempted before the expired-access rejection.
update public.questions set type = 'spr' where id = pg_temp.q(17);
update private.question_keys set correct_answer = '{"accepted":"broken"}' where question_id = pg_temp.q(17);
update public.attempts set started_at = now() - make_interval(secs => time_limit_s + 31)
  where id = pg_temp.att('access');
select tests.authenticate_as('quiz_expiry');
select throws_ok($$ select public.get_topic('00000000-0000-0000-0000-0000000017d3') $$,
  'P0001', 'invalid_key', 'PRC-03: get_topic attempts overdue grading before expired-access check');
select tests.clear_authentication();
reset role;
update public.questions set type = 'mcq' where id = pg_temp.q(17);
update private.question_keys set correct_answer = '{"choice":"B"}' where question_id = pg_temp.q(17);

-- A retried successful submit must survive access expiry after a lost response.
update public.enrollments set expires_at = now() - interval '1 minute'
  where user_id = tests.get_supabase_uid('quiz_student')
    and course_id = '00000000-0000-0000-0000-0000000017c1';
select tests.authenticate_as('quiz_student');
select is(public.submit_attempt(pg_temp.att('pass')), (select v from ctx where k = 'pass_report'),
  'PRC-03: submitted attempt returns its original report after enrollment expires');
select tests.clear_authentication();
reset role;

select * from finish();
rollback;
