-- PAY-06 / PAY-07: activation codes. From supabase/templates/test.sql.
begin;
create extension if not exists pgtap with schema extensions;
select plan(56);

select tests.create_supabase_user('activation_a');
select tests.create_supabase_user('activation_b');
select tests.create_supabase_user('activation_rate');

insert into public.courses (id, code, title, slug, is_published) values
  ('00000000-0000-0000-0000-0000000031c1', 'SAT', 'Activation SAT', 'activation-sat', true);
insert into public.activation_codes (code, course_id)
select c, '00000000-0000-0000-0000-0000000031c1'::uuid
from unnest(array['ABCDEFGH2345', 'JKMNPQRS6789', 'TUVWXYZ23456',
  'ABCDEFGH6789', 'JKMNPQRS2345', 'TUVWXYZ67892']) c;
insert into public.activation_codes (code, course_id) values
  ('HIDDEN234567', '00000000-0000-0000-0000-0000000031c1');

select is(private.setting_int('access_grace_days'), 14, 'PAY-07: grace defaults to 14 days');
select is(private.setting_int('access_min_days'), 60, 'PAY-07: minimum defaults to 60 days');
select is(private.setting_int('test_date_max_days'), 548, 'PAY-07: date maximum defaults to 548 days');
select is(private.setting_int('rate_redeem_per_min'), 5, 'PAY-06: quota defaults to five per minute');

select tests.authenticate_as('activation_a');
select set_config('test.activation', public.redeem_activation_code(
  ' abcd-efgh 2345 ', current_date)::text, true);
select is(current_setting('test.activation')::jsonb -> 'ok', 'true'::jsonb,
  'PAY-06: lowercase, dashes and spaces normalize and redeem');
select is(current_setting('test.activation')::jsonb ->> 'course_id',
  '00000000-0000-0000-0000-0000000031c1', 'PAY-06: returns course id');
select is(current_setting('test.activation')::jsonb ->> 'course_slug',
  'activation-sat', 'PAY-06: returns course slug');
select is(current_setting('test.activation')::jsonb ->> 'course_title',
  'Activation SAT', 'PAY-06: returns course title');
select is((current_setting('test.activation')::jsonb ->> 'target_test_date')::date,
  current_date, 'PAY-07: today is accepted and returned');
select is((current_setting('test.activation')::jsonb ->> 'expires_at')::timestamptz,
  now() + interval '60 days', 'PAY-07: near date uses minimum access');
select is((select count(*)::int from public.enrollments), 1,
  'PAY-06: creates exactly one own enrollment');
select is((select status::text from public.enrollments), 'active',
  'PAY-06: enrollment is active');
select is((select target_test_date from public.enrollments), current_date,
  'PAY-07: stores target date');
select is((select starts_at from public.enrollments), now(),
  'PAY-07: starts at server now');
select is((select expires_at from public.enrollments), now() + interval '60 days',
  'PAY-07: stores server-computed expiration');
select tests.clear_authentication();
reset role;
select is((select activation_code_id from public.enrollments
  where user_id = tests.get_supabase_uid('activation_a')),
  (select id from public.activation_codes where code = 'ABCDEFGH2345'),
  'PAY-06: enrollment references the redeemed code');
select is((select redeemed_by from public.activation_codes where code = 'ABCDEFGH2345'),
  tests.get_supabase_uid('activation_a'), 'PAY-06: records the caller as redeemer');
select is((select redeemed_at from public.activation_codes where code = 'ABCDEFGH2345'),
  now(), 'PAY-06: records server redemption time');

-- A second student cannot consume the same code or acquire its enrollment.
select tests.authenticate_as('activation_b');
select is(public.redeem_activation_code('ABCDEFGH2345', current_date),
  '{"ok":false,"error":"code_used"}'::jsonb, 'PAY-06: second student gets code_used');
select is((select count(*)::int from public.enrollments), 0,
  'PAY-06: losing student has no enrollment');
select is(public.redeem_activation_code('UNKNOWN23456', current_date),
  '{"ok":false,"error":"code_invalid"}'::jsonb, 'PAY-06: unknown code returns code_invalid');
select tests.clear_authentication();
reset role;
update public.courses set is_published = false where slug = 'activation-sat';
select tests.authenticate_as('activation_b');
select is(public.redeem_activation_code('HIDDEN234567', current_date),
  '{"ok":false,"error":"code_invalid"}'::jsonb, 'PAY-06: unpublished course returns code_invalid');
select tests.clear_authentication();
reset role;
select is((select redeemed_at from public.activation_codes where code = 'HIDDEN234567'),
  null::timestamptz, 'PAY-06: unpublished code stays unused');
