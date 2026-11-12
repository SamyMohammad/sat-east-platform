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
-- With an invalid setting and no template yet, the first call refuses instead of copying it.
create temp table t_bp_orig as select value from public.settings where key = 'mock_blueprint_sat';
update public.settings set value = jsonb_set(value, '{modules,M1,count}', '21') where key = 'mock_blueprint_sat';
select throws_ok($$ select private.mock_template_for((select id from public.courses where code = 'SAT')) $$, 'P0001', 'internal',
  'MCK-03: first template creation with an invalid setting is internal');
select is((select count(*)::int from public.mock_templates t join public.courses c on c.id = t.course_id where c.code = 'SAT'), 0,
  'MCK-03: nothing was created from the invalid setting');
update public.settings set value = (select value from t_bp_orig) where key = 'mock_blueprint_sat';
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


-- ================================================================================================
-- Task 2: eligibility, shortage, assemble, overview, read.
-- ================================================================================================
select tests.create_supabase_user('mk_student');
select tests.create_supabase_user('mk_teacher');
update public.profiles set role = 'teacher' where id = tests.get_supabase_uid('mk_teacher');

insert into public.topics (id, course_id, title, slug, sort)
select '50000000-0000-0000-0000-000000000001', id, 'Mock topic', 'mock-topic', 1 from public.courses where code = 'SAT';
insert into public.topics (id, course_id, title, slug, sort)
select '50000000-0000-0000-0000-000000000002', id, 'Other topic', 'mock-other', 1 from public.courses where code = 'EST';
insert into public.subtopics (id, topic_id, title, sort) values
  ('50000000-0000-0000-0000-000000000003', '50000000-0000-0000-0000-000000000001', 'Mock sub', 1),
  ('50000000-0000-0000-0000-000000000004', '50000000-0000-0000-0000-000000000002', 'Other sub', 1);
insert into public.skills (code, name, domain) values
  ('TEST.MK.ALG', 'Mock Algebra', 'Algebra'), ('TEST.MK.ADV', 'Mock Advanced', 'Advanced Math'),
  ('TEST.MK.PSD', 'Mock PSDA', 'PSDA'), ('TEST.MK.GEO', 'Mock Geometry', 'Geometry & Trig'),
  ('TEST.MK.TST', 'Mock Test', 'Test');

-- Bank: three forms' need per cell plus one spare, every question with one skill of its domain.
create temp table t_cell as
  select s.domain, s.difficulty, s.qtype, count(*)::int n
  from unnest(array['M1', 'M2E', 'M2H']) m, lateral private.mock_module_slots(pg_temp.bp(), m) s
  group by 1, 2, 3;
insert into public.questions (topic_id, subtopic_id, type, difficulty, stem_md, pool, status, external_ref)
select '50000000-0000-0000-0000-000000000001', '50000000-0000-0000-0000-000000000003',
       c.qtype, c.difficulty, c.domain, 'mock_reserve', 'published',
       'MK50-' || row_number() over (order by c.domain, c.difficulty, c.qtype, g)
from t_cell c, lateral generate_series(1, c.n * 3 + 1) g;
insert into public.question_skills (question_id, skill_id)
select q.id, s.id from public.questions q join public.skills s on s.domain = q.stem_md
where q.external_ref like 'MK50-%';

-- Questions that must never be picked (all Algebra / E / mcq shaped).
insert into public.questions (topic_id, subtopic_id, type, difficulty, stem_md, pool, status, external_ref) values
  ('50000000-0000-0000-0000-000000000001', '50000000-0000-0000-0000-000000000003', 'mcq', 'E', 'x', 'mock_reserve', 'draft', 'MKX-draft'),
  ('50000000-0000-0000-0000-000000000001', '50000000-0000-0000-0000-000000000003', 'mcq', 'E', 'x', 'mock_reserve', 'retired', 'MKX-retired'),
  ('50000000-0000-0000-0000-000000000001', '50000000-0000-0000-0000-000000000003', 'mcq', 'E', 'x', 'practice', 'published', 'MKX-practice'),
  ('50000000-0000-0000-0000-000000000002', '50000000-0000-0000-0000-000000000004', 'mcq', 'E', 'x', 'mock_reserve', 'published', 'MKX-othercourse'),
  ('50000000-0000-0000-0000-000000000001', '50000000-0000-0000-0000-000000000003', 'mcq', 'E', 'x', 'mock_reserve', 'published', 'MKX-noskill'),
  ('50000000-0000-0000-0000-000000000001', '50000000-0000-0000-0000-000000000003', 'mcq', 'E', 'x', 'mock_reserve', 'published', 'MKX-twodomains'),
  ('50000000-0000-0000-0000-000000000001', '50000000-0000-0000-0000-000000000003', 'mcq', 'E', 'x', 'mock_reserve', 'published', 'MKX-testdomain');
