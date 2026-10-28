-- ANL-01: get_my_skills(course) — the Skills screen payload. From templates/rpc.sql.
-- Aggregates only: no question ids, stems, answers, explanations or keys (CLAUDE.md rule 1);
-- private.question_keys is never read here. Every threshold comes from settings (rule 5).
-- Errors: docs/07 §9 codes (not_authenticated, invalid_input, not_enrolled, access_expired).

-- Published questions of a course (through published topics), with their pool.
create or replace function private.course_questions(p_course_id uuid)
returns table (question_id uuid, topic_id uuid, pool public.question_pool)
language sql
stable
security definer
set search_path = ''
as $$
  select q.id, q.topic_id, q.pool
  from public.questions q
  join public.topics t on t.id = q.topic_id
  where t.course_id = p_course_id and t.is_published and q.status = 'published';
$$;
revoke execute on function private.course_questions(uuid) from public, anon, authenticated;

-- The student's graded answers on a course's questions: practice/review rows as they stand and
-- every row of a submitted quiz/homework/mock attempt (in-progress saves have no grade yet).
create or replace function private.course_graded_answers(p_uid uuid, p_course_id uuid)
returns table (question_id uuid, is_correct boolean)
language sql
stable
security definer
set search_path = ''
as $$
  select aa.question_id, aa.is_correct
  from public.attempt_answers aa
  join public.attempts a on a.id = aa.attempt_id
  join private.course_questions(p_course_id) cq on cq.question_id = aa.question_id
  where a.user_id = p_uid
    and aa.is_correct is not null
    and (a.kind in ('practice', 'review')
         or (a.kind in ('quiz', 'homework', 'mock_module') and a.status = 'submitted'));
$$;
revoke execute on function private.course_graded_answers(uuid, uuid) from public, anon, authenticated;

-- Band of a mastery value. thin = not enough answers yet; strong threshold is the quiz pass mark.
create or replace function private.mastery_band(
  p_mastery numeric, p_attempts int, p_weak_below numeric, p_min_attempts int, p_pass_mark numeric
)
returns text
language sql
immutable
set search_path = ''
as $$
  select case
    when p_mastery is null or coalesce(p_attempts, 0) < p_min_attempts then 'thin'
    when p_mastery < p_weak_below then 'weak'
    when p_mastery >= p_pass_mark then 'strong'
    else 'building' end;
$$;
revoke execute on function private.mastery_band(numeric, int, numeric, int, numeric) from public, anon, authenticated;

-- Skills tagged on the course's published questions, with the student's mastery and band.
create or replace function private.course_skill_rows(p_uid uuid, p_course_id uuid)
returns table (skill_id uuid, code text, name text, domain text, mastery numeric, attempts int, band text)
language sql
stable
security definer
set search_path = ''
as $$
  select s.id, s.code, s.name, s.domain, m.mastery, coalesce(m.attempts, 0),
         private.mastery_band(m.mastery, coalesce(m.attempts, 0),
           private.setting_int('mastery_weak_below'), private.setting_int('mastery_min_attempts'),
           private.setting_int('pass_mark'))
  from public.skills s
  left join public.skill_mastery m on m.skill_id = s.id and m.user_id = p_uid
  where s.id in (select qs.skill_id from public.question_skills qs
                 join private.course_questions(p_course_id) cq on cq.question_id = qs.question_id);
$$;
revoke execute on function private.course_skill_rows(uuid, uuid) from public, anon, authenticated;

