-- CRS-06: free topic preview. Security envelope from supabase/templates/rpc.sql.
-- No CASCADE: replace the return shape explicitly, then recreate every current reader.
-- PL/pgSQL readers bind at runtime; their signatures and privileges are preserved below.
begin;

drop function private.topic_states(uuid, uuid);

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
  after_title     text,
  locked_reason   text
)
language sql
stable
security definer
set search_path = ''
as $$
  -- Published topics in course order (units first by sort/title, unit-less topics last),
  -- joined to the student's own progress only.
  with access as (
    select not exists (
      select 1 from public.enrollments e where e.user_id = p_uid and e.course_id = p_course_id
    ) as preview
  ), base as (
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
             when a.preview then case when l.is_free_preview then 'open' else 'locked' end
             when l.pos = 1 or l.is_free_preview or coalesce(l.prev_done, false) or l.unlocked then 'open'
             else 'locked'
           end as status
    from lagged l cross join access a
  )
  select s.id, s.unit_id, s.unit_title, s.title, s.slug, s.is_free_preview,
         s.pos::int, s.unit_no::int, s.topic_no::int, s.status,
         case when s.status = 'locked' and not a.preview then s.prev_title end,
         case when s.status = 'locked' then
           case when a.preview then 'needs_access' else 'previous_quiz' end end
  from shaped s cross join access a;
$$;

revoke execute on function private.topic_states(uuid, uuid) from public, anon, authenticated;

create or replace function private.practice_access(p_uid uuid, p_topic_id uuid)
returns uuid
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_course_id uuid;
  v_enr       public.enrollments%rowtype;
  v_status    text;
begin
  select t.course_id into v_course_id
  from public.topics t
  join public.courses c on c.id = t.course_id
  where t.id = p_topic_id and t.is_published and c.is_published;
  if not found then
    raise exception 'invalid_input';
  end if;

  select e.* into v_enr
  from public.enrollments e
  where e.user_id = p_uid and e.course_id = v_course_id;
  if not found then
    if exists (select 1 from public.topics t where t.id = p_topic_id and t.is_free_preview) then
      return v_course_id;
    end if;
    raise exception 'not_enrolled';
  end if;
  if v_enr.status <> 'active' or v_enr.expires_at <= now() then
    raise exception 'access_expired';
  end if;

  select ts.status into v_status
  from private.topic_states(p_uid, v_course_id) ts
  where ts.topic_id = p_topic_id;
  if v_status is distinct from 'open' and v_status is distinct from 'completed' then
    raise exception 'topic_locked';
  end if;

  return v_course_id;
end;
$$;

revoke execute on function private.practice_access(uuid, uuid) from public, anon, authenticated;

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
  v_access text := 'full';
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
      v_access := 'preview';
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

  if v_access = 'full' and (v_enr.status <> 'active' or v_enr.expires_at <= now()) then
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
               'locked_reason', s.locked_reason,
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
    'access',   v_access,
    'course',   jsonb_build_object('id', v_course.id, 'slug', v_course.slug, 'title', v_course.title),
    'continue', v_cont,
    'units',    v_units
  );
end;
$$;

revoke execute on function public.get_course_map(text) from public, anon;
grant execute on function public.get_course_map(text) to authenticated;

