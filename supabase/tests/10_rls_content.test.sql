-- F-2 / NFR-08 — docs/06 §4 content rows: assets, chapters, live sessions, announcements.
begin;
create extension if not exists pgtap with schema extensions;
select plan(9);

select tests.create_supabase_user('student_a');  -- enrolled
select tests.create_supabase_user('student_b');  -- not enrolled
select tests.create_supabase_user('student_c');  -- enrollment expired
select tests.create_supabase_user('teacher');
update public.profiles set role = 'teacher' where id = tests.get_supabase_uid('teacher');

insert into public.courses (id, code, title, slug, is_published)
  values ('00000000-0000-0000-0000-0000000000c1', 'SAT', 'SAT Math', 'sat', true);
insert into public.topics (id, course_id, title, slug, is_published, is_free_preview) values
  ('00000000-0000-0000-0000-0000000000d1', '00000000-0000-0000-0000-0000000000c1', 'Paid', 'paid', true, false),
  ('00000000-0000-0000-0000-0000000000d2', '00000000-0000-0000-0000-0000000000c1', 'Free', 'free', true, true),
  ('00000000-0000-0000-0000-0000000000d3', '00000000-0000-0000-0000-0000000000c1', 'Draft', 'draft', false, true);
insert into public.subtopics (id, topic_id, title)
  values ('00000000-0000-0000-0000-0000000000e1', '00000000-0000-0000-0000-0000000000d1', 'S1');
insert into public.topic_assets (id, topic_id, kind, title) values
  ('00000000-0000-0000-0000-0000000000b1', '00000000-0000-0000-0000-0000000000d1', 'video', 'Paid video'),
  ('00000000-0000-0000-0000-0000000000b2', '00000000-0000-0000-0000-0000000000d2', 'video', 'Free video'),
  ('00000000-0000-0000-0000-0000000000b3', '00000000-0000-0000-0000-0000000000d3', 'video', 'Draft video');
insert into public.video_chapters (asset_id, subtopic_id, start_s, label)
  values ('00000000-0000-0000-0000-0000000000b1', '00000000-0000-0000-0000-0000000000e1', 0, 'Intro');
insert into public.live_sessions (course_id, title, starts_at, duration_min)
  values ('00000000-0000-0000-0000-0000000000c1', 'Live', now() + interval '1 day', 60);
insert into public.announcements (course_id, title, body_md)
  values ('00000000-0000-0000-0000-0000000000c1', 'Hello', 'x');
insert into public.enrollments (user_id, course_id, status, expires_at) values
  (tests.get_supabase_uid('student_a'), '00000000-0000-0000-0000-0000000000c1', 'active', now() + interval '30 days'),
  (tests.get_supabase_uid('student_c'), '00000000-0000-0000-0000-0000000000c1', 'active', now() - interval '1 day');

select tests.authenticate_as('student_a');
select is((select count(*)::int from public.topic_assets), 2, 'NFR-08: enrolled student sees paid and free published assets');
select is((select count(*)::int from public.video_chapters), 1, 'NFR-08: enrolled student sees chapters');
select is((select count(*)::int from public.live_sessions), 1, 'NFR-08: enrolled student sees live sessions');
select is((select count(*)::int from public.announcements), 1, 'NFR-08: enrolled student sees announcements');

select tests.authenticate_as('student_b');
select is((select count(*)::int from public.topic_assets), 1, 'NFR-08: non-enrolled student sees free preview assets only');
select is((select count(*)::int from public.video_chapters), 0, 'NFR-08: non-enrolled student sees no paid chapters');
select is((select count(*)::int from public.announcements), 0, 'NFR-08: non-enrolled student sees no announcements');

select tests.authenticate_as('student_c');
select is((select count(*)::int from public.topic_assets), 1, 'NFR-08: expired enrollment loses paid assets');

select tests.authenticate_as('teacher');
select is((select count(*)::int from public.topic_assets), 3, 'NFR-08: teacher sees all assets');

select * from finish();
rollback;
