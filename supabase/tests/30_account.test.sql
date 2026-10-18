-- AUTH-04: account name lock and own-device listing. From supabase/templates/test.sql.
begin;
create extension if not exists pgtap with schema extensions;
select plan(26);

select tests.create_supabase_user('student_a');
select tests.create_supabase_user('student_b');
select tests.create_supabase_user('teacher');
update public.profiles set role = 'teacher' where id = tests.get_supabase_uid('teacher');

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-000000000030', 'account-signup@example.com',
   '{"full_name":"Account Student"}'::jsonb);
select is((select full_name from public.profiles
           where id = '00000000-0000-0000-0000-000000000030'),
          'Account Student', 'AUTH-04: sign-up trigger still stores full_name');

update public.settings set value = '2'::jsonb where key = 'device_changes_30d';
insert into public.devices
  (id, user_id, device_fingerprint, platform, label, last_seen_at, created_at, revoked_at)
values
  ('00000000-0000-0000-0000-000000000031', tests.get_supabase_uid('student_a'),
   'device-account-a-phone', 'android', 'Phone', now() - interval '1 day', now() - interval '5 days', null),
  ('00000000-0000-0000-0000-000000000032', tests.get_supabase_uid('student_a'),
   'device-account-a-laptop', 'web', 'Laptop', now(), now() - interval '4 days', null),
  ('00000000-0000-0000-0000-000000000033', tests.get_supabase_uid('student_a'),
   'device-account-a-tablet', 'ios', 'Tablet', null, now() - interval '3 days', null),
  ('00000000-0000-0000-0000-000000000034', tests.get_supabase_uid('student_a'),
   'device-account-a-revoked', 'web', 'Revoked', now(), now(), now()),
  ('00000000-0000-0000-0000-000000000035', tests.get_supabase_uid('student_b'),
   'device-account-a-laptop', 'web', 'Other student', now(), now(), null);

-- The 30-day boundary is excluded; another student's recent change must not count.
insert into public.device_changes (user_id, changed_at) values
  (tests.get_supabase_uid('student_a'), now() - interval '30 days'),
  (tests.get_supabase_uid('student_a'), now() - interval '31 days'),
  (tests.get_supabase_uid('student_b'), now());

select tests.authenticate_as('student_a');
select throws_ok($$ update public.profiles set full_name = 'Renamed' where id = auth.uid() $$,
                 '42501', null, 'AUTH-04: student cannot update own full_name');
select lives_ok($$ update public.profiles set phone = '+201000000030' where id = auth.uid() $$,
                'AUTH-04: student can still update own phone');
select is((select phone from public.profiles where id = auth.uid()), '+201000000030',
          'AUTH-04: own phone update persists');

select set_config('test.account_devices', public.list_my_devices('device-account-a-laptop')::text, true);
select is((select array_agg(d ->> 'id' order by ordinal)
           from jsonb_array_elements(current_setting('test.account_devices')::jsonb -> 'devices')
                with ordinality as listed(d, ordinal)),
          array['00000000-0000-0000-0000-000000000032',
                '00000000-0000-0000-0000-000000000031',
                '00000000-0000-0000-0000-000000000033'],
          'AUTH-04: list_my_devices returns only my non-revoked devices, newest seen first, nulls last');
select is(current_setting('test.account_devices')::jsonb #> '{devices,0,is_current}', 'true'::jsonb,
          'AUTH-04: list_my_devices marks is_current by fingerprint');
select is((select count(*)::int
           from jsonb_array_elements(current_setting('test.account_devices')::jsonb -> 'devices') d
           where (d ->> 'is_current')::boolean), 1,
          'AUTH-04: other fingerprints are not current');
