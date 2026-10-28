-- ANL-01: mastery is updated from graded answers (practice first try, quiz and homework submit) + backfill.
begin;
create extension if not exists pgtap with schema extensions;
select plan(14);

select tests.create_supabase_user('wire_a');
select tests.create_supabase_user('wire_b');
select tests.create_supabase_user('wire_c');

insert into public.courses (id, code, title, slug, is_published, sort) values
  ('00000000-0000-0000-0000-000000004501', 'SAT', 'Wiring Course', 'wiring-course', true, 1);
insert into public.units (id, course_id, title, sort) values
  ('00000000-0000-0000-0000-000000004502', '00000000-0000-0000-0000-000000004501', 'U1', 1);
insert into public.topics (id, course_id, unit_id, title, slug, sort, is_published, is_free_preview) values
  ('00000000-0000-0000-0000-000000004503', '00000000-0000-0000-0000-000000004501',
   '00000000-0000-0000-0000-000000004502', 'T1', 'wiring-t1', 1, true, true);
insert into public.subtopics (id, topic_id, title) values
  ('00000000-0000-0000-0000-000000004504', '00000000-0000-0000-0000-000000004503', 'S1');
insert into public.enrollments (user_id, course_id, status, starts_at, expires_at)
select tests.get_supabase_uid(u), '00000000-0000-0000-0000-000000004501', 'active',
       now() - interval '1 day', now() + interval '30 days'
from unnest(array['wire_a', 'wire_b']) u;

create function pg_temp.id(p_n int) returns uuid language sql immutable as $$
  select ('00000000-0000-0000-0000-0000000045' || lpad(p_n::text, 2, '0'))::uuid
$$;
-- skills 1..8 are ids 11..18; questions p1..p3 = 21..23, z1..z5 = 31..35, h1 = 41, b1..b4 = 51..54
insert into public.skills (id, code, name, domain)
select pg_temp.id(10 + i), 'T45-' || i, 'Wiring skill ' || i, 'Algebra' from generate_series(1, 8) i;
insert into public.questions (id, topic_id, subtopic_id, type, difficulty, stem_md, pool, status)
select pg_temp.id(v.n), '00000000-0000-0000-0000-000000004503', '00000000-0000-0000-0000-000000004504',
       'mcq', v.d::public.difficulty, 'Q' || v.n, v.pool::public.question_pool, 'published'
from (values
  (21, 'E', 'practice'), (22, 'M', 'practice'), (23, 'H', 'practice'),
  (31, 'E', 'quiz'), (32, 'M', 'quiz'), (33, 'H', 'quiz'), (34, 'M', 'quiz'), (35, 'E', 'quiz'),
  (41, 'M', 'practice'),
  (51, 'E', 'practice'), (52, 'M', 'practice'), (53, 'H', 'quiz'), (54, 'M', 'quiz')
) v(n, d, pool);
insert into public.question_choices (question_id, label, body_md)
select q.id, l.label, 'Choice ' || l.label from public.questions q
cross join (values ('A'), ('B'), ('C'), ('D')) l(label)
where q.topic_id = '00000000-0000-0000-0000-000000004503';
insert into private.question_keys (question_id, correct_answer, explanation_md)
select q.id, '{"choice":"B"}', 'Private' from public.questions q
where q.topic_id = '00000000-0000-0000-0000-000000004503';
-- Q34 (id 34) is deliberately untagged.
insert into public.question_skills (question_id, skill_id) values
  (pg_temp.id(21), pg_temp.id(11)), (pg_temp.id(22), pg_temp.id(12)), (pg_temp.id(23), pg_temp.id(13)),
  (pg_temp.id(31), pg_temp.id(14)), (pg_temp.id(32), pg_temp.id(14)), (pg_temp.id(33), pg_temp.id(15)),
  (pg_temp.id(35), pg_temp.id(16)), (pg_temp.id(41), pg_temp.id(17)),
  (pg_temp.id(51), pg_temp.id(18)), (pg_temp.id(52), pg_temp.id(18)),
  (pg_temp.id(53), pg_temp.id(18)), (pg_temp.id(54), pg_temp.id(18));