create or replace function public.get_my_skills(p_course_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid        uuid := auth.uid();
  v_enr        public.enrollments%rowtype;
  v_pass       int := private.setting_int('pass_mark');
  v_weak_below int := private.setting_int('mastery_weak_below');
  v_min        int := private.setting_int('mastery_min_attempts');
  v_trend_min  int := private.setting_int('mastery_trend_min_answers');
  v_today      date := (now() at time zone 'UTC')::date;
  v_total      int;
  v_solved     int;
  v_graded     int;
  v_skills     jsonb;
  v_weak       jsonb;
  v_trend      jsonb;
  v_topics     jsonb;
begin
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;
  if p_course_id is null then
    raise exception 'invalid_input';
  end if;
  if v_pass is null or v_weak_below is null or v_min is null or v_trend_min is null then
    raise exception 'internal';
  end if;

  -- Same not_enrolled / access_expired split as private.practice_access.
  select e.* into v_enr from public.enrollments e
  where e.user_id = v_uid and e.course_id = p_course_id;
  if not found then
    raise exception 'not_enrolled';
  end if;
  if not public.has_access(p_course_id) then
    raise exception 'access_expired';
  end if;

  select count(*)::int into v_total from private.course_questions(p_course_id);
  select (count(distinct g.question_id) filter (where g.is_correct))::int, count(*)::int
    into v_solved, v_graded
  from private.course_graded_answers(v_uid, p_course_id) g;

  select coalesce(jsonb_agg(jsonb_build_object(
           'code', r.code, 'name', r.name, 'domain', r.domain,
           'mastery', r.mastery, 'attempts', r.attempts, 'band', r.band)
         order by r.domain, r.name), '[]'::jsonb)
    into v_skills
  from private.course_skill_rows(v_uid, p_course_id) r;

  -- Up to three lowest weak skills; the target topic is the course topic with most practice
  -- questions for the skill (any pool as a fallback, then course order).
  select coalesce(jsonb_agg(jsonb_build_object(
           'code', w.code, 'name', w.name, 'mastery', w.mastery,
           'topic_id', w.topic_id, 'topic_title', w.topic_title)
         order by w.mastery, w.name), '[]'::jsonb)
    into v_weak
  from (
    select sk.code, sk.name, sk.mastery, wt.topic_id, wt.topic_title
    from (select r.* from private.course_skill_rows(v_uid, p_course_id) r
          where r.band = 'weak' order by r.mastery, r.name limit 3) sk
    join lateral (
      select t.id as topic_id, t.title as topic_title
      from private.course_questions(p_course_id) cq
      join public.question_skills qs on qs.question_id = cq.question_id and qs.skill_id = sk.skill_id
      join public.topics t on t.id = cq.topic_id
      join public.units u on u.id = t.unit_id
      group by t.id, t.title, u.sort, t.sort
      order by count(*) filter (where cq.pool = 'practice') desc, count(*) desc, u.sort, t.sort, t.id
      limit 1
    ) wt on true
  ) w;

  -- Weekly mean of the student's daily rows for this course's skills, last 8 weeks.
  -- Empty when there are too few graded answers or fewer than two weeks of points.
  with wk as (
    select date_trunc('week', d.day::timestamp)::date as week_start, round(avg(d.mastery), 1) as mastery
    from public.skill_mastery_daily d
    where d.user_id = v_uid
      and d.skill_id in (select r.skill_id from private.course_skill_rows(v_uid, p_course_id) r)
      and d.day >= date_trunc('week', v_today::timestamp)::date - 49
    group by 1
  )
  select case when v_graded < v_trend_min or count(*) < 2 then '[]'::jsonb
              else jsonb_agg(jsonb_build_object('week_start', wk.week_start, 'mastery', wk.mastery)
                             order by wk.week_start) end
    into v_trend
  from wk;

  -- Topics: solved / total and the band of the mean mastery of the skills tagged on the topic.
  with cq as (select * from private.course_questions(p_course_id)),
  solved as (select distinct g.question_id from private.course_graded_answers(v_uid, p_course_id) g where g.is_correct),
  counts as (
    select cq.topic_id, count(*)::int as total,
           (count(*) filter (where cq.question_id in (select s.question_id from solved s)))::int as solved
    from cq group by cq.topic_id
  ),
  topic_skills as (
    select cq.topic_id, qs.skill_id
    from cq join public.question_skills qs on qs.question_id = cq.question_id
    group by cq.topic_id, qs.skill_id
  ),
  topic_mastery as (
    select ts.topic_id, avg(m.mastery) as mean, sum(m.attempts)::int as att
    from topic_skills ts
    join public.skill_mastery m on m.skill_id = ts.skill_id and m.user_id = v_uid
    group by ts.topic_id
  )
  select coalesce(jsonb_agg(jsonb_build_object(
           'topic_id', t.id, 'title', t.title, 'unit_title', u.title,
           'solved', c.solved, 'total', c.total,
           'level', private.mastery_band(tm.mean, coalesce(tm.att, 0), v_weak_below, v_min, v_pass))
         order by u.sort, t.sort, t.id), '[]'::jsonb)
    into v_topics
  from public.topics t
  join public.units u on u.id = t.unit_id
  join counts c on c.topic_id = t.id
  left join topic_mastery tm on tm.topic_id = t.id;

  return jsonb_build_object(
    'summary', jsonb_build_object('solved', coalesce(v_solved, 0), 'total', v_total,
                                  'graded_answers', coalesce(v_graded, 0)),
    'skills', v_skills,
    'weak', v_weak,
    'trend', v_trend,
    'topics', v_topics);
end;
$$;

revoke execute on function public.get_my_skills(uuid) from public, anon;
grant execute on function public.get_my_skills(uuid) to authenticated;
