-- L-3 / SEC-02 / C-3. From supabase/templates/test.sql.
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();
create function pg_temp.n(i int) returns uuid language sql immutable as $$
 select ('37000000-0000-0000-0000-' || lpad(i::text,12,'0'))::uuid;
$$;
grant execute on function pg_temp.n(int) to authenticated;
select tests.create_supabase_user('notes_teacher');
select tests.create_supabase_user('notes_student');
select tests.create_supabase_user('notes_outsider');
update public.profiles set role='teacher' where id=tests.get_supabase_uid('notes_teacher');
insert into public.courses(id,code,title,slug,is_published) values (pg_temp.n(1),'SAT','Notes','notes-test',true);
insert into public.topics(id,course_id,title,slug,sort,is_published,is_free_preview) values
 (pg_temp.n(11),pg_temp.n(1),'Open','notes-open',1,true,false),
 (pg_temp.n(12),pg_temp.n(1),'Locked','notes-locked',2,true,false),
 (pg_temp.n(13),pg_temp.n(1),'No notes','notes-none',3,true,true),
 (pg_temp.n(14),pg_temp.n(1),'Pending only','notes-pending',4,true,true);
insert into public.subtopics(id,topic_id,title) values
 (pg_temp.n(21),pg_temp.n(11),'Section'),(pg_temp.n(22),pg_temp.n(12),'Other'),
 (pg_temp.n(23),pg_temp.n(13),'None'),(pg_temp.n(24),pg_temp.n(14),'Pending');
insert into public.enrollments(user_id,course_id,status,starts_at,expires_at)
values(tests.get_supabase_uid('notes_student'),pg_temp.n(1),'active',now(),now()+interval '1 day');
insert into public.topic_assets(id,topic_id,subtopic_id,kind,title,sort,storage_path,page_count,ready) values
 (pg_temp.n(31),pg_temp.n(11),pg_temp.n(21),'notes','Second',2,pg_temp.n(11)||'/'||pg_temp.n(31)||'.pdf',3,true),
 (pg_temp.n(32),pg_temp.n(11),null,'notes','First',1,pg_temp.n(11)||'/'||pg_temp.n(32)||'.pdf',2,true),
 (pg_temp.n(33),pg_temp.n(12),null,'notes','Locked',1,pg_temp.n(12)||'/'||pg_temp.n(33)||'.pdf',2,true),
 (pg_temp.n(34),pg_temp.n(14),null,'notes','Pending',1,pg_temp.n(14)||'/'||pg_temp.n(34)||'.pdf',2,false),
 (pg_temp.n(36),pg_temp.n(11),null,'video','Video',1,pg_temp.n(11)||'/'||pg_temp.n(36)||'.pdf',null,true);
-- Keep this ready video for the kind check without gating the notes scenarios.
insert into public.video_progress(user_id,asset_id,pct)
values(tests.get_supabase_uid('notes_student'),pg_temp.n(36),100);
-- Inspect the installed Storage schema rather than guessing additional required columns.
-- id/timestamps have defaults; bucket_id/name/owner are explicitly provided below.
select is_empty($$select column_name from information_schema.columns
 where table_schema='storage' and table_name='objects' and is_nullable='NO'
 and column_default is null and is_identity='NO' and is_generated='NEVER'
 and column_name not in ('bucket_id','name','owner')$$,
 'SEC-02: Storage fixture covers required columns in the running schema');
insert into storage.objects(bucket_id,name,owner)
select 'notes',storage_path,tests.get_supabase_uid('notes_teacher') from public.topic_assets;
insert into storage.objects(bucket_id,name,owner) values
 ('notes',pg_temp.n(12)||'/'||pg_temp.n(31)||'.pdf',tests.get_supabase_uid('notes_teacher')),
 ('notes','not-a-uuid/bad.pdf',tests.get_supabase_uid('notes_teacher'));