-- Attempts (ids 61.. are attempts): practice, review, quiz, overdue quiz, homework.
insert into public.attempts (id, user_id, kind, course_id, topic_id, status, started_at, time_limit_s) values
  (pg_temp.id(61), tests.get_supabase_uid('wire_a'), 'practice', '00000000-0000-0000-0000-000000004501', '00000000-0000-0000-0000-000000004503', 'in_progress', now(), null),
  (pg_temp.id(62), tests.get_supabase_uid('wire_a'), 'review',   '00000000-0000-0000-0000-000000004501', '00000000-0000-0000-0000-000000004503', 'in_progress', now(), null),
  (pg_temp.id(63), tests.get_supabase_uid('wire_a'), 'quiz',     '00000000-0000-0000-0000-000000004501', '00000000-0000-0000-0000-000000004503', 'in_progress', now(), 600),
  (pg_temp.id(64), tests.get_supabase_uid('wire_b'), 'quiz',     '00000000-0000-0000-0000-000000004501', '00000000-0000-0000-0000-000000004503', 'in_progress', now() - interval '2 hours', 60),
  (pg_temp.id(65), tests.get_supabase_uid('wire_a'), 'homework', '00000000-0000-0000-0000-000000004501', '00000000-0000-0000-0000-000000004503', 'in_progress', now(), null);
insert into public.attempt_questions (attempt_id, question_id, position) values
  (pg_temp.id(61), pg_temp.id(21), 1), (pg_temp.id(61), pg_temp.id(22), 2),
  (pg_temp.id(62), pg_temp.id(23), 1),
  (pg_temp.id(63), pg_temp.id(31), 1), (pg_temp.id(63), pg_temp.id(32), 2),
  (pg_temp.id(63), pg_temp.id(33), 3), (pg_temp.id(63), pg_temp.id(34), 4),
  (pg_temp.id(64), pg_temp.id(35), 1),
  (pg_temp.id(65), pg_temp.id(41), 1);

create function pg_temp.sm(p_user text, p_skill int) returns text language sql as $$
  select mastery::text || '/' || attempts::text || '/' || correct::text from public.skill_mastery
  where user_id = tests.get_supabase_uid(p_user) and skill_id = pg_temp.id(10 + p_skill)
$$;
grant execute on function pg_temp.id(int), pg_temp.sm(text, int) to authenticated;

-- Practice: only the first try moves mastery.
select tests.authenticate_as('wire_a');
select public.check_practice_answer(pg_temp.id(61), pg_temp.id(21), 'B', 1000);
select tests.clear_authentication();
reset role;
select is(pg_temp.sm('wire_a', 1), '53.00/1/1', 'ANL-01: practice_first_try_counts (easy, practice weight)');

select tests.authenticate_as('wire_a');
select public.check_practice_answer(pg_temp.id(61), pg_temp.id(21), 'B', 1000);
select public.check_practice_answer(pg_temp.id(61), pg_temp.id(22), 'A', 1000);
select public.check_practice_answer(pg_temp.id(61), pg_temp.id(22), 'B', 1000);
select tests.clear_authentication();
reset role;
select is(pg_temp.sm('wire_a', 1), '53.00/1/1', 'ANL-01: replaying the same answer does not count twice');
select is(pg_temp.sm('wire_a', 2), '46.25/1/0', 'ANL-01: practice_second_try_ignored (wrong first try stays the only signal)');

-- Review uses the practice weight.
select tests.authenticate_as('wire_a');
select public.check_practice_answer(pg_temp.id(62), pg_temp.id(23), 'B', 1000);
select tests.clear_authentication();
reset role;
select is(pg_temp.sm('wire_a', 3), '54.50/1/1', 'ANL-01: review_counts_as_practice_weight');

-- Quiz: saves do not count, submit counts once, unanswered is incorrect.
select tests.authenticate_as('wire_a');
select public.save_answer(pg_temp.id(63), pg_temp.id(31), 'B', 1000, false, array[]::text[], 1);
select public.save_answer(pg_temp.id(63), pg_temp.id(33), 'A', 1000, false, array[]::text[], 1);
select tests.clear_authentication();
reset role;
select is((select count(*)::int from public.skill_mastery
  where user_id = tests.get_supabase_uid('wire_a') and skill_id in (pg_temp.id(14), pg_temp.id(15))), 0,
  'ANL-01: quiz_save_answer_does_not_count');

select tests.authenticate_as('wire_a');
select public.submit_attempt(pg_temp.id(63));
select tests.clear_authentication();
reset role;
select is(pg_temp.sm('wire_a', 4), '46.90/2/1', 'ANL-01: quiz_unanswered_is_incorrect (submit counts every frozen question)');
select is(pg_temp.sm('wire_a', 5), '39.20/1/0', 'ANL-01: a wrong quiz answer on a hard question lowers mastery');

