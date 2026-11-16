-- MCK-03: SAT mock engine (server). Spec: docs/superpowers/specs/2026-11-12-mock-sat-design.md Part 3.
-- Plan: docs/superpowers/plans/2026-11-13-mck03-mock-engine-server.md Task 2. From templates/rpc.sql.
-- Sections: 1 indexes | 2 RLS (no M1 data before the result exists) | 3 private helpers |
--           4 mock RPCs | 5 save_answer / submit_attempt mock branches.
-- A mock = one attempts group (attempts.mock_attempt_group): module_no 1 (M1) and 2 (M2E or M2H).
-- M1 meta: route, gap_until. Nothing about the route or a score is readable before M2 ends.

-- 1. Indexes -----------------------------------------------------------------------------------
-- One M1 per student and form; one row per module per group; one result per group.
create unique index attempts_one_m1_per_form
  on public.attempts (user_id, mock_form_id) where kind = 'mock_module' and module_no = 1;
create unique index attempts_one_module_per_group
  on public.attempts (mock_attempt_group, module_no) where kind = 'mock_module';
create unique index mock_results_one_per_group on public.mock_results (group_id);

-- 2. RLS: mock rows stay hidden until the group has a result ------------------------------------
drop policy "attempt_answers: student selects own submitted" on public.attempt_answers;
create policy "attempt_answers: student selects own submitted" on public.attempt_answers
  for select to authenticated
  using (exists (select 1 from public.attempts a
                 where a.id = attempt_id and a.user_id = (select auth.uid())
                   and a.status <> 'in_progress'
                   and (a.kind <> 'mock_module'
                        or exists (select 1 from public.mock_results r
                                   where r.group_id = a.mock_attempt_group and r.user_id = a.user_id))));

-- attempts.meta carries the route and score_raw the module score: hide mock rows too.
drop policy "attempts: student selects own" on public.attempts;
create policy "attempts: student selects own" on public.attempts
  for select to authenticated
  using ((select auth.uid()) = user_id
         and (kind <> 'mock_module'
              or exists (select 1 from public.mock_results r
                         where r.group_id = attempts.mock_attempt_group and r.user_id = attempts.user_id)));

-- Same rule for the skills screen: a mock module counts only once its group has a result.
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
         or (a.kind in ('quiz', 'homework') and a.status = 'submitted')
         or (a.kind = 'mock_module' and a.status = 'submitted'
             and exists (select 1 from public.mock_results r
                         where r.group_id = a.mock_attempt_group and r.user_id = a.user_id)));
$$;
revoke execute on function private.course_graded_answers(uuid, uuid) from public, anon, authenticated;

-- 3. Private helpers (no grants: not reachable over the API) -------------------------------------

