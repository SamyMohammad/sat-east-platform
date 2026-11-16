-- MCK-03 hardening: the mock engine must never wedge, modules must look alike, a started mock can always be
-- found, and the mock settings are teacher-editable. Ports the review hardening of the abandoned
-- feat/MCK-01-mock-engine branch onto the merged engine (20261113100000..200).
-- Sections: 1 settings + teacher spec | 2 two-number unlock rule | 3 equal modules (blueprint validator) |
--           4 run snapshot + start checks | 5 finish with a null range | 6 mock_warn_s | 7 hub resume.

-- 1. Settings + teacher spec -------------------------------------------------------------------
-- The list setting is replaced by two numbers (MCK-09). mock_gap_s and sat_scale_margin already exist.
insert into public.settings (key, value) values
  ('mock_unlock_first_topics', '3'::jsonb),   -- passed topics needed for the first mock
  ('mock_unlock_step_topics', '3'::jsonb),    -- more needed for each later mock
  ('mock_warn_s', '300'::jsonb)               -- time warning in a mock module, seconds left
on conflict (key) do nothing;
delete from public.settings where key = 'mock_unlock_topics';

-- Latest definition (20261020100000_lane3b_settings.sql) plus group Mock. The scale tables stay migration-only.
create or replace function private.teacher_setting_spec()
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
    ('ai_daily_cap','AI','AI questions per day','per day',0,200,14),
    ('mock_unlock_first_topics','Mock','Topics to unlock mock 1','topics',0,50,15),
    ('mock_unlock_step_topics','Mock','Extra topics per next mock','topics',0,50,16),
    ('mock_gap_s','Mock','Break between modules','seconds',0,900,17),
    ('mock_warn_s','Mock','Mock time warning at','seconds left',0,1800,18),
    ('sat_scale_margin','Mock','Score range margin','points',0,100,19);
$$;
revoke all on function private.teacher_setting_spec() from public, anon, authenticated, service_role;

-- 2. Unlock rule: form k needs first + (k - 1) * step passed topics (k below 1 counts as 1) ------------
create or replace function private.mock_unlock_need(p_k int)
returns int
language plpgsql
stable
set search_path = ''
as $$
declare
  v_first jsonb := private.setting_json('mock_unlock_first_topics');
  v_step  jsonb := private.setting_json('mock_unlock_step_topics');