select is((select array_agg(k order by k)
           from jsonb_object_keys(current_setting('test.account_devices')::jsonb #> '{devices,0}') k),
          array['created_at', 'id', 'is_current', 'label', 'last_seen_at', 'platform'],
          'AUTH-04: device payload has the exact public fields and never a fingerprint');
select is(current_setting('test.account_devices')::jsonb #> '{devices,0}',
          jsonb_build_object('id', '00000000-0000-0000-0000-000000000032',
                             'label', 'Laptop', 'platform', 'web', 'last_seen_at', now(),
                             'created_at', now() - interval '4 days', 'is_current', true),
          'AUTH-04: device payload preserves label, platform and timestamps');
select is((current_setting('test.account_devices')::jsonb ->> 'changes_left')::int, 2,
          'AUTH-04: changes_left is 2 with no changes in the rolling window');
select is((public.list_my_devices('device-account-unknown') -> 'devices' -> 0 ->> 'is_current')::boolean,
          false, 'AUTH-04: an unknown fingerprint does not mark a device current');

select set_config('test.account_removal',
                  public.remove_device('00000000-0000-0000-0000-000000000031')::text, true);
select is((public.list_my_devices('device-account-a-laptop') ->> 'changes_left')::int, 1,
          'AUTH-04: changes_left is 1 after one removal');
select is(public.list_my_devices('device-account-a-laptop') -> 'changes_left',
          current_setting('test.account_removal')::jsonb -> 'changes_left',
          'AUTH-04: changes_left equals remove_device''s allowance');
select is(jsonb_array_length(public.list_my_devices('device-account-a-laptop') -> 'devices'), 2,
          'AUTH-04: removed device disappears from list_my_devices');
select public.remove_device('00000000-0000-0000-0000-000000000033');
select is((public.list_my_devices('device-account-a-laptop') ->> 'changes_left')::int, 0,
          'AUTH-04: exhausted allowance reports zero');
select throws_ok($$ select public.remove_device('00000000-0000-0000-0000-000000000032') $$,
                 'P0001', 'device_limit', 'AUTH-04: zero allowance agrees with remove_device rejection');

select throws_ok($$ select public.list_my_devices(null) $$, 'P0001', 'invalid_input',
                 'AUTH-04: null fingerprint is invalid_input');
select throws_ok($$ select public.list_my_devices('') $$, 'P0001', 'invalid_input',
                 'AUTH-04: empty fingerprint is invalid_input');
select throws_ok($$ select public.list_my_devices('   ') $$, 'P0001', 'invalid_input',
                 'AUTH-04: blank fingerprint is invalid_input');

select tests.authenticate_as('teacher');
select is(public.list_my_devices('device-account-a-laptop') -> 'devices', '[]'::jsonb,
          'AUTH-04: teacher with no devices gets an empty own list');

reset role;
update public.settings set value = '5'::jsonb where key = 'device_changes_30d';
select tests.authenticate_as('student_a');
select is((public.list_my_devices('device-account-a-laptop') ->> 'changes_left')::int, 3,
          'AUTH-04: changes_left reads the configured allowance');
reset role;
update public.settings set value = '1'::jsonb where key = 'device_changes_30d';
select tests.authenticate_as('student_a');
select is((public.list_my_devices('device-account-a-laptop') ->> 'changes_left')::int, 0,
          'AUTH-04: changes_left never becomes negative');

select ok(has_function_privilege('authenticated', 'public.list_my_devices(text)', 'execute'),
          'AUTH-04: authenticated has execute on list_my_devices');
select ok(not has_function_privilege('anon', 'public.list_my_devices(text)', 'execute'),
          'AUTH-04: anon has no execute including inherited PUBLIC grants');
select tests.clear_authentication();
set local role authenticated;
select throws_ok($$ select public.list_my_devices('device-account-a-laptop') $$,
                 'P0001', 'not_authenticated', 'AUTH-04: missing uid is not_authenticated');
reset role;
set local role anon;
select throws_ok($$ select public.list_my_devices('device-account-a-laptop') $$,
                 '42501', null, 'AUTH-04: anon cannot call list_my_devices');
reset role;

select * from finish();
rollback;