create function private.mock_lock(p_uid uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform pg_advisory_xact_lock(hashtextextended('mock:' || p_uid::text, 0));
end;
$$;

-- Active enrolment of the student in the course; returns the student's mock set number.
create function private.mock_enrolment(p_uid uuid, p_course_id uuid)
returns int
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_enr public.enrollments%rowtype;
begin
  select e.* into v_enr from public.enrollments e where e.user_id = p_uid and e.course_id = p_course_id;
  if not found then
    raise exception 'not_enrolled';
  end if;
  if v_enr.status <> 'active' or v_enr.expires_at <= now() then
    raise exception 'access_expired';
  end if;
  return v_enr.mock_set_no;
end;
$$;

create function private.mock_passed_topics(p_uid uuid, p_course_id uuid)
returns int
language sql
stable
security definer
set search_path = ''
as $$
  select count(*)::int from private.topic_states(p_uid, p_course_id) ts where ts.status = 'completed'
$$;

-- Playable forms of a set in order: k counts only published forms that have all three modules
-- published, so drafts and gaps in form_no do not shift it.
create function private.mock_forms_for(p_template_id uuid, p_set_no int)
returns table (k int, form_no int, m1_form_id uuid)
language sql
stable
security definer
set search_path = ''
as $$
  select (row_number() over (order by f.form_no))::int, f.form_no, f.id
  from public.mock_forms f
  where f.template_id = p_template_id and f.set_no = p_set_no and f.module = 'M1' and f.status = 'published'
    and exists (select 1 from public.mock_forms x
                where x.template_id = f.template_id and x.set_no = f.set_no and x.form_no = f.form_no
                  and x.module = 'M2E' and x.status = 'published')
    and exists (select 1 from public.mock_forms x
                where x.template_id = f.template_id and x.set_no = f.set_no and x.form_no = f.form_no
                  and x.module = 'M2H' and x.status = 'published')
$$;

-- Creates a module attempt (module_no 1 or 2) with its questions in slot order and exposure rows.
create function private.mock_create_module(
  p_uid uuid, p_course_id uuid, p_group uuid, p_form_id uuid, p_module_no int, p_started_at timestamptz)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_form public.mock_forms%rowtype;
  v_bp   jsonb;
  v_time int;
  v_id   uuid;
begin
  select f.* into v_form from public.mock_forms f where f.id = p_form_id;
  if not found then
    raise exception 'internal';
  end if;
  select t.blueprint into v_bp from public.mock_templates t where t.id = v_form.template_id;
  v_time := (v_bp -> 'modules' -> v_form.module ->> 'time_s')::int;
  if v_time is null or v_time <= 0 then
    raise exception 'internal';
  end if;
  insert into public.attempts (user_id, kind, course_id, mock_attempt_group, mock_form_id, module_no,
                               started_at, time_limit_s)
  values (p_uid, 'mock_module', p_course_id, p_group, p_form_id, p_module_no, p_started_at, v_time)
  returning id into v_id;
  insert into public.attempt_questions (attempt_id, question_id, position)
  select v_id, u.q, u.ord::int from unnest(v_form.question_ids) with ordinality as u(q, ord);
  insert into public.question_exposure (user_id, question_id)
  select p_uid, u.q from unnest(v_form.question_ids) as u(q)
  on conflict (user_id, question_id) do nothing;
  return v_id;
end;
$$;

-- Creates module 2 for a finished M1 (the form of the same number on the M1 route).
create function private.mock_create_m2(p_m1 public.attempts, p_started_at timestamptz)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_form uuid;
begin
  select f2.id into v_form
  from public.mock_forms f1
  join public.mock_forms f2 on f2.template_id = f1.template_id and f2.set_no = f1.set_no
                           and f2.form_no = f1.form_no and f2.module = p_m1.meta ->> 'route'
  where f1.id = p_m1.mock_form_id;
  if v_form is null then
    raise exception 'internal';
  end if;
  return private.mock_create_module(p_m1.user_id, p_m1.course_id, p_m1.mock_attempt_group, v_form, 2,
                                    p_started_at);
end;
$$;

-- Grades a module (unanswered = wrong). M1 sets the route and the gap. M2 writes the result and
-- applies mastery for both modules once.
create function private.finish_mock_module(p_attempt_id uuid, p_submitted_at timestamptz)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_att    public.attempts%rowtype;
  v_form   public.mock_forms%rowtype;
  v_bp     jsonb;
  v_raw    int;
  v_total  int;
  v_route  text;
  v_thr    jsonb;
  v_m1     public.attempts%rowtype;
  v_low    int;
  v_high   int;
  v_break  jsonb;
  r        record;
begin
  select a.* into v_att from public.attempts a
  where a.id = p_attempt_id and a.kind = 'mock_module' for update;
  if not found then
    raise exception 'invalid_input';
  end if;
  if v_att.status = 'submitted' then
    return;
  end if;
  if v_att.status <> 'in_progress' then
    raise exception 'invalid_input';
  end if;
  select f.* into v_form from public.mock_forms f where f.id = v_att.mock_form_id;
  select t.blueprint into v_bp from public.mock_templates t where t.id = v_form.template_id;

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

  if v_att.module_no = 1 then
    v_thr := v_bp -> 'routing' -> 'threshold_correct_m1';
    if v_thr is null or jsonb_typeof(v_thr) <> 'number' or (v_thr #>> '{}')::numeric <> trunc((v_thr #>> '{}')::numeric) then
      raise exception 'internal';   -- a bad blueprint must not silently route everyone to M2E
    end if;
    v_route := case when v_raw >= (v_thr #>> '{}')::int then 'M2H' else 'M2E' end;
    update public.attempts a
    set status = 'submitted', submitted_at = p_submitted_at,
        score_raw = v_raw, score_total = v_total, score_pct = round(100::numeric * v_raw / v_total, 2),
        meta = a.meta || jsonb_build_object(
          'route', v_route,
          'gap_until', p_submitted_at + make_interval(secs => private.setting_int('mock_gap_s')))
    where a.id = p_attempt_id;
    return;
  end if;

  update public.attempts a
  set status = 'submitted', submitted_at = p_submitted_at,
      score_raw = v_raw, score_total = v_total, score_pct = round(100::numeric * v_raw / v_total, 2)
  where a.id = p_attempt_id;
  select a.* into v_m1 from public.attempts a
  where a.mock_attempt_group = v_att.mock_attempt_group and a.kind = 'mock_module' and a.module_no = 1;
  v_route := v_m1.meta ->> 'route';
  select s.est_low, s.est_high into v_low, v_high from private.mock_score(v_route, v_m1.score_raw + v_raw) s;
  select coalesce(jsonb_agg(jsonb_build_object('domain', x.domain, 'correct', x.correct, 'total', x.total)
                            order by x.domain collate "C"), '[]'::jsonb)
  into v_break
  from (
    select coalesce(d.domain, 'Unclassified') as domain,
           count(*) filter (where aa.is_correct)::int as correct, count(*)::int as total
    from public.attempts a
    join public.attempt_answers aa on aa.attempt_id = a.id
    left join lateral (select min(s.domain) as domain from public.question_skills qs
                       join public.skills s on s.id = qs.skill_id
                       where qs.question_id = aa.question_id) d on true
    where a.mock_attempt_group = v_att.mock_attempt_group and a.kind = 'mock_module'
    group by 1
  ) x;
  insert into public.mock_results (user_id, template_id, group_id, route, raw_m1, raw_m2, est_low, est_high,
                                   domain_breakdown)
  values (v_att.user_id, v_form.template_id, v_att.mock_attempt_group, v_route, v_m1.score_raw, v_raw,
          v_low, v_high, v_break);

  -- Mastery once per question, only now (the attempts_mastery trigger excludes mock_module).
  for r in
    select aq.question_id, coalesce(aa.is_correct, false) as is_correct,
           case when (aa.answer ->> 'value') is null then null else aa.time_ms end as time_ms
    from public.attempts a
    join public.attempt_questions aq on aq.attempt_id = a.id
    left join public.attempt_answers aa on aa.attempt_id = aq.attempt_id and aa.question_id = aq.question_id
    where a.mock_attempt_group = v_att.mock_attempt_group and a.kind = 'mock_module'
    order by a.module_no, aq.position
  loop
    perform private.apply_mastery(v_att.user_id, r.question_id, 'mock_module', r.is_correct, r.time_ms,
                                  p_submitted_at);
  end loop;
end;
$$;

-- Brings one student's mocks up to date: finishes modules past deadline + grace at their deadline,
-- starts module 2 once the gap has ended, then finishes it too if it is already overdue.
create function private.mock_tick(p_uid uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_grace int := private.setting_int('save_grace_s');
  v_m1    public.attempts%rowtype;
  r       record;
begin
  perform private.mock_lock(p_uid);
  for r in
    select a.id, a.started_at, a.time_limit_s from public.attempts a
    where a.user_id = p_uid and a.kind = 'mock_module' and a.module_no = 1 and a.status = 'in_progress'
      and a.started_at + make_interval(secs => a.time_limit_s + v_grace) < now()
    order by a.started_at, a.id
  loop
    perform private.finish_mock_module(r.id, r.started_at + make_interval(secs => r.time_limit_s));
  end loop;
  for v_m1 in
    select m1.* from public.attempts m1
    where m1.user_id = p_uid and m1.kind = 'mock_module' and m1.module_no = 1 and m1.status = 'submitted'
      and (m1.meta ->> 'gap_until')::timestamptz <= now()
      and not exists (select 1 from public.attempts m2
                      where m2.mock_attempt_group = m1.mock_attempt_group and m2.module_no = 2
                        and m2.kind = 'mock_module')
    order by m1.started_at, m1.id
  loop
    perform private.mock_create_m2(v_m1, (v_m1.meta ->> 'gap_until')::timestamptz);
  end loop;
  for r in
    select a.id, a.started_at, a.time_limit_s from public.attempts a
    where a.user_id = p_uid and a.kind = 'mock_module' and a.module_no = 2 and a.status = 'in_progress'
      and a.started_at + make_interval(secs => a.time_limit_s + v_grace) < now()
    order by a.started_at, a.id
  loop
    perform private.finish_mock_module(r.id, r.started_at + make_interval(secs => r.time_limit_s));
  end loop;
end;
$$;

-- True while the student is in a quiz, in a mock module, or in the gap between mock modules.
create function private.has_active_exam(p_uid uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select 1 from public.attempts a
                 where a.user_id = p_uid and a.kind in ('quiz', 'mock_module') and a.status = 'in_progress')
      or exists (select 1 from public.attempts m1
                 where m1.user_id = p_uid and m1.kind = 'mock_module' and m1.module_no = 1
                   and m1.status = 'submitted'
                   and not exists (select 1 from public.mock_results r where r.group_id = m1.mock_attempt_group))
$$;

-- Stage of a group without any question data: module (which one) | gap | finished.
create function private.mock_stage(p_uid uuid, p_group uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_m1 public.attempts%rowtype;
  v_m2 public.attempts%rowtype;
  v_result uuid;
begin
  select a.* into v_m1 from public.attempts a
  where a.mock_attempt_group = p_group and a.user_id = p_uid and a.kind = 'mock_module' and a.module_no = 1;
  if not found then
    raise exception 'invalid_input';
  end if;
  select r.id into v_result from public.mock_results r where r.group_id = p_group and r.user_id = p_uid;
  if v_result is not null then
    return jsonb_build_object('stage', 'finished', 'group_id', p_group, 'result_id', v_result);
  end if;
  select a.* into v_m2 from public.attempts a
  where a.mock_attempt_group = p_group and a.user_id = p_uid and a.kind = 'mock_module' and a.module_no = 2;
  if found then
    return jsonb_build_object('stage', 'module', 'group_id', p_group, 'module_no', 2);
  end if;
  if v_m1.status = 'in_progress' then
    return jsonb_build_object('stage', 'module', 'group_id', p_group, 'module_no', 1);
  end if;
  return jsonb_build_object('stage', 'gap', 'group_id', p_group,
                            'gap_until', v_m1.meta -> 'gap_until', 'server_now', now());
end;
$$;

-- Quiz-shaped payload of a module attempt: questions without keys or difficulty (difficulty would reveal
-- the route in module 2), saved answers with marks and eliminated choices, deadline and server clock.
create function private.mock_module_payload(p_att public.attempts)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_questions jsonb;
  v_answers   jsonb;
  v_seq       int;
begin
  select jsonb_agg(jsonb_build_object('id', q.id, 'type', q.type,
    'stem_md', q.stem_md, 'choices', coalesce((select jsonb_agg(
      jsonb_build_object('label', c.label, 'body_md', c.body_md) order by c.label)
      from public.question_choices c where c.question_id = q.id), '[]'::jsonb)) order by aq.position)
  into v_questions from public.attempt_questions aq join public.questions q on q.id = aq.question_id
  where aq.attempt_id = p_att.id;
  select coalesce(jsonb_agg(jsonb_build_object('question_id', aa.question_id, 'answer', aa.answer -> 'value',
    'marked', aa.marked_for_review, 'eliminated', aa.eliminated) order by aq.position), '[]'::jsonb),
    coalesce(max(aa.client_seq), 0)
  into v_answers, v_seq from public.attempt_answers aa
  join public.attempt_questions aq on aq.attempt_id = aa.attempt_id and aq.question_id = aa.question_id
  where aa.attempt_id = p_att.id;
  return jsonb_build_object('stage', 'module', 'group_id', p_att.mock_attempt_group,
    'module_no', p_att.module_no, 'attempt_id', p_att.id, 'title', 'Module ' || p_att.module_no,
    'time_limit_s', p_att.time_limit_s,
    'deadline', p_att.started_at + make_interval(secs => p_att.time_limit_s),
    'server_now', now(), 'warn_s', private.setting_int('quiz_warn_s'),
    'questions', coalesce(v_questions, '[]'::jsonb), 'answers', v_answers, 'client_seq', v_seq);
end;
$$;

-- Session of a group for the client: the module payload, the gap, or the finished marker.
create function private.mock_session(p_uid uuid, p_group uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_stage jsonb := private.mock_stage(p_uid, p_group);
  v_att   public.attempts%rowtype;
begin
  if v_stage ->> 'stage' <> 'module' then
    return v_stage;
  end if;
  select a.* into v_att from public.attempts a
  where a.mock_attempt_group = p_group and a.user_id = p_uid and a.kind = 'mock_module'
    and a.module_no = (v_stage ->> 'module_no')::int;
  return private.mock_module_payload(v_att);
end;
$$;

revoke execute on function private.mock_lock(uuid) from public, anon, authenticated;
revoke execute on function private.mock_enrolment(uuid, uuid) from public, anon, authenticated;
revoke execute on function private.mock_passed_topics(uuid, uuid) from public, anon, authenticated;
revoke execute on function private.mock_forms_for(uuid, int) from public, anon, authenticated;
revoke execute on function private.mock_create_module(uuid, uuid, uuid, uuid, int, timestamptz) from public, anon, authenticated;
revoke execute on function private.mock_create_m2(public.attempts, timestamptz) from public, anon, authenticated;
revoke execute on function private.finish_mock_module(uuid, timestamptz) from public, anon, authenticated;
revoke execute on function private.mock_tick(uuid) from public, anon, authenticated;
revoke execute on function private.has_active_exam(uuid) from public, anon, authenticated;
revoke execute on function private.mock_stage(uuid, uuid) from public, anon, authenticated;
revoke execute on function private.mock_module_payload(public.attempts) from public, anon, authenticated;
revoke execute on function private.mock_session(uuid, uuid) from public, anon, authenticated;

-- 4. Mock RPCs -----------------------------------------------------------------------------------

-- Unlock state of every playable form for the student.
create function public.get_mock_hub(p_course_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid    uuid := auth.uid();
  v_set    int;
  v_tpl    uuid;
  v_passed int;
  v_forms  jsonb;
  v_active uuid;
begin
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;
  perform private.hit_rate_limit('get_mock_hub:' || v_uid, private.setting_int('rate_start_per_min'), 60);
  if p_course_id is null then
    raise exception 'invalid_input';
  end if;
  perform private.mock_tick(v_uid);
  v_set := private.mock_enrolment(v_uid, p_course_id);
  v_tpl := private.mock_template_for(p_course_id);
  v_passed := private.mock_passed_topics(v_uid, p_course_id);
  select coalesce(jsonb_agg(jsonb_build_object(
      'form_no', f.form_no, 'k', f.k, 'need', private.mock_unlock_need(f.k),
      'state', case when m1.id is null then case when v_passed >= private.mock_unlock_need(f.k)
                                                 then 'available' else 'locked' end
                    when r.id is not null then 'finished' else 'in_progress' end) order by f.k), '[]'::jsonb)
  into v_forms
  from private.mock_forms_for(v_tpl, v_set) f
  left join public.attempts m1 on m1.user_id = v_uid and m1.mock_form_id = f.m1_form_id
                              and m1.kind = 'mock_module' and m1.module_no = 1
  left join public.mock_results r on r.group_id = m1.mock_attempt_group and r.user_id = v_uid;
  select m1.mock_attempt_group into v_active from public.attempts m1
  where m1.user_id = v_uid and m1.kind = 'mock_module' and m1.module_no = 1 and m1.course_id = p_course_id
    and not exists (select 1 from public.mock_results r where r.group_id = m1.mock_attempt_group)
  order by m1.started_at desc limit 1;
  return jsonb_build_object('passed_topics', v_passed, 'forms', v_forms, 'active_group', v_active);
end;
$$;

-- Starts the lowest available mock, or resumes the unfinished one.
create function public.start_mock(p_course_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid     uuid := auth.uid();
  v_set     int;
  v_tpl     uuid;
  v_passed  int;
  v_group   uuid;
  v_form    record;
  v_unstarted int;
begin
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;
  perform private.hit_rate_limit('start_mock:' || v_uid, private.setting_int('rate_start_per_min'), 60);
  if p_course_id is null then
    raise exception 'invalid_input';
  end if;
  perform private.mock_tick(v_uid);

  -- A started mock always ends: resume it even if the enrolment has expired since.
  select m1.mock_attempt_group into v_group from public.attempts m1
  where m1.user_id = v_uid and m1.kind = 'mock_module' and m1.module_no = 1 and m1.course_id = p_course_id
    and not exists (select 1 from public.mock_results r where r.group_id = m1.mock_attempt_group)
  order by m1.started_at desc limit 1;
  if v_group is not null then
    return private.mock_session(v_uid, v_group);
  end if;

  v_set := private.mock_enrolment(v_uid, p_course_id);
  v_tpl := private.mock_template_for(p_course_id);
  v_passed := private.mock_passed_topics(v_uid, p_course_id);
  select f.* into v_form
  from private.mock_forms_for(v_tpl, v_set) f
  where not exists (select 1 from public.attempts m1
                    where m1.user_id = v_uid and m1.mock_form_id = f.m1_form_id
                      and m1.kind = 'mock_module' and m1.module_no = 1)
    and v_passed >= private.mock_unlock_need(f.k)
  order by f.k limit 1;
  if not found then
    select count(*)::int into v_unstarted
    from private.mock_forms_for(v_tpl, v_set) f
    where not exists (select 1 from public.attempts m1
                      where m1.user_id = v_uid and m1.mock_form_id = f.m1_form_id
                        and m1.kind = 'mock_module' and m1.module_no = 1);
    if v_unstarted > 0 then
      raise exception 'mock_locked';
    end if;
    raise exception 'mock_none_available';
  end if;

  v_group := gen_random_uuid();
  perform private.mock_create_module(v_uid, p_course_id, v_group, v_form.m1_form_id, 1, now());
  return private.mock_session(v_uid, v_group);
end;
$$;

-- Current stage of a mock: module payload, gap, or finished.
create function public.get_mock_session(p_group_id uuid)
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
  perform private.hit_rate_limit('get_mock_session:' || v_uid, private.setting_int('rate_save_per_min'), 60);
  if p_group_id is null then
    raise exception 'invalid_input';
  end if;
  perform private.mock_tick(v_uid);
  return private.mock_session(v_uid, p_group_id);
end;
$$;

-- Starts module 2 during the gap (early). Idempotent.
create function public.start_mock_module2(p_group_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_m1  public.attempts%rowtype;
begin
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;
  perform private.hit_rate_limit('start_mock_module2:' || v_uid, private.setting_int('rate_start_per_min'), 60);
  if p_group_id is null then
    raise exception 'invalid_input';
  end if;
  perform private.mock_tick(v_uid);
  select a.* into v_m1 from public.attempts a
  where a.mock_attempt_group = p_group_id and a.user_id = v_uid and a.kind = 'mock_module' and a.module_no = 1
  for update;
  if not found then
    raise exception 'invalid_input';
  end if;
  if v_m1.status <> 'submitted' then
    raise exception 'invalid_input';
  end if;
  if not exists (select 1 from public.attempts a
                 where a.mock_attempt_group = p_group_id and a.kind = 'mock_module' and a.module_no = 2) then
    perform private.mock_create_m2(v_m1, now());
  end if;
  return private.mock_session(v_uid, p_group_id);
end;
$$;

revoke execute on function public.get_mock_hub(uuid) from public, anon;
revoke execute on function public.start_mock(uuid) from public, anon;
revoke execute on function public.get_mock_session(uuid) from public, anon;
revoke execute on function public.start_mock_module2(uuid) from public, anon;
grant execute on function public.get_mock_hub(uuid) to authenticated;
grant execute on function public.start_mock(uuid) to authenticated;
grant execute on function public.get_mock_session(uuid) to authenticated;
grant execute on function public.start_mock_module2(uuid) to authenticated;

-- 5. save_answer / submit_attempt: new mock_module branch (quiz and homework unchanged) ----------

create or replace function public.save_answer(
  p_attempt_id uuid, p_question_id uuid, p_answer text, p_time_ms int,
  p_marked boolean, p_eliminated text[], p_client_seq int
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_uid uuid := auth.uid();
  v_att public.attempts%rowtype;
  v_written int;
begin
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;
  perform private.hit_rate_limit('save_answer:' || v_uid, private.setting_int('rate_save_per_min'), 60);
  select a.* into v_att from public.attempts a
  where a.id = p_attempt_id and a.user_id = v_uid and a.kind in ('quiz', 'homework', 'mock_module');
  if not found then
    raise exception 'invalid_input';
  end if;
  if v_att.kind = 'mock_module' then
    -- A started mock always ends: no access or topic check, only the deadline below.
    perform private.mock_tick(v_uid);
  else
    if v_att.kind = 'quiz' then
      perform private.expire_quiz(v_uid, v_att.topic_id);
    end if;
    perform private.practice_access(v_uid, v_att.topic_id);
  end if;
  select a.* into v_att from public.attempts a where a.id = p_attempt_id for update;
  if p_question_id is null or p_client_seq is null or p_marked is null or pg_catalog.length(p_answer) > 32
     or not exists (select 1 from public.attempt_questions aq
                    where aq.attempt_id = p_attempt_id and aq.question_id = p_question_id) then
    raise exception 'invalid_input';
  end if;
  if v_att.kind in ('quiz', 'mock_module')
     and v_att.started_at + pg_catalog.make_interval(secs => v_att.time_limit_s + private.setting_int('save_grace_s')) < pg_catalog.now() then
    raise exception 'deadline_passed';
  end if;
  if v_att.status <> 'in_progress' then
    raise exception 'invalid_input';
  end if;
  insert into public.attempt_answers as aa
    (attempt_id, question_id, answer, time_ms, marked_for_review, eliminated, client_seq, answered_at)
  values (p_attempt_id, p_question_id, pg_catalog.jsonb_build_object('value', p_answer),
          greatest(0, least(coalesce(p_time_ms, 0), 3600000)), p_marked, pg_catalog.to_jsonb(p_eliminated), p_client_seq, pg_catalog.now())
  on conflict (attempt_id, question_id) do update
    set answer = excluded.answer, time_ms = excluded.time_ms, marked_for_review = excluded.marked_for_review,
        eliminated = excluded.eliminated, client_seq = excluded.client_seq, answered_at = excluded.answered_at
    where excluded.client_seq > aa.client_seq;
  get diagnostics v_written = row_count;
  if v_written = 0 then
    return pg_catalog.jsonb_build_object('ok', true, 'stale', true);
  end if;
  return pg_catalog.jsonb_build_object('ok', true);
end;
$fn$;
revoke execute on function public.save_answer(uuid, uuid, text, int, boolean, text[], int) from public, anon;
grant execute on function public.save_answer(uuid, uuid, text, int, boolean, text[], int) to authenticated;

create or replace function public.submit_attempt(p_attempt_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_uid uuid := auth.uid();
  v_att public.attempts%rowtype;
  v_raw int;
  v_total int;
  v_pct numeric;
  v_report jsonb;
begin
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;
  perform private.hit_rate_limit('submit_attempt:' || v_uid, private.setting_int('rate_submit_per_min'), 60);
  select a.* into v_att from public.attempts a
  where a.id = p_attempt_id and a.user_id = v_uid and a.kind in ('quiz', 'homework', 'mock_module');
  if not found then
    raise exception 'invalid_input';
  end if;
  if v_att.kind = 'mock_module' then
    -- Returns only the next stage: no score, route or keys before module 2 ends.
    perform private.mock_tick(v_uid);
    select a.* into v_att from public.attempts a where a.id = p_attempt_id for update;
    if v_att.status = 'in_progress' then
      perform private.finish_mock_module(
        p_attempt_id, least(pg_catalog.now(), v_att.started_at + pg_catalog.make_interval(secs => v_att.time_limit_s)));
    end if;
    return private.mock_stage(v_uid, v_att.mock_attempt_group);
  end if;
  if v_att.status = 'submitted' then
    return v_att.meta -> 'report';
  end if;
  if v_att.kind = 'quiz' then
    perform private.expire_quiz(v_uid, v_att.topic_id);
  end if;
  perform private.practice_access(v_uid, v_att.topic_id);
  select a.* into v_att from public.attempts a where a.id = p_attempt_id for update;
  if v_att.kind = 'homework' then
    if v_att.status = 'submitted' then
      return v_att.meta -> 'report';
    end if;
    if v_att.status <> 'in_progress' then
      raise exception 'invalid_input';
    end if;
    insert into public.attempt_answers(attempt_id, question_id, answer, is_correct, answered_at)
    select aq.attempt_id, aq.question_id, pg_catalog.jsonb_build_object('value', null), false, pg_catalog.now()
    from public.attempt_questions aq where aq.attempt_id = p_attempt_id
    on conflict(attempt_id, question_id) do nothing;
    update public.attempt_answers aa
    set is_correct = private.grade_answer(aa.question_id, aa.answer ->> 'value')
    where aa.attempt_id = p_attempt_id;
    select pg_catalog.count(*)::int, pg_catalog.count(*) filter(where aa.is_correct)::int into v_total, v_raw
    from public.attempt_questions aq
    join public.attempt_answers aa on aa.attempt_id = aq.attempt_id and aa.question_id = aq.question_id
    where aq.attempt_id = p_attempt_id;
    if v_total = 0 then
      raise exception 'invalid_input';
    end if;
    v_pct := pg_catalog.round(100::numeric * v_raw / v_total, 2);
    v_report := pg_catalog.jsonb_build_object('attempt_id', p_attempt_id, 'kind', 'homework',
      'score_raw', v_raw, 'score_total', v_total, 'score_pct', v_pct);
    update public.attempts a set status = 'submitted', submitted_at = pg_catalog.now(),
      score_raw = v_raw, score_total = v_total, score_pct = v_pct,
      meta = a.meta || pg_catalog.jsonb_build_object('report', v_report)
    where a.id = p_attempt_id;
    insert into public.topic_progress(user_id, topic_id, homework_attempt_id, homework_score, homework_submitted_at)
    values(v_uid, v_att.topic_id, p_attempt_id, v_pct, pg_catalog.now())
    on conflict(user_id, topic_id) do update set homework_attempt_id = excluded.homework_attempt_id,
      homework_score = excluded.homework_score, homework_submitted_at = excluded.homework_submitted_at;
    return v_report;
  end if;
  return private.finish_quiz(p_attempt_id, least(pg_catalog.now(), v_att.started_at + pg_catalog.make_interval(secs => v_att.time_limit_s)));
end;
$fn$;
revoke execute on function public.submit_attempt(uuid) from public, anon;
grant execute on function public.submit_attempt(uuid) to authenticated;