insert into public.questions(id,topic_id,subtopic_id,type,difficulty,stem_md,pool,status)
select pg_temp.n(40+i),pg_temp.n(10+i),pg_temp.n(20+i),'mcq','M','One?','practice','published'
from unnest(array[1,3,4]) i;
insert into public.question_choices(question_id,label,body_md)
select q.id,l,'Choice' from public.questions q cross join unnest(array['A','B']) l where q.id in (pg_temp.n(41),pg_temp.n(43),pg_temp.n(44));
insert into private.question_keys(question_id,correct_answer,explanation_md)
select q.id,'{"choice":"B"}','Two.' from public.questions q where q.id in (pg_temp.n(41),pg_temp.n(43),pg_temp.n(44));
insert into public.attempts(id,user_id,course_id,topic_id,kind,status)
values(pg_temp.n(51),tests.get_supabase_uid('notes_student'),pg_temp.n(1),pg_temp.n(11),'practice','in_progress');
insert into public.attempt_questions(attempt_id,question_id,position) values(pg_temp.n(51),pg_temp.n(41),1);
select ok((select relrowsecurity from pg_catalog.pg_class where oid='storage.objects'::regclass),'SEC-02: Storage objects have RLS');
select ok((select relrowsecurity from pg_catalog.pg_class where oid='public.topic_assets'::regclass),'SEC-02: assets have RLS');
select ok(not has_column_privilege('authenticated','public.topic_assets','storage_path','select'),'SEC-02: asset paths remain hidden from the Data API');
select is((select public from storage.buckets where id='notes'),false,'SEC-02: private bucket');
select is((select file_size_limit from storage.buckets where id='notes'),
 ((select value::bigint from public.settings where key='notes_max_mb')*1024*1024),'SEC-02: limit comes from settings');
select is((select allowed_mime_types from storage.buckets where id='notes'),array['application/pdf'],'SEC-02: PDF only');
select is(private.notes_object_readable(null),false,'SEC-02: null path is safe');
select is(private.notes_object_readable('bad/bad.pdf'),false,'SEC-02: malformed path is safe');
select is(private.notes_object_readable(pg_temp.n(11)||'/'||pg_temp.n(31)||'.pdf/extra'),false,'SEC-02: extra path segments rejected');

select tests.authenticate_as('notes_student');
select is((select count(*)::int from storage.objects where bucket_id='notes'),2,'SEC-02: only ready notes in open topic readable');
select is((select count(*)::int from public.topic_assets where id=pg_temp.n(34)),0,'SEC-02: pending metadata hidden');
select is((select count(*)::int from storage.objects where bucket_id='notes' and name=blocked),0,
 'SEC-02: blocked object '||blocked)
from unnest(array[pg_temp.n(12)||'/'||pg_temp.n(33)||'.pdf',
 pg_temp.n(14)||'/'||pg_temp.n(34)||'.pdf', pg_temp.n(12)||'/'||pg_temp.n(31)||'.pdf',
 pg_temp.n(11)||'/'||pg_temp.n(36)||'.pdf','not-a-uuid/bad.pdf']) blocked;

select throws_ok($$insert into storage.objects(bucket_id,name,owner) values('notes',pg_temp.n(11)||'/'||pg_temp.n(99)||'.pdf',auth.uid())$$,'42501',null,'SEC-02: student cannot upload');
select is_empty($$update storage.objects set metadata='{}' where bucket_id='notes' returning name$$,'SEC-02: student cannot update');
-- Storage versions that protect direct DELETE require this flag; RLS still applies.
set local storage.allow_delete_query='true';
select is_empty($$delete from storage.objects where bucket_id='notes' returning name$$,'SEC-02: student cannot delete');
select throws_ok($$select public.mark_notes_opened(pg_temp.n(33))$$,'P0001','topic_locked','L-3: locked notes cannot be marked');
select throws_ok($$select public.mark_notes_opened(pg_temp.n(34))$$,'P0001','invalid_input','L-3: pending asset rejected');
select throws_ok($$select public.mark_notes_opened(pg_temp.n(36))$$,'P0001','invalid_input','L-3: video is not notes');
select throws_ok($$select public.mark_notes_opened(null)$$,'P0001','invalid_input','L-3: unknown asset rejected');
select throws_ok($$select public.get_practice_questions(pg_temp.n(11))$$,'P0001','notes_needed','L-3: practice entry gated');
select throws_ok($$select public.check_practice_answer(pg_temp.n(51),pg_temp.n(41),'B',1)$$,'P0001','notes_needed','L-3: defensive answer gate');
select is(public.get_topic(pg_temp.n(11))->'notes',jsonb_build_array(
 jsonb_build_object('asset_id',pg_temp.n(32),'title','First','subtopic_title',null,'page_count',2),
 jsonb_build_object('asset_id',pg_temp.n(31),'title','Second','subtopic_title','Section','page_count',3)),
 'L-3: get_topic lists ready notes in sort order');
select is(public.get_topic(pg_temp.n(11))->'notes_done','false'::jsonb,'L-3: notes initially incomplete');
select is((select array_agg(k order by k) from jsonb_object_keys(public.get_topic(pg_temp.n(11))-'notes'-'notes_done') k),
 array['id','practice','quiz','slug','sort_label','status','title','video_done','videos'],'L-3: topic keys include video fields');
