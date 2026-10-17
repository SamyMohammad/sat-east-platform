-- LRN-01 / LRN-03: course map read side (docs/07 §1.1, §2). From templates/rpc.sql.
-- Spec: docs/superpowers/specs/2026-10-17-p1-course-map-design.md §1.
-- Read-only; lock state is computed here, never on the client. Returns only the caller's own
-- progress. No answer keys, scores or other students' data.
-- Errors (docs/07 §9): not_authenticated, invalid_input, not_enrolled, access_expired.

create or replace function public.get_course_map(p_slug text default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid    uuid := auth.uid();
  v_course public.courses%rowtype;
  v_enr    public.enrollments%rowtype;
  v_units  jsonb;
  v_cont   jsonb;
begin
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;

  if p_slug is not null then
    select c.* into v_course
    from public.courses c
    where c.slug = p_slug and c.is_published;
    if not found then
      raise exception 'invalid_input';
    end if;

    select e.* into v_enr
    from public.enrollments e
    where e.user_id = v_uid and e.course_id = v_course.id;
    if not found then
      raise exception 'not_enrolled';
    end if;
  else
    -- Slice assumption: one enrolment. Latest of any status, so an ended one reports access_expired.
    select e.* into v_enr
    from public.enrollments e
    where e.user_id = v_uid
    order by e.starts_at desc
    limit 1;
    if not found then
      raise exception 'not_enrolled';
    end if;

    select c.* into v_course
    from public.courses c
    where c.id = v_enr.course_id and c.is_published;
    if not found then
      raise exception 'invalid_input';
    end if;
  end if;

  if v_enr.status <> 'active' or v_enr.expires_at <= now() then
    raise exception 'access_expired';
  end if;

  -- Published topics in course order (units first by sort/title, unit-less topics last),
  -- joined to the caller's own progress only.
  with base as (
    select t.id, t.slug, t.title, t.is_free_preview, t.unit_id,
           u.title as unit_title,
           (tp.quiz_passed_at is not null) as done,
           (tp.unlocked_at is not null)    as unlocked,
           row_number() over (
             order by (t.unit_id is null), u.sort, u.title, t.unit_id, t.sort, t.title, t.id
           ) as pos,
           dense_rank() over (
             partition by (t.unit_id is null)
             order by u.sort, u.title, t.unit_id
           ) as unit_no,
           row_number() over (
             partition by t.unit_id order by t.sort, t.title, t.id
           ) as topic_no
    from public.topics t
    left join public.units u on u.id = t.unit_id
    left join public.topic_progress tp on tp.topic_id = t.id and tp.user_id = v_uid
    where t.course_id = v_course.id and t.is_published
  ),
  lagged as (
    select b.*,
           lag(b.done)  over (order by b.pos) as prev_done,
           lag(b.title) over (order by b.pos) as prev_title
    from base b
  ),
  shaped as (
    select l.*,
           case
             when l.done then 'completed'
             when l.pos = 1 or l.is_free_preview or coalesce(l.prev_done, false) or l.unlocked then 'open'
             else 'locked'
           end as status
    from lagged l
  ),
  grouped as (
    select s.unit_id, s.unit_title, min(s.pos) as first_pos,
           jsonb_agg(
             jsonb_build_object(
               'id', s.id,
               'slug', s.slug,
               'title', s.title,
               'sort_label', case when s.unit_id is null then s.topic_no::text
                                  else s.unit_no || '.' || s.topic_no end,
               'is_free_preview', s.is_free_preview,
               'status', s.status,
               'locked_reason', case when s.status = 'locked' then 'previous_quiz' end,
               'after_title', case when s.status = 'locked' then s.prev_title end
             ) order by s.pos
           ) as topics
    from shaped s
    group by s.unit_id, s.unit_title
  )
  select
    coalesce((select jsonb_agg(
                jsonb_build_object('title', g.unit_title, 'topics', g.topics) order by g.first_pos)
              from grouped g), '[]'::jsonb),
    (select jsonb_build_object('topic_id', s.id, 'slug', s.slug, 'title', s.title, 'unit_title', s.unit_title)
     from shaped s
     where s.status = 'open'
     order by s.pos
     limit 1)
  into v_units, v_cont;

  return jsonb_build_object(
    'course',   jsonb_build_object('id', v_course.id, 'slug', v_course.slug, 'title', v_course.title),
    'continue', v_cont,
    'units',    v_units
  );
end;
$$;

revoke execute on function public.get_course_map(text) from public, anon;
grant execute on function public.get_course_map(text) to authenticated;