begin
  if v_first is null or jsonb_typeof(v_first) <> 'number' or (v_first #>> '{}')::numeric < 0
     or (v_first #>> '{}')::numeric <> trunc((v_first #>> '{}')::numeric)
     or v_step is null or jsonb_typeof(v_step) <> 'number' or (v_step #>> '{}')::numeric < 0
     or (v_step #>> '{}')::numeric <> trunc((v_step #>> '{}')::numeric) then
    raise exception 'mock_settings_invalid' using errcode = 'P0001';
  end if;
  return (v_first #>> '{}')::int + (greatest(p_k, 1) - 1) * (v_step #>> '{}')::int;
end;
$$;

-- 3. Equal modules: M2E and M2H must have the same count and time_s, or the payload length or the
--    time limit would reveal the route. Replaces the validator of 20261112100000_mck03_mock_assembly.sql
--    (rest unchanged). -----------------------------------------------------------------------------
create or replace function private.mock_blueprint_ok(p_blueprint jsonb)
returns boolean
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_mod   text;
  v_m     jsonb;
  v_count numeric;
  v_sum   numeric;
  v_ratio numeric;
  v_thr   numeric;
  v_dom   record;
  v_n     int := 0;
begin
  if p_blueprint is null or jsonb_typeof(p_blueprint) <> 'object' then
    return false;
  end if;

  foreach v_mod in array array['M1', 'M2E', 'M2H'] loop
    v_m := p_blueprint -> 'modules' -> v_mod;
    if v_m is null or jsonb_typeof(v_m) <> 'object'
       or jsonb_typeof(v_m -> 'count') <> 'number'
       or jsonb_typeof(v_m -> 'time_s') <> 'number'
       or jsonb_typeof(v_m -> 'difficulty') <> 'object' then
      return false;
    end if;
    v_count := (v_m ->> 'count')::numeric;
    if v_count <= 0 or v_count <> trunc(v_count) or (v_m ->> 'time_s')::numeric <= 0 then
      return false;
    end if;
    if jsonb_typeof(v_m -> 'difficulty' -> 'E') <> 'number'
       or jsonb_typeof(v_m -> 'difficulty' -> 'M') <> 'number'
       or jsonb_typeof(v_m -> 'difficulty' -> 'H') <> 'number' then
      return false;
    end if;
    if (v_m -> 'difficulty' ->> 'E')::numeric < 0 or (v_m -> 'difficulty' ->> 'M')::numeric < 0
       or (v_m -> 'difficulty' ->> 'H')::numeric < 0 then
      return false;
    end if;
    v_sum := (v_m -> 'difficulty' ->> 'E')::numeric + (v_m -> 'difficulty' ->> 'M')::numeric
           + (v_m -> 'difficulty' ->> 'H')::numeric;
    if v_sum <> v_count then
      return false;
    end if;
  end loop;

  -- M2E and M2H must look identical to the student (same length and time), or the module 2 payload
  -- or its time limit would reveal the route.
  if (p_blueprint -> 'modules' -> 'M2E' ->> 'count')::numeric <> (p_blueprint -> 'modules' -> 'M2H' ->> 'count')::numeric
     or (p_blueprint -> 'modules' -> 'M2E' ->> 'time_s')::numeric <> (p_blueprint -> 'modules' -> 'M2H' ->> 'time_s')::numeric then
    return false;
  end if;

  if jsonb_typeof(p_blueprint -> 'domains') <> 'object' then
    return false;
  end if;
  v_sum := 0;
  for v_dom in select key as k, value as v from jsonb_each(p_blueprint -> 'domains') loop
    if jsonb_typeof(v_dom.v) <> 'number' or (v_dom.v #>> '{}')::numeric <= 0 then
      return false;
    end if;
    v_sum := v_sum + (v_dom.v #>> '{}')::numeric;
    v_n := v_n + 1;
  end loop;
  if v_n = 0 or abs(v_sum - 1) > 0.001 then
    return false;
  end if;

  if jsonb_typeof(p_blueprint -> 'spr_ratio') <> 'number' then
    return false;
  end if;
  v_ratio := (p_blueprint ->> 'spr_ratio')::numeric;
  if v_ratio < 0 or v_ratio > 1 then
    return false;
  end if;

  if jsonb_typeof(p_blueprint -> 'routing' -> 'threshold_correct_m1') <> 'number' then
    return false;
  end if;
  v_thr := (p_blueprint -> 'routing' ->> 'threshold_correct_m1')::numeric;
  if v_thr < 0 or v_thr > (p_blueprint -> 'modules' -> 'M1' ->> 'count')::numeric then
    return false;
  end if;

  return true;
exception when others then
  return false;
end;
$$;


-- 4. Run snapshot + start checks ----------------------------------------------------------------------
-- A mock has no runs table: its module 1 attempt carries the snapshot in meta.blueprint. Students cannot
-- read mock attempts until the group has a result (RLS of 20261113100100), so the snapshot stays hidden.
-- Everything a finish needs is validated here, at start, so a started mock cannot wedge later:
-- routing threshold, module times (M2E = M2H), form lengths (M2E = M2H), both scale tables, the margin,
-- and the longest test (M1 + module 2) fitting the scale tables (max raw = length - 1).
create function private.mock_snapshot_check(p_m1_form_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_m1   public.mock_forms%rowtype;
  v_bp   jsonb;
  v_thr  jsonb;
  v_t    jsonb;
  v_mod  text;
  v_n_e  int;
  v_n_h  int;
  v_sc_e jsonb := private.setting_json('sat_scale_easy');
  v_sc_h jsonb := private.setting_json('sat_scale_hard');
  v_mg   jsonb := private.setting_json('sat_scale_margin');
begin
  select f.* into v_m1 from public.mock_forms f where f.id = p_m1_form_id and f.module = 'M1';
  if not found then
    raise exception 'internal';
  end if;
  select t.blueprint into v_bp from public.mock_templates t where t.id = v_m1.template_id;
  v_thr := v_bp -> 'routing' -> 'threshold_correct_m1';
  if v_thr is null or jsonb_typeof(v_thr) <> 'number' or (v_thr #>> '{}')::numeric <> trunc((v_thr #>> '{}')::numeric) then
    raise exception 'internal';   -- a bad blueprint must not silently route everyone to M2E
  end if;
  foreach v_mod in array array['M1', 'M2E', 'M2H'] loop
    v_t := v_bp -> 'modules' -> v_mod -> 'time_s';
    if v_t is null or jsonb_typeof(v_t) <> 'number' or (v_t #>> '{}')::numeric <= 0
       or (v_t #>> '{}')::numeric <> trunc((v_t #>> '{}')::numeric) then
      raise exception 'internal';
    end if;
  end loop;
  if (v_bp -> 'modules' -> 'M2E' ->> 'time_s')::numeric <> (v_bp -> 'modules' -> 'M2H' ->> 'time_s')::numeric then
    raise exception 'internal';
  end if;
  select cardinality(f.question_ids) into v_n_e from public.mock_forms f
  where f.template_id = v_m1.template_id and f.set_no = v_m1.set_no and f.form_no = v_m1.form_no and f.module = 'M2E';
  select cardinality(f.question_ids) into v_n_h from public.mock_forms f
  where f.template_id = v_m1.template_id and f.set_no = v_m1.set_no and f.form_no = v_m1.form_no and f.module = 'M2H';
  if v_n_e is null or v_n_h is null or v_n_e <> v_n_h then
    raise exception 'internal';
  end if;
  if not private.mock_scale_ok(v_sc_e) or not private.mock_scale_ok(v_sc_h)
     or v_mg is null or jsonb_typeof(v_mg) <> 'number' or (v_mg #>> '{}')::numeric < 0
     or cardinality(v_m1.question_ids) + v_n_e > jsonb_array_length(v_sc_e) - 1
     or cardinality(v_m1.question_ids) + v_n_h > jsonb_array_length(v_sc_h) - 1 then
    raise exception 'internal';
  end if;
  return v_bp;
end;
$$;
revoke execute on function private.mock_snapshot_check(uuid) from public, anon, authenticated;

-- Same signature and behaviour as 20261113100100, except: module 1 validates and snapshots the blueprint
-- (stored in the attempt's meta); module 2 reads the snapshot of the group's module 1, never the live template.
create or replace function private.mock_create_module(
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
  v_meta jsonb := '{}'::jsonb;
  v_id   uuid;
begin
  select f.* into v_form from public.mock_forms f where f.id = p_form_id;
  if not found then
    raise exception 'internal';
  end if;
  if p_module_no = 1 then
    v_bp := private.mock_snapshot_check(p_form_id);
    v_meta := jsonb_build_object('blueprint', v_bp);
  else
    select a.meta -> 'blueprint' into v_bp from public.attempts a
    where a.mock_attempt_group = p_group and a.kind = 'mock_module' and a.module_no = 1;
    if v_bp is null then   -- a mock started before the hardening migration
      select t.blueprint into v_bp from public.mock_templates t where t.id = v_form.template_id;
    end if;
  end if;
  v_time := (v_bp -> 'modules' -> v_form.module ->> 'time_s')::int;
  if v_time is null or v_time <= 0 then
    raise exception 'internal';
  end if;
  insert into public.attempts (user_id, kind, course_id, mock_attempt_group, mock_form_id, module_no,
                               started_at, time_limit_s, meta)
  values (p_uid, 'mock_module', p_course_id, p_group, p_form_id, p_module_no, p_started_at, v_time, v_meta)
  returning id into v_id;
  insert into public.attempt_questions (attempt_id, question_id, position)
  select v_id, u.q, u.ord::int from unnest(v_form.question_ids) with ordinality as u(q, ord);
  insert into public.question_exposure (user_id, question_id)
  select p_uid, u.q from unnest(v_form.question_ids) as u(q)
  on conflict (user_id, question_id) do nothing;
  return v_id;
end;
$$;

-- 5. finish_mock_module: reads the snapshot; module 2 finishes even when the score cannot be computed ---
create or replace function private.finish_mock_module(p_attempt_id uuid, p_submitted_at timestamptz)
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
  -- The run's snapshot (taken at start, stored in the module 1 attempt's meta, hidden from students by RLS
  -- until the mock ends); only a mock started before the hardening migration falls back to the live template.
  v_bp := coalesce(v_att.meta -> 'blueprint',
                   (select t.blueprint from public.mock_templates t where t.id = v_form.template_id));

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
  -- The mock must always finish: a scale or margin edited after start only costs the score range.
  begin
    select s.est_low, s.est_high into v_low, v_high from private.mock_score(v_route, v_m1.score_raw + v_raw) s;
  exception when others then
    v_low := null;
    v_high := null;
    raise warning 'mock_score failed at finish, result stored without a range: %', sqlerrm;
  end;
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

-- 6. mock_warn_s feeds warn_s of mock module payloads (was quiz_warn_s) --------------------------------
create or replace function private.mock_module_payload(p_att public.attempts)
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
    'server_now', now(), 'warn_s', private.setting_int('mock_warn_s'),
    'questions', coalesce(v_questions, '[]'::jsonb), 'answers', v_answers, 'client_seq', v_seq);
end;
$$;

-- 7. Hub: a student with an unfinished mock always gets it, even when the enrolment expired or is no longer
--    active (a started mock always ends); not_enrolled / access_expired apply only when there is none. ------
create or replace function public.get_mock_hub(p_course_id uuid)
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
  select m1.mock_attempt_group into v_active from public.attempts m1
  where m1.user_id = v_uid and m1.kind = 'mock_module' and m1.module_no = 1 and m1.course_id = p_course_id
    and not exists (select 1 from public.mock_results r where r.group_id = m1.mock_attempt_group)
  order by m1.started_at desc limit 1;
  if v_active is null then
    v_set := private.mock_enrolment(v_uid, p_course_id);
  else
    select e.mock_set_no into v_set from public.enrollments e where e.user_id = v_uid and e.course_id = p_course_id;
  end if;
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
  return jsonb_build_object('passed_topics', v_passed, 'forms', v_forms, 'active_group', v_active);
end;
$$;
revoke execute on function public.get_mock_hub(uuid) from public, anon;
grant execute on function public.get_mock_hub(uuid) to authenticated;
