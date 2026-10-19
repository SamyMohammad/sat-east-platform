-- AUTH-04: lock the watermark name after sign-up and list the caller's devices.
-- From supabase/templates/rpc.sql; keep remove_device's rolling allowance semantics.
revoke update (full_name) on public.profiles from authenticated;

create or replace function public.list_my_devices(p_fingerprint text)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid     uuid := auth.uid();
  v_changes int;
  v_devices jsonb;
begin
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;
  if p_fingerprint is null or btrim(p_fingerprint) = '' then
    raise exception 'invalid_input';
  end if;

  v_changes := private.setting_int('device_changes_30d');

  select coalesce(jsonb_agg(jsonb_build_object(
           'id', d.id, 'label', d.label, 'platform', d.platform,
           'last_seen_at', d.last_seen_at, 'created_at', d.created_at,
           'is_current', d.device_fingerprint = p_fingerprint)
           order by d.last_seen_at desc nulls last, d.created_at desc), '[]'::jsonb)
  into v_devices
  from public.devices d
  where d.user_id = v_uid and d.revoked_at is null;

  return jsonb_build_object(
    'devices', v_devices,
    'changes_left', greatest(v_changes - private.device_changes_used(v_uid), 0)
  );
end;
$$;

revoke execute on function public.list_my_devices(text) from public, anon;
grant execute on function public.list_my_devices(text) to authenticated;
