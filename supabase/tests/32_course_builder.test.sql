-- C-1 / ADM-01: course builder. From supabase/templates/test.sql.
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

select tests.create_supabase_user('builder_student');
select tests.create_supabase_user('builder_other');
select tests.create_supabase_user('builder_teacher');
update public.profiles set role = 'teacher'
where id = tests.get_supabase_uid('builder_teacher');

insert into public.courses (id, code, title, slug, sort) values
  ('00000000-0000-0000-0000-0000000032c1', 'SAT', 'Builder SAT', 'builder-sat', 2),
  ('00000000-0000-0000-0000-0000000032c2', 'EST', 'Builder EST', 'builder-est', 1);

-- Catalog-driven permission tests also cover future teacher RPC additions.
select tests.authenticate_as('builder_student');
select is((select role::text from public.profiles where id = auth.uid()),
  'student', 'ADM-01: own role is selectable without a role RPC');
select is_empty($$ select id from public.profiles where id <> auth.uid() $$,
  'ADM-01: student cannot read another profile role');
select throws_ok(format('select public.%I(%s)', p.proname,
    (select string_agg('null::' || format_type(a, null), ', ')
     from unnest(p.proargtypes::oid[]) a)),
  'P0001', 'forbidden', 'ADM-01: student denied ' || p.proname)
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.proname like 'teacher\_%' escape '\';
select tests.clear_authentication();
set local role anon;
select throws_ok(format('select public.%I(%s)', p.proname,
    (select string_agg('null::' || format_type(a, null), ', ')
     from unnest(p.proargtypes::oid[]) a)),
  '42501', null, 'ADM-01: anon denied ' || p.proname)
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.proname like 'teacher\_%' escape '\';
reset role;

select tests.authenticate_as('builder_teacher');
select is((select role::text from public.profiles where id = auth.uid()),
  'teacher', 'ADM-01: teacher can read own role');
select is(public.teacher_list_courses(),
  '[{"id":"00000000-0000-0000-0000-0000000032c2","code":"EST","title":"Builder EST","slug":"builder-est","is_published":false},
    {"id":"00000000-0000-0000-0000-0000000032c1","code":"SAT","title":"Builder SAT","slug":"builder-sat","is_published":false}]'::jsonb,
  'C-1: lists unpublished courses in sort order');
select is(public.teacher_get_course_tree('00000000-0000-0000-0000-0000000032c1'),
  '{"course":{"id":"00000000-0000-0000-0000-0000000032c1","title":"Builder SAT","code":"SAT"},"units":[]}'::jsonb,
  'C-1: empty course tree has an empty array');

-- Save generated IDs in transaction-local settings so calls run as real roles.
select set_config('test.bu1', public.teacher_upsert_unit(null,
  '00000000-0000-0000-0000-0000000032c1', '  Algebra  ') ->> 'id', true);
select set_config('test.bu2', public.teacher_upsert_unit(null,
  '00000000-0000-0000-0000-0000000032c1', 'Geometry') ->> 'id', true);
select set_config('test.bu3', public.teacher_upsert_unit(null,
  '00000000-0000-0000-0000-0000000032c2', 'EST unit') ->> 'id', true);
select set_config('test.bt1', public.teacher_upsert_topic(null,
  current_setting('test.bu1')::uuid, U&'  Caf\00e9 Algebra!  ') ->> 'id', true);
select set_config('test.bt2', public.teacher_upsert_topic(null,
  current_setting('test.bu1')::uuid, U&'Caf\00e9 Algebra!') ->> 'id', true);
select set_config('test.bt3', public.teacher_upsert_topic(null,
  current_setting('test.bu2')::uuid, U&'Caf\00e9 Algebra!') ->> 'id', true);
select set_config('test.bt4', public.teacher_upsert_topic(null,
  current_setting('test.bu3')::uuid, U&'Caf\00e9 Algebra!') ->> 'id', true);
select set_config('test.bs1', public.teacher_upsert_subtopic(null,
  current_setting('test.bt1')::uuid, '  Basics  ') ->> 'id', true);
select set_config('test.bs2', public.teacher_upsert_subtopic(null,
  current_setting('test.bt1')::uuid, 'Advanced') ->> 'id', true);
