-- LRN-01 / LRN-03 — get_course_map (docs/07 §1.1, §2). Spec: docs/superpowers/specs/2026-10-17-p1-course-map-design.md §1.
begin;
create extension if not exists pgtap with schema extensions;
select plan(34);

-- courses.code is an enum with unique values (SAT, EST); this test needs three courses.
alter table public.courses drop constraint courses_code_key;

select tests.create_supabase_user('a');
select tests.create_supabase_user('b');
select tests.create_supabase_user('c');
select tests.create_supabase_user('d');
select tests.create_supabase_user('e');
select tests.create_supabase_user('f');
select tests.create_supabase_user('g');

insert into public.courses (id, code, title, slug, is_published, sort) values
  ('00000000-0000-0000-0000-0000000000c1', 'SAT', 'CM Course',  'cm-course',  true,  1),
  ('00000000-0000-0000-0000-0000000000c2', 'SAT', 'CM2 Course', 'cm2-course', true,  2),
  ('00000000-0000-0000-0000-0000000000c3', 'EST', 'Hidden',     'cm-hidden',  false, 3);
insert into public.units (id, course_id, title, sort) values
  ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000c1', 'U1', 1),
  ('00000000-0000-0000-0000-0000000000a2', '00000000-0000-0000-0000-0000000000c1', 'U2', 2),
  ('00000000-0000-0000-0000-0000000000a3', '00000000-0000-0000-0000-0000000000c1', 'U3', 3);
insert into public.topics (id, course_id, unit_id, title, slug, sort, is_published, is_free_preview) values
  ('00000000-0000-0000-0000-0000000000d1', '00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-0000000000a1', 'A', 'a', 1, true,  false),
  ('00000000-0000-0000-0000-0000000000d2', '00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-0000000000a1', 'B', 'b', 2, true,  false),
  ('00000000-0000-0000-0000-0000000000d3', '00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-0000000000a1', 'X', 'x', 3, false, false),
  ('00000000-0000-0000-0000-0000000000d4', '00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-0000000000a1', 'C', 'c', 4, true,  false),
  ('00000000-0000-0000-0000-0000000000d5', '00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-0000000000a2', 'D', 'd', 1, true,  true),
  ('00000000-0000-0000-0000-0000000000d6', '00000000-0000-0000-0000-0000000000c1', null,                                   'E', 'e', 1, true,  false),
  ('00000000-0000-0000-0000-0000000000d7', '00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-0000000000a3', 'Y', 'y', 1, false, false),
  ('00000000-0000-0000-0000-0000000000d8', '00000000-0000-0000-0000-0000000000c2', null,                                   'Z', 'z', 1, true,  false);

insert into public.enrollments (user_id, course_id, status, starts_at, expires_at) values
  (tests.get_supabase_uid('a'), '00000000-0000-0000-0000-0000000000c1', 'active',   now() - interval '1 day',   now() + interval '30 days'),
  (tests.get_supabase_uid('b'), '00000000-0000-0000-0000-0000000000c1', 'active',   now() - interval '1 day',   now() + interval '30 days'),
  (tests.get_supabase_uid('c'), '00000000-0000-0000-0000-0000000000c1', 'expired',  now() - interval '1 day',   now() + interval '30 days'),
  (tests.get_supabase_uid('e'), '00000000-0000-0000-0000-0000000000c1', 'refunded', now() - interval '1 day',   now() + interval '30 days'),
  (tests.get_supabase_uid('f'), '00000000-0000-0000-0000-0000000000c1', 'active',   now() - interval '10 days', now() - interval '1 day'),
  (tests.get_supabase_uid('g'), '00000000-0000-0000-0000-0000000000c2', 'active',   now() - interval '10 days', now() + interval '30 days'),
  (tests.get_supabase_uid('g'), '00000000-0000-0000-0000-0000000000c1', 'expired',  now() - interval '1 day',   now() + interval '30 days');

-- Look up one topic of the cm-course map by slug (caller = current role/jwt).
create function pg_temp.tp(p_slug text) returns jsonb
language sql as $$
  select t from jsonb_array_elements(public.get_course_map('cm-course') -> 'units') u,
                jsonb_array_elements(u -> 'topics') t
  where t ->> 'slug' = p_slug
$$;
grant execute on function pg_temp.tp(text) to authenticated;

-- Anonymous: no grant at all.
select tests.clear_authentication();
set local role anon;
select throws_ok($$ select public.get_course_map('cm-course') $$, '42501', null,
                 'L-1: anon cannot execute get_course_map');
reset role;

-- Authenticated role but no user.
set local role authenticated;
select throws_ok($$ select public.get_course_map('cm-course') $$, 'P0001', 'not_authenticated',
                 'L-1: no session -> not_authenticated');
reset role;

-- Student a: bad slugs.
select tests.authenticate_as('a');
select throws_ok($$ select public.get_course_map('nope') $$, 'P0001', 'invalid_input',
                 'L-1: unknown slug -> invalid_input');
select throws_ok($$ select public.get_course_map('cm-hidden') $$, 'P0001', 'invalid_input',
                 'L-1: unpublished course slug -> invalid_input');

