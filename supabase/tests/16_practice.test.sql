-- PRC-01 / LRN-02 — get_practice_questions, check_practice_answer (docs/07 §1).
-- Spec: docs/superpowers/specs/2026-10-17-p1-practice-design.md §1.
begin;
create extension if not exists pgtap with schema extensions;
select plan(67);

select tests.create_supabase_user('a');  -- active
select tests.create_supabase_user('b');  -- active, second student
select tests.create_supabase_user('c');  -- enrolment status expired
select tests.create_supabase_user('d');  -- no enrolment
select tests.create_supabase_user('f');  -- active but past expires_at

insert into public.courses (id, code, title, slug, is_published, sort) values
  ('00000000-0000-0000-0000-0000000001c1', 'SAT', 'PR Course', 'pr-course', true, 1);
insert into public.units (id, course_id, title, sort) values
  ('00000000-0000-0000-0000-0000000001a1', '00000000-0000-0000-0000-0000000001c1', 'U1', 1);
-- t1 open (first), t2 locked, t3/t4/t5 free previews (open), tx unpublished.
insert into public.topics (id, course_id, unit_id, title, slug, sort, is_published, is_free_preview) values
  ('00000000-0000-0000-0000-0000000001d1', '00000000-0000-0000-0000-0000000001c1', '00000000-0000-0000-0000-0000000001a1', 'T1', 't1', 1, true,  false),
  ('00000000-0000-0000-0000-0000000001d2', '00000000-0000-0000-0000-0000000001c1', '00000000-0000-0000-0000-0000000001a1', 'T2', 't2', 2, true,  false),
  ('00000000-0000-0000-0000-0000000001d3', '00000000-0000-0000-0000-0000000001c1', '00000000-0000-0000-0000-0000000001a1', 'T3', 't3', 3, true,  true),
  ('00000000-0000-0000-0000-0000000001d4', '00000000-0000-0000-0000-0000000001c1', '00000000-0000-0000-0000-0000000001a1', 'T4', 't4', 4, true,  true),
  ('00000000-0000-0000-0000-0000000001d5', '00000000-0000-0000-0000-0000000001c1', '00000000-0000-0000-0000-0000000001a1', 'T5', 't5', 5, true,  true),
  ('00000000-0000-0000-0000-0000000001d9', '00000000-0000-0000-0000-0000000001c1', '00000000-0000-0000-0000-0000000001a1', 'TX', 'tx', 9, false, false);
insert into public.subtopics (id, topic_id, title)
  select ('00000000-0000-0000-0000-0000000002' || right(t.id::text, 2))::uuid, t.id, 'S'
  from public.topics t where t.course_id = '00000000-0000-0000-0000-0000000001c1';

-- T1: 2 MCQ + 2 SPR practice questions, plus a quiz-pool and a draft one that must never be drawn.
insert into public.questions (id, topic_id, subtopic_id, type, difficulty, stem_md, hint_md, pool, status) values
  ('00000000-0000-0000-0000-000000000e01', '00000000-0000-0000-0000-0000000001d1', '00000000-0000-0000-0000-0000000002d1', 'mcq', 'E', 'Stem one',   'H1', 'practice', 'published'),
  ('00000000-0000-0000-0000-000000000e02', '00000000-0000-0000-0000-0000000001d1', '00000000-0000-0000-0000-0000000002d1', 'mcq', 'M', 'Stem two',   'H2', 'practice', 'published'),
  ('00000000-0000-0000-0000-000000000e03', '00000000-0000-0000-0000-0000000001d1', '00000000-0000-0000-0000-0000000002d1', 'spr', 'H', 'Stem three', 'H3', 'practice', 'published'),
  ('00000000-0000-0000-0000-000000000e04', '00000000-0000-0000-0000-0000000001d1', '00000000-0000-0000-0000-0000000002d1', 'spr', 'E', 'Stem four',  'H4', 'practice', 'published'),
  ('00000000-0000-0000-0000-000000000e05', '00000000-0000-0000-0000-0000000001d1', '00000000-0000-0000-0000-0000000002d1', 'mcq', 'E', 'Stem quiz',  null, 'quiz',     'published'),
  ('00000000-0000-0000-0000-000000000e06', '00000000-0000-0000-0000-0000000001d1', '00000000-0000-0000-0000-0000000002d1', 'mcq', 'E', 'Stem draft', null, 'practice', 'draft'),
  -- T2 (locked for a fresh student)
  ('00000000-0000-0000-0000-000000000e21', '00000000-0000-0000-0000-0000000001d2', '00000000-0000-0000-0000-0000000002d2', 'mcq', 'E', 'Stem t2',    'H',  'practice', 'published'),
  -- T5: one SPR with a malformed key
  ('00000000-0000-0000-0000-000000000e51', '00000000-0000-0000-0000-0000000001d5', '00000000-0000-0000-0000-0000000002d5', 'spr', 'E', 'Stem t5',    'H',  'practice', 'published'),
  -- unpublished topic
  ('00000000-0000-0000-0000-000000000e91', '00000000-0000-0000-0000-0000000001d9', '00000000-0000-0000-0000-0000000002d9', 'mcq', 'E', 'Stem tx',    'H',  'practice', 'published');
