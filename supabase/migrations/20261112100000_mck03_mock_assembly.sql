-- MCK-03: SAT mock form assembly (server). Spec: docs/superpowers/specs/2026-11-12-mock-sat-design.md Part 1.
-- Sections: 1 form status | 2 blueprint setting | 3 template guard | 4 private helpers
-- (later tasks append: eligibility/shortage, teacher RPCs).

-- 1. Form status -------------------------------------------------------------------------------
alter table public.mock_forms
  add column status text not null default 'draft' check (status in ('draft', 'published')),
  add column published_at timestamptz;

-- 2. Blueprint setting (docs/08 section 3, verbatim; teacher edits are by migration, so it is
--    deliberately not in private.teacher_setting_spec()) ------------------------------------------
insert into public.settings (key, value)
values ('mock_blueprint_sat', '{
  "modules": {
    "M1":  {"count": 22, "time_s": 2100, "difficulty": {"E": 7, "M": 9, "H": 6}},
    "M2E": {"count": 22, "time_s": 2100, "difficulty": {"E": 10, "M": 9, "H": 3}},
    "M2H": {"count": 22, "time_s": 2100, "difficulty": {"E": 3, "M": 9, "H": 10}}
  },
  "domains": {"Algebra": 0.35, "Advanced Math": 0.35, "PSDA": 0.15, "Geometry & Trig": 0.15},
  "spr_ratio": 0.25,
  "routing": {"threshold_correct_m1": 14},
  "ordering": "difficulty_ascending_within_module"
}'::jsonb)
on conflict (key) do nothing;

-- 3. One adaptive template per course ------------------------------------------------------------
create unique index mock_templates_one_adaptive_per_course
  on public.mock_templates (course_id) where adaptive;

-- 4. Private helpers (no grants: not reachable over the API) -------------------------------------

-- True only for a blueprint assembly can use. Never raises.
create function private.mock_blueprint_ok(p_blueprint jsonb)
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

-- The slot recipe of one module (docs/08 section 3, "slot rule"). Deterministic: ties go to the
-- domain name ascending (C collation). Slot difficulty is E, then M, then H.
create function private.mock_module_slots(p_blueprint jsonb, p_module text)
returns table (slot_no int, difficulty public.difficulty, domain text, qtype public.question_type)
language plpgsql
stable
set search_path = ''
as $$
declare
  v_mod      jsonb;
  v_n        int;
  v_e        int;
  v_m        int;
  v_names    text[];
  v_counts   int[];
  v_fracs    numeric[];
  v_assigned int[];
  v_rem      int;
  v_s        numeric;
  v_best     int;
  v_score    numeric;
  v_top      numeric;
begin
  if not private.mock_blueprint_ok(p_blueprint) or p_module is null
     or p_module not in ('M1', 'M2E', 'M2H') then
    raise exception 'internal';
  end if;

  v_mod := p_blueprint -> 'modules' -> p_module;
  v_n := (v_mod ->> 'count')::int;
  v_e := (v_mod -> 'difficulty' ->> 'E')::int;
  v_m := (v_mod -> 'difficulty' ->> 'M')::int;

  -- Domain counts: floor(share * N), then one extra each to the largest fractions.
  select array_agg(d.k order by d.k collate "C"),
         array_agg(floor(d.share * v_n)::int order by d.k collate "C"),
         array_agg(d.share * v_n - floor(d.share * v_n) order by d.k collate "C")
    into v_names, v_counts, v_fracs
  from (select key as k, (value #>> '{}')::numeric as share
        from jsonb_each(p_blueprint -> 'domains')) d;

  v_rem := v_n - (select coalesce(sum(c), 0) from unnest(v_counts) c);
  while v_rem > 0 loop
    v_best := 1;
    v_top := v_fracs[1];
    for v_j in 2 .. array_length(v_names, 1) loop
      if v_fracs[v_j] > v_top then
        v_best := v_j;
        v_top := v_fracs[v_j];
      end if;
    end loop;
    v_counts[v_best] := v_counts[v_best] + 1;
    v_fracs[v_best] := -1;
    v_rem := v_rem - 1;
  end loop;

  v_assigned := array_fill(0, array[array_length(v_names, 1)]);
  v_s := round(v_n * (p_blueprint ->> 'spr_ratio')::numeric);

  for v_i in 1 .. v_n loop
    -- Largest n_d * i / N - assigned_d, compared as n_d * i - assigned_d * N (exact integers).
    v_best := 1;
    v_top := v_counts[1] * v_i - v_assigned[1] * v_n;
    for v_j in 2 .. array_length(v_names, 1) loop
      v_score := v_counts[v_j] * v_i - v_assigned[v_j] * v_n;
      if v_score > v_top then
        v_best := v_j;
        v_top := v_score;
      end if;
    end loop;
    v_assigned[v_best] := v_assigned[v_best] + 1;

    slot_no := v_i;
    difficulty := case when v_i <= v_e then 'E' when v_i <= v_e + v_m then 'M' else 'H' end::public.difficulty;
    domain := v_names[v_best];
    qtype := case when floor(v_i * v_s / v_n) > floor((v_i - 1) * v_s / v_n) then 'spr'::public.question_type else 'mcq'::public.question_type end;
    return next;
  end loop;
end;
$$;

-- The course's SAT template; created from the setting on first use.
create function private.mock_template_for(p_course_id uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_code      text;
  v_blueprint jsonb;
  v_id        uuid;
begin
  if p_course_id is null then
    raise exception 'invalid_input';
  end if;
  select c.code into v_code from public.courses c where c.id = p_course_id;
  if v_code is distinct from 'SAT' then
    raise exception 'invalid_input';
  end if;

  select t.id into v_id
  from public.mock_templates t
  where t.course_id = p_course_id and t.adaptive;
  if v_id is not null then
    return v_id;
  end if;

  select s.value into v_blueprint from public.settings s where s.key = 'mock_blueprint_sat';
  if not private.mock_blueprint_ok(v_blueprint) then
    raise exception 'internal';
  end if;

  insert into public.mock_templates (course_id, name, adaptive, blueprint)
  values (p_course_id, 'SAT Math', true, v_blueprint)
  on conflict (course_id) where adaptive do nothing
  returning id into v_id;

  if v_id is null then  -- lost a race with another session
    select t.id into v_id
    from public.mock_templates t
    where t.course_id = p_course_id and t.adaptive;
  end if;
  return v_id;
end;
$$;

revoke execute on function private.mock_blueprint_ok(jsonb) from public, anon, authenticated;
revoke execute on function private.mock_module_slots(jsonb, text) from public, anon, authenticated;
revoke execute on function private.mock_template_for(uuid) from public, anon, authenticated;
