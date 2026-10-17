-- LRN-05 / L-9: teacher unlock with idempotent audit. From templates/rpc.sql.
create or replace function public.teacher_unlock_topic(p_student_id uuid, p_topic_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_progress public.topic_progress%rowtype;
begin
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;
  if not public.is_teacher() then
    raise exception 'forbidden';
  end if;
  if p_student_id is null or p_topic_id is null
    or not exists (select 1 from public.profiles p where p.id = p_student_id and p.role = 'student')
    or not exists (select 1 from public.topics t where t.id = p_topic_id and t.is_published) then
    raise exception 'invalid_input';
  end if;

  -- The conflict update locks the row; only the first unlock returns a row to audit.
  insert into public.topic_progress (user_id, topic_id, unlocked_at, unlocked_by)
  values (p_student_id, p_topic_id, pg_catalog.now(), v_uid)
  on conflict (user_id, topic_id) do update
    set unlocked_at = coalesce(public.topic_progress.unlocked_at, pg_catalog.now()),
        unlocked_by = coalesce(public.topic_progress.unlocked_by, v_uid)
    where public.topic_progress.unlocked_at is null
  returning * into v_progress;

  if found then
    insert into public.audit_log (actor, action, entity, entity_id, diff)
    values (v_uid, 'topic.unlock', 'topic', p_topic_id,
      pg_catalog.jsonb_build_object('student_id', p_student_id, 'unlocked_at', v_progress.unlocked_at));
  else
    select tp.* into v_progress from public.topic_progress tp
    where tp.user_id = p_student_id and tp.topic_id = p_topic_id;
  end if;

  return pg_catalog.jsonb_build_object('topic_id', p_topic_id,
    'unlocked_at', v_progress.unlocked_at, 'unlocked_by', v_progress.unlocked_by);
end;
$$;
revoke execute on function public.teacher_unlock_topic(uuid, uuid) from public, anon;
grant execute on function public.teacher_unlock_topic(uuid, uuid) to authenticated;
