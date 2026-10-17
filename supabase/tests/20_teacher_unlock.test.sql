-- LRN-05 / L-9: teacher unlock authorization and idempotency. From templates/test.sql.
begin;
create extension if not exists pgtap with schema extensions;
select plan(27);

select tests.create_supabase_user('unlock_student');
select tests.create_supabase_user('unlock_other');
select tests.create_supabase_user('unlock_teacher');
select tests.create_supabase_user('unlock_teacher_b');
update public.profiles set role = 'teacher'
where id in (tests.get_supabase_uid('unlock_teacher'), tests.get_supabase_uid('unlock_teacher_b'));

insert into public.courses (id, code, title, slug, is_published, sort) values
  ('00000000-0000-0000-0000-0000000020c1', 'SAT', 'Unlock Course', 'unlock-course', true, 1);
insert into public.units (id, course_id, title, sort) values
  ('00000000-0000-0000-0000-0000000020a1', '00000000-0000-0000-0000-0000000020c1', 'U1', 1);
insert into public.topics (id, course_id, unit_id, title, slug, sort, is_published) values
  ('00000000-0000-0000-0000-0000000020d1', '00000000-0000-0000-0000-0000000020c1',
   '00000000-0000-0000-0000-0000000020a1', 'T1', 'unlock-t1', 1, true),
  ('00000000-0000-0000-0000-0000000020d2', '00000000-0000-0000-0000-0000000020c1',
   '00000000-0000-0000-0000-0000000020a1', 'T2', 'unlock-t2', 2, true),
  ('00000000-0000-0000-0000-0000000020d3', '00000000-0000-0000-0000-0000000020c1',
   '00000000-0000-0000-0000-0000000020a1', 'Draft', 'unlock-draft', 3, false);
insert into public.topic_progress (user_id, topic_id, practice_count, unlocked_at, unlocked_by) values
  (tests.get_supabase_uid('unlock_student'), '00000000-0000-0000-0000-0000000020d2', 3, null, null),
  (tests.get_supabase_uid('unlock_other'), '00000000-0000-0000-0000-0000000020d2', 0,
   now() - interval '1 day', tests.get_supabase_uid('unlock_teacher'));
create temp table unlock_ctx (k text primary key, v jsonb);
grant select, insert on unlock_ctx to authenticated;

select is(has_function_privilege('anon', 'public.teacher_unlock_topic(uuid,uuid)', 'execute'), false,
  'SEC: teacher unlock is not executable by anon');
select is(has_function_privilege('authenticated', 'public.teacher_unlock_topic(uuid,uuid)', 'execute'), true,
  'SEC: teacher unlock is executable by authenticated');
select tests.clear_authentication();
set local role anon;
select throws_ok($$ select public.teacher_unlock_topic(null, null) $$, '42501', null,
  'SEC: anon cannot execute teacher unlock');
reset role;
set local role authenticated;
select throws_ok($$ select public.teacher_unlock_topic(null, null) $$, 'P0001', 'not_authenticated',
  'LRN-05: anonymous session gets not_authenticated');
reset role;
select tests.authenticate_as('unlock_student');
select throws_ok($$ select public.teacher_unlock_topic(tests.get_supabase_uid('unlock_student'),
  '00000000-0000-0000-0000-0000000020d2') $$, 'P0001', 'forbidden', 'LRN-05: student gets forbidden');

select tests.authenticate_as('unlock_teacher');
select throws_ok($$ select public.teacher_unlock_topic('00000000-0000-0000-0000-000000002099',
  '00000000-0000-0000-0000-0000000020d2') $$, 'P0001', 'invalid_input', 'LRN-05: unknown student is invalid');
select throws_ok($$ select public.teacher_unlock_topic(tests.get_supabase_uid('unlock_teacher'),
  '00000000-0000-0000-0000-0000000020d2') $$, 'P0001', 'invalid_input', 'LRN-05: teacher as target is invalid');
select throws_ok($$ select public.teacher_unlock_topic(tests.get_supabase_uid('unlock_student'),
  '00000000-0000-0000-0000-000000002098') $$, 'P0001', 'invalid_input', 'LRN-05: unknown topic is invalid');
select throws_ok($$ select public.teacher_unlock_topic(tests.get_supabase_uid('unlock_student'),
  '00000000-0000-0000-0000-0000000020d3') $$, 'P0001', 'invalid_input', 'LRN-05: unpublished topic is invalid');
select throws_ok($$ select public.teacher_unlock_topic(null, '00000000-0000-0000-0000-0000000020d2') $$,
  'P0001', 'invalid_input', 'LRN-05: null student is invalid');
select throws_ok($$ select public.teacher_unlock_topic(tests.get_supabase_uid('unlock_student'), null) $$,
  'P0001', 'invalid_input', 'LRN-05: null topic is invalid');
select throws_ok($$ select public.teacher_unlock_topic(null, null) $$,
  'P0001', 'invalid_input', 'LRN-05: null arguments are invalid');