insert into public.question_skills (question_id, skill_id)
select q.id, s.id from public.questions q join public.skills s on s.code = 'TEST.MK.ALG'
where q.external_ref in ('MKX-draft', 'MKX-retired', 'MKX-practice', 'MKX-othercourse');
insert into public.question_skills (question_id, skill_id)
select q.id, s.id from public.questions q join public.skills s on s.code in ('TEST.MK.ALG', 'TEST.MK.ADV')
where q.external_ref = 'MKX-twodomains';
insert into public.question_skills (question_id, skill_id)
select q.id, s.id from public.questions q join public.skills s on s.code = 'TEST.MK.TST'
where q.external_ref = 'MKX-testdomain';

-- Drop the stub form the Task 1 insert test left behind.
delete from public.mock_forms;
create temp table t_res (n int, r jsonb);
grant all on t_res to authenticated;
create temp table t_tpl2 as select private.mock_template_for((select id from public.courses where code = 'SAT')) as id;
create function pg_temp.res(p_n int) returns jsonb language sql stable as $$ select r from t_res where n = p_n $$;

-- Permissions: student forbidden (before argument checks), anon denied, no uid -> not_authenticated.
select tests.authenticate_as('mk_student');
select throws_ok(format('select public.%I(%s)', p.proname,
  (select string_agg('null::' || format_type(a, null), ',') from unnest(p.proargtypes::oid[]) a)),
  'P0001', 'forbidden', 'MCK-03: student denied ' || p.proname)
from pg_proc p join pg_namespace ns on ns.oid = p.pronamespace
where ns.nspname = 'public' and p.proname in ('teacher_assemble_mock_form', 'teacher_mock_overview', 'teacher_get_mock_form');
select tests.clear_authentication();
reset role;
set local role anon;
select throws_ok(format('select public.%I(%s)', p.proname,
  (select string_agg('null::' || format_type(a, null), ',') from unnest(p.proargtypes::oid[]) a)),
  '42501', null, 'MCK-03: anon denied ' || p.proname)
from pg_proc p join pg_namespace ns on ns.oid = p.pronamespace
where ns.nspname = 'public' and p.proname in ('teacher_assemble_mock_form', 'teacher_mock_overview', 'teacher_get_mock_form');
reset role;
set local role authenticated;
select throws_ok(format('select public.%I(%s)', p.proname,
  (select string_agg('null::' || format_type(a, null), ',') from unnest(p.proargtypes::oid[]) a)),
  'P0001', 'not_authenticated', 'MCK-03: uid checked ' || p.proname)
from pg_proc p join pg_namespace ns on ns.oid = p.pronamespace
where ns.nspname = 'public' and p.proname in ('teacher_assemble_mock_form', 'teacher_mock_overview', 'teacher_get_mock_form');
reset role;
select is((select count(*)::int from pg_proc p join pg_namespace ns on ns.oid = p.pronamespace
  where ns.nspname = 'public' and p.proname in ('teacher_assemble_mock_form', 'teacher_mock_overview', 'teacher_get_mock_form')),
  3, 'MCK-03: three public RPC contracts exist');
select ok(not has_function_privilege('authenticated', 'private.mock_eligible(uuid)', 'execute')
  and not has_function_privilege('authenticated', 'private.mock_no_domain_count(uuid)', 'execute')
  and not has_function_privilege('authenticated', 'private.mock_shortage(uuid)', 'execute'),
  'MCK-03: task 2 helpers are not executable by authenticated');

-- Eligibility and no_domain on the untouched bank.
select is((select count(*)::int from private.mock_eligible((select id from t_tpl2))),
  (select sum(n * 3 + 1)::int from t_cell), 'MCK-03: eligible = the stocked bank only');
select is((select count(*)::int from private.mock_eligible((select id from t_tpl2)) e
  join public.questions q on q.id = e.question_id where q.external_ref like 'MKX-%'), 0,
  'MCK-03: draft, retired, practice, other-course, no-skill, two-domain, Test-domain are not eligible');
select is(private.mock_no_domain_count((select id from t_tpl2)), 3, 'MCK-03: no-skill, two-domain and Test-domain count as no_domain');
select is(private.mock_shortage((select id from t_tpl2)), '[]'::jsonb, 'MCK-03: no shortage on the stocked bank');

-- Assemble as teacher: set 1, set 2, set 1 again.
select tests.authenticate_as('mk_teacher');
insert into t_res select 1, public.teacher_assemble_mock_form((select id from public.courses where code = 'SAT'), 1);
insert into t_res select 2, public.teacher_assemble_mock_form((select id from public.courses where code = 'SAT'), 2);
insert into t_res select 3, public.teacher_assemble_mock_form((select id from public.courses where code = 'SAT'), 1);
select tests.clear_authentication();
reset role;

select is(pg_temp.res(1), '{"ok": true, "set_no": 1, "form_no": 1}'::jsonb, 'MCK-03: first assemble returns ok, form 1');
select is(pg_temp.res(2), '{"ok": true, "set_no": 2, "form_no": 1}'::jsonb, 'MCK-03: another set starts again at form 1');
select is(pg_temp.res(3), '{"ok": true, "set_no": 1, "form_no": 2}'::jsonb, 'MCK-03: second assemble in a set is form 2');
select is((select count(*)::int from public.mock_forms where template_id = (select id from t_tpl2)), 9, 'MCK-03: three forms = nine module rows');
select is((select count(*)::int from public.mock_forms where template_id = (select id from t_tpl2) and status = 'draft'
  and published_at is null and cardinality(question_ids) = 22), 9, 'MCK-03: all rows are drafts of 22 ids');
