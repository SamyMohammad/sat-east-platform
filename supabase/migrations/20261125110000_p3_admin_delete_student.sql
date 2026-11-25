-- P3.7 / NFR-12 / AUTH-03: the teacher hard-deletes a student on request (docs/06 §4, docs/07 §9).
-- Deleting auth.users cascades to profiles and every user_id table; activation_codes.redeemed_by
-- becomes null (the code stays used). One audit_log row survives, holding row counts only.
-- From supabase/templates/rpc.sql + setting.sql.

insert into public.settings (key, value) values
  ('rate_delete_student_per_hour', '20'::jsonb)
on conflict (key) do nothing;

create or replace function public.admin_delete_student(p_email text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid    uuid := auth.uid();
  v_email  text := pg_catalog.lower(pg_catalog.btrim(coalesce(p_email, '')));
  v_target uuid;
  v_role   public.user_role;
  v_counts jsonb;
begin
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;

  if not public.is_teacher() then
    raise exception 'forbidden';
  end if;

  if v_email = '' then
    raise exception 'invalid_input';
  end if;

  perform private.hit_rate_limit(
    'admin_delete_student:' || v_uid,
    private.setting_int('rate_delete_student_per_hour'), 3600);

  select u.id, p.role into v_target, v_role
  from auth.users u
  join public.profiles p on p.id = u.id
  where pg_catalog.lower(pg_catalog.btrim(u.email)) = v_email;

  if v_target is null then
    raise exception 'student_not_found';
  end if;

  -- Teachers and parents are never deleted here; this also covers the caller.
  if v_role <> 'student' or v_target = v_uid then
    raise exception 'forbidden';
  end if;

  -- Financial records block deletion (orders.user_id is on delete restrict).
  if exists (select 1 from public.orders o where o.user_id = v_target) then
    raise exception 'student_has_orders';
  end if;

  v_counts := pg_catalog.jsonb_build_object(
    'devices',          (select count(*) from public.devices where user_id = v_target),
    'enrollments',      (select count(*) from public.enrollments where user_id = v_target),
    'attempts',         (select count(*) from public.attempts where user_id = v_target),
    'topic_progress',   (select count(*) from public.topic_progress where user_id = v_target),
    'video_progress',   (select count(*) from public.video_progress where user_id = v_target),
    'mock_results',     (select count(*) from public.mock_results where user_id = v_target),
    'mistake_notebook', (select count(*) from public.mistake_notebook where user_id = v_target),
    'skill_mastery',    (select count(*) from public.skill_mastery where user_id = v_target),
    'ai_threads',       (select count(*) from public.ai_threads where user_id = v_target),
    'notifications',    (select count(*) from public.notifications where user_id = v_target));

  -- Counts only: no name, email or phone in the audit trail.
  insert into public.audit_log (actor, action, entity, entity_id, diff)
  values (v_uid, 'student_deleted', 'profiles', v_target, v_counts);

  delete from auth.users where id = v_target;

  return pg_catalog.jsonb_build_object(
    'ok', true, 'deleted_user_id', v_target, 'counts', v_counts);
end;
$$;

revoke execute on function public.admin_delete_student(text) from public, anon;
grant execute on function public.admin_delete_student(text) to authenticated;
