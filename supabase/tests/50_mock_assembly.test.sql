-- MCK-03 Task 1: form status, blueprint setting, slot rule, template helper. From supabase/templates/test.sql.
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

insert into public.courses (code, title, slug) values
  ('SAT', 'Mock SAT', 'mock-sat'), ('EST', 'Mock EST', 'mock-est')
on conflict (code) do nothing;

create function pg_temp.bp() returns jsonb language sql stable as
  $$ select value from public.settings where key = 'mock_blueprint_sat' $$;
-- 'E/M/H' counts of one module, as text.
create function pg_temp.emh(p_module text) returns text language sql stable as $$
  select string_agg(c::text, '/' order by ord) from (
    select case difficulty when 'E' then 1 when 'M' then 2 else 3 end ord, count(*) c
    from private.mock_module_slots(pg_temp.bp(), p_module) group by 1) x $$;
create function pg_temp.dom(p_module text) returns text language sql stable as $$
  select string_agg(domain || '=' || c, ', ' order by domain collate "C") from (
    select domain, count(*) c from private.mock_module_slots(pg_temp.bp(), p_module) group by 1) x $$;
create function pg_temp.spr(p_module text) returns int[] language sql stable as $$
  select array_agg(slot_no order by slot_no) from private.mock_module_slots(pg_temp.bp(), p_module)
  where qtype = 'spr' $$;

-- mock_forms status columns.
select has_column('public', 'mock_forms', 'status', 'MCK-03: mock_forms.status exists');
select has_column('public', 'mock_forms', 'published_at', 'MCK-03: mock_forms.published_at exists');
select col_default_is('public', 'mock_forms', 'status', 'draft', 'MCK-03: status defaults to draft');
select col_not_null('public', 'mock_forms', 'status', 'MCK-03: status is not null');
select throws_ok(
  $$ insert into public.mock_forms (template_id, set_no, form_no, module, question_ids, status)
     values (gen_random_uuid(), 1, 1, 'M1', '{}', 'archived') $$,
  '23514', null, 'MCK-03: status accepts only draft or published');

-- Blueprint setting.
select ok(exists (select 1 from public.settings where key = 'mock_blueprint_sat'),
  'MCK-03: setting mock_blueprint_sat exists');
select ok(private.mock_blueprint_ok(pg_temp.bp()), 'MCK-03: seeded blueprint is valid');

-- Slot counts and difficulty split.
select is((select count(*)::int from private.mock_module_slots(pg_temp.bp(), 'M1')), 22, 'MCK-03: M1 has 22 slots');
select is((select count(*)::int from private.mock_module_slots(pg_temp.bp(), 'M2E')), 22, 'MCK-03: M2E has 22 slots');
select is((select count(*)::int from private.mock_module_slots(pg_temp.bp(), 'M2H')), 22, 'MCK-03: M2H has 22 slots');
select is(pg_temp.emh('M1'), '7/9/6', 'MCK-03: M1 difficulty E/M/H');
select is(pg_temp.emh('M2E'), '10/9/3', 'MCK-03: M2E difficulty E/M/H');
select is(pg_temp.emh('M2H'), '3/9/10', 'MCK-03: M2H difficulty E/M/H');

-- Slot rule: domains, SPR positions, order, determinism.
select is(pg_temp.dom('M1'), 'Advanced Math=8, Algebra=8, Geometry & Trig=3, PSDA=3', 'MCK-03: M1 domain counts');
select is(pg_temp.dom('M2E'), 'Advanced Math=8, Algebra=8, Geometry & Trig=3, PSDA=3', 'MCK-03: M2E domain counts');
select is(pg_temp.dom('M2H'), 'Advanced Math=8, Algebra=8, Geometry & Trig=3, PSDA=3', 'MCK-03: M2H domain counts');
select is(pg_temp.spr('M1'), array[4, 8, 11, 15, 19, 22], 'MCK-03: M1 SPR slots');
select is(pg_temp.spr('M2E'), array[4, 8, 11, 15, 19, 22], 'MCK-03: M2E SPR slots');
select is(pg_temp.spr('M2H'), array[4, 8, 11, 15, 19, 22], 'MCK-03: M2H SPR slots');
select is((select array_agg(domain order by slot_no) from private.mock_module_slots(pg_temp.bp(), 'M1') where slot_no <= 4),
  array['Advanced Math', 'Algebra', 'Geometry & Trig', 'PSDA'], 'MCK-03: slots 1-4 domains');
