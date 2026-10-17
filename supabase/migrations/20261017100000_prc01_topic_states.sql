-- PRC-01 / LRN-01: topic lock state in one place (docs/07 §2). From templates/rpc.sql.
-- Spec: docs/superpowers/specs/2026-10-17-p1-practice-design.md §1.1.
-- private.topic_states computes each published topic's position, labels and lock status for one
-- student; get_course_map (unchanged output) and the practice RPCs read it. Internal: no grants.

create or replace function private.topic_states(p_uid uuid, p_course_id uuid)
returns table (
  topic_id        uuid,
  unit_id         uuid,
  unit_title      text,
  title           text,
  slug            text,
  is_free_preview boolean,
  pos             int,
  unit_no         int,
  topic_no        int,
  status          text,
  after_title     text
)
language sql
stable
security definer
set search_path = ''
as $$
  -- Published topics in course order (units first by sort/title, unit-less topics last),
  -- joined to the student's own progress only.
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
    left join public.topic_progress tp on tp.topic_id = t.id and tp.user_id = p_uid
    where t.course_id = p_course_id and t.is_published
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
  )
  select s.id, s.unit_id, s.unit_title, s.title, s.slug, s.is_free_preview,
         s.pos::int, s.unit_no::int, s.topic_no::int, s.status,
         case when s.status = 'locked' then s.prev_title end
  from shaped s;
$$;

revoke execute on function private.topic_states(uuid, uuid) from public, anon, authenticated;

-- get_course_map: same signature and output as 20261017000000_lrn01_course_map.sql; the lock rule
-- now comes from private.topic_states.
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
    order by e.starts_at desc, e.created_at desc, e.id
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

  with shaped as (
    select ts.* from private.topic_states(v_uid, v_course.id) ts
  ),
  grouped as (
    select s.unit_id, s.unit_title, min(s.pos) as first_pos,
           jsonb_agg(
             jsonb_build_object(
               'id', s.topic_id,
               'slug', s.slug,
               'title', s.title,
               'sort_label', case when s.unit_id is null then s.topic_no::text
                                  else s.unit_no || '.' || s.topic_no end,
               'is_free_preview', s.is_free_preview,
               'status', s.status,
               'locked_reason', case when s.status = 'locked' then 'previous_quiz' end,
               'after_title', s.after_title
             ) order by s.pos
           ) as topics
    from shaped s
    group by s.unit_id, s.unit_title
  )
  select
    coalesce((select jsonb_agg(
                jsonb_build_object('title', g.unit_title, 'topics', g.topics) order by g.first_pos)
              from grouped g), '[]'::jsonb),
    (select jsonb_build_object('topic_id', s.topic_id, 'slug', s.slug, 'title', s.title, 'unit_title', s.unit_title)
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