create or replace function public.get_topic(p_topic_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_uid uuid := auth.uid();
  v_quiz jsonb;
  v_topic record;
  v_label text;
  v_notes jsonb;
  v_videos jsonb;
begin
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;
  if p_topic_id is null then
    raise exception 'invalid_input';
  end if;
  perform private.expire_quiz(v_uid, p_topic_id);
  perform private.practice_access(v_uid, p_topic_id);
  v_quiz := private.quiz_state(v_uid, p_topic_id);
  select ts.* into v_topic from public.topics t
  cross join lateral private.topic_states(v_uid, t.course_id) ts
  where t.id = p_topic_id and ts.topic_id = t.id;
  v_label := v_topic.topic_no::text;
  if v_topic.unit_id is not null then
    v_label := v_topic.unit_no || '.' || v_topic.topic_no;
  end if;
  select coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('asset_id', a.id, 'title', a.title,
    'subtopic_title', s.title, 'page_count', a.page_count) order by a.sort, a.id), '[]'::jsonb)
  into v_notes from public.topic_assets a left join public.subtopics s on s.id = a.subtopic_id
  where a.topic_id = p_topic_id and a.kind = 'notes' and a.ready;
  select coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
    'asset_id',a.id,'title',a.title,'subtopic_title',s.title,'duration_s',a.duration_s,
    'provider',a.provider,'pct',coalesce(p.pct,0),'last_position_s',coalesce(p.last_position_s,0)
    ) order by a.sort,a.id),'[]'::jsonb)
  into v_videos from public.topic_assets a
  left join public.subtopics s on s.id=a.subtopic_id
  left join public.video_progress p on p.asset_id=a.id and p.user_id=v_uid
  where a.topic_id=p_topic_id and a.kind='video' and a.ready;
  return pg_catalog.jsonb_build_object('id', p_topic_id, 'title', v_topic.title, 'slug', v_topic.slug,
    'sort_label', v_label, 'status', v_topic.status,
    'practice', pg_catalog.jsonb_build_object('count', v_quiz -> 'practice_count', 'min', v_quiz -> 'practice_min'),
    'quiz', v_quiz, 'homework', private.homework_state(v_uid, p_topic_id),
    'videos',v_videos,'video_done',private.video_satisfied(v_uid,p_topic_id),
    'notes', v_notes, 'notes_done', private.notes_satisfied(v_uid, p_topic_id));
end;
$fn$;
revoke execute on function public.get_topic(uuid) from public, anon;
grant execute on function public.get_topic(uuid) to authenticated;

create or replace function private.notes_object_readable(p_name text)
returns boolean language plpgsql stable security definer set search_path='' as $$
declare
 v_uid uuid := auth.uid();
 v_parts text[];
 v_topic uuid;
 v_asset uuid;
begin
 if v_uid is null then return false; end if;
 v_parts := pg_catalog.regexp_match(p_name,
  '^([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})/([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})[.]pdf$');
 if v_parts is null then return false; end if;
 v_topic := v_parts[1]::uuid;
 v_asset := v_parts[2]::uuid;
 if public.is_teacher() then return true; end if;
 return exists (
  select 1 from public.topic_assets a
  join public.topics t on t.id=a.topic_id
  join public.courses c on c.id=t.course_id
  cross join lateral private.topic_states(v_uid,c.id) ts
  where a.id=v_asset and a.topic_id=v_topic and a.kind='notes' and a.ready
   and a.storage_path=p_name and c.is_published and t.is_published
   and public.has_access_topic(t.id)
   and (public.has_access(c.id) or not exists (
     select 1 from public.enrollments e where e.user_id=v_uid and e.course_id=c.id
   )) and ts.topic_id=t.id and ts.status in ('open','completed'));
end;
$$;
revoke all on function private.notes_object_readable(text) from public,anon,authenticated,service_role;
grant execute on function private.notes_object_readable(text) to authenticated;

-- Keep the OID-bound private helper and the existing ready/path/open-topic checks.
drop policy "notes: read accessible object" on storage.objects;
create policy "notes: read accessible object" on storage.objects
 for select to authenticated
 using (bucket_id='notes' and private.notes_object_readable(name));

