-- AUTH-04 / AUTH-05: device limit (docs/07 §8). From supabase/templates/rpc.sql + setting.sql.
-- Writes to devices / device_changes happen only here (students have no table write grants).

insert into public.settings (key, value)
values ('device_header_required', 'false'::jsonb)
on conflict (key) do nothing;  -- flipped to true once the client sends x-device-id (after A-1)

-- Internal: setting as int / bool. Not exposed (private schema).
create or replace function private.setting_int(p_key text)
returns int
language sql
stable
security definer
set search_path = ''
as $$
  select (s.value)::int from public.settings s where s.key = p_key;
$$;

-- Internal: the caller's devices that count towards the limit, as the S-11 list.
create or replace function private.active_devices_json(p_user_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(jsonb_agg(jsonb_build_object(
           'id', d.id, 'platform', d.platform, 'label', d.label, 'last_seen_at', d.last_seen_at)
           order by d.last_seen_at desc nulls last, d.created_at desc), '[]'::jsonb)
  from public.devices d
  where d.user_id = p_user_id and d.revoked_at is null;
$$;

-- Internal: changes used in the rolling 30-day window (the window is part of the setting's name,
-- device_changes_30d).
create or replace function private.device_changes_used(p_user_id uuid)
returns int
language sql
stable
security definer
set search_path = ''
as $$
  select count(*)::int from public.device_changes c
  where c.user_id = p_user_id and c.changed_at > now() - interval '30 days';
$$;

create or replace function public.register_device(
  p_fingerprint text,
  p_platform    text default null,
  p_label       text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid     uuid := auth.uid();
  v_device  public.devices%rowtype;
  v_known   boolean;
  v_limit   int;
  v_active  int;
  v_changes int;
begin
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;
  if p_fingerprint is null or p_fingerprint !~ '^[A-Za-z0-9_-]{16,128}$'
     or (p_platform is not null and p_platform not in ('web', 'android', 'ios'))
     or length(p_label) > 80 then
    raise exception 'invalid_input';
  end if;

  -- One registration at a time per user, so parallel calls cannot overshoot the limit.
  perform 1 from public.profiles p where p.id = v_uid for update;

  select * into v_device from public.devices d
  where d.user_id = v_uid and d.device_fingerprint = p_fingerprint;
  -- Keep the result: later queries overwrite FOUND.
  v_known := found;

  if v_known and v_device.revoked_at is null then
    update public.devices
    set last_seen_at = now(),
        platform = coalesce(p_platform, platform),
        label = coalesce(p_label, label)
    where id = v_device.id;
    return jsonb_build_object('status', 'ok', 'device_id', v_device.id);
  end if;

  -- New, or revoked and coming back: needs a free slot (teachers are never limited).
  v_limit := private.setting_int('device_limit');
  select count(*)::int into v_active from public.devices d
  where d.user_id = v_uid and d.revoked_at is null;

  if not public.is_teacher() and v_active >= v_limit then
    v_changes := private.setting_int('device_changes_30d');
    return jsonb_build_object(
      'status', 'limit_reached',
      'devices', private.active_devices_json(v_uid),
      'changes_left', greatest(v_changes - private.device_changes_used(v_uid), 0)
    );
  end if;

  if v_known then
    update public.devices
    set revoked_at = null, last_seen_at = now(),
        platform = coalesce(p_platform, platform), label = coalesce(p_label, label)
    where id = v_device.id;
    return jsonb_build_object('status', 'ok', 'device_id', v_device.id);
  end if;

  insert into public.devices (user_id, device_fingerprint, platform, label, last_seen_at)
  values (v_uid, p_fingerprint, p_platform, p_label, now())
  returning * into v_device;
  return jsonb_build_object('status', 'ok', 'device_id', v_device.id);
end;
$$;

create or replace function public.remove_device(p_device_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid     uuid := auth.uid();
  v_changes int;
  v_used    int;
begin
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;
  if p_device_id is null then
    raise exception 'invalid_input';
  end if;

  perform 1 from public.profiles p where p.id = v_uid for update;

  -- Only the caller's own, active devices (same answer for "not yours" and "does not exist").
  perform 1 from public.devices d
  where d.id = p_device_id and d.user_id = v_uid and d.revoked_at is null;
  if not found then
    raise exception 'forbidden';
  end if;

  v_changes := private.setting_int('device_changes_30d');
  v_used := private.device_changes_used(v_uid);
  if v_used >= v_changes then
    raise exception 'device_limit';
  end if;

  update public.devices set revoked_at = now() where id = p_device_id;
  insert into public.device_changes (user_id) values (v_uid);
  return jsonb_build_object('changes_left', v_changes - v_used - 1);
end;
$$;

create or replace function public.device_status(p_fingerprint text)
returns text
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid     uuid := auth.uid();
  v_revoked timestamptz;
begin
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;
  select d.revoked_at into v_revoked from public.devices d
  where d.user_id = v_uid and d.device_fingerprint = p_fingerprint;
  if not found then
    return 'unknown';
  end if;
  return case when v_revoked is null then 'active' else 'revoked' end;
end;
$$;

-- AUTH-05: teacher tools. Every action is audited.
create or replace function public.teacher_list_devices(p_user_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'not_authenticated';
  end if;
  if not public.is_teacher() then
    raise exception 'forbidden';
  end if;
  return jsonb_build_object(
    'devices', (
      select coalesce(jsonb_agg(jsonb_build_object(
               'id', d.id, 'platform', d.platform, 'label', d.label,
               'last_seen_at', d.last_seen_at, 'revoked_at', d.revoked_at, 'created_at', d.created_at)
               order by d.created_at), '[]'::jsonb)
      from public.devices d where d.user_id = p_user_id
    ),
    'changes_used_30d', private.device_changes_used(p_user_id)
  );
end;
$$;

create or replace function public.teacher_revoke_device(p_device_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;
  if not public.is_teacher() then
    raise exception 'forbidden';
  end if;
  update public.devices set revoked_at = now()
  where id = p_device_id and revoked_at is null;
  if not found then
    raise exception 'invalid_input';
  end if;
  insert into public.audit_log (actor, action, entity, entity_id)
  values (v_uid, 'device.revoke', 'devices', p_device_id);
  return jsonb_build_object('ok', true);
end;
$$;

create or replace function public.teacher_reset_devices(p_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid     uuid := auth.uid();
  v_revoked int;
  v_cleared int;
begin
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;
  if not public.is_teacher() then
    raise exception 'forbidden';
  end if;
  update public.devices set revoked_at = now()
  where user_id = p_user_id and revoked_at is null;
  get diagnostics v_revoked = row_count;
  delete from public.device_changes where user_id = p_user_id;
  get diagnostics v_cleared = row_count;
  insert into public.audit_log (actor, action, entity, entity_id, diff)
  values (v_uid, 'device.reset', 'profiles', p_user_id,
          jsonb_build_object('revoked', v_revoked, 'changes_cleared', v_cleared));
  return jsonb_build_object('ok', true, 'revoked', v_revoked);
end;
$$;

-- has_access gains the device check (docs/07 §8). Same signature, so existing policies keep it.
create or replace function private.device_allowed()
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_device text := nullif(current_setting('request.headers', true), '')::json ->> 'x-device-id';
begin
  if v_device is null then
    return not coalesce(
      (select (s.value)::boolean from public.settings s where s.key = 'device_header_required'),
      false);
  end if;
  return exists (
    select 1 from public.devices d
    where d.user_id = (select auth.uid())
      and d.device_fingerprint = v_device
      and d.revoked_at is null
  );
end;
$$;

create or replace function public.has_access(p_course_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.enrollments
    where user_id = (select auth.uid())
      and course_id = p_course_id
      and status = 'active'
      and now() < expires_at
  ) and private.device_allowed();
$$;

revoke execute on function private.setting_int(text) from public, anon, authenticated;
revoke execute on function private.active_devices_json(uuid) from public, anon, authenticated;
revoke execute on function private.device_changes_used(uuid) from public, anon, authenticated;
revoke execute on function private.device_allowed() from public, anon, authenticated;

revoke execute on function public.register_device(text, text, text) from public, anon;
revoke execute on function public.remove_device(uuid) from public, anon;
revoke execute on function public.device_status(text) from public, anon;
revoke execute on function public.teacher_list_devices(uuid) from public, anon;
revoke execute on function public.teacher_revoke_device(uuid) from public, anon;
revoke execute on function public.teacher_reset_devices(uuid) from public, anon;
grant execute on function public.register_device(text, text, text) to authenticated;
grant execute on function public.remove_device(uuid) to authenticated;
grant execute on function public.device_status(text) to authenticated;
grant execute on function public.teacher_list_devices(uuid) to authenticated;
grant execute on function public.teacher_revoke_device(uuid) to authenticated;
grant execute on function public.teacher_reset_devices(uuid) to authenticated;