select is((select count(distinct u)::int from public.mock_forms f, unnest(f.question_ids) u
  where f.template_id = (select id from t_tpl2) and f.set_no = 1 and f.form_no = 1), 66, 'MCK-03: form 1 has 66 distinct questions');
select is((select count(*)::int from public.mock_forms f, unnest(f.question_ids) u
  where f.template_id = (select id from t_tpl2)), 198, 'MCK-03: 198 slots over three forms');
select is((select count(distinct u)::int from public.mock_forms f, unnest(f.question_ids) u
  where f.template_id = (select id from t_tpl2)), 198, 'MCK-03: no question is shared between forms or sets');
select is((select string_agg(module || ':' || e, ' ' order by module) from (
    select f.module, string_agg(c::text, '/' order by ord) e from public.mock_forms f
    cross join lateral (select case q.difficulty when 'E' then 1 when 'M' then 2 else 3 end ord, count(*) c
      from unnest(f.question_ids) u join public.questions q on q.id = u
      group by 1) d
    where f.template_id = (select id from t_tpl2) and f.set_no = 1 and f.form_no = 1 group by f.module) x),
  'M1:7/9/6 M2E:10/9/3 M2H:3/9/10', 'MCK-03: per-module E/M/H counts');
select is((select count(*)::int from public.mock_forms f
  cross join lateral unnest(f.question_ids) with ordinality u(qid, slot)
  join public.questions q on q.id = u.qid
  join private.mock_module_slots((select blueprint from public.mock_templates where id = f.template_id), f.module) s on s.slot_no = u.slot
  where f.template_id = (select id from t_tpl2)
    and not (q.type = s.qtype and q.difficulty = s.difficulty and q.stem_md = s.domain)), 0,
  'MCK-03: the question in every slot matches that slot cell');
select is((select count(*)::int from public.mock_forms f, unnest(f.question_ids) u join public.questions q on q.id = u
  where f.template_id = (select id from t_tpl2) and not (q.pool = 'mock_reserve' and q.status = 'published')), 0,
  'MCK-03: every picked question is published mock_reserve');
select is((select count(*)::int from public.mock_forms f, unnest(f.question_ids) u join public.questions q on q.id = u
  where f.template_id = (select id from t_tpl2) and q.external_ref like 'MKX-%'), 0, 'MCK-03: no excluded question was picked');

