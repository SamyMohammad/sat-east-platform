-- PRC-03 / SEC: scheduled expiry and cleanup. From templates/rpc.sql + setting.sql.
create extension if not exists pg_cron;
revoke all on schema cron from public, anon, authenticated;

insert into public.settings (key, value)
values ('practice_stale_h', '24'::jsonb)
on conflict (key) do nothing;

-- Internal cron entry points run as the migration owner, without a user JWT.
create or replace function private.expire_overdue_attempts()
returns int
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_att public.attempts%rowtype;
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
  return v_finished;
end;
$$;
revoke execute on function private.expire_overdue_attempts() from public, anon, authenticated;

create or replace function private.nightly_cleanup()
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.attempts a
  set status = 'abandoned'
  where a.kind = 'practice' and a.status = 'in_progress'
    and coalesce((select pg_catalog.max(aa.answered_at) from public.attempt_answers aa where aa.attempt_id = a.id), a.started_at)
      < pg_catalog.now() - pg_catalog.make_interval(hours => private.setting_int('practice_stale_h'));

  delete from private.rate_limits r
  where r.window_start < pg_catalog.now() - interval '1 day';
end;
$$;
revoke execute on function private.nightly_cleanup() from public, anon, authenticated;

-- Named schedules upsert per job name and owner; pg_cron's default timezone is UTC.
select cron.schedule('expire-attempts', '* * * * *', 'select private.expire_overdue_attempts()');
select cron.schedule('nightly-cleanup', '0 2 * * *', 'select private.nightly_cleanup()');