-- Student d: no enrolment.
select tests.authenticate_as('d');
select throws_ok($$ select public.get_course_map() $$, 'P0001', 'not_enrolled',
                 'L-1: no enrolment, null slug -> not_enrolled');
select throws_ok($$ select public.get_course_map('cm-course') $$, 'P0001', 'not_enrolled',
                 'L-1: no enrolment for the slug -> not_enrolled');

-- Ended / expired access.
select tests.authenticate_as('c');
select throws_ok($$ select public.get_course_map() $$, 'P0001', 'access_expired',
                 'L-1: expired enrolment -> access_expired');
select tests.authenticate_as('e');
select throws_ok($$ select public.get_course_map() $$, 'P0001', 'access_expired',
                 'L-1: refunded enrolment -> access_expired');
select tests.authenticate_as('f');
select throws_ok($$ select public.get_course_map() $$, 'P0001', 'access_expired',
                 'L-1: active but past expires_at -> access_expired');
select tests.authenticate_as('g');
select throws_ok($$ select public.get_course_map() $$, 'P0001', 'access_expired',
                 'L-1: null slug picks the latest enrolment of any status');

-- Student a, fresh progress.
select tests.authenticate_as('a');
select is(pg_temp.tp('a') ->> 'status', 'open',   'L-1: first topic is open');
select is(pg_temp.tp('b') ->> 'status', 'locked', 'L-1: second topic is locked');
select is(pg_temp.tp('c') ->> 'status', 'locked', 'L-1: topic after an unpublished one is locked');
select is(pg_temp.tp('d') ->> 'status', 'open',   'L-1: free preview topic is open');
select is(pg_temp.tp('e') ->> 'status', 'locked', 'L-1: unit-less topic is locked');
select is(pg_temp.tp('c') ->> 'after_title', 'B', 'L-1: unpublished topics are skipped as previous');
select is(pg_temp.tp('b') ->> 'after_title', 'A', 'L-1: locked topic names the previous topic');
select is(pg_temp.tp('b') ->> 'locked_reason', 'previous_quiz', 'L-1: locked_reason is previous_quiz');
select is(pg_temp.tp('a') ->> 'sort_label', '1.1', 'L-1: label A');
select is(pg_temp.tp('b') ->> 'sort_label', '1.2', 'L-1: label B');
select is(pg_temp.tp('c') ->> 'sort_label', '1.3', 'L-1: label C ignores unpublished X');
select is(pg_temp.tp('d') ->> 'sort_label', '2.1', 'L-1: label D (second shown unit)');
select is(pg_temp.tp('e') ->> 'sort_label', '1',   'L-1: unit-less label is the topic position only');
select is(jsonb_array_length(public.get_course_map('cm-course') -> 'units'), 3,
          'L-1: unit with only unpublished topics is hidden; unit-less group appended');
select is(public.get_course_map('cm-course') #> '{units,2,title}', 'null'::jsonb,
          'L-1: unit-less group is last with null title');
select is(pg_temp.tp('x'), null, 'L-1: unpublished topic is not present');
select is(public.get_course_map('cm-course') #>> '{continue,slug}', 'a', 'L-1: continue points at the first open topic');

-- Student a passes A.
select tests.clear_authentication();
reset role;
insert into public.topic_progress (user_id, topic_id, quiz_passed_at)
  values (tests.get_supabase_uid('a'), '00000000-0000-0000-0000-0000000000d1', now());
select tests.authenticate_as('a');
select is(pg_temp.tp('a') ->> 'status', 'completed', 'L-1: passed quiz -> completed');
select is(pg_temp.tp('b') ->> 'status', 'open',      'L-1: topic after a passed quiz is open');
select is(public.get_course_map('cm-course') #>> '{continue,slug}', 'b', 'L-1: continue moves to the next open topic');
select is(pg_temp.tp('a') ->> 'locked_reason', null, 'L-1: completed topic has no locked_reason');

-- Another student's progress has no effect.
select tests.authenticate_as('b');
select is(pg_temp.tp('b') ->> 'status', 'locked', 'L-1: other student progress does not unlock');

-- Teacher unlock.
select tests.clear_authentication();
reset role;
insert into public.topic_progress (user_id, topic_id, unlocked_at)
  values (tests.get_supabase_uid('a'), '00000000-0000-0000-0000-0000000000d4', now());
select tests.authenticate_as('a');
select is(pg_temp.tp('c') ->> 'status', 'open', 'L-1: unlocked_at opens a topic');

-- Everything passed.
select tests.clear_authentication();
reset role;
insert into public.topic_progress (user_id, topic_id, quiz_passed_at)
  select tests.get_supabase_uid('a'), id, now() from public.topics
  where id in ('00000000-0000-0000-0000-0000000000d2', '00000000-0000-0000-0000-0000000000d4',
               '00000000-0000-0000-0000-0000000000d5', '00000000-0000-0000-0000-0000000000d6')
  on conflict (user_id, topic_id) do update set quiz_passed_at = now();
select tests.authenticate_as('a');
select is(public.get_course_map('cm-course') -> 'continue', 'null'::jsonb,
          'L-1: continue is null when nothing is open');

select * from finish();
rollback;