select is((select title from public.units where id = current_setting('test.bu1')::uuid),
  'Algebra', 'C-1: title is trimmed');
select is((select array_agg(sort order by sort) from public.units
  where course_id = '00000000-0000-0000-0000-0000000032c1'), array[1,2],
  'C-1: units append last');
select is((select array_agg(slug order by sort) from public.topics
  where unit_id = current_setting('test.bu1')::uuid),
  array['cafe-algebra','cafe-algebra-2'], 'C-1: unaccented slug with suffix');
select is((select slug from public.topics where id = current_setting('test.bt3')::uuid),
  'cafe-algebra-3', 'C-1: slug uniqueness spans units in the same course');
select is((select slug from public.topics where id = current_setting('test.bt4')::uuid),
  'cafe-algebra', 'C-1: slug may repeat in another course');
select is((select course_id from public.topics where id = current_setting('test.bt4')::uuid),
  '00000000-0000-0000-0000-0000000032c2'::uuid, 'C-1: course comes from unit');
select is((select array_agg(sort order by sort) from public.subtopics
  where topic_id = current_setting('test.bt1')::uuid), array[1,2],
  'C-1: subtopics append last');
select ok((select not is_published and not is_free_preview from public.topics
  where id = current_setting('test.bt1')::uuid), 'C-1: new topic is draft');

select is(public.teacher_upsert_unit(current_setting('test.bu1')::uuid,
  '00000000-0000-0000-0000-0000000032c1', 'Renamed unit'),
  jsonb_build_object('id', current_setting('test.bu1')), 'C-1: rename unit returns id');
select is(public.teacher_upsert_topic(current_setting('test.bt1')::uuid,
  current_setting('test.bu1')::uuid, 'Renamed topic'),
  jsonb_build_object('id', current_setting('test.bt1')), 'C-1: rename topic returns id');
select is(public.teacher_upsert_subtopic(current_setting('test.bs1')::uuid,
  current_setting('test.bt1')::uuid, 'Renamed subtopic'),
  jsonb_build_object('id', current_setting('test.bs1')), 'C-1: rename subtopic returns id');
select is((select slug from public.topics where id = current_setting('test.bt1')::uuid),
  'cafe-algebra', 'C-1: rename preserves slug');
select is((select title from public.units where id = current_setting('test.bu1')::uuid),
  'Renamed unit', 'C-1: unit rename persisted');
select is((select title from public.subtopics where id = current_setting('test.bs1')::uuid),
  'Renamed subtopic', 'C-1: subtopic rename persisted');
select is(public.teacher_set_topic_flags(current_setting('test.bt1')::uuid, true, null),
  '{"is_published":true,"is_free_preview":false}'::jsonb, 'C-1: publish leaves preview unchanged');
select is(public.teacher_set_topic_flags(current_setting('test.bt1')::uuid, null, true),
  '{"is_published":true,"is_free_preview":true}'::jsonb, 'C-1: preview leaves publish unchanged');
select is(public.teacher_set_topic_flags(current_setting('test.bt1')::uuid, false, null),
  '{"is_published":false,"is_free_preview":true}'::jsonb, 'C-1: topic can be unpublished');
select is(public.teacher_set_topic_flags(current_setting('test.bt1')::uuid, null, null),
  '{"is_published":false,"is_free_preview":true}'::jsonb, 'C-1: null flags preserve both');

select set_config('test.tree', public.teacher_get_course_tree(
  '00000000-0000-0000-0000-0000000032c1')::text, true);
select is(current_setting('test.tree')::jsonb #>> '{units,0,topics,0,title}',
  'Renamed topic', 'C-1: tree includes unpublished renamed topic');
select is(current_setting('test.tree')::jsonb #> '{units,0,in_use}',
  'true'::jsonb, 'C-1: tree marks unit with children in use');
select is(current_setting('test.tree')::jsonb #> '{units,0,topics,0,in_use}',
  'true'::jsonb, 'C-1: tree marks topic with children in use');
select is(current_setting('test.tree')::jsonb #> '{units,0,topics,0,subtopic_count}',
  '2'::jsonb, 'C-1: tree reports subtopic count');
