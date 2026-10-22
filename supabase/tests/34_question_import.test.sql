-- C-4 / QB-05. From supabase/templates/test.sql.
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();
select tests.create_supabase_user('import_student');
select tests.create_supabase_user('import_teacher');
update public.profiles set role='teacher' where id=tests.get_supabase_uid('import_teacher');
insert into public.courses(code,title,slug) values ('SAT','Import SAT','import-sat'),('EST','Import EST','import-est') on conflict(code) do nothing;
insert into public.topics (id,course_id,title,slug)
select '34000000-0000-0000-0000-000000000001',id,'Import topic','test-import' from public.courses where code='SAT';
insert into public.subtopics (id,topic_id,title) values
('34000000-0000-0000-0000-000000000002','34000000-0000-0000-0000-000000000001','Import subtopic');
insert into public.skills (code,name,domain) values ('TEST.IMP.ONE','Import one','Test'),('TEST.IMP.TWO','Import two','Test');
create function pg_temp.import_mcq() returns jsonb language sql as $$ select
'{"external_ref":"TEST-IMP-MCQ","course_codes":["SAT","EST"],"topic_slug":"test-import","subtopic_slug":"import-subtopic","skill_codes":["TEST.IMP.ONE"],"type":"mcq","difficulty":"M","stem_md":"Find x.","choices":[{"label":"A","body_md":"1"},{"label":"B","body_md":"2"}],"key":{"choice":"B"},"pool":"practice","status":"published","explanation_md":"Two.","images":["figure.png"],"hint_md":"Think.","desmos_friendly":true,"source":"import.pdf","source_page":12,"solved_by":"teacher","misconceptions":{"A":"one"}}'::jsonb $$;
create function pg_temp.import_spr() returns jsonb language sql as $$ select
(pg_temp.import_mcq()-'choices') || '{"external_ref":"TEST-IMP-SPR","type":"spr","key":{"accepted":["7/2","3.5"],"tolerance":0}}'::jsonb $$;
-- Definer only in this rolled-back fixture, to inspect private data after role changes.
create function pg_temp.import_snapshot() returns jsonb language sql security definer set search_path='' as $$
select jsonb_build_array(
 (select jsonb_agg(to_jsonb(q) order by id) from public.questions q),
 (select jsonb_agg(to_jsonb(c) order by id) from public.question_choices c),
 (select jsonb_agg(to_jsonb(c) order by question_id,course_id) from public.question_courses c),
 (select jsonb_agg(to_jsonb(s) order by question_id,skill_id) from public.question_skills s),
 (select jsonb_agg(to_jsonb(k) order by question_id) from private.question_keys k),
 (select count(*) from public.audit_log),
 (select count(*) from pg_catalog.pg_class where relnamespace=pg_my_temp_schema())) $$;
