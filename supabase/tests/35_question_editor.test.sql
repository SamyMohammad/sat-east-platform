-- C-5 / QB-06. From supabase/templates/test.sql.
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();
select tests.create_supabase_user('editor_student');
select tests.create_supabase_user('editor_teacher');
update public.profiles set role='teacher' where id=tests.get_supabase_uid('editor_teacher');
insert into public.courses(code,title,slug) values
 ('SAT','Editor SAT','editor-sat'),('EST','Editor EST','editor-est') on conflict(code) do nothing;
insert into public.topics(id,course_id,title,slug,sort)
select '35000000-0000-0000-0000-000000000001',id,'Editor topic','editor-topic',1
from public.courses where code='SAT';
insert into public.topics(id,course_id,title,slug,sort)
select '35000000-0000-0000-0000-000000000002',id,'Other topic','editor-other',2
from public.courses where code='EST';
insert into public.subtopics(id,topic_id,title,sort) values
 ('35000000-0000-0000-0000-000000000003','35000000-0000-0000-0000-000000000001','Editor subtopic',1),
 ('35000000-0000-0000-0000-000000000004','35000000-0000-0000-0000-000000000002','Other subtopic',1);
insert into public.skills(code,name,domain) values ('TEST.ED.ONE','Editor one','Test'),('TEST.ED.TWO','Editor two','Test');
create function pg_temp.editor_row() returns jsonb language sql as $$ select
'{"external_ref":"QB35_NEW","course_codes":["SAT","EST"],"topic_slug":"editor-topic","subtopic_slug":"editor-subtopic","skill_codes":["TEST.ED.ONE"],"type":"mcq","difficulty":"M","stem_md":"Solve x.","images":["figure.png"],"choices":[{"label":"A","body_md":"1"},{"label":"B","body_md":"2"}],"key":{"choice":"B"},"explanation_md":"SECRET_EXPLANATION_35","misconceptions":{"A":"SECRET_MISCONCEPTION_35"},"hint_md":"Think.","desmos_friendly":true,"pool":"practice","status":"draft","source":"editor.pdf","source_page":7,"solved_by":"teacher"}'::jsonb $$;
create function pg_temp.editor_snapshot() returns jsonb language sql security definer set search_path='' as $$
 select jsonb_build_array(
  (select jsonb_agg(to_jsonb(q) order by id) from public.questions q),
  (select jsonb_agg(to_jsonb(c) order by id) from public.question_choices c),
  (select jsonb_agg(to_jsonb(c) order by question_id,course_id) from public.question_courses c),
  (select jsonb_agg(to_jsonb(s) order by question_id,skill_id) from public.question_skills s),
  (select jsonb_agg(to_jsonb(k) order by question_id) from private.question_keys k),
  (select jsonb_agg(to_jsonb(a) order by id) from public.audit_log a)) $$;
grant execute on function pg_temp.editor_row(),pg_temp.editor_snapshot() to authenticated;
-- All four RPCs must authorize before checking their arguments.
select tests.authenticate_as('editor_student');
select throws_ok(format('select public.%I(%s)',p.proname,
 (select string_agg('null::'||format_type(a,null),',') from unnest(p.proargtypes::oid[]) a)),
 'P0001','forbidden','QB-06: student denied '||p.proname)
from pg_proc p join pg_namespace ns on ns.oid=p.pronamespace
where ns.nspname='public' and p.proname in ('teacher_list_questions','teacher_get_question','teacher_save_question','teacher_list_topics_tree');
select throws_ok($$select * from private.question_keys$$,'42501',null,'QB-06: keys remain private');
select tests.clear_authentication();
reset role;
set local role anon;
select throws_ok(format('select public.%I(%s)',p.proname,
 (select string_agg('null::'||format_type(a,null),',') from unnest(p.proargtypes::oid[]) a)),
 '42501',null,'QB-06: anon denied '||p.proname)
from pg_proc p join pg_namespace ns on ns.oid=p.pronamespace
where ns.nspname='public' and p.proname in ('teacher_list_questions','teacher_get_question','teacher_save_question','teacher_list_topics_tree');
reset role;
set local role authenticated;
select throws_ok(format('select public.%I(%s)',p.proname,
 (select string_agg('null::'||format_type(a,null),',') from unnest(p.proargtypes::oid[]) a)),
 'P0001','not_authenticated','QB-06: auth uid checked '||p.proname)
