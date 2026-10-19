-- C-7 / ADM-06: teacher settings. From supabase/templates/rpc.sql.
create function private.teacher_setting_spec()
returns table (key text, grp text, label text, unit text, min int, max int, sort int)
language sql
immutable
set search_path = ''
as $$
  values
    ('pass_mark','Quiz','Pass mark','%',1,100,1),
    ('cooldown_h','Quiz','Retake cooldown','hours',0,168,2),
    ('quiz_size','Quiz','Questions per quiz','questions',1,60,3),
    ('quiz_time_per_q_s','Quiz','Time per question','seconds',15,600,4),
    ('quiz_warn_s','Quiz','Time warning at','seconds left',0,1800,5),
    ('practice_min','Practice','Practice before quiz','questions',0,50,6),
    ('homework_size','Practice','Homework size','questions',1,60,7),
    ('review_max','Practice','Review set max','questions',1,30,8),
    ('review_per_skill','Practice','Review per skill','questions',1,10,9),
    ('access_grace_days','Access','Days after test date','days',0,60,10),
    ('access_min_days','Access','Minimum access','days',1,365,11),
    ('test_date_max_days','Access','Latest test date','days ahead',30,730,12),
    ('device_limit','Devices','Devices per student','devices',1,5,13),
    ('ai_daily_cap','AI','AI questions per day','per day',0,200,14);
$$;
revoke all on function private.teacher_setting_spec()
  from public, anon, authenticated, service_role;

create function public.teacher_get_settings()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  if not public.is_teacher() then raise exception 'forbidden'; end if;
  return (select coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
    'key', spec.key, 'group', spec.grp, 'label', spec.label, 'unit', spec.unit,
    'min', spec.min, 'max', spec.max, 'value', s.value) order by spec.sort), '[]'::jsonb)
    from private.teacher_setting_spec() spec join public.settings s on s.key = spec.key);
end;
$$;
revoke execute on function public.teacher_get_settings() from public, anon;
grant execute on function public.teacher_get_settings() to authenticated;

create function public.teacher_update_settings(p_values jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_pair record;
  v_number numeric;
  v_before jsonb;
  v_next jsonb;
  v_updated jsonb := '[]'::jsonb;
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  if not public.is_teacher() then raise exception 'forbidden'; end if;
  if pg_catalog.jsonb_typeof(p_values) is distinct from 'object' then
    raise exception 'invalid_input';
  end if;
  if p_values = '{}'::jsonb then
    return pg_catalog.jsonb_build_object('ok', true, 'updated', v_updated);
  end if;

  -- Every writer locks the same quiz triple as well as its patch keys. Reading
  -- the snapshot in a subsequent statement observes a concurrent winner's save.
  -- Key order prevents deadlocks between overlapping multi-key patches.
  perform s.key from public.settings s
  where s.key in (select pg_catalog.jsonb_object_keys(p_values))
    or s.key in ('quiz_warn_s', 'quiz_size', 'quiz_time_per_q_s')
  order by s.key for update;

  for v_pair in
    select e.key, e.value, spec.min, spec.max
    from pg_catalog.jsonb_each(p_values) e
    left join private.teacher_setting_spec() spec on spec.key = e.key
  loop
    if v_pair.min is null
      or pg_catalog.jsonb_typeof(v_pair.value) is distinct from 'number'
      or not exists (select 1 from public.settings s where s.key = v_pair.key) then
      raise exception 'invalid_input';
    end if;
    v_number := v_pair.value::numeric;
    if v_number <> pg_catalog.trunc(v_number)
      or v_number < v_pair.min or v_number > v_pair.max then
      raise exception 'invalid_input';
    end if;
  end loop;

  select pg_catalog.jsonb_object_agg(s.key, s.value) into v_before
  from public.settings s where s.key in ('quiz_warn_s', 'quiz_size', 'quiz_time_per_q_s')
    or s.key in (select pg_catalog.jsonb_object_keys(p_values));
  v_next := v_before || p_values;
  if pg_catalog.jsonb_typeof(v_next -> 'quiz_warn_s') is distinct from 'number'
    or pg_catalog.jsonb_typeof(v_next -> 'quiz_size') is distinct from 'number'
    or pg_catalog.jsonb_typeof(v_next -> 'quiz_time_per_q_s') is distinct from 'number' then
    raise exception 'invalid_input';
  end if;
  if (v_next ->> 'quiz_warn_s')::numeric >=
    (v_next ->> 'quiz_size')::numeric * (v_next ->> 'quiz_time_per_q_s')::numeric then
    raise exception 'invalid_input';
  end if;

  for v_pair in select e.key, e.value from pg_catalog.jsonb_each(p_values) e order by e.key
  loop
    update public.settings s set value = v_pair.value,
      updated_at = pg_catalog.now() where s.key = v_pair.key;
    insert into public.audit_log (actor, action, entity, entity_id, diff)
    values (auth.uid(), 'settings.update', v_pair.key, null,
      pg_catalog.jsonb_build_object('before', v_before -> v_pair.key, 'after', v_pair.value));
    v_updated := v_updated || pg_catalog.jsonb_build_array(v_pair.key);
  end loop;
  return pg_catalog.jsonb_build_object('ok', true, 'updated', v_updated);
end;
$$;
revoke execute on function public.teacher_update_settings(jsonb) from public, anon;
grant execute on function public.teacher_update_settings(jsonb) to authenticated;