create or replace function public.start_homework(p_topic_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_uid uuid := auth.uid();
  v_course uuid;
  v_att public.attempts%rowtype;
  v_questions jsonb;
  v_answers jsonb;
  v_seq int;
  v_n int;
  v_topic record;
  v_label text;
begin
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;
  if p_topic_id is null then
    raise exception 'invalid_input';
  end if;
  v_course := private.practice_access(v_uid, p_topic_id);
  perform private.require_notes_opened(v_uid, p_topic_id);
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('homework:' || v_uid::text || p_topic_id::text, 0));
  select a.* into v_att from public.attempts a
  where a.user_id = v_uid and a.topic_id = p_topic_id and a.kind = 'homework'
  order by a.started_at, a.id limit 1;
  if found then
    if v_att.status <> 'in_progress' then
      raise exception 'attempt_closed';
    end if;
  else
    if not exists (select 1 from public.topic_progress tp
      where tp.user_id = v_uid and tp.topic_id = p_topic_id
        and (tp.practice_count >= private.setting_int('practice_min') or tp.quiz_passed_at is not null)) then
      raise exception 'practice_needed';
    end if;
    insert into public.attempts(user_id, kind, course_id, topic_id)
    values(v_uid, 'homework', v_course, p_topic_id) returning * into v_att;
    insert into public.attempt_questions(attempt_id, question_id, position)
    select v_att.id, d.id, pg_catalog.row_number() over(order by d.practice_answered, d.first_seen_at nulls first, d.r)
    from (
      select q.id, exists (
        select 1 from public.attempt_answers aa join public.attempts a on a.id = aa.attempt_id
        where a.user_id = v_uid and a.kind = 'practice' and aa.question_id = q.id
          and aa.answered_at is not null
      ) as practice_answered, x.first_seen_at, pg_catalog.random() as r
      from public.questions q
      left join public.question_exposure x on x.user_id = v_uid and x.question_id = q.id
      where q.topic_id = p_topic_id and q.pool = 'practice' and q.status = 'published'
      order by practice_answered, x.first_seen_at nulls first, r
      limit private.setting_int('homework_size')
    ) d;
    get diagnostics v_n = row_count;
    if v_n = 0 then
      raise exception 'pool_exhausted';
    end if;
    insert into public.question_exposure(user_id, question_id)
    select v_uid, aq.question_id from public.attempt_questions aq where aq.attempt_id = v_att.id
    on conflict(user_id, question_id) do nothing;
  end if;
  select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
    'id', q.id, 'type', q.type, 'difficulty', q.difficulty, 'stem_md', q.stem_md,
    'choices', coalesce((select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
      'label', c.label, 'body_md', c.body_md) order by c.label)
      from public.question_choices c where c.question_id = q.id), '[]'::jsonb)) order by aq.position)
  into v_questions from public.attempt_questions aq join public.questions q on q.id = aq.question_id
  where aq.attempt_id = v_att.id;
  select coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('question_id', aa.question_id,
    'answer', aa.answer -> 'value', 'marked', aa.marked_for_review) order by aq.position), '[]'::jsonb),
    coalesce(pg_catalog.max(aa.client_seq), 0)
  into v_answers, v_seq from public.attempt_answers aa
  join public.attempt_questions aq on aq.attempt_id = aa.attempt_id and aq.question_id = aa.question_id
  where aa.attempt_id = v_att.id;
  select ts.* into v_topic from private.topic_states(v_uid, v_course) ts where ts.topic_id = p_topic_id;
  v_label := v_topic.topic_no::text;
  if v_topic.unit_id is not null then
    v_label := v_topic.unit_no || '.' || v_topic.topic_no;
  end if;
  return pg_catalog.jsonb_build_object('attempt_id', v_att.id, 'title', v_label || ' ' || v_topic.title,
    'questions', v_questions, 'answers', v_answers, 'client_seq', v_seq);
end;
$fn$;
revoke execute on function public.start_homework(uuid) from public, anon;
grant execute on function public.start_homework(uuid) to authenticated;