select is(current_setting('test.tree')::jsonb #> '{units,0,topics,0,subtopics,0,in_use}',
  'false'::jsonb, 'C-1: empty subtopic is not in use');

-- Every malformed reorder must leave order and audit count unchanged.
select set_config('test.order_before', (select jsonb_agg(to_jsonb(u) order by id)::text
  from public.units u), true);
select set_config('test.audit_before', (select count(*)::text from public.audit_log), true);
select throws_ok(q, 'P0001', 'invalid_input', 'C-1: invalid reorder ' || label)
from (values
  ('missing', format('select public.teacher_reorder(''unit'', %L, array[%L]::uuid[])',
    '00000000-0000-0000-0000-0000000032c1', current_setting('test.bu1'))),
  ('extra', format('select public.teacher_reorder(''unit'', %L, array[%L,%L,%L]::uuid[])',
    '00000000-0000-0000-0000-0000000032c1', current_setting('test.bu1'), current_setting('test.bu2'), gen_random_uuid())),
  ('duplicate', format('select public.teacher_reorder(''unit'', %L, array[%L,%L]::uuid[])',
    '00000000-0000-0000-0000-0000000032c1', current_setting('test.bu1'), current_setting('test.bu1'))),
  ('other parent', format('select public.teacher_reorder(''unit'', %L, array[%L,%L]::uuid[])',
    '00000000-0000-0000-0000-0000000032c1', current_setting('test.bu1'), current_setting('test.bu3'))),
  ('null array', 'select public.teacher_reorder(''unit'', ''00000000-0000-0000-0000-0000000032c1'', null)'),
  ('null element', 'select public.teacher_reorder(''unit'', ''00000000-0000-0000-0000-0000000032c1'', array[null]::uuid[])')
) v(label,q);
select is((select jsonb_agg(to_jsonb(u) order by id) from public.units u),
  current_setting('test.order_before')::jsonb, 'C-1: invalid reorder is atomic');
select is((select count(*)::text from public.audit_log), current_setting('test.audit_before'),
  'ADM-01: rejected writes produce no audits');
select is(public.teacher_reorder('unit', '00000000-0000-0000-0000-0000000032c1',
  array[current_setting('test.bu2')::uuid,current_setting('test.bu1')::uuid]),
  '{"ok":true}'::jsonb, 'C-1: unit reorder succeeds');
select is(public.teacher_reorder('topic', current_setting('test.bu1')::uuid,
  array[current_setting('test.bt2')::uuid,current_setting('test.bt1')::uuid]),
  '{"ok":true}'::jsonb, 'C-1: topic reorder succeeds');
select is(public.teacher_reorder('subtopic', current_setting('test.bt1')::uuid,
  array[current_setting('test.bs2')::uuid,current_setting('test.bs1')::uuid]),
  '{"ok":true}'::jsonb, 'C-1: subtopic reorder succeeds');
select is((select array_agg(id order by sort) from public.units
  where course_id = '00000000-0000-0000-0000-0000000032c1'),
  array[current_setting('test.bu2')::uuid,current_setting('test.bu1')::uuid],
  'C-1: unit order persisted');
select is((select array_agg(id order by sort) from public.topics
  where unit_id = current_setting('test.bu1')::uuid),
  array[current_setting('test.bt2')::uuid,current_setting('test.bt1')::uuid],
  'C-1: topic order persisted');
select is((select array_agg(id order by sort) from public.subtopics
  where topic_id = current_setting('test.bt1')::uuid),
  array[current_setting('test.bs2')::uuid,current_setting('test.bs1')::uuid],
  'C-1: subtopic order persisted');
select is((select array_agg(sort order by sort) from public.topics
  where unit_id = current_setting('test.bu1')::uuid), array[1,2],
  'C-1: reorder assigns contiguous sorts');

-- Validate the same malformed inputs for topics and subtopics too.
select throws_ok($$ select public.teacher_reorder('subtopic',
  current_setting('test.bt2')::uuid,
  array[current_setting('test.bs1')::uuid]) $$,
  'P0001','invalid_input','C-1: rejects an existing subtopic of another parent');