select lives_ok($$select public.mark_notes_opened(pg_temp.n(31))$$,'L-3: first open succeeds');
select is(public.get_topic(pg_temp.n(11))->'notes_done','true'::jsonb,'L-3: opening any notes completes step');
select lives_ok($$select public.get_practice_questions(pg_temp.n(11))$$,'L-3: practice unlocked');
select lives_ok($$select public.check_practice_answer(pg_temp.n(51),pg_temp.n(41),'B',1)$$,'L-3: answer unlocked');
select is(public.get_topic(pg_temp.n(13))->'notes','[]'::jsonb,'L-3: no notes list');
select is(public.get_topic(pg_temp.n(13))->'notes_done','true'::jsonb,'L-3: no notes skips step');
select lives_ok($$select public.get_practice_questions(pg_temp.n(13))$$,'L-3: no-notes practice unchanged');
select lives_ok($$select public.get_practice_questions(pg_temp.n(14))$$,'L-3: pending-only notes do not gate');
select is(public.get_topic(pg_temp.n(14))->'notes','[]'::jsonb,'L-3: pending notes not listed');
select throws_ok(format('select public.%I(%s)',p.proname,
 (select string_agg('null::'||format_type(a,null),',') from unnest(p.proargtypes::oid[]) a)),
 'P0001','forbidden','C-3: student denied '||p.proname)
from pg_proc p where p.pronamespace='public'::regnamespace and p.proname in
 ('teacher_create_notes_asset','teacher_confirm_notes_asset','teacher_update_notes_asset','teacher_reorder_notes','teacher_delete_notes_asset');
select tests.clear_authentication();
reset role;
update public.topic_progress set notes_opened_at='2001-01-01 00:00:00+00' where user_id=tests.get_supabase_uid('notes_student') and topic_id=pg_temp.n(11);
select tests.authenticate_as('notes_student');
select is((public.mark_notes_opened(pg_temp.n(32))->>'notes_opened_at')::timestamptz,
 '2001-01-01 00:00:00+00'::timestamptz,'L-3: first timestamp preserved');
select tests.authenticate_as('notes_outsider');
select is((select count(*)::int from storage.objects where bucket_id='notes'),0,'SEC-02: no enrollment denies reads');
select throws_ok($$select public.mark_notes_opened(pg_temp.n(31))$$,'P0001','not_enrolled','L-3: no enrollment denies mark');
select tests.clear_authentication();
reset role;
insert into public.enrollments(user_id,course_id,status,starts_at,expires_at)
values(tests.get_supabase_uid('notes_outsider'),pg_temp.n(1),'active',now()-interval '2 days',now()-interval '1 day');
select tests.authenticate_as('notes_outsider');
select is((select count(*)::int from storage.objects where bucket_id='notes'),0,'SEC-02: expired access denies reads');
select throws_ok($$select public.mark_notes_opened(pg_temp.n(31))$$,'P0001','access_expired','L-3: expired access denies mark');


select tests.authenticate_as('notes_teacher');
select is((select count(*)::int from storage.objects where bucket_id='notes' and name in (
 pg_temp.n(11)||'/'||pg_temp.n(31)||'.pdf',pg_temp.n(14)||'/'||pg_temp.n(34)||'.pdf')),2,'SEC-02: teacher sees ready and pending');
select throws_ok($$select public.teacher_create_notes_asset(pg_temp.n(11),pg_temp.n(22),'Wrong',2)$$,'P0001','invalid_input','C-3: subtopic must belong to topic');
select throws_ok($$select public.teacher_create_notes_asset(pg_temp.n(11),null,' ',0)$$,'P0001','invalid_input','C-3: invalid title/pages rejected');
select set_config('test.notes_created',public.teacher_create_notes_asset(pg_temp.n(11),null,'New',4)::text,true);
select is((current_setting('test.notes_created')::jsonb)->>'path',pg_temp.n(11)||'/'||((current_setting('test.notes_created')::jsonb)->>'asset_id')||'.pdf','C-3: canonical path');
select throws_ok($$select public.teacher_confirm_notes_asset((current_setting('test.notes_created')::jsonb->>'asset_id')::uuid)$$,'P0001','invalid_input','C-3: confirmation requires object');
select tests.clear_authentication();
reset role;
select is((select ready from public.topic_assets where id=(current_setting('test.notes_created')::jsonb->>'asset_id')::uuid),false,'C-3: creation is pending');
-- Fixture upload as postgres, as required by Storage policy tests.
insert into storage.objects(bucket_id,name,owner) values ('notes',current_setting('test.notes_created')::jsonb->>'path',tests.get_supabase_uid('notes_teacher'));
select tests.authenticate_as('notes_teacher');
select lives_ok($$select public.teacher_confirm_notes_asset((current_setting('test.notes_created')::jsonb->>'asset_id')::uuid)$$,'C-3: confirm after upload');
select lives_ok($$select public.teacher_confirm_notes_asset((current_setting('test.notes_created')::jsonb->>'asset_id')::uuid)$$,'C-3: repeated confirmation is a no-op');
select lives_ok($$select public.teacher_update_notes_asset((current_setting('test.notes_created')::jsonb->>'asset_id')::uuid,'Renamed',pg_temp.n(21))$$,'C-3: rename and tag');
select is((select title||':'||subtopic_id::text from public.topic_assets
 where id=(current_setting('test.notes_created')::jsonb->>'asset_id')::uuid),
 'Renamed:'||pg_temp.n(21),'C-3: metadata update persisted');