grant execute on function pg_temp.import_snapshot(),pg_temp.import_mcq(),pg_temp.import_spr() to authenticated;
select tests.authenticate_as('import_student');
select throws_ok($$select public.teacher_import_questions('[]',false)$$,'P0001','forbidden','QB-05: student dry run forbidden');
select throws_ok($$select public.teacher_import_questions('[]',true)$$,'P0001','forbidden','QB-05: student commit forbidden');
select throws_ok($$select * from private.question_keys$$,'42501',null,'QB-05: private keys stay inaccessible');
select tests.clear_authentication();
set local role anon;
select throws_ok($$select public.teacher_import_questions('[]',false)$$,'42501',null,'QB-05: anon has no execute');
reset role;
set local role authenticated;
select throws_ok($$select public.teacher_import_questions('[]',false)$$,'P0001','not_authenticated','QB-05: auth uid checked');
reset role;
select ok(not has_function_privilege('authenticated','private.validate_question_row(jsonb,integer)','execute'),'QB-05: validator is internal');
select tests.authenticate_as('import_teacher');
select set_config('test.import_before',pg_temp.import_snapshot()::text,true);
select is(public.teacher_import_questions(jsonb_build_array(pg_temp.import_mcq(),pg_temp.import_spr()),false),
'{"ok":true,"rows":2,"new":2,"updated":0,"errors":[],"truncated":false}'::jsonb,'QB-05: clean MCQ and SPR report');
select is(pg_temp.import_snapshot(),current_setting('test.import_before')::jsonb,'QB-05: dry run writes nothing, including temp tables and audits');
select throws_ok(format('select public.teacher_import_questions(%L,true)',jsonb_build_array(pg_temp.import_mcq(),pg_temp.import_spr()||'{"difficulty":"X"}')::text),'P0001','invalid_input','QB-05: mixed batch rejected');
select is(pg_temp.import_snapshot(),current_setting('test.import_before')::jsonb,'QB-05: failed commit is atomic');
-- Every report code, including invalid JSON shapes, without throwing casts.
create temp table import_bad (patch jsonb,field text,problem text);
grant select on import_bad to authenticated;
insert into import_bad values
('{"external_ref":""}','external_ref','missing:external_ref'),
('{"course_codes":[]}','course_codes','missing:course_codes'),
('{"type":"essay"}','type','bad_enum:type'),
('{"difficulty":"X"}','difficulty','bad_enum:difficulty'),
('{"pool":"other"}','pool','bad_enum:pool'),
('{"status":"retired"}','status','bad_enum:status'),
('{"solved_by":"student"}','solved_by','bad_enum:solved_by'),
('{"course_codes":["NOPE"]}','course_codes','unknown_course:NOPE'),
('{"topic_slug":"absent"}','topic_slug','unknown_topic'),
('{"subtopic_slug":"absent"}','subtopic_slug','unknown_subtopic'),
('{"skill_codes":["MISSING"]}','skill_codes','unknown_skill:MISSING'),
('{"choices":[]}','choices','mcq_choices'),
('{"choices":[{"label":"A","body_md":"1"},{"label":"A","body_md":"2"}]}','choices','mcq_choices'),
('{"choices":[{"label":"Z","body_md":"1"},{"label":"B","body_md":"2"}]}','choices','mcq_choices'),
('{"key":{"choice":"C"}}','key','key_not_in_choices'),
('{"type":"spr","key":{"accepted":["1"]}}','choices','spr_has_choices'),
('{"type":"spr","choices":[],"key":{"accepted":[]}}','key','spr_key'),
('{"type":"spr","choices":[],"key":{"accepted":["1/0"]}}','key','spr_key'),
('{"type":"spr","choices":[],"key":{"accepted":[1]}}','key','spr_key'),
('{"type":"spr","choices":[],"key":{"accepted":["1"],"tolerance":-1}}','key','spr_key'),
('{"type":"spr","choices":[],"key":{"accepted":["1"],"tolerance":"0"}}','key','spr_key'),
('{"images":{}}','images','missing:images'),
('{"source_page":1.5}','source_page','missing:source_page'),
('{"desmos_friendly":"yes"}','desmos_friendly','missing:desmos_friendly');
insert into import_bad values
(jsonb_build_object('stem_md',repeat('x',5001)),'stem_md','too_long:stem_md'),
(jsonb_build_object('explanation_md',repeat('x',5001)),'explanation_md','too_long:explanation_md'),
(jsonb_build_object('choices',jsonb_build_array(jsonb_build_object('label','A','body_md',repeat('x',1001)),jsonb_build_object('label','B','body_md','2'))),'choices','too_long:choices');
select ok(exists(select 1 from jsonb_array_elements(public.teacher_import_questions(jsonb_build_array(pg_temp.import_mcq()||b.patch),false)->'errors') e
 where e->>'problem'=b.problem and e->>'field'=b.field and e->>'row'='1' and e ? 'external_ref'), 'QB-05: reports '||b.problem) from import_bad b;
select ok((public.teacher_import_questions(jsonb_build_array(pg_temp.import_mcq(),pg_temp.import_mcq()),false)->'errors') @> '[{"problem":"duplicate_ref"}]','QB-05: duplicate refs reported');
select ok((public.teacher_import_questions('[null,12,[],"x"]',false)->'errors') @> '[{"problem":"missing:row"}]','QB-05: malformed rows return problems');
select throws_ok($$select public.teacher_import_questions('{}',false)$$,'P0001','invalid_input','QB-05: root must be array');
select ok((public.teacher_import_questions((select jsonb_agg(pg_temp.import_mcq()) from generate_series(1,501)),false)->'errors') @> '[{"row":0,"problem":"too_many_rows"}]','QB-05: batch limit from setting');
select is(public.teacher_import_questions((select jsonb_agg('{}'::jsonb) from generate_series(1,30)),false)->>'truncated','true','QB-05: report truncation marked');
select is(jsonb_array_length(public.teacher_import_questions((select jsonb_agg('{}'::jsonb) from generate_series(1,30)),false)->'errors'),200,'QB-05: errors capped at 200');
select is(pg_temp.import_snapshot() - 6,current_setting('test.import_before')::jsonb - 6,'QB-05: all invalid dry runs leave data unchanged');
select ok((public.teacher_import_questions(jsonb_build_array(pg_temp.import_mcq()-f),false)->'errors') @> jsonb_build_array(jsonb_build_object('problem','missing:'||f)),
 'QB-05: required field '||f)
