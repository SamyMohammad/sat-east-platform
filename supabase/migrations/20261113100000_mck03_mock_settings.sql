-- MCK-03: mock engine settings and scoring helpers. Spec: docs/superpowers/specs/2026-11-12-mock-sat-design.md Part 3.
-- Sections: 1 settings | 2 private helpers | 3 seed check.
-- None of these keys is in private.teacher_setting_spec(): they change by migration for the beta.

-- 1. Settings (never overwrite a value that was already changed) --------------------------------
-- Mock k unlocks after mock_unlock_topics[min(k, length)] passed topics.
insert into public.settings (key, value) values
  ('mock_unlock_topics', '[3, 6, 10]'::jsonb),
  ('mock_gap_s', '120'::jsonb),            -- break between module 1 and module 2, seconds
  ('sat_scale_margin', '30'::jsonb)        -- score range = table value +/- margin
on conflict (key) do nothing;

-- Raw score (0-44 = correct in module 1 + module 2) -> scaled score, one table per module-2 route.
-- Starting values: easy is linear 200 -> 620 over raw 0-35 then -> 650 at raw 44; hard is linear
-- 200 -> 480 over raw 0-14 then -> 800 at raw 44; all rounded to 10.
insert into public.settings (key, value) values
  ('sat_scale_easy', '[200, 210, 220, 240, 250, 260, 270, 280, 300, 310, 320, 330, 340, 360, 370, 380, 390, 400, 420, 430, 440, 450, 460, 480, 490, 500, 510, 520, 540, 550, 560, 570, 580, 600, 610, 620, 620, 630, 630, 630, 640, 640, 640, 650, 650]'::jsonb),
  ('sat_scale_hard', '[200, 220, 240, 260, 280, 300, 320, 340, 360, 380, 400, 420, 440, 460, 480, 490, 500, 510, 520, 530, 540, 550, 570, 580, 590, 600, 610, 620, 630, 640, 650, 660, 670, 680, 690, 700, 710, 730, 740, 750, 760, 770, 780, 790, 800]'::jsonb)
on conflict (key) do nothing;

-- 2. Private helpers (no grants: not reachable over the API) -------------------------------------

create function private.setting_json(p_key text)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select value from public.settings where key = p_key
$$;

-- True only for a usable scale table: 45 entries (raw 0-44), integers 200-800, non-decreasing.
-- Never raises.
create function private.mock_scale_ok(p_table jsonb)
returns boolean
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_len  constant int := 45;
  v_min  constant int := 200;
  v_max  constant int := 800;
  v_e    jsonb;
  v_n    numeric;
  v_prev numeric := v_min;
begin
  if p_table is null or jsonb_typeof(p_table) <> 'array' or jsonb_array_length(p_table) <> v_len then
    return false;
  end if;
  for v_e in select * from jsonb_array_elements(p_table) loop
    if jsonb_typeof(v_e) <> 'number' then
      return false;
    end if;
    v_n := (v_e #>> '{}')::numeric;
    if v_n <> trunc(v_n) or v_n < v_min or v_n > v_max or v_n < v_prev then
      return false;
    end if;
    v_prev := v_n;
  end loop;
  return true;
end;
$$;

-- Passed-topic count needed to unlock the k-th mock: list[min(k, length)] (k below 1 counts as 1).
create function private.mock_unlock_need(p_k int)
returns int
language plpgsql
stable
set search_path = ''
as $$
declare
  v_list jsonb := private.setting_json('mock_unlock_topics');
  v_len  int;
begin
  if v_list is null or jsonb_typeof(v_list) <> 'array' then
    raise exception 'mock_settings_invalid' using errcode = 'P0001';
  end if;
  v_len := jsonb_array_length(v_list);
  if v_len = 0 or jsonb_typeof(v_list -> 0) <> 'number' then
    raise exception 'mock_settings_invalid' using errcode = 'P0001';
  end if;
  return (v_list ->> (least(greatest(p_k, 1), v_len) - 1))::int;
end;
$$;

-- Estimated score range for a module-2 route ('M2E' easy, 'M2H' hard) and a raw total (0-44):
-- table value +/- margin, rounded to the nearest 10, clamped to 200-800.
create function private.mock_score(p_route text, p_raw int)
returns table (est_low int, est_high int)
language plpgsql
stable
set search_path = ''
as $$
declare
  v_floor  constant int := 200;
  v_ceil   constant int := 800;
  v_step   constant int := 10;
  v_table  jsonb;
  v_m      jsonb := private.setting_json('sat_scale_margin');
  v_margin numeric;
  v_val    numeric;
begin
  if p_route is null or p_route not in ('M2E', 'M2H') then
    raise exception 'mock_route_invalid' using errcode = 'P0001';
  end if;
  v_table := private.setting_json(case p_route when 'M2E' then 'sat_scale_easy' else 'sat_scale_hard' end);
  if not private.mock_scale_ok(v_table) or v_m is null or jsonb_typeof(v_m) <> 'number'
     or (v_m #>> '{}')::numeric < 0 then
    raise exception 'mock_settings_invalid' using errcode = 'P0001';
  end if;
  if p_raw is null or p_raw < 0 or p_raw >= jsonb_array_length(v_table) then
    raise exception 'mock_raw_invalid' using errcode = 'P0001';
  end if;
  v_margin := (v_m #>> '{}')::numeric;
  v_val := (v_table ->> p_raw)::numeric;
  est_low := least(v_ceil, greatest(v_floor, (round((v_val - v_margin) / v_step) * v_step)::int));
  est_high := least(v_ceil, greatest(v_floor, (round((v_val + v_margin) / v_step) * v_step)::int));
  return next;
end;
$$;

-- 3. Seed check: the seeded tables must pass the validator ---------------------------------------
do $$
begin
  if not private.mock_scale_ok(private.setting_json('sat_scale_easy'))
     or not private.mock_scale_ok(private.setting_json('sat_scale_hard')) then
    raise exception 'mck03: seeded sat_scale tables fail mock_scale_ok';
  end if;
end;
$$;
