-- L-3: preserve practice access when notes are added after completion.
-- From supabase/templates/rpc.sql; internal helpers are not client executable.
create function private.notes_satisfied(p_uid uuid, p_topic_id uuid)
returns boolean
language sql
stable
set search_path = ''
as $$
  select not exists (
    select 1 from public.topic_assets a
    where a.topic_id = p_topic_id and a.kind = 'notes' and a.ready
  ) or exists (
    select 1 from public.topic_progress p
    where p.user_id = p_uid and p.topic_id = p_topic_id
      and (p.notes_opened_at is not null
        or p.practice_count >= private.setting_int('practice_min')
        or p.quiz_passed_at is not null)
  );
$$;
revoke all on function private.notes_satisfied(uuid, uuid)
  from public, anon, authenticated, service_role;

create or replace function private.require_notes_opened(p_uid uuid, p_topic_id uuid)
returns void language plpgsql stable set search_path='' as $$
begin
 if not private.notes_satisfied(p_uid, p_topic_id) then
  raise exception 'notes_needed';
 end if;
end;
$$;
revoke all on function private.require_notes_opened(uuid,uuid) from public,anon,authenticated,service_role;

-- Copied from 20261027100000_l3_notes.sql; only the notes_done expression changes.
create or replace function public.get_topic(p_topic_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_quiz jsonb;
  v_topic record;
  v_label text;
  v_notes jsonb;
begin
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;
  if p_topic_id is null then
    raise exception 'invalid_input';
  end if;
  perform private.expire_quiz(v_uid, p_topic_id);
  v_quiz := private.quiz_state(v_uid, p_topic_id);
  select ts.* into v_topic from public.topics t
  cross join lateral private.topic_states(v_uid, t.course_id) ts
  where t.id = p_topic_id and ts.topic_id = t.id;
  v_label := v_topic.topic_no::text;
  if v_topic.unit_id is not null then
    v_label := v_topic.unit_no || '.' || v_topic.topic_no;
  end if;
  select coalesce(jsonb_agg(jsonb_build_object('asset_id', a.id, 'title', a.title,
    'subtopic_title', s.title, 'page_count', a.page_count) order by a.sort, a.id), '[]'::jsonb)
  into v_notes from public.topic_assets a left join public.subtopics s on s.id = a.subtopic_id
  where a.topic_id = p_topic_id and a.kind = 'notes' and a.ready;
  return jsonb_build_object('id', p_topic_id, 'title', v_topic.title, 'slug', v_topic.slug,
    'sort_label', v_label, 'status', v_topic.status,
    'practice', jsonb_build_object('count', v_quiz -> 'practice_count', 'min', v_quiz -> 'practice_min'),
    'quiz', v_quiz,
    'notes', v_notes, 'notes_done', private.notes_satisfied(v_uid, p_topic_id));
end;
$$;
revoke execute on function public.get_topic(uuid) from public, anon;
grant execute on function public.get_topic(uuid) to authenticated;