-- T3: 12 practice questions (T4 has none).
insert into public.questions (id, topic_id, subtopic_id, type, difficulty, stem_md, pool, status)
  select ('00000000-0000-0000-0000-000000000f' || lpad(g::text, 2, '0'))::uuid,
         '00000000-0000-0000-0000-0000000001d3', '00000000-0000-0000-0000-0000000002d3',
         'spr', 'E', 'Stem ' || g, 'practice', 'published'
  from generate_series(1, 12) g;

insert into public.question_choices (question_id, label, body_md)
  select q.id, l.label, 'Choice ' || l.label
  from (values ('00000000-0000-0000-0000-000000000e01'::uuid), ('00000000-0000-0000-0000-000000000e02'),
               ('00000000-0000-0000-0000-000000000e05'), ('00000000-0000-0000-0000-000000000e06'),
               ('00000000-0000-0000-0000-000000000e21'), ('00000000-0000-0000-0000-000000000e91')) q(id)
  cross join (values ('A'), ('B'), ('C'), ('D')) l(label);

insert into private.question_keys (question_id, correct_answer, explanation_md, misconceptions) values
  ('00000000-0000-0000-0000-000000000e01', '{"choice":"B"}',                 'E1', '{"A":"N1a"}'),
  ('00000000-0000-0000-0000-000000000e02', '{"choice":"C"}',                 'E2', '{"A":"N2a"}'),
  ('00000000-0000-0000-0000-000000000e03', '{"accepted":["1/2"],"tolerance":0}', 'E3', null),
  ('00000000-0000-0000-0000-000000000e04', '{"accepted":["3"]}',             'E4', null),
  ('00000000-0000-0000-0000-000000000e05', '{"choice":"A"}',                 'E5', null),
  ('00000000-0000-0000-0000-000000000e06', '{"choice":"A"}',                 'E6', null),
  ('00000000-0000-0000-0000-000000000e21', '{"choice":"A"}',                 'E21', null),
  ('00000000-0000-0000-0000-000000000e51', '{"accepted":"7"}',               'E51', null),
  ('00000000-0000-0000-0000-000000000e91', '{"choice":"A"}',                 'E91', null);
insert into private.question_keys (question_id, correct_answer, explanation_md)
  select q.id, '{"accepted":["1"]}', 'EF' from public.questions q
  where q.topic_id = '00000000-0000-0000-0000-0000000001d3';

insert into public.enrollments (user_id, course_id, status, starts_at, expires_at) values
  (tests.get_supabase_uid('a'), '00000000-0000-0000-0000-0000000001c1', 'active',  now() - interval '1 day',   now() + interval '30 days'),
  (tests.get_supabase_uid('b'), '00000000-0000-0000-0000-0000000001c1', 'active',  now() - interval '1 day',   now() + interval '30 days'),
  (tests.get_supabase_uid('c'), '00000000-0000-0000-0000-0000000001c1', 'expired', now() - interval '1 day',   now() + interval '30 days'),
  (tests.get_supabase_uid('f'), '00000000-0000-0000-0000-0000000001c1', 'active',  now() - interval '10 days', now() - interval '1 day');