select tests.clear_authentication();
reset role;
select is((select status from private.topic_states(tests.get_supabase_uid('unlock_student'),
  '00000000-0000-0000-0000-0000000020c1') where topic_id = '00000000-0000-0000-0000-0000000020d2'),
  'locked', 'LRN-05: topic 2 starts locked');

select tests.authenticate_as('unlock_teacher');
insert into unlock_ctx values ('first', public.teacher_unlock_topic(tests.get_supabase_uid('unlock_student'),
  '00000000-0000-0000-0000-0000000020d2'));
select is((select v ->> 'topic_id' from unlock_ctx where k = 'first'), '00000000-0000-0000-0000-0000000020d2',
  'LRN-05: teacher unlock returns topic_id');
select ok((select (v ->> 'unlocked_at')::timestamptz is not null from unlock_ctx where k = 'first'),
  'LRN-05: teacher unlock returns a timestamp');
select is((select (v ->> 'unlocked_by')::uuid from unlock_ctx where k = 'first'), tests.get_supabase_uid('unlock_teacher'),
  'LRN-05: teacher unlock returns the teacher uid');
select tests.clear_authentication();
reset role;
select is((select status from private.topic_states(tests.get_supabase_uid('unlock_student'),
  '00000000-0000-0000-0000-0000000020c1') where topic_id = '00000000-0000-0000-0000-0000000020d2'),
  'open', 'LRN-05: teacher unlock opens topic 2');

select tests.authenticate_as('unlock_teacher_b');
select is(public.teacher_unlock_topic(tests.get_supabase_uid('unlock_student'), '00000000-0000-0000-0000-0000000020d2'),
  (select v from unlock_ctx where k = 'first'), 'LRN-05: repeated unlock preserves timestamp and original teacher');
insert into unlock_ctx values ('historical', public.teacher_unlock_topic(tests.get_supabase_uid('unlock_other'),
  '00000000-0000-0000-0000-0000000020d2'));
select is((select (v ->> 'unlocked_at')::timestamptz from unlock_ctx where k = 'historical'), now() - interval '1 day',
  'LRN-05: an earlier unlock timestamp is preserved');
select is((select (v ->> 'unlocked_by')::uuid from unlock_ctx where k = 'historical'), tests.get_supabase_uid('unlock_teacher'),
  'LRN-05: an earlier unlock keeps its original teacher');
select lives_ok($$ select public.teacher_unlock_topic(tests.get_supabase_uid('unlock_other'),
  '00000000-0000-0000-0000-0000000020d1') $$, 'LRN-05: teacher unlock creates missing progress');
select tests.clear_authentication();
reset role;
select is((select practice_count from public.topic_progress
  where user_id = tests.get_supabase_uid('unlock_student') and topic_id = '00000000-0000-0000-0000-0000000020d2'),
  3, 'LRN-05: existing progress row kept');
select is((select count(*)::int from public.audit_log where action = 'topic.unlock' and entity = 'topic'
  and entity_id = '00000000-0000-0000-0000-0000000020d2' and diff ->> 'student_id' = tests.get_supabase_uid('unlock_student')::text),
  1, 'LRN-05: repeated unlock writes exactly one audit row');
select is((select pg_catalog.jsonb_build_object('actor', actor, 'diff', diff) from public.audit_log
  where action = 'topic.unlock' and entity = 'topic' and entity_id = '00000000-0000-0000-0000-0000000020d2'
    and diff ->> 'student_id' = tests.get_supabase_uid('unlock_student')::text),
  (select jsonb_build_object('actor', tests.get_supabase_uid('unlock_teacher'), 'diff',
    jsonb_build_object('student_id', tests.get_supabase_uid('unlock_student'), 'unlocked_at', v -> 'unlocked_at'))
   from unlock_ctx where k = 'first'), 'LRN-05: audit records the original actor, student and timestamp');
select is((select count(*)::int from public.audit_log where action = 'topic.unlock' and entity = 'topic'
  and entity_id = '00000000-0000-0000-0000-0000000020d2' and diff ->> 'student_id' = tests.get_supabase_uid('unlock_other')::text),
  0, 'LRN-05: an existing historical unlock produces no new audit');
select ok((select unlocked_at is not null and unlocked_by = tests.get_supabase_uid('unlock_teacher_b')
  from public.topic_progress where user_id = tests.get_supabase_uid('unlock_other')
    and topic_id = '00000000-0000-0000-0000-0000000020d1'), 'LRN-05: missing progress stores unlock timestamp and teacher');
select is((select count(*)::int from public.audit_log where action = 'topic.unlock' and entity = 'topic'
  and entity_id = '00000000-0000-0000-0000-0000000020d1' and diff ->> 'student_id' = tests.get_supabase_uid('unlock_other')::text),
  1, 'LRN-05: a newly inserted progress row is audited once');

select * from finish();
rollback;
