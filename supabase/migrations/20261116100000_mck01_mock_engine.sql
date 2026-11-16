-- MCK-01: SAT mock engine, server. Spec: docs/superpowers/specs/2026-11-12-mock-sat-design.md Part 3.
-- Sections: 1 settings | 2 scale tables | 3 teacher spec | 4 scale + estimate helpers | 5 mock_runs |
-- 6 unlock | 7 access + hub rows | 8 hub | 9 payload helpers + stage | 10 start_mock + get_mock_stage |
-- 11 save_answer | 12 has_active_exam | 13-22 Task 3: grading, finish 1/2, module 2, tick, hub tick + active_run,
-- start_mock_module2, submit_attempt, attempt_answers policy, mock cron (4b: blueprint_ok replacement).

-- 1. Settings (rule 5: no magic numbers) -----------------------------------------------------------
insert into public.settings (key, value) values
  ('mock_unlock_first_topics', '3'::jsonb),
  ('mock_unlock_step_topics', '3'::jsonb),
  ('mock_gap_s', '120'::jsonb),
  ('mock_warn_s', '300'::jsonb),
  ('mock_score_margin', '30'::jsonb)
on conflict (key) do nothing;

-- 2. Scale tables: raw 0..44 -> scaled score. Starting values, not calibrated (a straight line):
--    hard = round10(200 + 600 * raw / 44), easy = round10(200 + 420 * raw / 44). Changed by migration only.
insert into public.settings (key, value) values
  ('sat_scale_hard', '[200,210,230,240,250,270,280,300,310,320,340,350,360,380,390,400,420,430,450,460,470,490,500,510,530,540,550,570,580,600,610,620,640,650,660,680,690,700,720,730,750,760,770,790,800]'::jsonb),
  ('sat_scale_easy', '[200,210,220,230,240,250,260,270,280,290,300,310,310,320,330,340,350,360,370,380,390,400,410,420,430,440,450,460,470,480,490,500,510,520,520,530,540,550,560,570,580,590,600,610,620]'::jsonb)
on conflict (key) do nothing;

-- 3. Teacher spec: the full existing list (20261020100000_lane3b_settings.sql) plus group Mock ------
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
    ('mock_score_margin','Mock','Score range margin','points',0,100,19);
$$;
revoke all on function private.teacher_setting_spec() from public, anon, authenticated, service_role;

-- 4. Scale + estimate helpers --------------------------------------------------------------------
-- True for 45 integers, each 200..800, multiple of 10, non-decreasing. Never raises.
create function private.mock_scale_ok(p_scale jsonb)
returns boolean
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_el   record;
  v_prev numeric := 200;
  v_val  numeric;