select set_config('test.children_before', (select jsonb_build_object(
  'topics',(select jsonb_agg(to_jsonb(t) order by id) from public.topics t),
  'subtopics',(select jsonb_agg(to_jsonb(s) order by id) from public.subtopics s))::text),true);
select throws_ok(format('select public.teacher_reorder(%L,%L,%s)',kind,parent,ids),
  'P0001','invalid_input','C-1: ' || kind || ' reorder rejects ' || label)
from (values
  ('topic',current_setting('test.bu1'),current_setting('test.bt1'),current_setting('test.bt2'),current_setting('test.bt3')),
  ('subtopic',current_setting('test.bt1'),current_setting('test.bs1'),current_setting('test.bs2'),gen_random_uuid()::text)
) f(kind,parent,a,b,foreign_id)
cross join lateral (values
  ('missing',format('array[%L]::uuid[]',a)),
  ('extra',format('array[%L,%L,%L]::uuid[]',a,b,gen_random_uuid())),
  ('duplicate',format('array[%L,%L]::uuid[]',a,a)),
  ('outside parent',format('array[%L,%L]::uuid[]',a,foreign_id)),
  ('null array','null'),
  ('null element',format('array[%L,null]::uuid[]',a)),
  ('multidimensional',format('array[[%L,%L]]::uuid[]',a,b))
) v(label,ids);
select is((select jsonb_build_object(
  'topics',(select jsonb_agg(to_jsonb(t) order by id) from public.topics t),
  'subtopics',(select jsonb_agg(to_jsonb(s) order by id) from public.subtopics s))),
  current_setting('test.children_before')::jsonb,
  'C-1: invalid child reorders leave all rows unchanged');

select throws_ok($$ select public.teacher_delete_node('unit', current_setting('test.bu1')::uuid) $$,
  'P0001', 'in_use', 'C-1: unit with topics cannot be deleted');
select throws_ok($$ select public.teacher_delete_node('topic', current_setting('test.bt1')::uuid) $$,
  'P0001', 'in_use', 'C-1: topic with subtopics cannot be deleted');

-- Invalid titles, IDs and parent changes across all upserts.
select throws_ok(format('select public.%I(null,%L,%L)', fn, parent, title),
  'P0001', 'invalid_input', 'C-1: rejects invalid title in ' || fn)
from (values
  ('teacher_upsert_unit','00000000-0000-0000-0000-0000000032c1'),
  ('teacher_upsert_topic',current_setting('test.bu1')),
  ('teacher_upsert_subtopic',current_setting('test.bt1'))
) f(fn,parent) cross join (values (null::text),('   '),(repeat('x',121))) t(title);
select throws_ok(format('select public.%I(%L,%L,''Rename'')',fn,id,parent),
  'P0001','invalid_input','C-1: cannot move node through ' || fn)
from (values
  ('teacher_upsert_unit',current_setting('test.bu1'),'00000000-0000-0000-0000-0000000032c2'),
  ('teacher_upsert_topic',current_setting('test.bt1'),current_setting('test.bu3')),
  ('teacher_upsert_subtopic',current_setting('test.bs1'),current_setting('test.bt2'))
) f(fn,id,parent);
select throws_ok(q,'P0001','invalid_input','C-1: rejects unknown or null input')
from (values
  ('select public.teacher_get_course_tree(null)'),
  ('select public.teacher_get_course_tree(gen_random_uuid())'),
  ('select public.teacher_upsert_unit(null,gen_random_uuid(),''Title'')'),
  ('select public.teacher_upsert_topic(null,gen_random_uuid(),''Title'')'),
  ('select public.teacher_upsert_subtopic(null,gen_random_uuid(),''Title'')'),
  ('select public.teacher_reorder(''other'',gen_random_uuid(),''{}''::uuid[])'),
  ('select public.teacher_reorder(null,gen_random_uuid(),''{}''::uuid[])'),
  ('select public.teacher_reorder(''unit'',gen_random_uuid(),''{}''::uuid[])'),
  ('select public.teacher_delete_node(''other'',gen_random_uuid())'),
  ('select public.teacher_delete_node(null,gen_random_uuid())'),
  ('select public.teacher_delete_node(''topic'',null)'),
  ('select public.teacher_delete_node(''subtopic'',gen_random_uuid())'),
  ('select public.teacher_set_topic_flags(gen_random_uuid(),true,true)')
) v(q);