create or replace function public.start_quiz(p_topic_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_uid uuid := auth.uid();
  v_state jsonb;
  v_att public.attempts%rowtype;
  v_course uuid;
  v_n int;
  v_questions jsonb;
  v_answers jsonb;
  v_seq int;
  v_topic record;
  v_label text;
begin
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;
  perform private.hit_rate_limit('start_quiz:' || v_uid, private.setting_int('rate_start_per_min'), 60);
  if p_topic_id is null then
    raise exception 'invalid_input';
  end if;
  perform private.expire_quiz(v_uid, p_topic_id);
  v_state := private.quiz_state(v_uid, p_topic_id);
  if v_state ->> 'state' = 'practice_needed' then
    raise exception 'practice_needed';
  end if;
  if v_state ->> 'state' = 'homework_needed' then
    raise exception 'homework_needed';
  end if;
  if v_state ->> 'state' = 'review_needed' then
    raise exception 'review_needed';
  end if;
  if v_state ->> 'state' = 'cooldown' then
    raise exception 'cooldown_active';
  end if;

  select t.course_id into v_course from public.topics t where t.id = p_topic_id;
  if v_state ->> 'state' = 'in_progress' then
    select a.* into v_att from public.attempts a where a.id = (v_state ->> 'attempt_id')::uuid;
  else
    insert into public.attempts (user_id, kind, course_id, topic_id, started_at)
    values (v_uid, 'quiz', v_course, p_topic_id, pg_catalog.now()) returning * into v_att;
    insert into public.attempt_questions (attempt_id, question_id, position)
    select v_att.id, d.id, pg_catalog.row_number() over (order by d.unseen desc, d.r)
    from (
      select q.id, (x.question_id is null) as unseen, pg_catalog.random() as r
      from public.questions q
      left join public.question_exposure x on x.user_id = v_uid and x.question_id = q.id
      where q.topic_id = p_topic_id and q.pool = 'quiz' and q.status = 'published'
      order by unseen desc, r limit private.setting_int('quiz_size')
    ) d;
    get diagnostics v_n = row_count;
    if v_n = 0 then
      raise exception 'pool_exhausted';
    end if;
    update public.attempts a set time_limit_s = v_n * private.setting_int('quiz_time_per_q_s')
    where a.id = v_att.id returning a.* into v_att;
    insert into public.question_exposure (user_id, question_id)
    select v_uid, aq.question_id from public.attempt_questions aq where aq.attempt_id = v_att.id
    on conflict (user_id, question_id) do nothing;
  end if;

  select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('id', q.id, 'type', q.type, 'difficulty', q.difficulty,
    'stem_md', q.stem_md, 'choices', coalesce((select pg_catalog.jsonb_agg(
      pg_catalog.jsonb_build_object('label', c.label, 'body_md', c.body_md) order by c.label)
      from public.question_choices c where c.question_id = q.id), '[]'::jsonb)) order by aq.position)
  into v_questions from public.attempt_questions aq join public.questions q on q.id = aq.question_id
  where aq.attempt_id = v_att.id;
  select coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('question_id', aa.question_id,
    'answer', aa.answer -> 'value', 'marked', aa.marked_for_review) order by aq.position), '[]'::jsonb),
    coalesce(pg_catalog.max(aa.client_seq), 0)
  into v_answers, v_seq from public.attempt_answers aa
  join public.attempt_questions aq on aq.attempt_id = aa.attempt_id and aq.question_id = aa.question_id
  where aa.attempt_id = v_att.id;
  select ts.* into v_topic from private.topic_states(v_uid, v_course) ts where ts.topic_id = p_topic_id;
  v_label := v_topic.topic_no::text;
  if v_topic.unit_id is not null then
    v_label := v_topic.unit_no || '.' || v_topic.topic_no;
  end if;
  return pg_catalog.jsonb_build_object('attempt_id', v_att.id, 'title', v_label || ' ' || v_topic.title,
    'time_limit_s', v_att.time_limit_s, 'deadline', v_att.started_at + pg_catalog.make_interval(secs => v_att.time_limit_s),
    'server_now', pg_catalog.now(), 'warn_s', private.setting_int('quiz_warn_s'),
    'questions', v_questions, 'answers', v_answers, 'client_seq', v_seq);
end;
$fn$;
revoke execute on function public.start_quiz(uuid) from public, anon;
grant execute on function public.start_quiz(uuid) to authenticated;

create or replace function private.finish_quiz(p_attempt_id uuid, p_submitted_at timestamptz)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_att public.attempts%rowtype;
  v_raw int;
  v_total int;
  v_pct numeric;
  v_pass_mark int := private.setting_int('pass_mark');
  v_passed boolean;
  v_next jsonb;
  v_next_needs_access boolean;
  v_retake_at timestamptz;
  v_report jsonb;
  v_skills jsonb;