update public.courses set is_published = true where slug = 'activation-sat';
-- Clear the unrelated attempts; the dedicated quota regression below never clears its counter.
delete from private.rate_limits where key = 'redeem:' || tests.get_supabase_uid('activation_b');

-- Use a non-UTC session to catch an implicit date-to-timestamptz cast.
set local timezone = 'Pacific/Honolulu';
select tests.authenticate_as('activation_b');
select set_config('test.activation_far', public.redeem_activation_code(
  'JKMNPQRS6789', current_date + 548)::text, true);
select is(current_setting('test.activation_far')::jsonb -> 'ok', 'true'::jsonb,
  'PAY-07: upper date boundary is accepted');
select is((current_setting('test.activation_far')::jsonb ->> 'expires_at')::timestamptz,
  (current_date + 563)::timestamp at time zone 'UTC',
  'PAY-07: far date expires at midnight UTC after the grace day');
select is((select expires_at from public.enrollments),
  (current_date + 563)::timestamp at time zone 'UTC', 'PAY-07: far expiration is stored');
select tests.clear_authentication();
reset role;
set local timezone = 'UTC';

-- Every existing status blocks redemption without consuming the new code.
select tests.authenticate_as('activation_a');
select is(public.redeem_activation_code('TUVWXYZ23456', current_date),
  '{"ok":false,"error":"already_enrolled"}'::jsonb, 'PAY-06: active enrollment blocks redeem');
select tests.clear_authentication();
reset role;
update public.enrollments set status = 'expired' where user_id = tests.get_supabase_uid('activation_a');
select tests.authenticate_as('activation_a');
select is(public.redeem_activation_code('TUVWXYZ23456', current_date),
  '{"ok":false,"error":"already_enrolled"}'::jsonb, 'PAY-06: expired enrollment blocks redeem');
select tests.clear_authentication();
reset role;
update public.enrollments set status = 'refunded' where user_id = tests.get_supabase_uid('activation_a');
select tests.authenticate_as('activation_a');
select is(public.redeem_activation_code('TUVWXYZ23456', current_date),
  '{"ok":false,"error":"already_enrolled"}'::jsonb, 'PAY-06: refunded enrollment blocks redeem');
select tests.clear_authentication();
reset role;
delete from private.rate_limits where key = 'redeem:' || tests.get_supabase_uid('activation_a');
update public.enrollments set status = 'suspended' where user_id = tests.get_supabase_uid('activation_a');
select tests.authenticate_as('activation_a');
select is(public.redeem_activation_code('TUVWXYZ23456', current_date),
  '{"ok":false,"error":"already_enrolled"}'::jsonb, 'PAY-06: suspended enrollment blocks redeem');
select tests.clear_authentication();
reset role;
select ok((select redeemed_by is null and redeemed_at is null from public.activation_codes
  where code = 'TUVWXYZ23456'), 'PAY-06: all already_enrolled failures leave code unused');
select is((select count(*)::int from public.enrollments), 2,
  'PAY-06: duplicate redemption never adds an enrollment');

select tests.authenticate_as('activation_rate');
select throws_ok($$ select public.redeem_activation_code('ABCDEFGH6789', current_date - 2) $$,
  'P0001', 'invalid_input', 'PAY-07: rejects today minus two');
select throws_ok($$ select public.redeem_activation_code('ABCDEFGH6789', current_date + 549) $$,
  'P0001', 'invalid_input', 'PAY-07: rejects today plus 549');
select throws_ok($$ select public.redeem_activation_code(null, current_date) $$,
  'P0001', 'invalid_input', 'PAY-06: rejects null code');
select throws_ok($$ select public.redeem_activation_code(' -- ', current_date) $$,
  'P0001', 'invalid_input', 'PAY-06: rejects empty normalized code');
select throws_ok($$ select public.redeem_activation_code('ABCDEFGH6789', null) $$,
  'P0001', 'invalid_input', 'PAY-07: rejects null date');
select is(public.redeem_activation_code('ABCDEFGH6789', current_date - 1) -> 'ok',
  'true'::jsonb, 'PAY-07: yesterday is accepted for client timezone tolerance');
select tests.clear_authentication();
reset role;
delete from private.rate_limits where key = 'redeem:' || tests.get_supabase_uid('activation_rate');

-- Five actual RPC calls return business errors; no seeded counter or exception wrapper.
select tests.authenticate_as('activation_rate');
select is(array(select public.redeem_activation_code('WRONG' || n, current_date)
  from generate_series(1, 5) n),
  array_fill('{"ok":false,"error":"code_invalid"}'::jsonb, array[5]),
  'PAY-06: all five wrong guesses return code_invalid');