-- Attempts made directly (bypassing the draw): a on locked T2, c (expired) on T1.
insert into public.attempts (id, user_id, kind, course_id, topic_id) values
  ('00000000-0000-0000-0000-0000000003a2', tests.get_supabase_uid('a'), 'practice', '00000000-0000-0000-0000-0000000001c1', '00000000-0000-0000-0000-0000000001d2'),
  ('00000000-0000-0000-0000-0000000003c1', tests.get_supabase_uid('c'), 'practice', '00000000-0000-0000-0000-0000000001c1', '00000000-0000-0000-0000-0000000001d1');
insert into public.attempt_questions (attempt_id, question_id, position) values
  ('00000000-0000-0000-0000-0000000003a2', '00000000-0000-0000-0000-000000000e21', 1),
  ('00000000-0000-0000-0000-0000000003c1', '00000000-0000-0000-0000-000000000e01', 1);

-- Shared values between role switches.
create temp table ctx (k text primary key, v jsonb);
grant select, insert, update on ctx to authenticated;
create function pg_temp.att(p_k text) returns uuid language sql as $$ select (v ->> 'attempt_id')::uuid from ctx where k = p_k $$;
create function pg_temp.ids(p_k text) returns uuid[] language sql as $$
  select array_agg((q ->> 'id')::uuid order by (q ->> 'id')) from ctx, jsonb_array_elements(v -> 'questions') q where k = p_k
$$;
create function pg_temp.chk(p_k text, p_q text, p_ans text, p_ms int default 1000) returns jsonb language sql as $$
  select public.check_practice_answer(pg_temp.att(p_k), ('00000000-0000-0000-0000-000000000' || p_q)::uuid, p_ans, p_ms)
$$;
create function pg_temp.pcount(p_user text) returns int language sql security definer as $$
  select coalesce((select practice_count from public.topic_progress
                   where user_id = tests.get_supabase_uid(p_user) and topic_id = '00000000-0000-0000-0000-0000000001d1'), 0)
$$;
grant execute on function pg_temp.att(text), pg_temp.ids(text), pg_temp.chk(text, text, text, int), pg_temp.pcount(text) to authenticated;

-- Anonymous: no grant at all.
select tests.clear_authentication();
set local role anon;
select throws_ok($$ select public.get_practice_questions('00000000-0000-0000-0000-0000000001d1') $$, '42501', null,
                 'PRC-01: anon cannot execute get_practice_questions');
select throws_ok($$ select public.check_practice_answer('00000000-0000-0000-0000-0000000003c1', '00000000-0000-0000-0000-000000000e01', 'A', 1) $$,
                 '42501', null, 'PRC-01: anon cannot execute check_practice_answer');
reset role;

-- Authenticated role but no user.
set local role authenticated;
select throws_ok($$ select public.get_practice_questions('00000000-0000-0000-0000-0000000001d1') $$, 'P0001', 'not_authenticated',
                 'PRC-01: no session -> get not_authenticated');
select throws_ok($$ select public.check_practice_answer('00000000-0000-0000-0000-0000000003c1', '00000000-0000-0000-0000-000000000e01', 'A', 1) $$,
                 'P0001', 'not_authenticated', 'PRC-01: no session -> check not_authenticated');
select throws_ok($$ select * from private.topic_states(gen_random_uuid(), gen_random_uuid()) $$, '42501', null,
                 'PRC-01: authenticated cannot execute private.topic_states');
select throws_ok($$ select private.practice_access(gen_random_uuid(), gen_random_uuid()) $$, '42501', null,
                 'PRC-01: authenticated cannot execute private.practice_access');
reset role;

