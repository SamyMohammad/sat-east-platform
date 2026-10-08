-- AUTH-04 / AUTH-05 — device limit (docs/07 §8). Settings: device_limit 2, device_changes_30d 2.
begin;
create extension if not exists pgtap with schema extensions;
select plan(31);

select tests.create_supabase_user('student_a');
select tests.create_supabase_user('student_b');
select tests.create_supabase_user('teacher');
update public.profiles set role = 'teacher' where id = tests.get_supabase_uid('teacher');

insert into public.courses (id, code, title, slug, is_published)
  values ('00000000-0000-0000-0000-0000000000c1', 'SAT', 'SAT Math', 'sat', true);
insert into public.enrollments (user_id, course_id, status, expires_at)
  values (tests.get_supabase_uid('student_a'), '00000000-0000-0000-0000-0000000000c1', 'active', now() + interval '30 days');

-- Student A: two devices fit, the third hits the limit.
select tests.authenticate_as('student_a');
select is(public.register_device('device-aaaa-1111-phone', 'android', 'Phone') ->> 'status', 'ok',
          'AUTH-04: first device registers');
select is(public.register_device('device-aaaa-2222-laptop', 'web', 'Laptop') ->> 'status', 'ok',
          'AUTH-04: second device registers');
select is(public.register_device('device-aaaa-1111-phone', 'android') ->> 'status', 'ok',
          'AUTH-04: a known active device just signs in again');
select is((public.register_device('device-aaaa-3333-tablet', 'ios')) ->> 'status', 'limit_reached',
          'AUTH-04: third device gets limit_reached');
select is(jsonb_array_length(public.register_device('device-aaaa-3333-tablet', 'ios') -> 'devices'), 2,
          'AUTH-04: limit_reached lists the two active devices');
select is((public.register_device('device-aaaa-3333-tablet', 'ios') ->> 'changes_left')::int, 2,
          'AUTH-04: limit_reached reports the changes left');
select is((select count(*)::int from public.devices), 2,
          'AUTH-04: the third device was not stored');

select throws_ok($$ select public.register_device('short') $$, 'P0001', 'invalid_input',
                 'AUTH-04: malformed fingerprint is refused');
select throws_ok($$ select public.register_device('device-aaaa-4444-xxxx', 'windows') $$, 'P0001', 'invalid_input',
                 'AUTH-04: unknown platform is refused');

-- Remove one device, then the third registers.
select lives_ok($$ select public.remove_device(
                     (select id from public.devices where device_fingerprint = 'device-aaaa-1111-phone')) $$,
                'AUTH-04: student removes an own device');
select is(public.device_status('device-aaaa-1111-phone'), 'revoked',
          'AUTH-04: removed device reports revoked');
select is(public.register_device('device-aaaa-3333-tablet', 'ios') ->> 'status', 'ok',
          'AUTH-04: after removing one, the third device registers');
select is(public.device_status('device-aaaa-3333-tablet'), 'active', 'AUTH-04: device_status active');
select is(public.device_status('device-never-seen-0000'), 'unknown', 'AUTH-04: device_status unknown');

-- The removed phone comes back: it needs a slot like any new device.
select is(public.register_device('device-aaaa-1111-phone', 'android') ->> 'status', 'limit_reached',
          'AUTH-04: a revoked device coming back needs a free slot');

-- has_access follows the device header.
select is(public.has_access('00000000-0000-0000-0000-0000000000c1'), true,
          'AUTH-04: no header + device_header_required=false → access');
select set_config('request.headers', '{"x-device-id":"device-aaaa-1111-phone"}', true);
select is(public.has_access('00000000-0000-0000-0000-0000000000c1'), false,
          'AUTH-04: revoked device header → no access');
select set_config('request.headers', '{"x-device-id":"device-unknown-99999"}', true);
select is(public.has_access('00000000-0000-0000-0000-0000000000c1'), false,
          'AUTH-04: unknown device header → no access');
select set_config('request.headers', '{"x-device-id":"device-aaaa-3333-tablet"}', true);
select is(public.has_access('00000000-0000-0000-0000-0000000000c1'), true,
          'AUTH-04: active device header → access');
select set_config('request.headers', '', true);
reset role;
update public.settings set value = 'true' where key = 'device_header_required';
select tests.authenticate_as('student_a');
select is(public.has_access('00000000-0000-0000-0000-0000000000c1'), false,
          'AUTH-04: no header + device_header_required=true → no access');

-- Second removal uses the last change; a third removal is blocked.
select lives_ok($$ select public.remove_device(
                     (select id from public.devices where device_fingerprint = 'device-aaaa-2222-laptop')) $$,
                'AUTH-04: second change allowed');
select is(public.register_device('device-aaaa-5555-new', 'web') ->> 'status', 'ok',
          'AUTH-04: freed slot is usable');
select throws_ok($$ select public.remove_device(
                      (select id from public.devices where device_fingerprint = 'device-aaaa-3333-tablet')) $$,
                 'P0001', 'device_limit', 'AUTH-04: change beyond the 30-day allowance is blocked');

-- Student B cannot touch A's devices (the id is read while still signed in as A).
select set_config('test.a_device',
                  (select id::text from public.devices where device_fingerprint = 'device-aaaa-5555-new'), true);
select tests.authenticate_as('student_b');
select throws_ok(format('select public.remove_device(%L)', current_setting('test.a_device')),
                 'P0001', 'forbidden', 'AUTH-04: student cannot remove another student''s device');
select throws_ok($$ select public.teacher_reset_devices(tests.get_supabase_uid('student_a')) $$,
                 'P0001', 'forbidden', 'AUTH-05: student cannot use teacher tools');

-- Teacher: no device limit; list, revoke, reset are audited.
select tests.authenticate_as('teacher');
select public.register_device('device-teach-0001-aa', 'web');
select public.register_device('device-teach-0002-bb', 'web');
select is(public.register_device('device-teach-0003-cc', 'web') ->> 'status', 'ok',
          'AUTH-04: teachers are not limited');
select is((public.teacher_list_devices(tests.get_supabase_uid('student_a')) ->> 'changes_used_30d')::int, 2,
          'AUTH-05: teacher sees the changes used');
select lives_ok(format('select public.teacher_revoke_device(%L)',
                       (select id from public.devices where device_fingerprint = 'device-aaaa-5555-new')),
                'AUTH-05: teacher revokes a device');
select is((public.teacher_reset_devices(tests.get_supabase_uid('student_a')) ->> 'revoked')::int, 1,
          'AUTH-05: reset revokes the remaining active device');
select is((select array_agg(action order by id) from public.audit_log),
          array['device.revoke', 'device.reset'], 'AUTH-05: teacher actions are audited');

-- Anon: no execute at all.
select tests.clear_authentication();
set local role anon;
select throws_ok($$ select public.register_device('device-anon-0000-zz') $$, '42501', null,
                 'AUTH-04: anon cannot call register_device');
reset role;

select * from finish();
rollback;