select is((select ready from public.topic_assets
 where id=(current_setting('test.notes_created')::jsonb->>'asset_id')::uuid),true,'C-3: confirmation persisted');

select throws_ok($$select public.teacher_update_notes_asset(pg_temp.n(31),'Wrong',pg_temp.n(22))$$,'P0001','invalid_input','C-3: update validates parent');
select throws_ok($$select public.teacher_reorder_notes(pg_temp.n(11),array[pg_temp.n(31)])$$,'P0001','invalid_input','C-3: reorder requires full set');
select throws_ok($$select public.teacher_reorder_notes(pg_temp.n(11),array[pg_temp.n(31),pg_temp.n(31)])$$,'P0001','invalid_input','C-3: duplicates rejected');
select lives_ok($$select public.teacher_reorder_notes(pg_temp.n(11),array[(current_setting('test.notes_created')::jsonb->>'asset_id')::uuid,pg_temp.n(31),pg_temp.n(32)])$$,'C-3: reorder succeeds');
select results_eq($$update storage.objects set metadata='{"test":true}' where bucket_id='notes' and name=current_setting('test.notes_created')::jsonb->>'path' returning name$$,
 $$select current_setting('test.notes_created')::jsonb->>'path'$$,'SEC-02: teacher may update object');
select results_eq($$delete from storage.objects where bucket_id='notes' and name=current_setting('test.notes_created')::jsonb->>'path' returning name$$,
 $$select current_setting('test.notes_created')::jsonb->>'path'$$,'SEC-02: teacher may delete object');
select lives_ok($$select public.teacher_delete_notes_asset((current_setting('test.notes_created')::jsonb->>'asset_id')::uuid)$$,'C-3: delete metadata after object');
insert into storage.objects(bucket_id,name,owner) values('notes',pg_temp.n(11)||'/'||pg_temp.n(99)||'.pdf',auth.uid());
select is((select count(*)::int from storage.objects where name=pg_temp.n(11)||'/'||pg_temp.n(99)||'.pdf'),1,'SEC-02: teacher may upload');
select tests.clear_authentication();
reset role;
select is((select count(*)::int from public.audit_log where actor=tests.get_supabase_uid('notes_teacher') and action like 'notes.%'),5,'C-3: all five writes audited');
select is((select count(*)::int from public.topic_assets where id=(current_setting('test.notes_created')::jsonb->>'asset_id')::uuid),0,'C-3: asset deleted');
select is((select sort from public.topic_assets where id=pg_temp.n(31)),2,'C-3: reorder persisted');
select ok(not has_function_privilege('anon',p.oid,'execute'),'L-3: anon denied '||p.proname)
from pg_proc p where p.pronamespace='public'::regnamespace and p.proname in
 ('mark_notes_opened','teacher_create_notes_asset','teacher_confirm_notes_asset','teacher_update_notes_asset','teacher_reorder_notes','teacher_delete_notes_asset');

select is((select count(*)::int from pg_proc p where p.pronamespace='public'::regnamespace and p.proname in
 ('mark_notes_opened','teacher_create_notes_asset','teacher_confirm_notes_asset','teacher_update_notes_asset','teacher_reorder_notes','teacher_delete_notes_asset')),6,'L-3: all six RPCs exist');
set local role authenticated;
select throws_ok($$select public.mark_notes_opened(null)$$,'P0001','not_authenticated','L-3: mark requires auth uid');
select throws_ok($$select public.teacher_confirm_notes_asset(null)$$,'P0001','not_authenticated','C-3: teacher RPC requires auth uid');
reset role;
select * from finish();
rollback;