select throws_ok($$ select public.redeem_activation_code('WRONG6', current_date) $$,
  'P0001', 'rate_limited', 'PAY-06: sixth wrong guess is rate limited');
select tests.clear_authentication();
reset role;
select is((select count from private.rate_limits
  where key = 'redeem:' || tests.get_supabase_uid('activation_rate')
    and window_start = to_timestamp(floor(extract(epoch from now()) / 60) * 60)),
  5, 'PAY-06: wrong guesses persist five increments; denied sixth rolls back');

select tests.authenticate_as('activation_a');
select throws_ok($$ select private.generate_activation_codes(
  '00000000-0000-0000-0000-0000000031c1', 3, 'forbidden') $$,
  '42501', null, 'PAY-06: authenticated cannot call generator');
select tests.clear_authentication();
set local role anon;
select throws_ok($$ select public.redeem_activation_code('TUVWXYZ67892', current_date) $$,
  '42501', null, 'PAY-06: anon cannot execute redemption');
reset role;
select throws_ok($$ select public.redeem_activation_code('TUVWXYZ67892', current_date) $$,
  'P0001', 'not_authenticated', 'PAY-06: privileged call without uid still checks authentication');
select ok(not has_function_privilege('anon', 'private.generate_activation_codes(uuid,integer,text)', 'execute')
  and not has_function_privilege('authenticated', 'private.generate_activation_codes(uuid,integer,text)', 'execute')
  and not has_function_privilege('service_role', 'private.generate_activation_codes(uuid,integer,text)', 'execute'),
  'PAY-06: generator execute revoked from every API role');

create temporary table generated_codes as
select private.generate_activation_codes('00000000-0000-0000-0000-0000000031c1', 25, 'beta batch') as code;
select is((select count(*)::int from generated_codes), 25, 'PAY-06: generator returns N codes');
select is((select count(distinct code)::int from generated_codes), 25, 'PAY-06: generated codes are unique');
select ok((select bool_and(code ~ '^[ABCDEFGHJKMNPQRSTUVWXYZ23456789]{12}$') from generated_codes),
  'PAY-06: generated codes have exactly twelve characters from the alphabet');
select is((select count(*)::int from public.activation_codes a join generated_codes g using (code)
  where a.course_id = '00000000-0000-0000-0000-0000000031c1' and a.note = 'beta batch'
    and a.created_by is null and a.redeemed_by is null and a.redeemed_at is null),
  25, 'PAY-06: generated codes are stored unused with course, note and no creator');
select throws_ok($$ select private.generate_activation_codes(null, 1, null) $$,
  'P0001', 'invalid_input', 'PAY-06: generator rejects missing course');
select throws_ok($$ select private.generate_activation_codes(
  '00000000-0000-0000-0000-0000000031c1', 0, null) $$,
  'P0001', 'invalid_input', 'PAY-06: generator rejects nonpositive count');

-- Two real sessions need committed fixtures, since the main transaction is invisible
-- to them. Reserve EST for this harness; remove all remote fixtures on success/error.
-- dblink is test-only, installed transactionally and rolled back with this file.
create extension if not exists dblink with schema extensions;
do $race$
declare
  v_connection text := format('host=%L port=%s dbname=%L user=postgres connect_timeout=5',
    split_part(current_setting('unix_socket_directories'), ',', 1),
    current_setting('port'), current_database());
  v_a_pid int;
  v_b_pid int;
  v_deadline timestamptz;
  v_blocked boolean := false;
  v_result jsonb;
  v_cleanup constant text := $cleanup$
    delete from public.enrollments where course_id = '00000000-0000-0000-0000-0000000031cc';
    delete from public.activation_codes where course_id = '00000000-0000-0000-0000-0000000031cc';
    delete from public.courses where id = '00000000-0000-0000-0000-0000000031cc';
    delete from private.rate_limits where key in (
      'redeem:00000000-0000-0000-0000-0000000031aa',
      'redeem:00000000-0000-0000-0000-0000000031bb');
    delete from auth.users where id in (
      '00000000-0000-0000-0000-0000000031aa', '00000000-0000-0000-0000-0000000031bb');
  $cleanup$;