-- Topic / enrolment / lock errors.
select tests.authenticate_as('a');
select throws_ok($$ select public.get_practice_questions(gen_random_uuid()) $$, 'P0001', 'invalid_input',
                 'PRC-01: unknown topic -> invalid_input');
select throws_ok($$ select public.get_practice_questions('00000000-0000-0000-0000-0000000001d9') $$, 'P0001', 'invalid_input',
                 'PRC-01: unpublished topic -> invalid_input');
select throws_ok($$ select public.get_practice_questions(null) $$, 'P0001', 'invalid_input',
                 'PRC-01: null topic -> invalid_input');
select throws_ok($$ select public.get_practice_questions('00000000-0000-0000-0000-0000000001d2') $$, 'P0001', 'topic_locked',
                 'PRC-01: locked topic -> get topic_locked');
select throws_ok($$ select public.check_practice_answer('00000000-0000-0000-0000-0000000003a2', '00000000-0000-0000-0000-000000000e21', 'A', 1) $$,
                 'P0001', 'topic_locked', 'PRC-01: locked topic -> check topic_locked');
select throws_ok($$ select public.get_practice_questions('00000000-0000-0000-0000-0000000001d4') $$, 'P0001', 'pool_exhausted',
                 'PRC-01: topic without practice questions -> pool_exhausted');
select tests.authenticate_as('d');
select throws_ok($$ select public.get_practice_questions('00000000-0000-0000-0000-0000000001d1') $$, 'P0001', 'not_enrolled',
                 'PRC-01: no enrolment -> not_enrolled');
select tests.authenticate_as('c');
select throws_ok($$ select public.get_practice_questions('00000000-0000-0000-0000-0000000001d1') $$, 'P0001', 'access_expired',
                 'PRC-01: expired enrolment -> get access_expired');
select throws_ok($$ select public.check_practice_answer('00000000-0000-0000-0000-0000000003c1', '00000000-0000-0000-0000-000000000e01', 'B', 1) $$,
                 'P0001', 'access_expired', 'PRC-01: expired enrolment -> check access_expired');
select tests.authenticate_as('f');
select throws_ok($$ select public.get_practice_questions('00000000-0000-0000-0000-0000000001d1') $$, 'P0001', 'access_expired',
                 'PRC-01: active but past expires_at -> access_expired');

-- Course map before any practice (compared at the end).
select tests.authenticate_as('a');
insert into ctx values ('map_before', public.get_course_map('pr-course'));

-- Draw: T1 has 4 eligible questions (< practice_min 10).
insert into ctx values ('a1', public.get_practice_questions('00000000-0000-0000-0000-0000000001d1'));
select is((select jsonb_array_length(v -> 'questions') from ctx where k = 'a1'), 4,
          'PRC-01: smaller pool -> every eligible question');
select is((select (v ->> 'rep_target')::int from ctx where k = 'a1'), 4, 'PRC-01: rep_target = questions returned');
select is(pg_temp.ids('a1'), array['00000000-0000-0000-0000-000000000e01', '00000000-0000-0000-0000-000000000e02',
                                   '00000000-0000-0000-0000-000000000e03', '00000000-0000-0000-0000-000000000e04']::uuid[],
          'PRC-01: only published practice-pool questions of the topic');
select is((select v::text ~* '(correct_answer|explanation|hint|misconception)' from ctx where k = 'a1'), false,
          'PRC-01: payload has no key, explanation, hint or misconceptions');
select is((select q from ctx, jsonb_array_elements(v -> 'questions') q
           where k = 'a1' and q ->> 'id' = '00000000-0000-0000-0000-000000000e01'),
          '{"id":"00000000-0000-0000-0000-000000000e01","type":"mcq","difficulty":"E","stem_md":"Stem one",
            "choices":[{"label":"A","body_md":"Choice A"},{"label":"B","body_md":"Choice B"},
                       {"label":"C","body_md":"Choice C"},{"label":"D","body_md":"Choice D"}]}'::jsonb,
          'PRC-01: MCQ question shape');
