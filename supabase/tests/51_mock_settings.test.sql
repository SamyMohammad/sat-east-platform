-- MCK-03 Task 1: mock settings (unlock list, gap, score margin, scale tables) and scoring helpers.
-- From supabase/templates/test.sql.
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

-- Builds a jsonb array of n ints, all equal to v (helper for validator cases).
create function pg_temp.flat(n int, v int) returns jsonb language sql immutable as
  $$ select coalesce(jsonb_agg(v), '[]'::jsonb) from generate_series(1, n) $$;
-- Replaces one array element (0-based index) of a jsonb array.
create function pg_temp.with_at(a jsonb, i int, v jsonb) returns jsonb language sql immutable as
  $$ select jsonb_set(a, array[i::text], v) $$;
create function pg_temp.setting(p_key text) returns jsonb language sql stable as
  $$ select value from public.settings where key = p_key $$;
-- Same score call, text result 'low-high'.
create function pg_temp.score(p_route text, p_raw int) returns text language sql stable as
  $$ select est_low || '-' || est_high from private.mock_score(p_route, p_raw) $$;

-- Seeds exist with the agreed values.
select is(pg_temp.setting('mock_unlock_topics'), '[3, 6, 10]'::jsonb, 'MCK-03: mock_unlock_topics seed');
select is(pg_temp.setting('mock_gap_s'), '120'::jsonb, 'MCK-03: mock_gap_s seed');
select is(pg_temp.setting('sat_scale_margin'), '30'::jsonb, 'MCK-03: sat_scale_margin seed');
select ok(exists (select 1 from public.settings where key = 'sat_scale_easy'), 'MCK-03: sat_scale_easy exists');
select ok(exists (select 1 from public.settings where key = 'sat_scale_hard'), 'MCK-03: sat_scale_hard exists');

-- Seeded tables are valid and have the documented shape.
select ok(private.mock_scale_ok(pg_temp.setting('sat_scale_easy')), 'MCK-03: seeded easy table is valid');
select ok(private.mock_scale_ok(pg_temp.setting('sat_scale_hard')), 'MCK-03: seeded hard table is valid');
select is(jsonb_array_length(pg_temp.setting('sat_scale_easy')), 45, 'MCK-03: easy table has 45 entries');
select is(jsonb_array_length(pg_temp.setting('sat_scale_hard')), 45, 'MCK-03: hard table has 45 entries');
select is(pg_temp.setting('sat_scale_easy') -> 0, '200'::jsonb, 'MCK-03: easy raw 0 is 200');
select is(pg_temp.setting('sat_scale_easy') -> 44, '650'::jsonb, 'MCK-03: easy raw 44 is 650');
select is(pg_temp.setting('sat_scale_hard') -> 0, '200'::jsonb, 'MCK-03: hard raw 0 is 200');
select is(pg_temp.setting('sat_scale_hard') -> 44, '800'::jsonb, 'MCK-03: hard raw 44 is 800');
select ok(not exists (
    select 1 from public.settings s, jsonb_array_elements_text(s.value) e
    where s.key in ('sat_scale_easy', 'sat_scale_hard') and e::int % 10 <> 0),
  'MCK-03: every seeded scale value is a multiple of 10');
select ok(not exists (select 1 from private.teacher_setting_spec() where key in
    ('mock_unlock_topics', 'mock_gap_s', 'sat_scale_margin', 'sat_scale_easy', 'sat_scale_hard')),
  'MCK-03: new keys are not teacher-editable (migration only)');

-- setting_json.
select is(private.setting_json('mock_gap_s'), '120'::jsonb, 'MCK-03: setting_json returns the value');
select is(private.setting_json('no_such_setting_key'), null, 'MCK-03: setting_json of a missing key is null');

-- Validator rejections.
select ok(private.mock_scale_ok(pg_temp.flat(45, 500)), 'MCK-03: a flat 45-entry table is valid');
select ok(not private.mock_scale_ok(pg_temp.flat(44, 500)), 'MCK-03: 44 entries rejected');
select ok(not private.mock_scale_ok(pg_temp.flat(46, 500)), 'MCK-03: 46 entries rejected');
select ok(not private.mock_scale_ok(pg_temp.with_at(pg_temp.flat(45, 500), 0, '190'::jsonb)), 'MCK-03: 190 rejected');
select ok(not private.mock_scale_ok(pg_temp.with_at(pg_temp.flat(45, 500), 44, '810'::jsonb)), 'MCK-03: 810 rejected');
select ok(not private.mock_scale_ok(pg_temp.with_at(pg_temp.flat(45, 500), 20, '490'::jsonb)), 'MCK-03: a decrease is rejected');
select ok(not private.mock_scale_ok(pg_temp.with_at(pg_temp.flat(45, 500), 20, '"500"'::jsonb)), 'MCK-03: a string entry rejected');
select ok(not private.mock_scale_ok(pg_temp.with_at(pg_temp.flat(45, 500), 20, '500.5'::jsonb)), 'MCK-03: a non-int entry rejected');
select ok(not private.mock_scale_ok(pg_temp.with_at(pg_temp.flat(45, 500), 20, 'null'::jsonb)), 'MCK-03: a null entry rejected');
select ok(not private.mock_scale_ok('{"a": 1}'::jsonb), 'MCK-03: an object rejected');
select ok(not private.mock_scale_ok(null), 'MCK-03: null rejected');