select tests.clear_authentication();
reset role;
-- Isolate the topic_assets FK to topic (no children mask the reference).
insert into public.topic_assets (topic_id,kind,title) values (current_setting('test.bt2')::uuid,'notes','Notes');
select tests.authenticate_as('builder_teacher');
select is(jsonb_path_query_first(public.teacher_get_course_tree(
  '00000000-0000-0000-0000-0000000032c1'),
  '$.units[*].topics[*] ? (@.id == $id).in_use',
  jsonb_build_object('id',current_setting('test.bt2'))),
  'true'::jsonb, 'C-1: tree sees topic referenced by topic_assets');
select throws_ok($$ select public.teacher_delete_node('topic', current_setting('test.bt2')::uuid) $$,
  'P0001','in_use','C-1: topic_assets blocks topic deletion');
select tests.clear_authentication();
reset role;
delete from public.topic_assets where topic_id = current_setting('test.bt2')::uuid;

-- Isolate the questions FK to topic (no children mask the reference).
insert into public.questions (topic_id,subtopic_id,type,difficulty,stem_md,pool) values (current_setting('test.bt2')::uuid,current_setting('test.bs1')::uuid,'spr','E','Stem','practice');
-- These indirect topic references cannot exist without the parent question.
insert into public.question_courses (question_id,course_id)
select id,'00000000-0000-0000-0000-0000000032c1' from public.questions
where topic_id = current_setting('test.bt2')::uuid;
insert into public.question_exposure (user_id,question_id)
select tests.get_supabase_uid('builder_student'),id from public.questions
where topic_id = current_setting('test.bt2')::uuid;
select tests.authenticate_as('builder_teacher');
select is(jsonb_path_query_first(public.teacher_get_course_tree(
  '00000000-0000-0000-0000-0000000032c1'),
  '$.units[*].topics[*] ? (@.id == $id).in_use',
  jsonb_build_object('id',current_setting('test.bt2'))),
  'true'::jsonb, 'C-1: tree sees topic referenced by questions');
select throws_ok($$ select public.teacher_delete_node('topic', current_setting('test.bt2')::uuid) $$,
  'P0001','in_use','C-1: questions blocks topic deletion');
select tests.clear_authentication();
reset role;
delete from public.question_exposure where question_id in
  (select id from public.questions where topic_id = current_setting('test.bt2')::uuid);
delete from public.question_courses where question_id in
  (select id from public.questions where topic_id = current_setting('test.bt2')::uuid);
delete from public.questions where topic_id = current_setting('test.bt2')::uuid;

-- Isolate the attempts FK to topic (no children mask the reference).
insert into public.attempts (topic_id,user_id,course_id,kind) values (current_setting('test.bt2')::uuid,tests.get_supabase_uid('builder_student'),'00000000-0000-0000-0000-0000000032c1','practice');
select tests.authenticate_as('builder_teacher');
select is(jsonb_path_query_first(public.teacher_get_course_tree(
  '00000000-0000-0000-0000-0000000032c1'),
  '$.units[*].topics[*] ? (@.id == $id).in_use',
  jsonb_build_object('id',current_setting('test.bt2'))),
  'true'::jsonb, 'C-1: tree sees topic referenced by attempts');
select throws_ok($$ select public.teacher_delete_node('topic', current_setting('test.bt2')::uuid) $$,
  'P0001','in_use','C-1: attempts blocks topic deletion');
select tests.clear_authentication();
reset role;
delete from public.attempts where topic_id = current_setting('test.bt2')::uuid;

-- Isolate the topic_progress FK to topic (no children mask the reference).
insert into public.topic_progress (topic_id,user_id) values (current_setting('test.bt2')::uuid,tests.get_supabase_uid('builder_student'));
select tests.authenticate_as('builder_teacher');
select is(jsonb_path_query_first(public.teacher_get_course_tree(
  '00000000-0000-0000-0000-0000000032c1'),
  '$.units[*].topics[*] ? (@.id == $id).in_use',
  jsonb_build_object('id',current_setting('test.bt2'))),
  'true'::jsonb, 'C-1: tree sees topic referenced by topic_progress');
