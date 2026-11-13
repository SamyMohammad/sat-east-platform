-- MCK-03: scheduled expiry of mock modules. Plan: docs/superpowers/plans/2026-11-13-mck03-mock-engine-server.md Task 3.
-- The every-minute cron job (expire-attempts) already calls private.expire_overdue_attempts(); this only extends it.

-- Partial index for the overdue-module scan.
create index attempts_mock_in_progress_idx
  on public.attempts (started_at, id) where kind = 'mock_module' and status = 'in_progress';

-- One advisory key per student for all mock work, shared by RPCs and cron.
create function private.mock_lock_key(p_uid uuid)
returns bigint
language sql
immutable
set search_path = ''
as $$
  select pg_catalog.hashtextextended('mock:' || p_uid::text, 0)
$$;
revoke execute on function private.mock_lock_key(uuid) from public, anon, authenticated;

-- Same behaviour as before, now through the shared key.
create or replace function private.mock_lock(p_uid uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform pg_advisory_xact_lock(private.mock_lock_key(p_uid));
end;
$$;

-- Quiz loop identical to 20261018100000_lane2a_expire_cron.sql; new mock loop below it.
-- Returns the number of quizzes finished plus the number of students whose mocks were advanced.
create or replace function private.expire_overdue_attempts()
returns int
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_att public.attempts%rowtype;
  v_uid uuid;
  v_finished int := 0;
begin
  for v_att in
    select a.* from public.attempts a
    where a.kind = 'quiz' and a.status = 'in_progress'
      and a.started_at + pg_catalog.make_interval(secs => a.time_limit_s + private.setting_int('save_grace_s')) < pg_catalog.now()
    order by a.started_at, a.id
    for update skip locked
  loop
    -- RPCs take the advisory lock before the row lock; never wait in reverse order.
    if not pg_catalog.pg_try_advisory_xact_lock(
      pg_catalog.hashtextextended('quiz:' || v_att.user_id::text || v_att.topic_id::text, 0)
    ) then
      continue;
    end if;

    select a.* into v_att from public.attempts a where a.id = v_att.id;
    if v_att.status <> 'in_progress' then
      continue;
    end if;
    perform private.finish_quiz(v_att.id, v_att.started_at + pg_catalog.make_interval(secs => v_att.time_limit_s));
    v_finished := v_finished + 1;
  end loop;

  -- Mocks: students with a module past deadline + grace, or an ended gap with no module 2 yet.
  for v_uid in
    select distinct a.user_id from public.attempts a
    where a.kind = 'mock_module'
      and ((a.status = 'in_progress'
            and a.started_at + pg_catalog.make_interval(secs => a.time_limit_s + private.setting_int('save_grace_s')) < pg_catalog.now())
           or (a.module_no = 1 and a.status = 'submitted'
               and (a.meta ->> 'gap_until')::timestamptz <= pg_catalog.now()
               and not exists (select 1 from public.attempts m2
                               where m2.mock_attempt_group = a.mock_attempt_group and m2.kind = 'mock_module'
                                 and m2.module_no = 2)))
  loop
    -- Same key as private.mock_lock: a student mid-RPC is skipped and picked up next minute.
    if not pg_catalog.pg_try_advisory_xact_lock(private.mock_lock_key(v_uid)) then
      continue;
    end if;
    perform private.mock_tick(v_uid);
    v_finished := v_finished + 1;
  end loop;
  return v_finished;
end;
$$;
revoke execute on function private.expire_overdue_attempts() from public, anon, authenticated;