begin
  if p_scale is null or jsonb_typeof(p_scale) <> 'array' or jsonb_array_length(p_scale) <> 45 then
    return false;
  end if;
  for v_el in select value as v from jsonb_array_elements(p_scale) loop
    if jsonb_typeof(v_el.v) <> 'number' then
      return false;
    end if;
    v_val := (v_el.v #>> '{}')::numeric;
    if v_val < 200 or v_val > 800 or v_val % 10 <> 0 or v_val < v_prev then
      return false;
    end if;
    v_prev := v_val;
  end loop;
  return true;
exception when others then
  return false;
end;
$$;

-- Score range for a route ('M2H' hard table, 'M2E' easy table): mid +/- margin, rounded to 10, 200..800.
create function private.mock_estimate(p_route text, p_raw_total int)
returns table (est_low int, est_high int)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_scale  jsonb;
  v_margin int;
  v_mid    numeric;
begin
  if p_route is null or p_route not in ('M2H', 'M2E') or p_raw_total is null
     or p_raw_total < 0 or p_raw_total > 44 then
    raise exception 'internal';
  end if;
  select s.value into v_scale from public.settings s
  where s.key = case p_route when 'M2H' then 'sat_scale_hard' else 'sat_scale_easy' end;
  if not private.mock_scale_ok(v_scale) then
    raise exception 'internal';
  end if;
  select (s.value)::int into v_margin from public.settings s where s.key = 'mock_score_margin';
  if v_margin is null or v_margin < 0 then
    raise exception 'internal';
  end if;
  v_mid := (v_scale ->> p_raw_total)::numeric;
  est_low := least(800, greatest(200, (round((v_mid - v_margin) / 10) * 10)::int));
  est_high := least(800, greatest(200, (round((v_mid + v_margin) / 10) * 10)::int));
  return next;
end;
$$;
revoke execute on function private.mock_scale_ok(jsonb) from public, anon, authenticated;
revoke execute on function private.mock_estimate(text, int) from public, anon, authenticated;

-- 4b. mock_blueprint_ok (MCK-03, 20261112100000) replaced: M2E and M2H must have the same count and time_s,
--     otherwise the module 2 payload or time_limit_s would reveal the route. Rest copied unchanged.
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

-- 5. mock_runs: one row per (student, form); hidden state (plan Decision 3) -------------------------
create table private.mock_runs (
  group_id         uuid primary key default gen_random_uuid(),
  user_id          uuid not null references public.profiles (id) on delete cascade,
  course_id        uuid not null references public.courses (id) on delete restrict,
  template_id      uuid not null references public.mock_templates (id) on delete restrict,
  set_no           int not null,
  form_no          int not null,
  m1_attempt_id    uuid references public.attempts (id) on delete set null,
  m2_attempt_id    uuid references public.attempts (id) on delete set null,
  route            text check (route in ('M2H', 'M2E')),
  raw_m1           int,
  m1_submitted_at  timestamptz,
  finished_at      timestamptz,
  blueprint        jsonb not null,  -- snapshot of the template blueprint at start: the run never reads the live one
  created_at       timestamptz not null default now(),
  unique (user_id, template_id, set_no, form_no)
);
-- One result per run (the finish functions are idempotent, this makes it a rule).
create unique index mock_results_group_id_key on public.mock_results (group_id);
alter table private.mock_runs enable row level security;  -- no policy: only definer functions touch it
revoke all on table private.mock_runs from anon, authenticated;
create index mock_runs_unfinished_idx on private.mock_runs (user_id) where finished_at is null;
-- FK indexes (docs/16).
create index mock_runs_template_idx on private.mock_runs (template_id);
create index mock_runs_course_idx on private.mock_runs (course_id);
create index mock_runs_m1_attempt_idx on private.mock_runs (m1_attempt_id);
create index mock_runs_m2_attempt_idx on private.mock_runs (m2_attempt_id);

-- 6. Unlock: published forms (all three module rows published) of the student's set -----------------
create function private.mock_form_unlock(p_user_id uuid, p_course_id uuid)
returns table (template_id uuid, set_no int, form_no int, k int, topics_needed int)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_first int;
  v_step  int;
begin
  select (s.value)::int into v_first from public.settings s where s.key = 'mock_unlock_first_topics';
  select (s.value)::int into v_step from public.settings s where s.key = 'mock_unlock_step_topics';
  if v_first is null or v_step is null then
    raise exception 'internal';
  end if;
  return query
    select f.template_id, f.set_no, f.form_no,
           (row_number() over (order by f.form_no))::int,
           v_first + ((row_number() over (order by f.form_no))::int - 1) * v_step
    from (
      select mf.template_id, mf.set_no, mf.form_no
      from public.mock_forms mf
      join public.mock_templates t on t.id = mf.template_id and t.course_id = p_course_id and t.adaptive
      join public.enrollments e on e.user_id = p_user_id and e.course_id = p_course_id
                               and e.mock_set_no = mf.set_no
      where mf.module in ('M1', 'M2E', 'M2H') and mf.status = 'published'
      group by mf.template_id, mf.set_no, mf.form_no
      having count(distinct mf.module) = 3
    ) f
    order by f.form_no;
end;
$$;
revoke execute on function private.mock_form_unlock(uuid, uuid) from public, anon, authenticated;

-- 7. Access + hub rows (shared by get_mock_hub and start_mock) -------------------------------------
-- Course-level access. A student with an unfinished run for the course always passes (plan Decision 6:
-- a started run is never locked out); otherwise not_enrolled / access_expired. Returns the set number.
create function private.mock_access(p_uid uuid, p_course_id uuid)
returns int
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_enr       public.enrollments%rowtype;
  v_has_enr   boolean;
  v_open_set  int;
begin
  select e.* into v_enr from public.enrollments e where e.user_id = p_uid and e.course_id = p_course_id;
  v_has_enr := found;
  select r.set_no into v_open_set from private.mock_runs r
  where r.user_id = p_uid and r.course_id = p_course_id and r.finished_at is null
  limit 1;
  if v_open_set is not null then
    return case when v_has_enr then v_enr.mock_set_no else v_open_set end;
  end if;
  if not v_has_enr then
    raise exception 'not_enrolled';
  end if;
  -- Same condition as private.practice_access (status active and not past expires_at). public.has_access
  -- (20261009000000_auth04) says the same plus private.device_allowed(), which is bound to auth.uid() and
  -- cannot be asked for p_uid; neither looks at starts_at, and free preview is a per-topic rule.
  if v_enr.status <> 'active' or v_enr.expires_at <= now() then
    raise exception 'access_expired';
  end if;
  return v_enr.mock_set_no;
end;
$$;
revoke execute on function private.mock_access(uuid, uuid) from public, anon, authenticated;

-- One row per published form of the student's set with its state: locked / available / in_progress /
-- finished. Exactly one form can be available: the lowest not-started one, unlocked, with no run unfinished.
create function private.mock_hub_rows(p_uid uuid, p_course_id uuid, p_passed int)
returns table (template_id uuid, set_no int, form_no int, topics_needed int, group_id uuid,
               finished_at timestamptz, state text)
language sql
stable
security definer
set search_path = ''
as $$
  with u as (
    select * from private.mock_form_unlock(p_uid, p_course_id)
  ), j as (
    select u.template_id, u.set_no, u.form_no, u.topics_needed, r.group_id, r.finished_at
    from u
    left join private.mock_runs r on r.user_id = p_uid and r.template_id = u.template_id
                                 and r.set_no = u.set_no and r.form_no = u.form_no
  ), c as (
    select (select min(j2.form_no) from j j2 where j2.group_id is null) as next_form,
           exists (select 1 from private.mock_runs x where x.user_id = p_uid and x.finished_at is null) as busy
  )
  select j.template_id, j.set_no, j.form_no, j.topics_needed, j.group_id, j.finished_at,
         case
           when j.group_id is not null and j.finished_at is not null then 'finished'
           when j.group_id is not null then 'in_progress'
           when j.form_no = c.next_form and not c.busy and p_passed >= j.topics_needed then 'available'
           else 'locked' end
  from j cross join c
  order by j.form_no;
$$;
revoke execute on function private.mock_hub_rows(uuid, uuid, int) from public, anon, authenticated;

-- 8. Hub ------------------------------------------------------------------------------------------
create function public.get_mock_hub(p_course_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid    uuid := auth.uid();
  v_set_no int;
  v_passed int;
  v_forms  jsonb;
begin
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;
  if p_course_id is null then
    raise exception 'invalid_input';
  end if;

  v_set_no := private.mock_access(v_uid, p_course_id);

  select count(*)::int into v_passed
  from private.topic_states(v_uid, p_course_id) ts where ts.status = 'completed';

  select coalesce(jsonb_agg(jsonb_build_object(
      'form_no', r.form_no,
      'state', r.state,
      'topics_needed', r.topics_needed,
      'group_id', r.group_id,
      'est_low', case when r.state = 'finished' then res.est_low end,
      'est_high', case when r.state = 'finished' then res.est_high end
    ) order by r.form_no), '[]'::jsonb)
  into v_forms
  from private.mock_hub_rows(v_uid, p_course_id, v_passed) r
  left join public.mock_results res on res.group_id = r.group_id and res.user_id = v_uid;

  return jsonb_build_object('set_no', v_set_no, 'topics_passed', v_passed, 'forms', v_forms);
end;
$$;
revoke execute on function public.get_mock_hub(uuid) from public, anon;
grant execute on function public.get_mock_hub(uuid) to authenticated;

-- 9. Per-user lock, module payload, stage ------------------------------------------------------------
-- Serialises every mock RPC of one student (two tabs, double tap, cron tick). Fixed namespace 7301.
create function private.mock_lock_user(p_uid uuid)
returns void
language sql
security definer
set search_path = ''
as $$
  select pg_catalog.pg_advisory_xact_lock(7301, pg_catalog.hashtext(p_uid::text));
$$;
revoke execute on function private.mock_lock_user(uuid) from public, anon, authenticated;

-- A module stage object. Same question shape as start_quiz; never a key, explanation or is_correct.
create function private.mock_module_stage(p_group_id uuid, p_module_no int, p_attempt_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_att       public.attempts%rowtype;
  v_questions jsonb;
  v_answers   jsonb;
  v_seq       int;
begin
  select a.* into v_att from public.attempts a where a.id = p_attempt_id;
  if not found then
    raise exception 'internal';
  end if;

  select coalesce(jsonb_agg(jsonb_build_object('id', q.id, 'type', q.type,
    'stem_md', q.stem_md, 'choices', coalesce((select jsonb_agg(
      jsonb_build_object('label', c.label, 'body_md', c.body_md) order by c.label)
      from public.question_choices c where c.question_id = q.id), '[]'::jsonb)) order by aq.position), '[]'::jsonb)
  into v_questions
  from public.attempt_questions aq join public.questions q on q.id = aq.question_id
  where aq.attempt_id = p_attempt_id;

  select coalesce(jsonb_agg(jsonb_build_object('question_id', aa.question_id,
    'answer', aa.answer -> 'value', 'marked', aa.marked_for_review,
    'eliminated', coalesce(aa.eliminated, '[]'::jsonb)) order by aq.position), '[]'::jsonb),
    coalesce(max(aa.client_seq), 0)
  into v_answers, v_seq
  from public.attempt_answers aa
  join public.attempt_questions aq on aq.attempt_id = aa.attempt_id and aq.question_id = aa.question_id
  where aa.attempt_id = p_attempt_id;

  return jsonb_build_object('stage', 'module', 'group_id', p_group_id, 'module_no', p_module_no,
    'attempt_id', p_attempt_id, 'title', 'Module ' || p_module_no,
    'time_limit_s', v_att.time_limit_s,
    'deadline', v_att.started_at + make_interval(secs => v_att.time_limit_s),
    'server_now', now(), 'warn_s', private.setting_int('mock_warn_s'),
    'questions', v_questions, 'answers', v_answers, 'client_seq', v_seq);
end;
$$;
revoke execute on function private.mock_module_stage(uuid, int, uuid) from public, anon, authenticated;

-- The current stage of a run: finished, module 2, module 1, or the gap in between.
-- (Task 3 puts private.mock_tick in front of this so time moves a run forward.)
create function private.mock_stage(p_group_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_run private.mock_runs%rowtype;
begin
  select r.* into v_run from private.mock_runs r where r.group_id = p_group_id;
  if not found then
    raise exception 'invalid_input';
  end if;
  if v_run.finished_at is not null then
    return jsonb_build_object('stage', 'finished', 'group_id', v_run.group_id);
  end if;
  if v_run.m2_attempt_id is not null then
    return private.mock_module_stage(v_run.group_id, 2, v_run.m2_attempt_id);
  end if;
  if v_run.m1_submitted_at is null then
    return private.mock_module_stage(v_run.group_id, 1, v_run.m1_attempt_id);
  end if;
  return jsonb_build_object('stage', 'gap', 'group_id', v_run.group_id,
    'gap_ends_at', v_run.m1_submitted_at + make_interval(secs => private.setting_int('mock_gap_s')),
    'server_now', now());
end;
$$;
revoke execute on function private.mock_stage(uuid) from public, anon, authenticated;

-- 10. start_mock + get_mock_stage ----------------------------------------------------------------------
create function public.start_mock(p_course_id uuid, p_form_no int)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid     uuid := auth.uid();
  v_passed  int;
  v_row     record;
  v_bp      jsonb;
  v_scale_h jsonb;
  v_scale_e jsonb;
  v_margin  int;
  v_mod     text;
  v_form    public.mock_forms%rowtype;
  v_m1_form uuid;
  v_group   uuid;
  v_att     uuid;
begin
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;
  perform private.hit_rate_limit('start_mock:' || v_uid, private.setting_int('rate_start_per_min'), 60);
  if p_course_id is null or p_form_no is null then
    raise exception 'invalid_input';
  end if;
  perform private.mock_lock_user(v_uid);
  perform private.mock_tick(v_uid);

  perform private.mock_access(v_uid, p_course_id);
  select count(*)::int into v_passed
  from private.topic_states(v_uid, p_course_id) ts where ts.status = 'completed';

  select r.* into v_row from private.mock_hub_rows(v_uid, p_course_id, v_passed) r where r.form_no = p_form_no;
  if not found then
    raise exception 'invalid_input';
  end if;
  if v_row.state = 'finished' then
    raise exception 'mock_already_taken';
  end if;
  if v_row.state = 'in_progress' then
    return private.mock_stage(v_row.group_id);
  end if;
  if exists (select 1 from private.mock_runs x where x.user_id = v_uid and x.finished_at is null) then
    raise exception 'mock_in_progress';
  end if;
  if v_row.state <> 'available' then
    raise exception 'mock_locked';
  end if;

  -- The form must match its template's blueprint exactly; nothing is inserted otherwise.
  select t.blueprint into v_bp from public.mock_templates t where t.id = v_row.template_id;
  if not private.mock_blueprint_ok(v_bp) then
    raise exception 'internal';
  end if;
  -- Fail at start, not at finish: both scale tables and the margin must be valid, and a whole test
  -- (M1 + either module 2) must fit the scale tables (max raw = length - 1).
  select s.value into v_scale_h from public.settings s where s.key = 'sat_scale_hard';
  select s.value into v_scale_e from public.settings s where s.key = 'sat_scale_easy';
  select (s.value)::int into v_margin from public.settings s where s.key = 'mock_score_margin';
  if not private.mock_scale_ok(v_scale_h) or not private.mock_scale_ok(v_scale_e)
     or v_margin is null or v_margin < 0
     or (v_bp -> 'modules' -> 'M1' ->> 'count')::int + (v_bp -> 'modules' -> 'M2H' ->> 'count')::int > jsonb_array_length(v_scale_h) - 1
     or (v_bp -> 'modules' -> 'M1' ->> 'count')::int + (v_bp -> 'modules' -> 'M2E' ->> 'count')::int > jsonb_array_length(v_scale_e) - 1 then
    raise exception 'internal';
  end if;
  foreach v_mod in array array['M1', 'M2E', 'M2H'] loop
    select f.* into v_form from public.mock_forms f
    where f.template_id = v_row.template_id and f.set_no = v_row.set_no and f.form_no = v_row.form_no
      and f.module = v_mod and f.status = 'published';
    if not found
       or pg_catalog.cardinality(v_form.question_ids) <> (v_bp -> 'modules' -> v_mod ->> 'count')::int then
      raise exception 'internal';
    end if;
    if v_mod = 'M1' then
      v_m1_form := v_form.id;
    end if;
  end loop;

  insert into private.mock_runs (user_id, course_id, template_id, set_no, form_no, blueprint)
  values (v_uid, p_course_id, v_row.template_id, v_row.set_no, v_row.form_no, v_bp)
  returning group_id into v_group;

  insert into public.attempts (user_id, kind, course_id, mock_attempt_group, mock_form_id, module_no, started_at, time_limit_s)
  values (v_uid, 'mock_module', p_course_id, v_group, v_m1_form, 1, now(), (v_bp -> 'modules' -> 'M1' ->> 'time_s')::int)
  returning id into v_att;

  insert into public.attempt_questions (attempt_id, question_id, position)
  select v_att, u.qid, u.pos::int
  from public.mock_forms f, unnest(f.question_ids) with ordinality u(qid, pos)
  where f.id = v_m1_form;

  update private.mock_runs r set m1_attempt_id = v_att where r.group_id = v_group;

  return private.mock_stage(v_group);
end;
$$;
revoke execute on function public.start_mock(uuid, int) from public, anon;
grant execute on function public.start_mock(uuid, int) to authenticated;

-- Resume after a reload. Owner only; needs no active access (a started run can always be resumed).
create function public.get_mock_stage(p_group_id uuid)
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
  if p_group_id is null
     or not exists (select 1 from private.mock_runs r where r.group_id = p_group_id and r.user_id = v_uid) then
    raise exception 'invalid_input';
  end if;
  return private.mock_stage(p_group_id);
end;
$$;
revoke execute on function public.get_mock_stage(uuid) from public, anon;
grant execute on function public.get_mock_stage(uuid) to authenticated;

-- 11. save_answer: the quiz/homework body unchanged, plus kind 'mock_module' (no topic access check;
--     deadline = time_limit_s + save_grace_s, like a quiz) ----------------------------------------------
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
  if v_att.kind = 'quiz' then
    perform private.expire_quiz(v_uid, v_att.topic_id);
  end if;
  if v_att.kind <> 'mock_module' then
    perform private.practice_access(v_uid, v_att.topic_id);
  else
    perform private.mock_lock_user(v_uid);
    perform private.mock_tick(v_uid);
  end if;
  select a.* into v_att from public.attempts a where a.id = p_attempt_id for update;
  if p_question_id is null or p_client_seq is null or p_marked is null or pg_catalog.length(p_answer) > 32
     or not exists (select 1 from public.attempt_questions aq
                    where aq.attempt_id = p_attempt_id and aq.question_id = p_question_id) then
    raise exception 'invalid_input';
  end if;
  if v_att.kind in ('quiz', 'mock_module') and v_att.started_at + pg_catalog.make_interval(secs => v_att.time_limit_s + private.setting_int('save_grace_s')) < pg_catalog.now() then
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

-- 12. has_active_exam: a quiz in progress (inside deadline + grace) or a mock run without finished_at
--     (includes the gap). For lane B (AI-03). ----------------------------------------------------------
create function private.has_active_exam(p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.attempts a
    where a.user_id = p_user_id and a.kind = 'quiz' and a.status = 'in_progress'
      and a.started_at + make_interval(secs => a.time_limit_s + private.setting_int('save_grace_s')) >= now()
  ) or exists (
    select 1 from private.mock_runs r where r.user_id = p_user_id and r.finished_at is null
  );
$$;
revoke execute on function private.has_active_exam(uuid) from public, anon, authenticated;

-- ================================================================================================
-- Task 3: submit, routing, gap, module 2, tick, results, leak guards.
-- Sections: 13 grading helper | 14 module 1 finish | 15 module 2 create + finish | 16 tick |
-- 17 hub / start / stage with tick + active_run | 18 start_mock_module2 | 19 submit_attempt |
-- 20 save_answer tick | 21 attempt_answers policy | 22 cron
-- ================================================================================================

-- 13. Grade one module attempt: unanswered rows are added as null (wrong), every row graded.
--     Returns the raw score. is_correct lives on attempt_answers, hidden from the student by the
--     policy of section 21 until the run is finished. -----------------------------------------------
create function private.mock_grade_attempt(p_attempt_id uuid, p_at timestamptz)
returns int
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_raw int;
begin
  insert into public.attempt_answers (attempt_id, question_id, answer, is_correct, answered_at)
  select aq.attempt_id, aq.question_id, jsonb_build_object('value', null), false, p_at
  from public.attempt_questions aq where aq.attempt_id = p_attempt_id
  on conflict (attempt_id, question_id) do nothing;
  update public.attempt_answers aa
  set is_correct = private.grade_answer(aa.question_id, aa.answer ->> 'value')
  where aa.attempt_id = p_attempt_id;
  select count(*) filter (where aa.is_correct)::int into v_raw
  from public.attempt_answers aa where aa.attempt_id = p_attempt_id;
  return coalesce(v_raw, 0);
end;
$$;
revoke execute on function private.mock_grade_attempt(uuid, timestamptz) from public, anon, authenticated;

-- 14. Finish module 1: grade, route. raw_m1 and route live only in mock_runs; the attempt gets status
--     and submitted_at but no score, meta or report until the run is finished. Idempotent. ----------
create function private.mock_finish_module1(p_group_id uuid, p_at timestamptz)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_run private.mock_runs%rowtype;
  v_att public.attempts%rowtype;
  v_bp  jsonb;
  v_at  timestamptz;
  v_raw int;
begin
  select r.* into v_run from private.mock_runs r where r.group_id = p_group_id for update;
  if not found then
    raise exception 'internal';
  end if;
  if v_run.finished_at is not null or v_run.m1_submitted_at is not null then
    return;
  end if;
  select a.* into v_att from public.attempts a where a.id = v_run.m1_attempt_id for update;
  if not found or v_att.status <> 'in_progress' then
    raise exception 'internal';
  end if;
  v_bp := v_run.blueprint;
  if not private.mock_blueprint_ok(v_bp) then
    raise exception 'internal';
  end if;

  v_at := least(p_at, v_att.started_at + make_interval(secs => v_att.time_limit_s));
  v_raw := private.mock_grade_attempt(v_att.id, v_at);
  update public.attempts a set status = 'submitted', submitted_at = v_at where a.id = v_att.id;
  update private.mock_runs r
  set raw_m1 = v_raw,
      route = case when v_raw >= (v_bp -> 'routing' ->> 'threshold_correct_m1')::int then 'M2H' else 'M2E' end,
      m1_submitted_at = v_at
  where r.group_id = p_group_id;
end;
$$;
revoke execute on function private.mock_finish_module1(uuid, timestamptz) from public, anon, authenticated;

-- 15. Module 2: create (routed module row, started_at given) and finish (score, results, mastery). -----
create function private.mock_create_module2(p_group_id uuid, p_started_at timestamptz)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_run  private.mock_runs%rowtype;
  v_bp   jsonb;
  v_form public.mock_forms%rowtype;
  v_att  uuid;
begin
  select r.* into v_run from private.mock_runs r where r.group_id = p_group_id for update;
  if not found or v_run.route is null or v_run.m1_submitted_at is null then
    raise exception 'internal';
  end if;
  if v_run.m2_attempt_id is not null or v_run.finished_at is not null then
    return;
  end if;
  v_bp := v_run.blueprint;
  if not private.mock_blueprint_ok(v_bp) then
    raise exception 'internal';
  end if;
  select f.* into v_form from public.mock_forms f
  where f.template_id = v_run.template_id and f.set_no = v_run.set_no and f.form_no = v_run.form_no
    and f.module = v_run.route;
  if not found or cardinality(v_form.question_ids) <> (v_bp -> 'modules' -> v_run.route ->> 'count')::int then
    raise exception 'internal';
  end if;

  insert into public.attempts (user_id, kind, course_id, mock_attempt_group, mock_form_id, module_no, started_at, time_limit_s)
  values (v_run.user_id, 'mock_module', v_run.course_id, v_run.group_id, v_form.id, 2, p_started_at,
          (v_bp -> 'modules' -> v_run.route ->> 'time_s')::int)
  returning id into v_att;
  insert into public.attempt_questions (attempt_id, question_id, position)
  select v_att, u.qid, u.pos::int from unnest(v_form.question_ids) with ordinality u(qid, pos);
  update private.mock_runs r set m2_attempt_id = v_att where r.group_id = p_group_id;
end;
$$;
revoke execute on function private.mock_create_module2(uuid, timestamptz) from public, anon, authenticated;

create function private.mock_finish_module2(p_group_id uuid, p_at timestamptz)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_run    private.mock_runs%rowtype;
  v_a1     public.attempts%rowtype;
  v_a2     public.attempts%rowtype;
  v_bp     jsonb;
  v_at     timestamptz;
  v_raw2   int;
  v_n1     int;
  v_n2     int;
  v_est_low  int;
  v_est_high int;
  v_dom    jsonb;
  v_ans    record;
begin
  select r.* into v_run from private.mock_runs r where r.group_id = p_group_id for update;
  if not found then
    raise exception 'internal';
  end if;
  if v_run.finished_at is not null then
    return;
  end if;
  if v_run.m1_submitted_at is null or v_run.m2_attempt_id is null or v_run.raw_m1 is null then
    raise exception 'internal';
  end if;
  select a.* into v_a1 from public.attempts a where a.id = v_run.m1_attempt_id for update;
  select a.* into v_a2 from public.attempts a where a.id = v_run.m2_attempt_id for update;
  if v_a2.status <> 'in_progress' then
    raise exception 'internal';
  end if;
  v_bp := v_run.blueprint;
  if not private.mock_blueprint_ok(v_bp) then
    raise exception 'internal';
  end if;

  v_at := least(p_at, v_a2.started_at + make_interval(secs => v_a2.time_limit_s));
  v_raw2 := private.mock_grade_attempt(v_a2.id, v_at);
  select count(*)::int into v_n1 from public.attempt_questions aq where aq.attempt_id = v_a1.id;
  select count(*)::int into v_n2 from public.attempt_questions aq where aq.attempt_id = v_a2.id;
  -- The run must always finish: a scale or margin edited after start only costs the range.
  begin
    select e.est_low, e.est_high into v_est_low, v_est_high
    from private.mock_estimate(v_run.route, v_run.raw_m1 + v_raw2) e;
  exception when others then
    v_est_low := null;
    v_est_high := null;
    raise warning 'mock_estimate failed at finish, result stored without a range: %', sqlerrm;
  end;

  select coalesce(jsonb_object_agg(d.domain, jsonb_build_object('correct', d.c, 'total', d.t)), '{}'::jsonb)
  into v_dom
  from (
    select s.domain, (count(*) filter (where aa.is_correct))::int as c, count(*)::int as t
    from (values (v_a1.id, 'M1'), (v_a2.id, v_run.route)) m(att, modname)
    cross join lateral private.mock_module_slots(v_bp, m.modname) s
    join public.attempt_questions aq on aq.attempt_id = m.att and aq.position = s.slot_no
    join public.attempt_answers aa on aa.attempt_id = aq.attempt_id and aa.question_id = aq.question_id
    group by s.domain
  ) d;

  update public.attempts a set status = 'submitted', submitted_at = v_at,
    score_raw = v_raw2, score_total = v_n2, score_pct = round(100::numeric * v_raw2 / nullif(v_n2, 0), 2)
  where a.id = v_a2.id;
  update public.attempts a set
    score_raw = v_run.raw_m1, score_total = v_n1, score_pct = round(100::numeric * v_run.raw_m1 / nullif(v_n1, 0), 2)
  where a.id = v_a1.id;

  insert into public.mock_results (user_id, template_id, group_id, route, raw_m1, raw_m2, est_low, est_high, domain_breakdown)
  values (v_run.user_id, v_run.template_id, v_run.group_id, v_run.route, v_run.raw_m1, v_raw2,
          v_est_low, v_est_high, v_dom);

  -- Mastery once, for every answer of both modules (the attempts trigger ignores mock_module).
  for v_ans in
    select aq.question_id, coalesce(aa.is_correct, false) as is_correct,
           case when (aa.answer ->> 'value') is null then null else aa.time_ms end as time_ms,
           coalesce(aa.answered_at, v_at) as at
    from public.attempt_questions aq
    join public.attempt_answers aa on aa.attempt_id = aq.attempt_id and aa.question_id = aq.question_id
    where aq.attempt_id in (v_a1.id, v_a2.id)
    order by aq.attempt_id = v_a2.id, aq.position
  loop
    perform private.apply_mastery(v_run.user_id, v_ans.question_id, 'mock_module', v_ans.is_correct, v_ans.time_ms, v_ans.at);
  end loop;

  update private.mock_runs r set finished_at = v_at where r.group_id = p_group_id;
end;
$$;
revoke execute on function private.mock_finish_module2(uuid, timestamptz) from public, anon, authenticated;

-- 16. Tick: moves a student's unfinished run forward as far as the clock allows, in one call:
--     module 1 overdue -> finish it; gap over and no module 2 -> create it (started when the gap ended);
--     module 2 overdue -> finish it. Idempotent; takes the per-user lock (re-entrant for RPCs). -----------
create function private.mock_tick(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_gid   uuid;
  v_run   private.mock_runs%rowtype;
  v_a     public.attempts%rowtype;
  v_grace int := private.setting_int('save_grace_s');
  v_gap   int := private.setting_int('mock_gap_s');
begin
  if p_user_id is null then
    return;
  end if;
  perform private.mock_lock_user(p_user_id);
  for v_gid in
    select r.group_id from private.mock_runs r
    where r.user_id = p_user_id and r.finished_at is null order by r.created_at, r.group_id
  loop
    select r.* into v_run from private.mock_runs r where r.group_id = v_gid;

    if v_run.m1_submitted_at is null then
      select a.* into v_a from public.attempts a where a.id = v_run.m1_attempt_id;
      if v_a.started_at + make_interval(secs => v_a.time_limit_s + v_grace) < now() then
        perform private.mock_finish_module1(v_gid, now());
        select r.* into v_run from private.mock_runs r where r.group_id = v_gid;
      end if;
    end if;

    if v_run.m1_submitted_at is not null and v_run.m2_attempt_id is null
       and v_run.m1_submitted_at + make_interval(secs => v_gap) <= now() then
      perform private.mock_create_module2(v_gid, v_run.m1_submitted_at + make_interval(secs => v_gap));
      select r.* into v_run from private.mock_runs r where r.group_id = v_gid;
    end if;

    if v_run.m2_attempt_id is not null then
      select a.* into v_a from public.attempts a where a.id = v_run.m2_attempt_id;
      if v_a.status = 'in_progress'
         and v_a.started_at + make_interval(secs => v_a.time_limit_s + v_grace) < now() then
        perform private.mock_finish_module2(v_gid, now());
      end if;
    end if;
  end loop;
end;
$$;
revoke execute on function private.mock_tick(uuid) from public, anon, authenticated;

-- 17. Hub, start_mock and get_mock_stage now tick first. The hub also reports active_run (any unfinished
--     run of the course, whatever the set) so a student can always find it. ----------------------------------
create or replace function public.get_mock_hub(p_course_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid    uuid := auth.uid();
  v_set_no int;
  v_passed int;
  v_forms  jsonb;
  v_active jsonb;
begin
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;
  if p_course_id is null then
    raise exception 'invalid_input';
  end if;

  perform private.mock_tick(v_uid);
  v_set_no := private.mock_access(v_uid, p_course_id);

  select count(*)::int into v_passed
  from private.topic_states(v_uid, p_course_id) ts where ts.status = 'completed';

  select coalesce(jsonb_agg(jsonb_build_object(
      'form_no', r.form_no,
      'state', r.state,
      'topics_needed', r.topics_needed,
      'group_id', r.group_id,
      'est_low', case when r.state = 'finished' then res.est_low end,
      'est_high', case when r.state = 'finished' then res.est_high end
    ) order by r.form_no), '[]'::jsonb)
  into v_forms
  from private.mock_hub_rows(v_uid, p_course_id, v_passed) r
  left join public.mock_results res on res.group_id = r.group_id and res.user_id = v_uid;

  select jsonb_build_object('group_id', x.group_id, 'set_no', x.set_no, 'form_no', x.form_no) into v_active
  from private.mock_runs x
  where x.user_id = v_uid and x.course_id = p_course_id and x.finished_at is null
  order by x.created_at limit 1;

  return jsonb_build_object('set_no', v_set_no, 'topics_passed', v_passed, 'forms', v_forms,
                            'active_run', v_active);
end;
$$;
revoke execute on function public.get_mock_hub(uuid) from public, anon;
grant execute on function public.get_mock_hub(uuid) to authenticated;

create or replace function public.get_mock_stage(p_group_id uuid)
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
  if p_group_id is null
     or not exists (select 1 from private.mock_runs r where r.group_id = p_group_id and r.user_id = v_uid) then
    raise exception 'invalid_input';
  end if;
  perform private.mock_tick(v_uid);
  return private.mock_stage(p_group_id);
end;
$$;
revoke execute on function public.get_mock_stage(uuid) from public, anon;
grant execute on function public.get_mock_stage(uuid) to authenticated;

-- 18. start_mock_module2: valid during the gap; after the gap (or once started) returns module 2. -----------
create function public.start_mock_module2(p_group_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_run private.mock_runs%rowtype;
begin
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;
  perform private.hit_rate_limit('start_mock_module2:' || v_uid, private.setting_int('rate_start_per_min'), 60);
  if p_group_id is null
     or not exists (select 1 from private.mock_runs r where r.group_id = p_group_id and r.user_id = v_uid) then
    raise exception 'invalid_input';
  end if;
  perform private.mock_tick(v_uid);
  select r.* into v_run from private.mock_runs r where r.group_id = p_group_id;
  if v_run.finished_at is null and v_run.m2_attempt_id is null then
    if v_run.m1_submitted_at is null then
      raise exception 'invalid_input';
    end if;
    perform private.mock_create_module2(p_group_id, now());
  end if;
  return private.mock_stage(p_group_id);
end;
$$;
revoke execute on function public.start_mock_module2(uuid) from public, anon;
grant execute on function public.start_mock_module2(uuid) to authenticated;

-- 19. submit_attempt: quiz/homework body unchanged, plus the mock_module branch. A mock module takes the
--     per-user lock, ticks, finishes the module at least(now, deadline) and returns the stage (no score).
--     Submitting an already-submitted module returns the current stage without regrading. -----------------
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
    perform private.mock_lock_user(v_uid);
    perform private.mock_tick(v_uid);
    select a.* into v_att from public.attempts a where a.id = p_attempt_id for update;
    if v_att.status = 'in_progress' then
      if v_att.module_no = 1 then
        perform private.mock_finish_module1(v_att.mock_attempt_group, pg_catalog.now());
      else
        perform private.mock_finish_module2(v_att.mock_attempt_group, pg_catalog.now());
      end if;
    end if;
    return private.mock_stage(v_att.mock_attempt_group);
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

-- 21. attempt_answers policy: answers of a mock_module attempt (is_correct, the student's answers) become
--     readable only when the run has finished; every other kind is unchanged. The helper is in public
--     (like is_teacher) so the policy needs no grant on private.mock_runs. -------------------------------
create function public.mock_attempt_visible(p_attempt_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select not exists (
    select 1 from public.attempts a
    where a.id = p_attempt_id and a.kind = 'mock_module'
      and a.user_id = (select auth.uid())  -- reveals nothing about anyone else's attempt
      and not exists (select 1 from private.mock_runs r
                      where r.group_id = a.mock_attempt_group and r.finished_at is not null)
  );
$$;
revoke execute on function public.mock_attempt_visible(uuid) from public, anon;
grant execute on function public.mock_attempt_visible(uuid) to authenticated;

drop policy "attempt_answers: student selects own submitted" on public.attempt_answers;
create policy "attempt_answers: student selects own submitted" on public.attempt_answers
  for select to authenticated
  using (exists (select 1 from public.attempts a
                 where a.id = attempt_id and a.user_id = (select auth.uid())
                   and a.status <> 'in_progress')
         and public.mock_attempt_visible(attempt_id));

-- 22. Cron: its own job, separate from the quiz cron (expire_overdue_attempts is untouched: the quiz cron
--     holds skill_mastery row locks from finish_quiz and then waits on the user lock, while a mock finish
--     holds the user lock and updates the same rows; keeping them apart removes that lock-order cycle).
--     tick_overdue_mocks ticks every user with an unfinished run that has something due (module 1 or 2 past
--     deadline + grace, or the gap over with no module 2). The partial index on unfinished runs keeps the
--     scan cheap; nothing due means no work. A failing user is logged and skipped so it cannot block the
--     others. Returns the number of users ticked. ------------------------------------------------------
create function private.tick_overdue_mocks()
returns int
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_ticked int := 0;
  v_user   uuid;
begin
  for v_user in
    select distinct r.user_id
    from private.mock_runs r
    left join public.attempts a1 on a1.id = r.m1_attempt_id
    left join public.attempts a2 on a2.id = r.m2_attempt_id
    where r.finished_at is null
      and ((r.m1_submitted_at is null
            and a1.started_at + pg_catalog.make_interval(secs => a1.time_limit_s + private.setting_int('save_grace_s')) < pg_catalog.now())
        or (r.m1_submitted_at is not null and r.m2_attempt_id is null
            and r.m1_submitted_at + pg_catalog.make_interval(secs => private.setting_int('mock_gap_s')) <= pg_catalog.now())
        or (r.m2_attempt_id is not null and a2.status = 'in_progress'
            and a2.started_at + pg_catalog.make_interval(secs => a2.time_limit_s + private.setting_int('save_grace_s')) < pg_catalog.now()))
  loop
    begin
      perform private.mock_tick(v_user);
      v_ticked := v_ticked + 1;
    exception when others then
      raise warning 'mock_tick failed for a user: %', sqlerrm;
    end;
  end loop;
  return v_ticked;
end;
$$;
revoke execute on function private.tick_overdue_mocks() from public, anon, authenticated;

-- Named schedules upsert per job name and owner (same as 'expire-attempts'); idempotent.
select cron.schedule('tick-mocks', '* * * * *', 'select private.tick_overdue_mocks()');
