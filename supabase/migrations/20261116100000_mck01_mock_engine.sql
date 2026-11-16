-- MCK-01: SAT mock engine, server. Spec: docs/superpowers/specs/2026-11-12-mock-sat-design.md Part 3.
-- Sections: 1 settings | 2 scale tables | 3 teacher spec | 4 scale + estimate helpers | 5 mock_runs |
-- 6 unlock | 7 hub (later tasks append: start/save/resume, submit/routing/tick/results).

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
  created_at       timestamptz not null default now(),
  unique (user_id, template_id, set_no, form_no)
);
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

-- 7. Hub ------------------------------------------------------------------------------------------
create function public.get_mock_hub(p_course_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid    uuid := auth.uid();
  v_enr    public.enrollments%rowtype;
  v_passed int;
  v_forms  jsonb;
begin
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;
  if p_course_id is null then
    raise exception 'invalid_input';
  end if;

  select e.* into v_enr from public.enrollments e where e.user_id = v_uid and e.course_id = p_course_id;
  if not found then
    raise exception 'not_enrolled';
  end if;
  if v_enr.status <> 'active' or v_enr.expires_at <= now() then
    raise exception 'access_expired';
  end if;

  select count(*)::int into v_passed
  from private.topic_states(v_uid, p_course_id) ts where ts.status = 'completed';

  with u as (
    select * from private.mock_form_unlock(v_uid, p_course_id)
  ), j as (
    select u.form_no, u.topics_needed, r.group_id, r.finished_at, res.est_low, res.est_high,
           (r.group_id is null) as not_started
    from u
    left join private.mock_runs r on r.user_id = v_uid and r.template_id = u.template_id
                                 and r.set_no = u.set_no and r.form_no = u.form_no
    left join public.mock_results res on res.group_id = r.group_id and res.user_id = v_uid
  ), c as (
    select (select min(j.form_no) from j where j.not_started) as next_form,
           exists (select 1 from private.mock_runs x where x.user_id = v_uid and x.finished_at is null) as busy
  )
  select coalesce(jsonb_agg(jsonb_build_object(
      'form_no', j.form_no,
      'state', case
        when j.group_id is not null and j.finished_at is not null then 'finished'
        when j.group_id is not null then 'in_progress'
        when j.form_no = c.next_form and not c.busy and v_passed >= j.topics_needed then 'available'
        else 'locked' end,
      'topics_needed', j.topics_needed,
      'group_id', j.group_id,
      'est_low', case when j.finished_at is not null then j.est_low end,
      'est_high', case when j.finished_at is not null then j.est_high end
    ) order by j.form_no), '[]'::jsonb)
  into v_forms
  from j cross join c;

  return jsonb_build_object('set_no', v_enr.mock_set_no, 'topics_passed', v_passed, 'forms', v_forms);
end;
$$;
revoke execute on function public.get_mock_hub(uuid) from public, anon;
grant execute on function public.get_mock_hub(uuid) to authenticated;