select tests.authenticate_as('wire_a');
select public.submit_attempt(pg_temp.id(63));
select tests.clear_authentication();
reset role;
select is(pg_temp.sm('wire_a', 4), '46.90/2/1', 'ANL-01: quiz_submit_counts_once (second submit changes nothing)');

-- Timer path: the overdue quiz is finished by expire_quiz, then submitted again by the student.
select private.expire_quiz(tests.get_supabase_uid('wire_b'), '00000000-0000-0000-0000-000000004503');
select private.expire_quiz(tests.get_supabase_uid('wire_b'), '00000000-0000-0000-0000-000000004503');
select tests.authenticate_as('wire_b');
select public.submit_attempt(pg_temp.id(64));
select tests.clear_authentication();
reset role;
select is(pg_temp.sm('wire_b', 6), '42.80/1/0', 'ANL-01: timer-path expiry counts once (unanswered easy quiz question)');

-- Homework submit counts.
select tests.authenticate_as('wire_a');
select public.save_answer(pg_temp.id(65), pg_temp.id(41), 'B', 1000, false, array[]::text[], 1);
select public.submit_attempt(pg_temp.id(65));
select tests.clear_authentication();
reset role;
select is(pg_temp.sm('wire_a', 7), '57.50/1/1', 'ANL-01: homework_submit_counts');

-- Backfill: history inserted without the triggers, then replayed in time order.
alter table public.attempt_answers disable trigger attempt_answers_mastery;
insert into public.attempts (id, user_id, kind, course_id, topic_id, status, started_at, submitted_at, time_limit_s) values
  (pg_temp.id(71), tests.get_supabase_uid('wire_c'), 'practice', '00000000-0000-0000-0000-000000004501', '00000000-0000-0000-0000-000000004503', 'submitted', '2026-10-01 09:00+00', '2026-10-01 12:00+00', null),
  (pg_temp.id(72), tests.get_supabase_uid('wire_c'), 'quiz',     '00000000-0000-0000-0000-000000004501', '00000000-0000-0000-0000-000000004503', 'submitted', '2026-10-02 11:00+00', '2026-10-02 12:00+00', 600);
insert into public.attempt_questions (attempt_id, question_id, position) values
  (pg_temp.id(71), pg_temp.id(51), 1), (pg_temp.id(71), pg_temp.id(52), 2),
  (pg_temp.id(72), pg_temp.id(53), 1), (pg_temp.id(72), pg_temp.id(54), 2);
insert into public.attempt_answers (attempt_id, question_id, answer, is_correct, time_ms, answered_at) values
  (pg_temp.id(71), pg_temp.id(51), '{"tries":["B"]}', true,  1000, '2026-10-01 10:00+00'),
  (pg_temp.id(71), pg_temp.id(52), '{"tries":["A","B"]}', true, 2000, '2026-10-01 11:00+00'),
  (pg_temp.id(72), pg_temp.id(53), '{"value":"B"}', true,  1000, '2026-10-02 11:30+00'),
  (pg_temp.id(72), pg_temp.id(54), '{"value":null}', false, 0, '2026-10-02 12:00+00');
alter table public.attempt_answers enable trigger attempt_answers_mastery;

create temp table before_backfill as
  select skill_id, mastery, attempts, correct from public.skill_mastery
  where user_id = tests.get_supabase_uid('wire_a');
select private.backfill_mastery();
select is(pg_temp.sm('wire_c', 8), '49.23/4/2', 'ANL-01: backfill_replays_history (first tries, then quiz in time order)');
select is((select array_agg(day::text || '=' || mastery::text order by day) from public.skill_mastery_daily
  where user_id = tests.get_supabase_uid('wire_c')), array['2026-10-01=49.03', '2026-10-02=49.23'],
  'ANL-01: backfill writes one daily row per day');
select is((select count(*)::int from (
    select skill_id, mastery, attempts, correct from public.skill_mastery where user_id = tests.get_supabase_uid('wire_a')
    except select skill_id, mastery, attempts, correct from before_backfill) d), 0,
  'ANL-01: backfill reproduces what the live triggers computed');
select private.backfill_mastery();
select is(pg_temp.sm('wire_c', 8), '49.23/4/2', 'ANL-01: backfill_is_deterministic (a second run gives the same result)');

select * from finish();
rollback;