select is((select array_agg(domain order by slot_no) from private.mock_module_slots(pg_temp.bp(), 'M1')),
  array['Advanced Math', 'Algebra', 'Geometry & Trig', 'PSDA', 'Advanced Math', 'Algebra', 'Advanced Math', 'Algebra',
        'Advanced Math', 'Algebra', 'Geometry & Trig', 'PSDA', 'Advanced Math', 'Algebra', 'Advanced Math', 'Algebra',
        'Geometry & Trig', 'Advanced Math', 'Algebra', 'PSDA', 'Advanced Math', 'Algebra'],
  'MCK-03: full domain order of a module');
select is((select array_agg(slot_no order by slot_no) from private.mock_module_slots(pg_temp.bp(), 'M1')),
  (select array_agg(g) from generate_series(1, 22) g), 'MCK-03: slot_no runs 1..22');
select is((select count(*)::int from (
    select slot_no, difficulty, lag(difficulty) over (order by slot_no) prev
    from private.mock_module_slots(pg_temp.bp(), 'M2E')) x
  where prev is not null and difficulty < prev), 0, 'MCK-03: difficulty never decreases with slot_no');
select results_eq(
  $$ select * from private.mock_module_slots((select value from public.settings where key = 'mock_blueprint_sat'), 'M2H') order by slot_no $$,
  $$ select * from private.mock_module_slots((select value from public.settings where key = 'mock_blueprint_sat'), 'M2H') order by slot_no $$,
  'MCK-03: two calls return identical rows');

-- Per-form cell table (domain x difficulty x type, summed over M1 + M2E + M2H).
select results_eq(
  $$ select domain, difficulty::text, qtype::text, count(*)::int
     from unnest(array['M1', 'M2E', 'M2H']) m,
          lateral private.mock_module_slots((select value from public.settings where key = 'mock_blueprint_sat'), m)
     group by 1, 2, 3 order by domain collate "C", 2, 3 $$,
  $$ values
     ('Advanced Math', 'E', 'mcq', 8), ('Advanced Math', 'H', 'mcq', 6), ('Advanced Math', 'H', 'spr', 1),
     ('Advanced Math', 'M', 'mcq', 7), ('Advanced Math', 'M', 'spr', 2),
     ('Algebra', 'E', 'mcq', 6), ('Algebra', 'E', 'spr', 1), ('Algebra', 'H', 'mcq', 2), ('Algebra', 'H', 'spr', 5),
     ('Algebra', 'M', 'mcq', 7), ('Algebra', 'M', 'spr', 3),
     ('Geometry & Trig', 'E', 'mcq', 3), ('Geometry & Trig', 'H', 'mcq', 2),
     ('Geometry & Trig', 'M', 'mcq', 1), ('Geometry & Trig', 'M', 'spr', 3),
     ('PSDA', 'E', 'spr', 2), ('PSDA', 'H', 'mcq', 3), ('PSDA', 'M', 'mcq', 3), ('PSDA', 'M', 'spr', 1) $$,
  'MCK-03: per-form cell table is pinned');

-- mock_blueprint_ok rejects bad blueprints; mock_module_slots then raises internal.
create function pg_temp.bad(p_kind int) returns jsonb language sql stable as $$
  select case p_kind
    when 1 then jsonb_set(pg_temp.bp(), '{modules,M1,difficulty,H}', '5')
    when 2 then jsonb_set(pg_temp.bp(), '{domains,PSDA}', '0.05')
    when 3 then pg_temp.bp() #- '{modules,M2H}'
    when 4 then jsonb_set(pg_temp.bp(), '{spr_ratio}', '1.5')
    when 5 then jsonb_set(pg_temp.bp(), '{routing,threshold_correct_m1}', '30')
    when 6 then jsonb_set(pg_temp.bp(), '{modules,M1,time_s}', '0')
    when 7 then jsonb_set(pg_temp.bp(), '{domains,PSDA}', '0')
    when 8 then 'null'::jsonb
  end $$;