begin
  -- Owner-only connect_u permits the local database socket without embedding credentials.
  perform extensions.dblink_connect_u('activation_race_a', v_connection);
  perform extensions.dblink_connect_u('activation_race_b', v_connection);
  perform extensions.dblink_exec('activation_race_a', 'set statement_timeout = ''15s''');
  perform extensions.dblink_exec('activation_race_b', 'set statement_timeout = ''15s''');
  perform extensions.dblink_exec('activation_race_a', $seed$
    begin;
    insert into auth.users (id, email, raw_user_meta_data) values
      ('00000000-0000-0000-0000-0000000031aa', 'activation-race-a@example.com', '{"full_name":"Race A"}'),
      ('00000000-0000-0000-0000-0000000031bb', 'activation-race-b@example.com', '{"full_name":"Race B"}');
    insert into public.courses (id, code, title, slug, is_published) values
      ('00000000-0000-0000-0000-0000000031cc', 'EST', 'Race EST', 'activation-race-est', true);
    insert into public.activation_codes (code, course_id) values
      ('RACE23456789', '00000000-0000-0000-0000-0000000031cc');
    commit;
  $seed$);
  select pid into v_a_pid from extensions.dblink('activation_race_a',
    'select pg_backend_pid()') as r(pid int);
  select pid into v_b_pid from extensions.dblink('activation_race_b',
    'select pg_backend_pid()') as r(pid int);
  perform extensions.dblink_exec('activation_race_a', $auth$
    begin;
    set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-0000000031aa","role":"authenticated"}';
    set local role authenticated;
  $auth$);
  select result into v_result from extensions.dblink('activation_race_a',
    $$select public.redeem_activation_code('RACE23456789', current_date)$$) as r(result jsonb);
  perform set_config('test.race_first', v_result::text, true);
  perform extensions.dblink_exec('activation_race_b', $auth$
    begin;
    set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-0000000031bb","role":"authenticated"}';
    set local role authenticated;
  $auth$);
  perform extensions.dblink_send_query('activation_race_b',
    $$select public.redeem_activation_code('RACE23456789', current_date)$$);
  v_deadline := clock_timestamp() + interval '5 seconds';
  loop
    v_blocked := v_a_pid = any(pg_blocking_pids(v_b_pid));
    exit when v_blocked or clock_timestamp() >= v_deadline;
    perform pg_sleep(0.01);
  end loop;
  perform set_config('test.race_blocked', v_blocked::text, true);
  perform extensions.dblink_exec('activation_race_a', 'commit');
  select result into v_result from extensions.dblink_get_result('activation_race_b') as r(result jsonb);
  perform set_config('test.race_second', v_result::text, true);
  -- Async connections must be drained once more before issuing another command.
  perform * from extensions.dblink_get_result('activation_race_b') as r(result jsonb);
  perform extensions.dblink_exec('activation_race_b', 'commit');
  select result into v_result from extensions.dblink('activation_race_a', $check$
    select jsonb_build_object('count', count(*), 'only_winner', bool_and(
      user_id = '00000000-0000-0000-0000-0000000031aa'::uuid))
    from public.enrollments where course_id = '00000000-0000-0000-0000-0000000031cc'
  $check$) as r(result jsonb);
  perform set_config('test.race_enrollments', v_result::text, true);
  perform extensions.dblink_exec('activation_race_a', v_cleanup);
  perform extensions.dblink_disconnect('activation_race_b');
  perform extensions.dblink_disconnect('activation_race_a');
exception when others then
  -- Disconnecting rolls back either in-flight redemption before fixture cleanup.
  if 'activation_race_b' = any(extensions.dblink_get_connections()) then
    perform extensions.dblink_disconnect('activation_race_b');
  end if;
  if 'activation_race_a' = any(extensions.dblink_get_connections()) then
    perform extensions.dblink_exec('activation_race_a', 'rollback');
    perform extensions.dblink_exec('activation_race_a', v_cleanup);
    perform extensions.dblink_disconnect('activation_race_a');
  end if;
  raise;
end;
$race$;
select is(current_setting('test.race_first')::jsonb -> 'ok', 'true'::jsonb,
  'PAY-06: first concurrent caller redeems successfully');
select is(current_setting('test.race_blocked')::boolean, true,
  'PAY-06: second concurrent caller blocks on the first transaction');
select is(current_setting('test.race_second')::jsonb, '{"ok":false,"error":"code_used"}'::jsonb,
  'PAY-06: blocked caller sees code_used after the winner commits');
select is(current_setting('test.race_enrollments')::jsonb ->> 'count', '1',
  'PAY-06: concurrent redemption creates exactly one enrollment');
select is(current_setting('test.race_enrollments')::jsonb -> 'only_winner', 'true'::jsonb,
  'PAY-06: concurrent enrollment belongs only to the winner');

select * from finish();
rollback;
