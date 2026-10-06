-- F-2 / NFR-08 — docs/06 conventions: sign-up profile, updated_at, FK delete rules.
begin;
create extension if not exists pgtap with schema extensions;
select plan(8);

-- Sign-up trigger
insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000a1', 'amira@example.com', '{"full_name":"Amira Hassan"}'),
  ('00000000-0000-0000-0000-0000000000a2', 'evil@example.com',  '{"full_name":"Evil","role":"teacher"}'),
  ('00000000-0000-0000-0000-0000000000a3', 'sara@example.com',  '{}'),
  ('00000000-0000-0000-0000-0000000000a4', null,                '{}');

select is((select full_name from public.profiles where id = '00000000-0000-0000-0000-0000000000a1'),
          'Amira Hassan', 'sign-up creates profile with metadata full_name');
select is((select role from public.profiles where id = '00000000-0000-0000-0000-0000000000a2'),
          'student'::public.user_role, 'role is never taken from sign-up metadata');
select is((select full_name from public.profiles where id = '00000000-0000-0000-0000-0000000000a3'),
          'sara', 'missing name falls back to e-mail local part');
select is((select full_name from public.profiles where id = '00000000-0000-0000-0000-0000000000a4'),
          'Student', 'phone sign-up without name or e-mail falls back to Student');

-- The real sign-up path (GoTrue as supabase_auth_admin) is checked end to end in the PR
-- (postgres cannot switch to that role here).

-- Fixture: course → topic → subtopic → question, attempt with an empty draw
insert into public.courses (id, code, title, slug)
  values ('00000000-0000-0000-0000-0000000000c1', 'SAT', 'SAT Math', 'sat');
insert into public.topics (id, course_id, title, slug)
  values ('00000000-0000-0000-0000-0000000000d1', '00000000-0000-0000-0000-0000000000c1', 'Linear', 'linear');
insert into public.subtopics (id, topic_id, title)
  values ('00000000-0000-0000-0000-0000000000e1', '00000000-0000-0000-0000-0000000000d1', 'Slope');
insert into public.questions (id, topic_id, subtopic_id, type, difficulty, stem_md, pool)
  values ('00000000-0000-0000-0000-0000000000f1', '00000000-0000-0000-0000-0000000000d1',
          '00000000-0000-0000-0000-0000000000e1', 'mcq', 'E', 'x', 'quiz');
insert into public.attempts (id, user_id, kind, course_id)
  values ('00000000-0000-0000-0000-0000000000b1', '00000000-0000-0000-0000-0000000000a1',
          'quiz', '00000000-0000-0000-0000-0000000000c1');
insert into public.devices (user_id, device_fingerprint)
  values ('00000000-0000-0000-0000-0000000000a1', 'fp-1');

select throws_ok($$insert into public.attempt_answers (attempt_id, question_id)
                   values ('00000000-0000-0000-0000-0000000000b1', '00000000-0000-0000-0000-0000000000f1')$$,
                 '23503', null, 'answer for a question outside the frozen draw is rejected');

select throws_ok($$delete from public.courses where id = '00000000-0000-0000-0000-0000000000c1'$$,
                 '23503', null, 'content in use cannot be deleted (restrict)');

delete from auth.users where id = '00000000-0000-0000-0000-0000000000a1';
select is((select count(*)::int from public.devices
           where user_id = '00000000-0000-0000-0000-0000000000a1'),
          0, 'deleting a user cascades to their own data');

-- updated_at trigger (now() is fixed inside a transaction, so start from an old value).
-- The update runs as a non-owner role without USAGE on private, as API writes will in row 3.
insert into public.settings (key, value, updated_at) values ('t_probe', '1', '2000-01-01');
set local role service_role;
update public.settings set value = '2' where key = 't_probe';
reset role;
select ok((select updated_at > '2000-01-02' from public.settings where key = 't_probe'),
          'updated_at is set on update');

select * from finish();
rollback;