from pg_proc p join pg_namespace ns on ns.oid=p.pronamespace
where ns.nspname='public' and p.proname in ('teacher_list_questions','teacher_get_question','teacher_save_question','teacher_list_topics_tree');
reset role;
select is((select count(*)::int from pg_proc p join pg_namespace ns on ns.oid=p.pronamespace
 where ns.nspname='public' and p.proname in ('teacher_list_questions','teacher_get_question','teacher_save_question','teacher_list_topics_tree')),4,'QB-06: four RPC contracts exist');
select ok(not has_function_privilege('authenticated','private.bank_search_pattern(text)','execute')
 and not has_function_privilege('authenticated','private.question_status_change_allowed(text,text)','execute'),
 'QB-06: new helpers are not API executable');
select tests.authenticate_as('editor_teacher');
select throws_ok($$select public.teacher_get_question('35000000-0000-0000-0000-999999999999')$$,'P0001','invalid_input','QB-06: unknown question');
select throws_ok($$select public.teacher_save_question('35000000-0000-0000-0000-999999999999',pg_temp.editor_row(),1)$$,'P0001','invalid_input','QB-06: unknown save id');
select set_config('test.editor_id',public.teacher_save_question(null,pg_temp.editor_row(),null)->>'id',true);
select is(public.teacher_get_question(current_setting('test.editor_id')::uuid)-array['id','version','updated_at'],
 pg_temp.editor_row(),'QB-06: create/get round-trips every import field, primary course first');
select is(public.teacher_get_question(current_setting('test.editor_id')::uuid)->>'version','1','QB-06: create version one');
select is((select diff from public.audit_log where entity_id=current_setting('test.editor_id')::uuid and action='question.save'),
 '{"from_version":null,"to_version":1,"status_from":null,"status_to":"draft"}'::jsonb,'QB-06: create audit contains only version and status');
select tests.clear_authentication();
reset role;
update public.questions set updated_at='2020-01-01' where id=current_setting('test.editor_id')::uuid;
select tests.authenticate_as('editor_teacher');
select set_config('test.editor_before',pg_temp.editor_snapshot()::text,true);
select throws_ok($$select public.teacher_save_question(null,pg_temp.editor_row(),null)$$,'P0001','invalid_input','QB-06: create refuses taken ref');
select throws_ok($$select public.teacher_save_question(current_setting('test.editor_id')::uuid,pg_temp.editor_row(),0)$$,'P0001','version_conflict','QB-06: stale version');
select throws_ok($$select public.teacher_save_question(current_setting('test.editor_id')::uuid,pg_temp.editor_row(),null)$$,'P0001','version_conflict','QB-06: missing expected version');
select is(public.teacher_save_question(current_setting('test.editor_id')::uuid,pg_temp.editor_row()||'{"key":{"choice":"C"}}',1),
 jsonb_build_object('ok',false,'errors',jsonb_build_array(jsonb_build_object('row',1,'external_ref','QB35_NEW','field','key','problem','key_not_in_choices'))),
 'QB-06: validation problems are returned, not raised');
select ok((public.teacher_save_question(null,'null',null)->'errors') @> '[{"problem":"missing:row"}]','QB-06: malformed row returns validation report');
select ok((public.teacher_save_question(null,pg_temp.editor_row()||'{"external_ref":"QB35_BAD","status":"published","key":{}}',null)->'errors') @> '[{"problem":"key_not_in_choices"}]','QB-06: invalid create cannot publish');
select is(pg_temp.editor_snapshot(),current_setting('test.editor_before')::jsonb,'QB-06: failed saves change no rows, children, private keys or audits');
-- Successful replacement, with the old key and explanation never copied to audit.
select is(public.teacher_save_question(current_setting('test.editor_id')::uuid,
 pg_temp.editor_row()||'{"course_codes":["SAT"],"skill_codes":["TEST.ED.TWO"],"choices":[{"label":"B","body_md":"new B"},{"label":"C","body_md":"new C"}],"key":{"choice":"C"},"explanation_md":"NEW_SECRET_35","status":"published"}',1),
 jsonb_build_object('id',current_setting('test.editor_id'),'version',2),'QB-06: update bumps version and replaces children');
select ok((public.teacher_get_question(current_setting('test.editor_id')::uuid)->>'updated_at')::timestamptz=now(),'QB-06: update refreshes timestamp');
select is(public.teacher_get_question(current_setting('test.editor_id')::uuid)->'choices',
 '[{"label":"B","body_md":"new B"},{"label":"C","body_md":"new C"}]'::jsonb,'QB-06: choice replacement');