-- Unlock thresholds: list [3, 6, 10]; form k beyond the list uses the last entry.
select is((select array_agg(private.mock_unlock_need(k) order by k) from generate_series(1, 5) k),
  array[3, 6, 10, 10, 10], 'MCK-03: unlock_need(1..5) with [3,6,10]');
select is(private.mock_unlock_need(0), 3, 'MCK-03: unlock_need below 1 uses the first entry');

update public.settings set value = '[2, 4]'::jsonb where key = 'mock_unlock_topics';
select is((select array_agg(private.mock_unlock_need(k) order by k) from generate_series(1, 4) k),
  array[2, 4, 4, 4], 'MCK-03: unlock_need follows an edited list');
update public.settings set value = '[]'::jsonb where key = 'mock_unlock_topics';
select throws_ok($$ select private.mock_unlock_need(1) $$, 'P0001', 'mock_settings_invalid',
  'MCK-03: an empty unlock list raises mock_settings_invalid');
update public.settings set value = '[3, 6, 10]'::jsonb where key = 'mock_unlock_topics';

-- mock_score edges (seeded margin 30).
select is(pg_temp.score('M2E', 0), '200-230', 'MCK-03: easy raw 0 clamps low to 200');
select is(pg_temp.score('M2H', 44), '770-800', 'MCK-03: hard raw 44 clamps high to 800');
select is(pg_temp.score('M2E', 35), '590-650', 'MCK-03: easy raw 35 is table value 620 +/- 30');
select is(pg_temp.score('M2H', 14), '450-510', 'MCK-03: hard raw 14 is table value 480 +/- 30');
select is((select est_low from private.mock_score('M2H', 0)), 200, 'MCK-03: hard raw 0 low is 200');

-- Margin is a setting; non-multiples of 10 round to the nearest 10.
update public.settings set value = '25'::jsonb where key = 'sat_scale_margin';
select is(pg_temp.score('M2E', 35), '600-650', 'MCK-03: margin 25 rounds 595 to 600 and 645 to 650');
update public.settings set value = '30'::jsonb where key = 'sat_scale_margin';

-- Bad arguments.
select throws_ok($$ select * from private.mock_score('M1', 10) $$, 'P0001', 'mock_route_invalid',
  'MCK-03: unknown route raises mock_route_invalid');
select throws_ok($$ select * from private.mock_score('M2E', -1) $$, 'P0001', 'mock_raw_invalid',
  'MCK-03: negative raw raises mock_raw_invalid');
select throws_ok($$ select * from private.mock_score('M2E', 45) $$, 'P0001', 'mock_raw_invalid',
  'MCK-03: raw 45 raises mock_raw_invalid');

-- Corrupt table in settings is refused, never scored.
update public.settings set value = pg_temp.flat(44, 500) where key = 'sat_scale_easy';
select throws_ok($$ select * from private.mock_score('M2E', 10) $$, 'P0001', 'mock_settings_invalid',
  'MCK-03: an invalid stored table raises mock_settings_invalid');

-- Grants: helpers are private, nothing for authenticated or anon.
select ok(not has_function_privilege('authenticated', 'private.setting_json(text)', 'execute')
  and not has_function_privilege('authenticated', 'private.mock_scale_ok(jsonb)', 'execute')
  and not has_function_privilege('authenticated', 'private.mock_unlock_need(integer)', 'execute')
  and not has_function_privilege('authenticated', 'private.mock_score(text,integer)', 'execute'),
  'MCK-03: helpers are not executable by authenticated');
select ok(not has_function_privilege('anon', 'private.setting_json(text)', 'execute')
  and not has_function_privilege('anon', 'private.mock_scale_ok(jsonb)', 'execute')
  and not has_function_privilege('anon', 'private.mock_unlock_need(integer)', 'execute')
  and not has_function_privilege('anon', 'private.mock_score(text,integer)', 'execute'),
  'MCK-03: helpers are not executable by anon');

select * from finish();
rollback;