select throws_ok($$ select public.teacher_delete_node('topic', current_setting('test.bt2')::uuid) $$,
  'P0001','in_use','C-1: topic_progress blocks topic deletion');
select tests.clear_authentication();
reset role;
delete from public.topic_progress where topic_id = current_setting('test.bt2')::uuid;

-- Isolate the topic_assets FK to subtopic (no children mask the reference).
insert into public.topic_assets (topic_id,subtopic_id,kind,title) values (current_setting('test.bt2')::uuid,current_setting('test.bs2')::uuid,'notes','Notes');
select tests.authenticate_as('builder_teacher');
select is(jsonb_path_query_first(public.teacher_get_course_tree(
  '00000000-0000-0000-0000-0000000032c1'),
  '$.units[*].topics[*].subtopics[*] ? (@.id == $id).in_use',
  jsonb_build_object('id',current_setting('test.bs2'))),
  'true'::jsonb, 'C-1: tree sees subtopic referenced by topic_assets');
select throws_ok($$ select public.teacher_delete_node('subtopic', current_setting('test.bs2')::uuid) $$,
  'P0001','in_use','C-1: topic_assets blocks subtopic deletion');
select tests.clear_authentication();
reset role;
delete from public.topic_assets where subtopic_id = current_setting('test.bs2')::uuid;

-- Isolate the questions FK to subtopic (no children mask the reference).
insert into public.questions (topic_id,subtopic_id,type,difficulty,stem_md,pool) values (current_setting('test.bt2')::uuid,current_setting('test.bs2')::uuid,'spr','E','Stem','practice');
select tests.authenticate_as('builder_teacher');
select is(jsonb_path_query_first(public.teacher_get_course_tree(
  '00000000-0000-0000-0000-0000000032c1'),
  '$.units[*].topics[*].subtopics[*] ? (@.id == $id).in_use',
  jsonb_build_object('id',current_setting('test.bs2'))),
  'true'::jsonb, 'C-1: tree sees subtopic referenced by questions');
select throws_ok($$ select public.teacher_delete_node('subtopic', current_setting('test.bs2')::uuid) $$,
  'P0001','in_use','C-1: questions blocks subtopic deletion');
select tests.clear_authentication();
reset role;
delete from public.questions where subtopic_id = current_setting('test.bs2')::uuid;

-- Isolate the subtopic_skills FK to subtopic (no children mask the reference).
insert into public.skills (code,name,domain) values ('builder-skill','Skill','Algebra');
insert into public.subtopic_skills (subtopic_id,skill_id) select current_setting('test.bs2')::uuid,id from public.skills where code = 'builder-skill';
select tests.authenticate_as('builder_teacher');
select is(jsonb_path_query_first(public.teacher_get_course_tree(
  '00000000-0000-0000-0000-0000000032c1'),
  '$.units[*].topics[*].subtopics[*] ? (@.id == $id).in_use',
  jsonb_build_object('id',current_setting('test.bs2'))),
  'true'::jsonb, 'C-1: tree sees subtopic referenced by subtopic_skills');
select throws_ok($$ select public.teacher_delete_node('subtopic', current_setting('test.bs2')::uuid) $$,
  'P0001','in_use','C-1: subtopic_skills blocks subtopic deletion');
select tests.clear_authentication();
reset role;
delete from public.subtopic_skills where subtopic_id = current_setting('test.bs2')::uuid;
delete from public.skills where code = 'builder-skill';

-- Isolate the video_chapters FK to subtopic (no children mask the reference).
insert into public.topic_assets (topic_id,kind,title) values (current_setting('test.bt2')::uuid,'video','Video');
insert into public.video_chapters (asset_id,subtopic_id,start_s,label) select id,current_setting('test.bs2')::uuid,0,'Chapter' from public.topic_assets where title = 'Video' and topic_id = current_setting('test.bt2')::uuid;
select tests.authenticate_as('builder_teacher');
select is(jsonb_path_query_first(public.teacher_get_course_tree(
  '00000000-0000-0000-0000-0000000032c1'),
  '$.units[*].topics[*].subtopics[*] ? (@.id == $id).in_use',
  jsonb_build_object('id',current_setting('test.bs2'))),
  'true'::jsonb, 'C-1: tree sees subtopic referenced by video_chapters');