select is(public.teacher_get_question(current_setting('test.editor_id')::uuid)->'course_codes','["SAT"]'::jsonb,'QB-06: courses replaced');
select is(public.teacher_get_question(current_setting('test.editor_id')::uuid)->'skill_codes','["TEST.ED.TWO"]'::jsonb,'QB-06: skills replaced');
select is(public.teacher_get_question(current_setting('test.editor_id')::uuid)->'key','{"choice":"C"}'::jsonb,'QB-06: key upserted');
select is((select diff from public.audit_log where entity_id=current_setting('test.editor_id')::uuid and action='question.save' and diff->>'to_version'='2'),
 '{"from_version":1,"to_version":2,"status_from":"draft","status_to":"published"}'::jsonb,'QB-06: exact safe update audit');
select set_config('test.editor_before',pg_temp.editor_snapshot()::text,true);
select ok((public.teacher_save_question(current_setting('test.editor_id')::uuid,pg_temp.editor_row(),2)->'errors') @> '[{"field":"status","problem":"bad_status_change"}]','QB-06: published to draft forbidden');
select ok((public.teacher_save_question(current_setting('test.editor_id')::uuid,pg_temp.editor_row()||'{"status":"approved"}',2)->'errors') @> '[{"problem":"bad_status_change"}]','QB-06: backward lifecycle forbidden');
select ok((public.teacher_save_question(current_setting('test.editor_id')::uuid,pg_temp.editor_row()||'{"status":"published","key":{}}',2)->'errors') @> '[{"problem":"key_not_in_choices"}]','QB-06: published update still needs valid key');
select is(pg_temp.editor_snapshot(),current_setting('test.editor_before')::jsonb,'QB-06: rejected status/publish change is atomic');
select is(public.teacher_save_question(current_setting('test.editor_id')::uuid,pg_temp.editor_row()||'{"status":"retired"}',2)->>'version','3','QB-06: published to retired allowed');
select ok((public.teacher_save_question(current_setting('test.editor_id')::uuid,pg_temp.editor_row()||'{"status":"solved"}',3)->'errors') @> '[{"problem":"bad_status_change"}]','QB-06: retired may only return to draft');
select is(public.teacher_save_question(current_setting('test.editor_id')::uuid,pg_temp.editor_row(),3)->>'version','4','QB-06: retired to draft allowed');
select is(public.teacher_save_question(current_setting('test.editor_id')::uuid,pg_temp.editor_row(),4)->>'version','5','QB-06: unchanged status content edits allowed');
select set_config('test.editor_spr',public.teacher_save_question(null,
 (pg_temp.editor_row()-'choices')||'{"external_ref":"QB35_SPR","type":"spr","key":{"accepted":["7/2","3.5"],"tolerance":0.01},"pool":"quiz","difficulty":"H","status":"solved"}',null)->>'id',true);
select is(public.teacher_get_question(current_setting('test.editor_spr')::uuid)->'key',
 '{"accepted":["7/2","3.5"],"tolerance":0.01}'::jsonb,'QB-06: SPR tolerance round-trips');
select is(public.teacher_get_question(current_setting('test.editor_spr')::uuid)->'choices','[]'::jsonb,'QB-06: SPR has no choices');
select set_config('test.editor_before',pg_temp.editor_snapshot()::text,true);
select throws_ok($$select public.teacher_save_question(current_setting('test.editor_spr')::uuid,pg_temp.editor_row(),1)$$,'P0001','invalid_input','QB-06: update cannot take another ref');
select is(pg_temp.editor_snapshot(),current_setting('test.editor_before')::jsonb,'QB-06: ref collision rollback');
-- Paging, order, wildcard escaping, all filters and a tree independent of seeds.
select tests.clear_authentication();
reset role;
insert into public.questions(id,external_ref,topic_id,subtopic_id,type,difficulty,stem_md,pool,status,updated_at) values
 ('35000000-0000-0000-0000-000000000010','QB35_A_B','35000000-0000-0000-0000-000000000002','35000000-0000-0000-0000-000000000004','mcq','E','Needle stem','mock_reserve','approved','2020-01-01'),
 ('35000000-0000-0000-0000-000000000011','QB35_AXB','35000000-0000-0000-0000-000000000002','35000000-0000-0000-0000-000000000004','mcq','E','Other stem','practice','retired','2020-01-01'),
 ('35000000-0000-0000-0000-000000000012','QB35_A%B!','35000000-0000-0000-0000-000000000002','35000000-0000-0000-0000-000000000004','mcq','E','Other stem','practice','draft','2020-01-01');
