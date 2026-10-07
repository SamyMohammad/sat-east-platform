-- F-2 / NFR-08 — docs/06 §4 identity rows: profiles, devices, notifications, push_tokens, settings.
begin;
create extension if not exists pgtap with schema extensions;
select plan(13);

select tests.create_supabase_user('student_a');
select tests.create_supabase_user('student_b');
select tests.create_supabase_user('teacher');
update public.profiles set role = 'teacher' where id = tests.get_supabase_uid('teacher');

insert into public.devices (user_id, device_fingerprint) values
  (tests.get_supabase_uid('student_a'), 'fp-a'), (tests.get_supabase_uid('student_b'), 'fp-b');
insert into public.notifications (user_id, kind) values
  (tests.get_supabase_uid('student_a'), 'info'), (tests.get_supabase_uid('student_b'), 'info');

select tests.authenticate_as('student_a');
select is((select count(*)::int from public.profiles), 1, 'NFR-08: student sees only own profile');
select lives_ok($$ update public.profiles set full_name = 'A Two' where id = auth.uid() $$,
                'NFR-08: student updates own full_name');
select throws_ok($$ update public.profiles set role = 'teacher' where id = auth.uid() $$, '42501', null,
                 'NFR-08: student cannot change own role');
select is_empty($$ update public.profiles set full_name = 'x' where id <> auth.uid() returning id $$,
                'NFR-08: student cannot update another profile');
select is((select count(*)::int from public.devices), 1, 'NFR-08: student sees only own devices');
select lives_ok($$ update public.notifications set read_at = now() where user_id = auth.uid() $$,
                'NFR-08: student marks own notification read');
select throws_ok($$ update public.notifications set kind = 'x' $$, '42501', null,
                 'NFR-08: student can only update read_at');
select lives_ok($$ insert into public.push_tokens (user_id, token, platform) values (auth.uid(), 't-a', 'web') $$,
                'NFR-08: student registers own push token');
select throws_ok(format($$ insert into public.push_tokens (user_id, token, platform) values (%L, 't-b', 'web') $$,
                        tests.get_supabase_uid('student_b')), '42501', null,
                 'NFR-08: student cannot register a token for someone else');
select ok((select count(*) from public.settings) >= 9, 'NFR-08: student reads settings');

select tests.authenticate_as('teacher');
select ok((select count(*) from public.profiles) >= 3, 'NFR-08: teacher sees all profiles');

select tests.clear_authentication();
select throws_ok($$ select 1 from public.profiles $$, '42501', null, 'NFR-08: anon cannot read profiles');
select throws_ok($$ select 1 from public.settings $$, '42501', null, 'NFR-08: anon cannot read settings');

select * from finish();
rollback;