select throws_ok($$ select public.teacher_delete_node('subtopic', current_setting('test.bs2')::uuid) $$,
  'P0001','in_use','C-1: video_chapters blocks subtopic deletion');
select tests.clear_authentication();
reset role;
delete from public.video_chapters where subtopic_id = current_setting('test.bs2')::uuid;
delete from public.topic_assets where title = 'Video' and topic_id = current_setting('test.bt2')::uuid;

select tests.authenticate_as('builder_teacher');
-- Every successful mutation emits exactly one complete audit entry.
select is((select count(*)::int from public.audit_log
  where actor = auth.uid()), 19, 'ADM-01: every successful write is audited');
select results_eq($$ select action,entity,count(*)::int from public.audit_log
  where actor = auth.uid() group by action,entity order by action,entity $$,
  $$ values ('node.reorder'::text,'subtopic'::text,1),('node.reorder','topic',1),
    ('node.reorder','unit',1),('node.upsert','subtopic',3),
    ('node.upsert','topic',5),('node.upsert','unit',4),('topic.flags','topic',4) $$,
  'ADM-01: every write RPC audits its entity exactly once per call');
select is_empty($$ select id from public.audit_log where actor = auth.uid()
  and (action is null or entity not in ('unit','topic','subtopic')
    or entity_id is null or diff is null or diff = '{}'::jsonb) $$,
  'ADM-01: audits contain actor, action, entity, entity_id and diff');
select is(public.teacher_delete_node('subtopic',current_setting('test.bs2')::uuid),
  '{"ok":true}'::jsonb,'C-1: deletes empty subtopic');
select is(public.teacher_reorder('subtopic',current_setting('test.bt2')::uuid,'{}'::uuid[]),
  '{"ok":true}'::jsonb,'C-1: empty parent accepts empty reorder');
select is(public.teacher_delete_node('topic',current_setting('test.bt2')::uuid),
  '{"ok":true}'::jsonb,'C-1: deletes unreferenced topic');
select set_config('test.empty_unit',public.teacher_upsert_unit(null,
  '00000000-0000-0000-0000-0000000032c1',repeat('x',120))->>'id',true);
select is(public.teacher_delete_node('unit',current_setting('test.empty_unit')::uuid),
  '{"ok":true}'::jsonb,'C-1: deletes empty unit and accepts 120-char title');
select is((select count(*)::int from public.audit_log where actor = auth.uid()
  and action = 'node.delete'),3,'ADM-01: every successful deletion is audited');
select is((select count(*)::int from public.subtopics where id = current_setting('test.bs2')::uuid),
  0,'C-1: deleted subtopic is gone');
select is((select count(*)::int from public.topics where id = current_setting('test.bt2')::uuid),
  0,'C-1: deleted topic is gone');
select is((select count(*)::int from public.units where id = current_setting('test.empty_unit')::uuid),
  0,'C-1: deleted unit is gone');
select set_config('test.fallback',public.teacher_upsert_topic(null,
  current_setting('test.bu3')::uuid,U&'\062c\0628\0631')->>'id',true);
select is((select slug from public.topics where id = current_setting('test.fallback')::uuid),
  'topic','C-1: topic RPC uses fallback for non-ASCII-only title');
select is((select count(*)::int from public.audit_log where actor = auth.uid()
  and entity_id = current_setting('test.fallback')::uuid),1,
  'ADM-01: topic create audit identifies the created row');
select tests.clear_authentication();
reset role;

-- Private slug helper is inaccessible to API roles.
select ok(not has_function_privilege('authenticated','private.slugify(text)','EXECUTE')
  and not has_function_privilege('anon','private.slugify(text)','EXECUTE'),
  'ADM-01: slug helper has no API execute grants');
select is(private.slugify(U&'\062c\0628\0631'), 'topic',
  'C-1: non-ASCII-only title falls back to topic');
select is(private.slugify(' -- A / B -- '), 'a-b', 'C-1: slug separators collapse');

select * from finish();
rollback;
