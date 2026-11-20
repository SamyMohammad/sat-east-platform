-- MCK-09: mock exams unlock when the student has completed ALL published topics of the course.
-- A teacher-editable switch (mock_unlock_require_all_topics, 1 = on, 0 = off) falls back to the old
-- first + (k - 1) * step rule. Stored as the number 1/0 (not a JSON boolean) because teacher_update_settings
-- and the teacher settings screen only handle whole numbers.
-- Sections: 1 setting + teacher spec | 2 total topics + unlock need | 3 get_mock_hub | 4 start_mock.

-- 1. Setting + teacher spec ----------------------------------------------------------------------
insert into public.settings (key, value)
values ('mock_unlock_require_all_topics', '1'::jsonb)
on conflict (key) do nothing;  -- never overwrite a value a teacher has already changed

-- Latest definition (20261116100000_mck03_mock_hardening.sql) plus the switch at the head of group Mock.
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
    ('mock_unlock_require_all_topics','Mock','Require all topics before mocks','1 = yes, 0 = no',0,1,15),
    ('mock_unlock_first_topics','Mock','Topics to unlock mock 1','topics',0,50,16),
    ('mock_unlock_step_topics','Mock','Extra topics per next mock','topics',0,50,17),
    ('mock_gap_s','Mock','Break between modules','seconds',0,900,18),
    ('mock_warn_s','Mock','Mock time warning at','seconds left',0,1800,19),
    ('sat_scale_margin','Mock','Score range margin','points',0,100,20);
$$;
revoke all on function private.teacher_setting_spec() from public, anon, authenticated, service_role;

-- 2. Total topics + unlock need ------------------------------------------------------------------
-- Published topics of a course: exactly the rows private.topic_states returns (its base set), so the
-- total can never exceed what private.mock_passed_topics can reach.
create function private.mock_total_topics(p_course_id uuid)
returns int
language sql
stable
security definer
set search_path = ''
as $$
  select count(*)::int from public.topics t where t.course_id = p_course_id and t.is_published
$$;
revoke execute on function private.mock_total_topics(uuid) from public, anon, authenticated;

-- Replaces private.mock_unlock_need(int) of 20261116100000: the course id decides the "all topics" need.
-- Switch on: every form needs all published topics (at least 1, so an empty course never unlocks a mock).
-- Switch off: form k needs first + (k - 1) * step (k below 1 counts as 1).
drop function private.mock_unlock_need(int);
create function private.mock_unlock_need(p_k int, p_course_id uuid)
returns int
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_all   jsonb := private.setting_json('mock_unlock_require_all_topics');
  v_first jsonb;
  v_step  jsonb;
begin
  if v_all is null or jsonb_typeof(v_all) <> 'number' or (v_all #>> '{}')::numeric not in (0, 1) then
    raise exception 'mock_settings_invalid' using errcode = 'P0001';
  end if;
  if (v_all #>> '{}')::numeric = 1 then
    return greatest(private.mock_total_topics(p_course_id), 1);
  end if;
  v_first := private.setting_json('mock_unlock_first_topics');
  v_step  := private.setting_json('mock_unlock_step_topics');
  if v_first is null or jsonb_typeof(v_first) <> 'number' or (v_first #>> '{}')::numeric < 0
     or (v_first #>> '{}')::numeric <> trunc((v_first #>> '{}')::numeric)
     or v_step is null or jsonb_typeof(v_step) <> 'number' or (v_step #>> '{}')::numeric < 0
     or (v_step #>> '{}')::numeric <> trunc((v_step #>> '{}')::numeric) then
    raise exception 'mock_settings_invalid' using errcode = 'P0001';
  end if;
  return (v_first #>> '{}')::int + (greatest(p_k, 1) - 1) * (v_step #>> '{}')::int;
end;
$$;
revoke execute on function private.mock_unlock_need(int, uuid) from public, anon, authenticated;

-- 3. Hub: same as 20261116100000 plus total_topics; need comes from the course-aware rule --------------
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
  v_total  int;
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
  v_total := private.mock_total_topics(p_course_id);
  select coalesce(jsonb_agg(jsonb_build_object(
      'form_no', f.form_no, 'k', f.k, 'need', private.mock_unlock_need(f.k, p_course_id),
      'state', case when m1.id is null then case when v_passed >= private.mock_unlock_need(f.k, p_course_id)
                                                 then 'available' else 'locked' end
                    when r.id is not null then 'finished' else 'in_progress' end) order by f.k), '[]'::jsonb)
  into v_forms
  from private.mock_forms_for(v_tpl, v_set) f
  left join public.attempts m1 on m1.user_id = v_uid and m1.mock_form_id = f.m1_form_id
                              and m1.kind = 'mock_module' and m1.module_no = 1
  left join public.mock_results r on r.group_id = m1.mock_attempt_group and r.user_id = v_uid;
  return jsonb_build_object('passed_topics', v_passed, 'total_topics', v_total, 'forms', v_forms,
                            'active_group', v_active);
end;
$$;
revoke execute on function public.get_mock_hub(uuid) from public, anon;
grant execute on function public.get_mock_hub(uuid) to authenticated;

-- 4. start_mock: same as 20261113100100 except the unlock check passes the course id -------------------
create or replace function public.start_mock(p_course_id uuid)
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
    and v_passed >= private.mock_unlock_need(f.k, p_course_id)
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
revoke execute on function public.start_mock(uuid) from public, anon;
grant execute on function public.start_mock(uuid) to authenticated;
