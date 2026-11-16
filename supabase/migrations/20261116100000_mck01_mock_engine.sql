-- MCK-01: SAT mock engine, server. Spec: docs/superpowers/specs/2026-11-12-mock-sat-design.md Part 3.
-- Sections: 1 settings | 2 scale tables | 3 teacher spec | 4 scale + estimate helpers | 5 mock_runs |
-- 6 unlock | 7 access + hub rows | 8 hub | 9 payload helpers + stage | 10 start_mock + get_mock_stage |
-- 11 save_answer | 12 has_active_exam (Task 3 appends: submit/routing/tick/results).

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

  select coalesce(jsonb_agg(jsonb_build_object('id', q.id, 'type', q.type, 'difficulty', q.difficulty,
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

  insert into private.mock_runs (user_id, course_id, template_id, set_no, form_no)
  values (v_uid, p_course_id, v_row.template_id, v_row.set_no, v_row.form_no)
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