select is(private.mock_blueprint_ok(pg_temp.bad(1)), false, 'MCK-03: difficulty summing to 21 is rejected');
select is(private.mock_blueprint_ok(pg_temp.bad(2)), false, 'MCK-03: shares summing to 0.9 are rejected');
select is(private.mock_blueprint_ok(pg_temp.bad(3)), false, 'MCK-03: missing M2H is rejected');
select is(private.mock_blueprint_ok(pg_temp.bad(4)), false, 'MCK-03: spr_ratio above 1 is rejected');
select is(private.mock_blueprint_ok(pg_temp.bad(5)), false, 'MCK-03: threshold above M1 count is rejected');
select is(private.mock_blueprint_ok(pg_temp.bad(6)), false, 'MCK-03: time_s 0 is rejected');
select is(private.mock_blueprint_ok(pg_temp.bad(7)), false, 'MCK-03: a zero share is rejected');
select is(private.mock_blueprint_ok(pg_temp.bad(8)), false, 'MCK-03: json null is rejected');
select is(private.mock_blueprint_ok(null), false, 'MCK-03: null blueprint is rejected');
select throws_ok($$ select * from private.mock_module_slots(pg_temp.bad(1), 'M1') $$, 'P0001', 'internal',
  'MCK-03: slots on a 21-question module throw internal');
select throws_ok($$ select * from private.mock_module_slots(pg_temp.bad(2), 'M1') $$, 'P0001', 'internal',
  'MCK-03: slots on bad shares throw internal');
select throws_ok($$ select * from private.mock_module_slots(pg_temp.bad(3), 'M2H') $$, 'P0001', 'internal',
  'MCK-03: slots on a missing module throw internal');
select throws_ok($$ select * from private.mock_module_slots(pg_temp.bp(), 'EST1') $$, 'P0001', 'internal',
  'MCK-03: slots for an unknown module throw internal');

-- mock_template_for.
select is((select count(*)::int from public.mock_templates t join public.courses c on c.id = t.course_id where c.code = 'SAT'),
  0, 'MCK-03: no SAT template before first use');
create temp table t_tpl as
  select private.mock_template_for((select id from public.courses where code = 'SAT')) as id;
select is((select count(*)::int from public.mock_templates t join public.courses c on c.id = t.course_id where c.code = 'SAT'),
  1, 'MCK-03: first call creates one SAT template');
select is((select blueprint from public.mock_templates where id = (select id from t_tpl)), pg_temp.bp(),
  'MCK-03: template blueprint is copied from the setting');
select ok((select adaptive and name = 'SAT Math' from public.mock_templates where id = (select id from t_tpl)),
  'MCK-03: template is adaptive and named SAT Math');
select is(private.mock_template_for((select id from public.courses where code = 'SAT')), (select id from t_tpl),
  'MCK-03: second call returns the same template');
select is((select count(*)::int from public.mock_templates t join public.courses c on c.id = t.course_id where c.code = 'SAT'),
  1, 'MCK-03: second call creates nothing');
select throws_ok($$ select private.mock_template_for(gen_random_uuid()) $$, 'P0001', 'invalid_input',
  'MCK-03: unknown course is invalid_input');
select throws_ok($$ select private.mock_template_for((select id from public.courses where code = 'EST')) $$, 'P0001', 'invalid_input',
  'MCK-03: EST course is invalid_input');
select throws_ok($$ select private.mock_template_for(null) $$, 'P0001', 'invalid_input',
  'MCK-03: null course is invalid_input');
select throws_ok(
  $$ insert into public.mock_templates (course_id, name, adaptive, blueprint)
     values ((select id from public.courses where code = 'SAT'), 'Second', true, '{}') $$,
  '23505', null, 'MCK-03: a second adaptive template for a course is refused');
select lives_ok(
  $$ insert into public.mock_templates (course_id, name, adaptive, blueprint)
     values ((select id from public.courses where code = 'SAT'), 'Fixed', false, '{}') $$,
  'MCK-03: a non-adaptive template for the same course is allowed');

-- Existing insert style (09_rls_catalogue) still works with the new columns.
select lives_ok(
  $$ insert into public.mock_forms (template_id, set_no, form_no, module, question_ids)
     values ((select id from t_tpl), 1, 1, 'M1', '{}') $$,
  'MCK-03: old-style mock_forms insert still works');
select is((select status from public.mock_forms where template_id = (select id from t_tpl)), 'draft',
  'MCK-03: new form defaults to draft');

-- Private helpers are not API executable.
select ok(not has_function_privilege('authenticated', 'private.mock_blueprint_ok(jsonb)', 'execute')
  and not has_function_privilege('authenticated', 'private.mock_module_slots(jsonb,text)', 'execute')
  and not has_function_privilege('authenticated', 'private.mock_template_for(uuid)', 'execute'),
  'MCK-03: helpers are not executable by authenticated');

select * from finish();
rollback;
