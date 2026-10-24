-- C-4 / QB-05 / QB-06. From supabase/templates/test.sql.
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

select tests.create_supabase_user('dollar_teacher');
update public.profiles set role = 'teacher'
where id = tests.get_supabase_uid('dollar_teacher');
insert into public.courses(code, title, slug)
values ('SAT', 'Dollar SAT', 'dollar-sat') on conflict(code) do nothing;
insert into public.topics(id, course_id, title, slug)
select '36000000-0000-0000-0000-000000000001', id, 'Dollar topic', 'dollar-topic'
from public.courses where code = 'SAT';
insert into public.subtopics(id, topic_id, title) values
('36000000-0000-0000-0000-000000000002',
 '36000000-0000-0000-0000-000000000001', 'Dollar subtopic');
create function pg_temp.dollar_row() returns jsonb language sql as $$
select '{"external_ref":"QB36_DOLLAR","course_codes":["SAT"],"topic_slug":"dollar-topic","subtopic_slug":"dollar-subtopic","type":"mcq","difficulty":"M","stem_md":"Find x.","choices":[{"label":"A","body_md":"1"},{"label":"B","body_md":"2"}],"key":{"choice":"B"},"pool":"practice","status":"draft","hint_md":"Think.","explanation_md":"Two."}'::jsonb;
$$;
grant execute on function pg_temp.dollar_row() to authenticated;

create temp table dollar_bad(field text, patch jsonb);
insert into dollar_bad values
('stem_md', jsonb_build_object('stem_md', '$x^2$')),
('choices', jsonb_build_object('choices', jsonb_build_array(
 jsonb_build_object('label', 'A', 'body_md', '$\frac{1}{2}$'),
 jsonb_build_object('label', 'B', 'body_md', '2')))),
('hint_md', jsonb_build_object('hint_md', '$a_1$')),
('explanation_md', jsonb_build_object('explanation_md', '${x}$'));
grant select on dollar_bad to authenticated;

select is((select jsonb_agg(problem) from private.validate_question_row(
 pg_temp.dollar_row() || b.patch, 1) problem),
 jsonb_build_array(jsonb_build_object('row', 1, 'external_ref', 'QB36_DOLLAR',
 'field', b.field, 'problem', 'latex_dollar:' || b.field)),
 'QB-05: dollar LaTeX rejected in ' || b.field)
from dollar_bad b;
-- Each choice is inspected, including choices after the first one.
select is((select count(*)::int from private.validate_question_row(
 jsonb_set(jsonb_set(pg_temp.dollar_row(), '{choices,0,body_md}', to_jsonb('$x^2$'::text)),
 '{choices,1,body_md}', to_jsonb('$a_1$'::text)), 1) problem
 where problem ->> 'problem' = 'latex_dollar:choices'), 2,
 'QB-05: every choice body is checked');

select is((select count(*)::int from private.validate_question_row(
 jsonb_set(pg_temp.dollar_row(), '{stem_md}', to_jsonb(sample)), 1)), 0,
 'QB-05: permitted text ' || sample)
from unnest(array['$3 each and $5 each', 'costs $12', '\(x^2\)',
 '$x^2', '$x$', '\[x^2\]']) sample;
select ok(private.has_dollar_latex('$\alpha$'), 'QB-05: backslash alone is a LaTeX signal');
select ok(private.has_dollar_latex('${x$'), 'QB-05: opening brace is a LaTeX signal');
select ok(private.has_dollar_latex('$x}$'), 'QB-05: closing brace is a LaTeX signal');
select is(private.has_dollar_latex(null), false, 'QB-05: absent optional text is harmless');
select ok(not has_function_privilege(role_name, 'private.has_dollar_latex(text)', 'execute'),
 'QB-05: dollar helper is internal for ' || role_name)
from unnest(array['anon', 'authenticated', 'service_role']) role_name;
select ok(not exists(select 1 from pg_catalog.pg_proc p
 cross join lateral pg_catalog.aclexplode(coalesce(p.proacl,
 pg_catalog.acldefault('f', p.proowner))) acl
 where p.oid = 'private.has_dollar_latex(text)'::regprocedure and acl.grantee = 0
 and acl.privilege_type = 'EXECUTE'), 'QB-05: PUBLIC cannot execute the helper');

select tests.authenticate_as('dollar_teacher');
select is(public.teacher_import_questions(jsonb_build_array(pg_temp.dollar_row() || b.patch), false)
 -> 'errors', jsonb_build_array(jsonb_build_object('row', 1, 'external_ref', 'QB36_DOLLAR',
 'field', b.field, 'problem', 'latex_dollar:' || b.field)),
 'QB-05: import reports dollar LaTeX in ' || b.field)
from dollar_bad b;
select is(public.teacher_save_question(null,
 pg_temp.dollar_row() || '{"stem_md":"$x^2$"}'::jsonb, null),
 '{"ok":false,"errors":[{"row":1,"external_ref":"QB36_DOLLAR","field":"stem_md","problem":"latex_dollar:stem_md"}]}'::jsonb,
 'QB-06: editor reuses dollar LaTeX validation');
select tests.clear_authentication();
reset role;
select is((select count(*)::int from public.questions where external_ref = 'QB36_DOLLAR'), 0,
 'QB-06: rejected create writes no question');
select is((select count(*)::int from public.audit_log where actor = tests.get_supabase_uid('dollar_teacher')), 0,
 'QB-05: dry run and rejected save write no audit');

select * from finish();
rollback;