-- Overview and read.
select tests.authenticate_as('mk_teacher');
insert into t_res select 10, public.teacher_mock_overview((select id from public.courses where code = 'SAT'));
insert into t_res select 11, public.teacher_get_mock_form((select id from public.courses where code = 'SAT'), 1, 2);
select tests.clear_authentication();
reset role;
select is(pg_temp.res(10) #>> '{template,id}', (select id::text from t_tpl2), 'MCK-03: overview names the template');
select is(pg_temp.res(10) #> '{template,blueprint}', pg_temp.bp(), 'MCK-03: overview carries the blueprint');
select is(jsonb_array_length(pg_temp.res(10) -> 'forms'), 3, 'MCK-03: overview lists three forms');
select is((select string_agg((f ->> 'set_no') || '.' || (f ->> 'form_no') || ':' || (f ->> 'status'), ' ')
  from jsonb_array_elements(pg_temp.res(10) -> 'forms') f), '1.1:draft 1.2:draft 2.1:draft', 'MCK-03: overview forms ordered by set, form');
select is(pg_temp.res(10) #> '{next_form,missing}', private.mock_shortage((select id from t_tpl2)), 'MCK-03: overview next_form.missing = mock_shortage');
select is((pg_temp.res(10) #>> '{next_form,no_domain}')::int, 3, 'MCK-03: overview reports no_domain');
select is((select count(*)::int from jsonb_array_elements(pg_temp.res(10) -> 'need_per_form')), 19, 'MCK-03: need_per_form has 19 cells');
select is((select sum((e ->> 'count')::int)::int from jsonb_array_elements(pg_temp.res(10) -> 'need_per_form') e), 66, 'MCK-03: need_per_form sums to 66');
select is((select jsonb_agg(jsonb_build_array(e ->> 'domain', e ->> 'difficulty', e ->> 'type', (e ->> 'count')::int))
  from jsonb_array_elements(pg_temp.res(10) -> 'need_per_form') e),
  (select jsonb_agg(jsonb_build_array(domain, difficulty::text, qtype::text, n) order by domain collate "C", difficulty, qtype) from t_cell),
  'MCK-03: need_per_form equals the slot cell table, ordered');

select is(jsonb_array_length(pg_temp.res(11) -> 'modules'), 3, 'MCK-03: form read returns three modules');
select is((select string_agg(m ->> 'module', ',') from jsonb_array_elements(pg_temp.res(11) -> 'modules') m), 'M1,M2E,M2H', 'MCK-03: modules in order');
select is((select count(*)::int from jsonb_array_elements(pg_temp.res(11) -> 'modules') m, jsonb_array_elements(m -> 'questions') q), 66, 'MCK-03: form read returns 66 questions');
select is((select string_agg(q ->> 'slot_no', ',' order by ord) from jsonb_array_elements(pg_temp.res(11) -> 'modules') m,
  jsonb_array_elements(m -> 'questions') with ordinality x(q, ord) where m ->> 'module' = 'M1'),
  (select string_agg(g::text, ',' order by g) from generate_series(1, 22) g), 'MCK-03: questions come in slot order');
select is((select array_agg((q ->> 'id')::uuid order by (m ->> 'module'), (q ->> 'slot_no')::int)
  from jsonb_array_elements(pg_temp.res(11) -> 'modules') m, jsonb_array_elements(m -> 'questions') q),
  (select array_agg(u order by f.module, o) from public.mock_forms f, unnest(f.question_ids) with ordinality x(u, o)
   where f.template_id = (select id from t_tpl2) and f.set_no = 1 and f.form_no = 2),
  'MCK-03: form read returns the stored ids');
select is((select count(*)::int from jsonb_array_elements(pg_temp.res(11) -> 'modules') m, jsonb_array_elements(m -> 'questions') q
  join public.questions qq on qq.id = (q ->> 'id')::uuid
  where q ->> 'domain' = qq.stem_md and q ->> 'type' = qq.type::text and q ->> 'difficulty' = qq.difficulty::text
    and q ->> 'external_ref' = qq.external_ref and q ->> 'stem_md' = qq.stem_md), 66, 'MCK-03: form read shows resolved domain, type, difficulty, ref, stem');
select ok(pg_temp.res(11)::text !~ 'correct_answer|explanation|choices', 'MCK-03: form read leaks no key, explanation or choices');

-- Errors.
select tests.authenticate_as('mk_teacher');
select throws_ok($$ select public.teacher_get_mock_form((select id from public.courses where code = 'SAT'), 1, 99) $$, 'P0001', 'invalid_input', 'MCK-03: unknown form is invalid_input');
select throws_ok($$ select public.teacher_get_mock_form(null, 1, 1) $$, 'P0001', 'invalid_input', 'MCK-03: read with null course is invalid_input');
select throws_ok($$ select public.teacher_assemble_mock_form((select id from public.courses where code = 'SAT'), 0) $$, 'P0001', 'invalid_input', 'MCK-03: set_no 0 is invalid_input');
select throws_ok($$ select public.teacher_assemble_mock_form((select id from public.courses where code = 'SAT'), null) $$, 'P0001', 'invalid_input', 'MCK-03: null set_no is invalid_input');
select throws_ok($$ select public.teacher_assemble_mock_form(null, 1) $$, 'P0001', 'invalid_input', 'MCK-03: null course is invalid_input');
select throws_ok($$ select public.teacher_assemble_mock_form((select id from public.courses where code = 'EST'), 1) $$, 'P0001', 'invalid_input', 'MCK-03: non-SAT course is invalid_input');
select throws_ok($$ select public.teacher_mock_overview((select id from public.courses where code = 'EST')) $$, 'P0001', 'invalid_input', 'MCK-03: overview of a non-SAT course is invalid_input');
select tests.clear_authentication();
reset role;
select is((select count(*)::int from public.mock_forms where template_id = (select id from t_tpl2)), 9, 'MCK-03: rejected calls wrote nothing');

-- Shortage: free set 2 (spare = 1 per cell again), then retire two Algebra/H/spr questions.
delete from public.mock_forms where template_id = (select id from t_tpl2) and set_no = 2;
update public.questions set status = 'retired' where id in (
  select e.question_id from private.mock_eligible((select id from t_tpl2)) e
  where e.domain = 'Algebra' and e.difficulty = 'H' and e.qtype = 'spr' limit 2);
select is(private.mock_shortage((select id from t_tpl2)),
  '[{"domain": "Algebra", "difficulty": "H", "type": "spr", "needed": 5, "available": 4, "modules": {"M1": 2, "M2E": 1, "M2H": 2}}]'::jsonb,
  'MCK-03: shortage names exactly the short cell');
select tests.authenticate_as('mk_teacher');
insert into t_res select 20, public.teacher_assemble_mock_form((select id from public.courses where code = 'SAT'), 3);
select tests.clear_authentication();
reset role;
select is(pg_temp.res(20) -> 'ok', 'false'::jsonb, 'MCK-03: shortage returns ok false');
select is(pg_temp.res(20) -> 'missing', private.mock_shortage((select id from t_tpl2)), 'MCK-03: assemble returns the shortage report');
select is((pg_temp.res(20) ->> 'no_domain')::int, 3, 'MCK-03: assemble returns no_domain');
select is((select count(*)::int from public.mock_forms where template_id = (select id from t_tpl2)), 6, 'MCK-03: shortage inserted nothing');


-- ================================================================================================
-- Task 3: swap candidates, swap, delete draft, publish.
-- ================================================================================================
-- Back to a clean bank: un-retire the two questions the shortage test retired. State: set 1 has
-- drafts form 1 and form 2; every cell has need + 1 eligible questions.
update public.questions set status = 'published' where external_ref like 'MK50-%' and status = 'retired';
select is(private.mock_shortage((select id from t_tpl2)), '[]'::jsonb, 'MCK-03: bank restored for task 3 tests');

create function pg_temp.slot_id(p_set int, p_form int, p_module text, p_slot int) returns uuid language sql stable security definer as $$
  select f.question_ids[p_slot] from public.mock_forms f
  where f.template_id = (select id from t_tpl2) and f.set_no = p_set and f.form_no = p_form and f.module = p_module $$;
grant execute on function pg_temp.slot_id(int, int, text, int) to authenticated;
create function pg_temp.cell_ids(p_domain text, p_diff public.difficulty, p_type public.question_type) returns uuid[]
language sql stable as $$
  select array_agg(e.question_id order by q.external_ref) from private.mock_eligible((select id from t_tpl2)) e
  join public.questions q on q.id = e.question_id
  where e.domain = p_domain and e.difficulty = p_diff and e.qtype = p_type $$;
create function pg_temp.cand_ids(p_json jsonb) returns uuid[] language sql stable as $$
  select array_agg((e ->> 'id')::uuid order by ord) from jsonb_array_elements(p_json) with ordinality x(e, ord) $$;

grant execute on function pg_temp.cand_ids(jsonb), pg_temp.res(int) to authenticated;
create temp table t_snap as
  select f.module, u.o as slot, u.q as qid
  from public.mock_forms f, unnest(f.question_ids) with ordinality u(q, o)
  where f.template_id = (select id from t_tpl2) and f.set_no = 1 and f.form_no = 1;
create temp table t_old as select pg_temp.slot_id(1, 1, 'M1', 1) as id;      -- Advanced Math / E / mcq slot
create temp table t_old2 as select pg_temp.slot_id(1, 1, 'M1', 2) as id;     -- Algebra / E / mcq slot
-- Pre-picked candidates (chosen as postgres).
grant select on t_snap, t_old, t_old2, t_tpl2 to authenticated;
create temp table t_pick as select
  (pg_temp.cell_ids('Advanced Math', 'E', 'mcq'))[1] as same_cell,
  (pg_temp.cell_ids('Algebra', 'E', 'mcq'))[1] as other_cell,
  pg_temp.slot_id(1, 2, 'M1', 2) as in_other_form,
  pg_temp.slot_id(1, 1, 'M1', 6) as in_this_form,
  (select id from public.questions where external_ref = 'MKX-retired') as not_eligible;

grant select on t_pick to authenticated;

-- Permissions for the four new RPCs.
select tests.authenticate_as('mk_student');
select throws_ok(format('select public.%I(%s)', p.proname,
  (select string_agg('null::' || format_type(a, null), ',') from unnest(p.proargtypes::oid[]) a)),
  'P0001', 'forbidden', 'MCK-03: student denied ' || p.proname)
from pg_proc p join pg_namespace ns on ns.oid = p.pronamespace
where ns.nspname = 'public' and p.proname in ('teacher_mock_swap_candidates', 'teacher_swap_mock_question', 'teacher_delete_mock_draft', 'teacher_publish_mock_form');
select tests.clear_authentication();
reset role;
set local role anon;
select throws_ok(format('select public.%I(%s)', p.proname,
  (select string_agg('null::' || format_type(a, null), ',') from unnest(p.proargtypes::oid[]) a)),
  '42501', null, 'MCK-03: anon denied ' || p.proname)
from pg_proc p join pg_namespace ns on ns.oid = p.pronamespace
where ns.nspname = 'public' and p.proname in ('teacher_mock_swap_candidates', 'teacher_swap_mock_question', 'teacher_delete_mock_draft', 'teacher_publish_mock_form');
reset role;
set local role authenticated;
select throws_ok(format('select public.%I(%s)', p.proname,
  (select string_agg('null::' || format_type(a, null), ',') from unnest(p.proargtypes::oid[]) a)),
  'P0001', 'not_authenticated', 'MCK-03: uid checked ' || p.proname)
from pg_proc p join pg_namespace ns on ns.oid = p.pronamespace
where ns.nspname = 'public' and p.proname in ('teacher_mock_swap_candidates', 'teacher_swap_mock_question', 'teacher_delete_mock_draft', 'teacher_publish_mock_form');
reset role;
select is((select count(*)::int from pg_proc p join pg_namespace ns on ns.oid = p.pronamespace
  where ns.nspname = 'public' and p.proname in ('teacher_mock_swap_candidates', 'teacher_swap_mock_question', 'teacher_delete_mock_draft', 'teacher_publish_mock_form')),
  4, 'MCK-03: four more public RPC contracts exist');

-- Candidates: exactly the eligible questions of the slot's cell, ordered by external_ref.
select tests.authenticate_as('mk_teacher');
insert into t_res select 30, public.teacher_mock_swap_candidates((select id from public.courses where code = 'SAT'), 1, 1, (select id from t_old));
select tests.clear_authentication();
reset role;
select is(pg_temp.cand_ids(pg_temp.res(30)), pg_temp.cell_ids('Advanced Math', 'E', 'mcq'), 'MCK-03: candidates = eligible of the slot cell, ordered');
select is(jsonb_array_length(pg_temp.res(30)), 9, 'MCK-03: candidates = need 8 + 1 spare');
select is((select count(*)::int from jsonb_array_elements(pg_temp.res(30)) e
  where (e ->> 'id')::uuid in (select u from public.mock_forms f, unnest(f.question_ids) u where f.template_id = (select id from t_tpl2))), 0,
  'MCK-03: candidates exclude every question used in any form');
select ok(pg_temp.res(30) -> 0 ?& array['id', 'external_ref', 'stem_md'] and pg_temp.res(30)::text !~ 'correct_answer|explanation|choices',
  'MCK-03: candidate rows carry id, external_ref, stem_md only');

-- The cell comes from the slot, not from the old question's current attributes.
update public.questions set difficulty = 'M' where id = (select id from t_old2);
select tests.authenticate_as('mk_teacher');
insert into t_res select 31, public.teacher_mock_swap_candidates((select id from public.courses where code = 'SAT'), 1, 1, (select id from t_old2));
select tests.clear_authentication();
reset role;
select is(pg_temp.cand_ids(pg_temp.res(31)), pg_temp.cell_ids('Algebra', 'E', 'mcq'), 'MCK-03: candidates follow the slot cell after the old question was edited');
update public.questions set difficulty = 'E' where id = (select id from t_old2);

-- Swap.
select tests.authenticate_as('mk_teacher');
insert into t_res select 32, public.teacher_swap_mock_question((select id from public.courses where code = 'SAT'), 1, 1, (select id from t_old), (select same_cell from t_pick));
select tests.clear_authentication();
reset role;
select is(pg_temp.res(32), '{"ok": true}'::jsonb, 'MCK-03: swap returns ok');
select is(pg_temp.slot_id(1, 1, 'M1', 1), (select same_cell from t_pick), 'MCK-03: the new question sits in the same slot');
select is((select count(*)::int from public.mock_forms f cross join lateral unnest(f.question_ids) with ordinality u(q, o)
  join t_snap s on s.module = f.module and s.slot = u.o and s.qid = u.q
  where f.template_id = (select id from t_tpl2) and f.set_no = 1 and f.form_no = 1), 65, 'MCK-03: the other 65 questions are unchanged');
select ok((select id from t_old) in (select question_id from private.mock_eligible((select id from t_tpl2))), 'MCK-03: the swapped-out question is eligible again');
select ok((select same_cell from t_pick) not in (select question_id from private.mock_eligible((select id from t_tpl2))), 'MCK-03: the swapped-in question is no longer eligible');

-- Swap and candidate rejections.
select tests.authenticate_as('mk_teacher');
select throws_ok($$ select public.teacher_swap_mock_question((select id from public.courses where code = 'SAT'), 1, 1, pg_temp.slot_id(1, 1, 'M1', 1), (select other_cell from t_pick)) $$,
  'P0001', 'invalid_input', 'MCK-03: swap with a candidate from another cell is invalid_input');
select throws_ok($$ select public.teacher_swap_mock_question((select id from public.courses where code = 'SAT'), 1, 1, pg_temp.slot_id(1, 1, 'M1', 2), (select in_other_form from t_pick)) $$,
  'P0001', 'invalid_input', 'MCK-03: swap with a question used in another form is invalid_input');
select throws_ok($$ select public.teacher_swap_mock_question((select id from public.courses where code = 'SAT'), 1, 1, pg_temp.slot_id(1, 1, 'M1', 2), (select in_this_form from t_pick)) $$,
  'P0001', 'invalid_input', 'MCK-03: swap with a question already in this form is invalid_input');
select throws_ok($$ select public.teacher_swap_mock_question((select id from public.courses where code = 'SAT'), 1, 1, pg_temp.slot_id(1, 1, 'M1', 2), (select not_eligible from t_pick)) $$,
  'P0001', 'invalid_input', 'MCK-03: swap with an ineligible question is invalid_input');
select throws_ok($$ select public.teacher_swap_mock_question((select id from public.courses where code = 'SAT'), 1, 1, (select in_other_form from t_pick), (select other_cell from t_pick)) $$,
  'P0001', 'invalid_input', 'MCK-03: swap of a question not in the form is invalid_input');
select throws_ok($$ select public.teacher_swap_mock_question((select id from public.courses where code = 'SAT'), 1, 1, null, (select other_cell from t_pick)) $$,
  'P0001', 'invalid_input', 'MCK-03: swap with a null old id is invalid_input');
select throws_ok($$ select public.teacher_swap_mock_question((select id from public.courses where code = 'SAT'), 1, 1, pg_temp.slot_id(1, 1, 'M1', 2), null) $$,
  'P0001', 'invalid_input', 'MCK-03: swap with a null new id is invalid_input');
select throws_ok($$ select public.teacher_swap_mock_question((select id from public.courses where code = 'SAT'), 1, 99, pg_temp.slot_id(1, 1, 'M1', 2), (select other_cell from t_pick)) $$,
  'P0001', 'invalid_input', 'MCK-03: swap in an unknown form is invalid_input');
select throws_ok($$ select public.teacher_mock_swap_candidates((select id from public.courses where code = 'SAT'), 1, 1, (select in_other_form from t_pick)) $$,
  'P0001', 'invalid_input', 'MCK-03: candidates for a question not in the form is invalid_input');
select throws_ok($$ select public.teacher_mock_swap_candidates((select id from public.courses where code = 'SAT'), 1, 1, null) $$,
  'P0001', 'invalid_input', 'MCK-03: candidates with a null id is invalid_input');
select throws_ok($$ select public.teacher_delete_mock_draft((select id from public.courses where code = 'SAT'), 1, 99) $$,
  'P0001', 'invalid_input', 'MCK-03: delete of an unknown form is invalid_input');
select throws_ok($$ select public.teacher_delete_mock_draft(null, 1, 1) $$, 'P0001', 'invalid_input', 'MCK-03: delete with a null course is invalid_input');
select throws_ok($$ select public.teacher_publish_mock_form((select id from public.courses where code = 'SAT'), 1, 99) $$,
  'P0001', 'invalid_input', 'MCK-03: publish of an unknown form is invalid_input');
select throws_ok($$ select public.teacher_publish_mock_form((select id from public.courses where code = 'SAT'), null, 1) $$,
  'P0001', 'invalid_input', 'MCK-03: publish with a null set is invalid_input');
select throws_ok($$ select public.teacher_publish_mock_form((select id from public.courses where code = 'EST'), 1, 1) $$,
  'P0001', 'invalid_input', 'MCK-03: publish for a non-SAT course is invalid_input');
select tests.clear_authentication();
reset role;
select is((select count(*)::int from public.mock_forms f cross join lateral unnest(f.question_ids) with ordinality u(q, o)
  join t_snap s on s.module = f.module and s.slot = u.o and s.qid = u.q
  where f.template_id = (select id from t_tpl2) and f.set_no = 1 and f.form_no = 1), 65, 'MCK-03: rejected swaps changed nothing');

-- Stale publish: retire one question of form 2, publish must report it and change nothing.
create temp table t_stale as select pg_temp.slot_id(1, 2, 'M2H', 5) as id;
grant select on t_stale to authenticated;
update public.questions set status = 'retired' where id = (select id from t_stale);
select tests.authenticate_as('mk_teacher');
insert into t_res select 40, public.teacher_publish_mock_form((select id from public.courses where code = 'SAT'), 1, 2);
select tests.clear_authentication();
reset role;
select is(pg_temp.res(40), jsonb_build_object('ok', false, 'stale', jsonb_build_array((select id from t_stale))), 'MCK-03: stale publish lists the retired question');
select is((select count(*)::int from public.mock_forms where template_id = (select id from t_tpl2) and set_no = 1 and form_no = 2
  and status = 'draft' and published_at is null), 3, 'MCK-03: stale publish leaves the form a draft');

-- A question edited out of its slot cell is stale too (difficulty changed).
create temp table t_stale2 as select pg_temp.slot_id(1, 2, 'M1', 1) as id;
grant select on t_stale2 to authenticated;
update public.questions set difficulty = 'H' where id = (select id from t_stale2);
select tests.authenticate_as('mk_teacher');
insert into t_res select 41, public.teacher_publish_mock_form((select id from public.courses where code = 'SAT'), 1, 2);
select tests.clear_authentication();
reset role;
select is(pg_temp.res(41) -> 'stale', jsonb_build_array((select id from t_stale2), (select id from t_stale)),
  'MCK-03: stale ids list a cell mismatch too, ordered by module then slot');
update public.questions set difficulty = 'E' where id = (select id from t_stale2);

-- Swap the retired one out (its candidates come from the slot cell), then publish.
select tests.authenticate_as('mk_teacher');
insert into t_res select 42, public.teacher_mock_swap_candidates((select id from public.courses where code = 'SAT'), 1, 2, (select id from t_stale));
select tests.clear_authentication();
reset role;
select ok(jsonb_array_length(pg_temp.res(42)) > 0, 'MCK-03: a retired question still has candidates from its slot cell');
select tests.authenticate_as('mk_teacher');
insert into t_res select 43, public.teacher_swap_mock_question((select id from public.courses where code = 'SAT'), 1, 2, (select id from t_stale), (pg_temp.cand_ids(pg_temp.res(42)))[1]);
insert into t_res select 44, public.teacher_publish_mock_form((select id from public.courses where code = 'SAT'), 1, 2);
select tests.clear_authentication();
reset role;
select is(pg_temp.res(43), '{"ok": true}'::jsonb, 'MCK-03: a retired question can be swapped out');
select is(pg_temp.res(44), '{"ok": true}'::jsonb, 'MCK-03: publish succeeds once nothing is stale');
select is((select count(*)::int from public.mock_forms where template_id = (select id from t_tpl2) and set_no = 1 and form_no = 2
  and status = 'published' and published_at is not null), 3, 'MCK-03: three rows are published');
select is((select count(distinct published_at)::int from public.mock_forms where template_id = (select id from t_tpl2) and set_no = 1 and form_no = 2), 1,
  'MCK-03: one identical published_at');
select is((select count(*)::int from public.mock_forms where template_id = (select id from t_tpl2) and set_no = 1 and form_no = 1 and status = 'draft'), 3,
  'MCK-03: the other form stays a draft');

-- Published forms are frozen.
select tests.authenticate_as('mk_teacher');
select throws_ok($$ select public.teacher_swap_mock_question((select id from public.courses where code = 'SAT'), 1, 2, pg_temp.slot_id(1, 2, 'M1', 1), (select other_cell from t_pick)) $$,
  'P0001', 'mock_form_published', 'MCK-03: swap on a published form is refused');
select throws_ok($$ select public.teacher_delete_mock_draft((select id from public.courses where code = 'SAT'), 1, 2) $$,
  'P0001', 'mock_form_published', 'MCK-03: delete of a published form is refused');
select throws_ok($$ select public.teacher_publish_mock_form((select id from public.courses where code = 'SAT'), 1, 2) $$,
  'P0001', 'mock_form_published', 'MCK-03: publishing twice is refused');
select tests.clear_authentication();
reset role;
select is((select count(*)::int from private.mock_eligible((select id from t_tpl2)) e
  where e.question_id in (select u from public.mock_forms f, unnest(f.question_ids) u where f.set_no = 1 and f.form_no = 2)), 0,
  'MCK-03: published questions stay ineligible');

-- Delete a draft: rows gone, questions free, form_no reuse only when it was the highest.
select tests.authenticate_as('mk_teacher');
insert into t_res select 50, public.teacher_delete_mock_draft((select id from public.courses where code = 'SAT'), 1, 1);
select tests.clear_authentication();
reset role;
select is(pg_temp.res(50), '{"ok": true}'::jsonb, 'MCK-03: delete returns ok');
select is((select count(*)::int from public.mock_forms where template_id = (select id from t_tpl2) and set_no = 1 and form_no = 1), 0, 'MCK-03: the three rows are gone');
select ok((select bool_and(s.qid in (select question_id from private.mock_eligible((select id from t_tpl2)))) from t_snap s where s.qid <> (select id from t_old)),
  'MCK-03: the deleted form questions are eligible again');
select tests.authenticate_as('mk_teacher');
insert into t_res select 51, public.teacher_assemble_mock_form((select id from public.courses where code = 'SAT'), 1);
insert into t_res select 52, public.teacher_delete_mock_draft((select id from public.courses where code = 'SAT'), 1, 3);
insert into t_res select 53, public.teacher_assemble_mock_form((select id from public.courses where code = 'SAT'), 1);
select tests.clear_authentication();
reset role;
select is(pg_temp.res(51), '{"ok": true, "set_no": 1, "form_no": 3}'::jsonb, 'MCK-03: next form_no is max + 1 (form 1 was deleted, form 2 exists)');
select is(pg_temp.res(53), '{"ok": true, "set_no": 1, "form_no": 3}'::jsonb, 'MCK-03: the highest form_no is reused after its draft is deleted');

-- Invalid stored blueprint: assemble, publish and overview refuse with internal and write nothing.
create temp table t_before as select count(*)::int n from public.mock_forms;
create temp table t_bp_good as select blueprint from public.mock_templates where id = (select id from t_tpl2);
grant select on t_before, t_bp_good to authenticated;
update public.mock_templates set blueprint = jsonb_set(blueprint, '{modules,M1,count}', '21') where id = (select id from t_tpl2);
select tests.authenticate_as('mk_teacher');
select throws_ok($$ select public.teacher_assemble_mock_form((select id from public.courses where code = 'SAT'), 7) $$, 'P0001', 'internal',
  'MCK-03: assemble with an invalid template blueprint is internal');
select throws_ok($$ select public.teacher_publish_mock_form((select id from public.courses where code = 'SAT'), 1, 3) $$, 'P0001', 'internal',
  'MCK-03: publish with an invalid template blueprint is internal');
select throws_ok($$ select public.teacher_mock_overview((select id from public.courses where code = 'SAT')) $$, 'P0001', 'internal',
  'MCK-03: overview with an invalid template blueprint is internal');
select tests.clear_authentication();
reset role;
select is((select count(*)::int from public.mock_forms), (select n from t_before), 'MCK-03: the invalid blueprint calls wrote nothing');
select is((select count(*)::int from public.mock_forms where status = 'published' and set_no = 1 and form_no = 3), 0, 'MCK-03: the draft stayed a draft');
update public.mock_templates set blueprint = (select blueprint from t_bp_good) where id = (select id from t_tpl2);

select * from finish();
rollback;