begin
  select a.* into v_att from public.attempts a where a.id = p_attempt_id and a.kind = 'quiz' for update;
  if not found then
    raise exception 'invalid_input';
  end if;
  if v_att.status = 'submitted' then
    return v_att.meta -> 'report';
  end if;
  if v_att.status <> 'in_progress' then
    raise exception 'invalid_input';
  end if;

  insert into public.attempt_answers (attempt_id, question_id, answer, is_correct, answered_at)
  select aq.attempt_id, aq.question_id, jsonb_build_object('value', null), false, p_submitted_at
  from public.attempt_questions aq where aq.attempt_id = p_attempt_id
  on conflict (attempt_id, question_id) do nothing;
  update public.attempt_answers aa
  set is_correct = private.grade_answer(aa.question_id, aa.answer ->> 'value')
  where aa.attempt_id = p_attempt_id;
  select count(*)::int, count(*) filter (where aa.is_correct)::int into v_total, v_raw
  from public.attempt_questions aq
  join public.attempt_answers aa on aa.attempt_id = aq.attempt_id and aa.question_id = aq.question_id
  where aq.attempt_id = p_attempt_id;
  if v_total = 0 then
    raise exception 'invalid_input';
  end if;
  v_pct := round(100::numeric * v_raw / v_total, 2);
  v_passed := v_pct >= v_pass_mark;

  insert into public.topic_progress (user_id, topic_id, quiz_best_score)
  values (v_att.user_id, v_att.topic_id, v_pct)
  on conflict (user_id, topic_id) do update
    set quiz_best_score = greatest(public.topic_progress.quiz_best_score, excluded.quiz_best_score);
  if v_passed then
    update public.topic_progress tp set quiz_passed_at = coalesce(tp.quiz_passed_at, p_submitted_at)
    where tp.user_id = v_att.user_id and tp.topic_id = v_att.topic_id;
  else
    update public.topic_progress tp set quiz_last_failed_at = p_submitted_at
    where tp.user_id = v_att.user_id and tp.topic_id = v_att.topic_id;
    v_retake_at := p_submitted_at + make_interval(hours => private.setting_int('cooldown_h'));
  end if;

  select jsonb_build_object('id', ts.topic_id, 'title', ts.title) into v_next
  from private.topic_states(v_att.user_id, v_att.course_id) ts
  where ts.pos = (select cur.pos + 1 from private.topic_states(v_att.user_id, v_att.course_id) cur
                  where cur.topic_id = v_att.topic_id)
    and ts.status = 'open';
  select exists (
    select 1 from private.topic_states(v_att.user_id, v_att.course_id) ts
    where ts.pos = (select cur.pos + 1 from private.topic_states(v_att.user_id, v_att.course_id) cur
                    where cur.topic_id = v_att.topic_id)
      and ts.locked_reason = 'needs_access'
  ) into v_next_needs_access;
  select coalesce(jsonb_agg(jsonb_build_object(
    'code', sk.code, 'name', sk.name, 'correct', sk.correct, 'total', sk.total)
    order by sk.name, sk.code), '[]'::jsonb)
  into v_skills
  from (
    select s.code, s.name, count(*) filter (where aa.is_correct)::int as correct,
           count(*)::int as total
    from public.attempt_questions aq
    join public.question_skills qs on qs.question_id = aq.question_id
    join public.skills s on s.id = qs.skill_id
    join public.attempt_answers aa
      on aa.attempt_id = aq.attempt_id and aa.question_id = aq.question_id
    where aq.attempt_id = p_attempt_id
    group by s.id, s.code, s.name
  ) sk;

  v_report := jsonb_build_object(
    'score_raw', v_raw, 'score_total', v_total, 'score_pct', v_pct, 'pass_mark', v_pass_mark,
    'passed', v_passed, 'next_topic', v_next, 'retake_at', v_retake_at, 'skills', v_skills)
    || case when v_next_needs_access then jsonb_build_object('next_needs_access', true)
            else '{}'::jsonb end;
  update public.attempts a
  set status = 'submitted', submitted_at = p_submitted_at,
      score_raw = v_raw, score_total = v_total, score_pct = v_pct,
      meta = a.meta || jsonb_build_object('report', v_report)
  where a.id = p_attempt_id;
  return v_report;
end;
$$;
revoke execute on function private.finish_quiz(uuid, timestamptz) from public, anon, authenticated;

commit;