from unnest(array['external_ref','course_codes','topic_slug','subtopic_slug','type','difficulty','stem_md','key','pool','status']) f;
select is(public.teacher_import_questions('[]',true),'{"ok":true,"rows":0,"new":0,"updated":0,"errors":[],"truncated":false}'::jsonb,'QB-05: empty batch is a no-op');
select tests.clear_authentication();
update public.settings set value='1' where key='import_max_rows';
select tests.authenticate_as('import_teacher');
select ok((public.teacher_import_questions(jsonb_build_array(pg_temp.import_mcq(),pg_temp.import_spr()),false)->'errors') @> '[{"row":0,"problem":"too_many_rows"}]','QB-05: configured limit is honored');
select tests.clear_authentication();
update public.settings set value='500' where key='import_max_rows';
select tests.authenticate_as('import_teacher');
-- Real writes and reimport replacement.
select is(public.teacher_import_questions(jsonb_build_array(pg_temp.import_mcq(),pg_temp.import_spr()),true)->>'ok','true','QB-05: valid published MCQ and SPR commit');
select is((select count(*)::int from public.questions where external_ref like 'TEST-IMP-%'),2,'QB-05: two questions created');
select is((select count(*)::int from public.question_courses c join public.questions q on q.id=c.question_id where q.external_ref='TEST-IMP-MCQ'),2,'QB-05: all courses linked');
select is((select image_paths from public.questions where external_ref='TEST-IMP-MCQ'),array['figure.png'],'QB-05: images stored');
select is((select diff from public.audit_log where actor=auth.uid() and action='questions.import'),'{"created":2,"updated":0,"refs":["TEST-IMP-MCQ","TEST-IMP-SPR"]}'::jsonb,'QB-05: one batch audit');
select set_config('test.import_id',(select id::text from public.questions where external_ref='TEST-IMP-MCQ'),true);
select tests.clear_authentication();
update public.questions set updated_at='2020-01-01' where external_ref='TEST-IMP-MCQ';
select is((select correct_answer from private.question_keys where question_id=current_setting('test.import_id')::uuid),'{"choice":"B"}'::jsonb,'QB-05: private key written');
select tests.authenticate_as('import_teacher');
select is(public.teacher_import_questions(jsonb_build_array(pg_temp.import_mcq()||'{"course_codes":["SAT"],"skill_codes":["TEST.IMP.TWO"],"choices":[{"label":"B","body_md":"new B"},{"label":"C","body_md":"new C"}],"key":{"choice":"C"}}'),true)->>'updated','1','QB-05: existing ref updated');
select is((select id::text from public.questions where external_ref='TEST-IMP-MCQ'),current_setting('test.import_id'),'QB-05: id preserved');
select is((select version from public.questions where external_ref='TEST-IMP-MCQ'),2,'QB-05: version incremented');
select ok((select updated_at=now() from public.questions where external_ref='TEST-IMP-MCQ'),'QB-05: updated_at bumped');
select is((select array_agg(c.label::text order by c.label) from public.question_choices c where question_id=current_setting('test.import_id')::uuid),array['B','C'],'QB-05: choices replaced');
select is((select count(*)::int from public.question_courses where question_id=current_setting('test.import_id')::uuid),1,'QB-05: courses replaced');
select is((select s.code from public.question_skills qs join public.skills s on s.id=qs.skill_id where question_id=current_setting('test.import_id')::uuid),'TEST.IMP.TWO','QB-05: skills replaced');
select tests.clear_authentication();
select is((select correct_answer from private.question_keys where question_id=current_setting('test.import_id')::uuid),'{"choice":"C"}'::jsonb,'QB-05: key upserted');
select tests.authenticate_as('import_teacher');
select is(public.teacher_import_questions((select jsonb_agg(pg_temp.import_spr()||jsonb_build_object('external_ref','TEST-BULK-'||i)) from generate_series(1,500) i),true)->>'new','500','QB-05: 500 rows in one call');
select * from finish();
rollback;