select is((select q -> 'choices' from ctx, jsonb_array_elements(v -> 'questions') q
           where k = 'a1' and q ->> 'id' = '00000000-0000-0000-0000-000000000e03'),
          '[]'::jsonb, 'PRC-01: SPR question has empty choices');
select tests.clear_authentication();
reset role;
select is((select array_agg(position order by position) from public.attempt_questions where attempt_id = pg_temp.att('a1')),
          array[1, 2, 3, 4], 'PRC-01: attempt_questions positions 1..n');
select is((select (kind, status, topic_id, course_id)::text from public.attempts where id = pg_temp.att('a1')),
          '(practice,in_progress,00000000-0000-0000-0000-0000000001d1,00000000-0000-0000-0000-0000000001c1)',
          'PRC-01: practice attempt row created');
select is((select count(*)::int from public.question_exposure
           where user_id = tests.get_supabase_uid('a') and question_id = any (pg_temp.ids('a1'))), 4,
          'PRC-01: drawn questions recorded in question_exposure');
select is((select q ->> 'id' from ctx, jsonb_array_elements(v -> 'questions') q
           where k = 'a1' and (q ->> 'id')::uuid = (select question_id from public.attempt_questions
                                                    where attempt_id = pg_temp.att('a1') and position = 1)),
          (select v #>> '{questions,0,id}' from ctx where k = 'a1'),
          'PRC-01: questions returned in position order');

-- Unseen first: a has seen 8 of T3's 12; with practice_min 4 the set is exactly the 4 unseen.
insert into public.question_exposure (user_id, question_id)
  select tests.get_supabase_uid('a'), q.id from public.questions q
  where q.topic_id = '00000000-0000-0000-0000-0000000001d3' and q.id <= '00000000-0000-0000-0000-000000000f08';
update public.settings set value = '4'::jsonb where key = 'practice_min';
select tests.authenticate_as('a');
insert into ctx values ('a3', public.get_practice_questions('00000000-0000-0000-0000-0000000001d3'));
select is(pg_temp.ids('a3'), array['00000000-0000-0000-0000-000000000f09', '00000000-0000-0000-0000-000000000f10',
                                   '00000000-0000-0000-0000-000000000f11', '00000000-0000-0000-0000-000000000f12']::uuid[],
          'PRC-01: never-seen questions are drawn first');

-- Size = practice_min.
select tests.clear_authentication();
reset role;
update public.settings set value = '5'::jsonb where key = 'practice_min';
select tests.authenticate_as('b');
insert into ctx values ('b3', public.get_practice_questions('00000000-0000-0000-0000-0000000001d3'));
select is((select jsonb_array_length(v -> 'questions') from ctx where k = 'b3'), 5, 'PRC-01: set size = settings.practice_min');
select is((select (v ->> 'rep_target')::int from ctx where k = 'b3'), 5, 'PRC-01: rep_target = practice_min when the pool is larger');
select tests.clear_authentication();
reset role;
update public.settings set value = '10'::jsonb where key = 'practice_min';

-- Check: MCQ correct on try 1 (case-insensitive label).
select tests.authenticate_as('a');
select is(pg_temp.chk('a1', 'e01', ' b '),
          '{"is_correct":true,"try":1,"key":{"choice":"B"},"explanation_md":"E1"}'::jsonb,
          'PRC-01: MCQ correct -> key + explanation');
select is(pg_temp.pcount('a'), 1, 'PRC-01: first answer counts towards practice_count');

-- MCQ wrong try 1 -> hint + misconception, no key.
select is(pg_temp.chk('a1', 'e02', 'a'),
          '{"is_correct":false,"try":1,"hint_md":"H2","misconception_md":"N2a"}'::jsonb,
          'PRC-01: MCQ wrong try 1 -> hint + misconception, no key');
select is(pg_temp.pcount('a'), 2, 'PRC-01: wrong try 1 counts towards practice_count');
-- Replay of try 1.
select is(pg_temp.chk('a1', 'e02', 'A'),
          '{"is_correct":false,"try":1,"hint_md":"H2","misconception_md":"N2a"}'::jsonb,
          'PRC-01: replay of try 1 -> same response');
select is(pg_temp.pcount('a'), 2, 'PRC-01: replay does not count');
-- Wrong try 2 -> key + explanation.
select is(pg_temp.chk('a1', 'e02', 'D', 1500),
          '{"is_correct":false,"try":2,"key":{"choice":"C"},"explanation_md":"E2"}'::jsonb,
          'PRC-01: MCQ wrong try 2 -> key + explanation');
select is(pg_temp.pcount('a'), 2, 'PRC-01: try 2 does not count');
-- Replay of try 2.
select is(pg_temp.chk('a1', 'e02', 'd'),
          '{"is_correct":false,"try":2,"key":{"choice":"C"},"explanation_md":"E2"}'::jsonb,
          'PRC-01: replay of try 2 -> key again');
select throws_ok($$ select pg_temp.chk('a1', 'e02', 'B') $$, 'P0001', 'invalid_input',
                 'PRC-01: third distinct answer -> invalid_input');
select throws_ok($$ select pg_temp.chk('a1', 'e01', 'A') $$, 'P0001', 'invalid_input',
                 'PRC-01: another answer after a correct one -> invalid_input');
select is(pg_temp.chk('a1', 'e01', 'B'),
          '{"is_correct":true,"try":1,"key":{"choice":"B"},"explanation_md":"E1"}'::jsonb,
          'PRC-01: replay of a correct answer -> same response');

-- SPR.
select is(pg_temp.chk('a1', 'e03', ' .5 '),
          '{"is_correct":true,"try":1,"key":{"text":"1/2"},"explanation_md":"E3"}'::jsonb,
          'PRC-01: SPR equivalent form graded correct, key is the first accepted form');
select is(pg_temp.chk('a1', 'e04', 'abc', -5),
          '{"is_correct":false,"try":1,"hint_md":"H4","misconception_md":null}'::jsonb,
          'PRC-01: malformed SPR answer is wrong, not an error');
select is(pg_temp.chk('a1', 'e04', '3', 99999999),
          '{"is_correct":true,"try":2,"key":{"text":"3"},"explanation_md":"E4"}'::jsonb,
          'PRC-01: SPR correct on try 2 -> key + explanation');
select is(pg_temp.pcount('a'), 4, 'PRC-01: practice_count = distinct questions answered');

-- Input validation.
select throws_ok($$ select pg_temp.chk('a1', 'e03', '  ') $$, 'P0001', 'invalid_input',
                 'PRC-01: empty answer -> invalid_input');
select throws_ok($$ select pg_temp.chk('a1', 'e03', repeat('1', 33)) $$, 'P0001', 'invalid_input',
                 'PRC-01: answer over 32 chars -> invalid_input');
select throws_ok($$ select pg_temp.chk('a1', 'e03', null) $$, 'P0001', 'invalid_input',
                 'PRC-01: null answer -> invalid_input');
select throws_ok($$ select pg_temp.chk('a1', 'e05', 'A') $$, 'P0001', 'invalid_input',
                 'PRC-01: question not in the attempt -> invalid_input');
select throws_ok($$ select public.check_practice_answer(gen_random_uuid(), '00000000-0000-0000-0000-000000000e01', 'A', 1) $$,
                 'P0001', 'invalid_input', 'PRC-01: unknown attempt -> invalid_input');

-- Logged rows.
select tests.clear_authentication();
reset role;
select is((select (answer, is_correct, time_ms)::text from public.attempt_answers
           where attempt_id = pg_temp.att('a1') and question_id = '00000000-0000-0000-0000-000000000e02'),
          '("{""tries"": [""A"", ""D""]}",f,2500)', 'PRC-01: tries stored, time_ms summed, replays not logged');
select is((select (answer, is_correct, time_ms)::text from public.attempt_answers
           where attempt_id = pg_temp.att('a1') and question_id = '00000000-0000-0000-0000-000000000e04'),
          '("{""tries"": [""abc"", ""3""]}",t,3600000)', 'PRC-01: time_ms clamped to 0..3600000');
select is((select count(*)::int from public.attempt_answers where attempt_id = pg_temp.att('a1')), 4,
          'PRC-01: one attempt_answers row per question');
select is((select answered_at is not null from public.attempt_answers
           where attempt_id = pg_temp.att('a1') and question_id = '00000000-0000-0000-0000-000000000e01'), true,
          'PRC-01: answered_at set');
select is((select status::text from public.attempts where id = pg_temp.att('a1')), 'in_progress',
          'PRC-01: practice attempt stays in_progress');
select is((select (quiz_passed_at, quiz_best_score, unlocked_at)::text from public.topic_progress
           where user_id = tests.get_supabase_uid('a') and topic_id = '00000000-0000-0000-0000-0000000001d1'),
          '(,,)', 'PRC-01: practice never touches quiz or unlock fields');

-- Another student's attempt.
select tests.authenticate_as('b');
select throws_ok($$ select pg_temp.chk('a1', 'e03', '1') $$, 'P0001', 'invalid_input',
                 'PRC-01: other student attempt -> invalid_input');
select throws_ok($$ select pg_temp.chk('a1', 'e01', 'B') $$, 'P0001', 'invalid_input',
                 'PRC-01: other student cannot replay an answer');
select tests.clear_authentication();
reset role;
select is(pg_temp.pcount('b'), 0, 'PRC-01: other student practice_count untouched');

-- Second set: re-answering a question does not count again.
select tests.authenticate_as('a');
insert into ctx values ('a2', public.get_practice_questions('00000000-0000-0000-0000-0000000001d1'));
select isnt(pg_temp.att('a2'), pg_temp.att('a1'), 'PRC-01: a new set is a new attempt');
select is(pg_temp.chk('a2', 'e01', 'C'),
          '{"is_correct":false,"try":1,"hint_md":"H1","misconception_md":null}'::jsonb,
          'PRC-01: a new set grades again from try 1');
select is(pg_temp.pcount('a'), 4, 'PRC-01: question repeated in a second set is not counted again');

-- Submitted / non-practice attempts are not answerable.
select tests.clear_authentication();
reset role;
update public.attempts set status = 'submitted' where id = pg_temp.att('a2');
select tests.authenticate_as('a');
select throws_ok($$ select pg_temp.chk('a2', 'e02', 'C') $$, 'P0001', 'invalid_input',
                 'PRC-01: attempt not in_progress -> invalid_input');
select tests.clear_authentication();
reset role;
update public.attempts set status = 'in_progress', kind = 'quiz' where id = pg_temp.att('a2');
select tests.authenticate_as('a');
select throws_ok($$ select pg_temp.chk('a2', 'e02', 'C') $$, 'P0001', 'invalid_input',
                 'PRC-01: non-practice attempt -> invalid_input');

-- Enrolment ends mid-set: check re-runs access.
select tests.clear_authentication();
reset role;
update public.enrollments set expires_at = now() - interval '1 minute'
  where user_id = tests.get_supabase_uid('b');
select tests.authenticate_as('b');
select throws_ok($$ select public.check_practice_answer(pg_temp.att('b3'), (select (v #>> '{questions,0,id}')::uuid from ctx where k = 'b3'), '1', 1) $$,
                 'P0001', 'access_expired', 'PRC-01: access re-checked on every answer');

-- A malformed key still fails loudly.
select tests.authenticate_as('a');
insert into ctx values ('a5', public.get_practice_questions('00000000-0000-0000-0000-0000000001d5'));
select throws_ok($$ select pg_temp.chk('a5', 'e51', '7') $$, 'P0001', 'invalid_key',
                 'PRC-01: malformed SPR key raises invalid_key');

-- Course map unaffected by practice rows.
select is(public.get_course_map('pr-course'), (select v from ctx where k = 'map_before'),
          'PRC-01: get_course_map output unchanged by practice');

select * from finish();
rollback;