insert into public.question_courses(question_id,course_id)
select q.id,c.id from public.questions q cross join public.courses c
where q.id in ('35000000-0000-0000-0000-000000000010','35000000-0000-0000-0000-000000000011','35000000-0000-0000-0000-000000000012') and c.code='EST';
update public.settings set value='2' where key='bank_page_size';
select tests.authenticate_as('editor_teacher');
select is(public.teacher_list_questions('{"q":"QB35"}',1)->>'total','5','QB-06: list total');
select is(public.teacher_list_questions('{"q":"QB35"}',1)->>'page_size','2','QB-06: configurable page size');
select is(jsonb_array_length(public.teacher_list_questions('{"q":"QB35"}',3)->'rows'),1,'QB-06: final page');
select is(public.teacher_list_questions('{"q":"QB35"}',20)->'rows','[]'::jsonb,'QB-06: page past end');
select is(public.teacher_list_questions('{"q":"QB35"}',2)->'rows'->0->>'external_ref','QB35_A_B','QB-06: ordered by updated_at desc then id');
select is(public.teacher_list_questions('{"q":"QB35_A_B"}',1)->>'total','1','QB-06: underscore is literal');
select is(public.teacher_list_questions('{"q":"QB35_A%B!"}',1)->>'total','1','QB-06: percent and escape marker literal');
select is(public.teacher_list_questions('{"q":"needle STEM"}',1)->>'total','1','QB-06: stem search is case insensitive');
select is(public.teacher_list_questions('{"q":"QB35","course_code":"SAT"}',1)->>'total','2','QB-06: course filter uses links without duplicate rows');
select is(public.teacher_list_questions('{"q":"QB35","topic_id":"35000000-0000-0000-0000-000000000002"}',1)->>'total','3','QB-06: topic filter');
select is(public.teacher_list_questions('{"q":"QB35","subtopic_id":"35000000-0000-0000-0000-000000000003"}',1)->>'total','2','QB-06: subtopic filter');
select is(public.teacher_list_questions('{"q":"QB35","status":"retired"}',1)->>'total','1','QB-06: status filter');
select is(public.teacher_list_questions('{"q":"QB35","pool":"mock_reserve"}',1)->>'total','1','QB-06: pool filter');
select is(public.teacher_list_questions('{"q":"QB35","difficulty":"H"}',1)->>'total','1','QB-06: difficulty filter');
select is(public.teacher_list_questions('{"q":"QB35","type":"spr"}',1)->>'total','1','QB-06: type filter');
select is(public.teacher_list_questions('{"q":"QB35","type":"spr","status":"draft"}',1)->>'total','0','QB-06: combined filters');
select is((select array_agg(k order by k) from jsonb_object_keys(public.teacher_list_questions('{"q":"QB35"}',1)->'rows'->0) k),
 array['difficulty','external_ref','id','pool','status','stem_preview','subtopic_title','topic_title','type','updated_at','version'],
 'QB-06: list has only safe fields, no key/explanation/misconceptions');
select throws_ok($$select public.teacher_list_questions('{}',0)$$,'P0001','invalid_input','QB-06: invalid page');
select throws_ok($$select public.teacher_list_questions('{"topic_id":"bad"}',1)$$,'P0001','invalid_input','QB-06: malformed uuid filter');
select throws_ok($$select public.teacher_list_questions('[]',1)$$,'P0001','invalid_input','QB-06: filter must be object');
select ok(exists(select 1 from jsonb_array_elements(public.teacher_list_topics_tree()) c
 cross join lateral jsonb_array_elements(c->'topics') t
 cross join lateral jsonb_array_elements(t->'subtopics') s
 where c->>'course_code'='SAT' and t->>'id'='35000000-0000-0000-0000-000000000001'
 and t->>'slug'='editor-topic' and s->>'id'='35000000-0000-0000-0000-000000000003'
 and s->>'slug'='editor-subtopic'),'QB-06: tree includes unpublished nodes and import-compatible subtopic slug');
select is_empty($$select diff from public.audit_log where action='question.save' and actor=auth.uid()
 and ((diff ?| array['key','correct_answer','explanation_md','misconceptions']) or diff::text like '%SECRET%')$$,
 'QB-06: audit contains no answer or explanation content');
select tests.clear_authentication();
reset role;
select is((select count(*)::int from public.audit_log where action='question.save' and actor=tests.get_supabase_uid('editor_teacher')),6,'QB-06: one audit per successful save');
select * from finish();
rollback;
