-- CRS-06: from supabase/templates/test.sql. All fixtures roll back.
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

create function pg_temp.fp(i int) returns uuid language sql immutable set search_path='' as $$
 select ('47000000-0000-0000-0000-' || pg_catalog.lpad(i::text,12,'0'))::uuid;
$$;
grant execute on function pg_temp.fp(int) to authenticated;
select tests.create_supabase_user(u) from unnest(array['fp_preview','fp_expired','fp_inactive','fp_elsewhere','fp_full']) u;
update public.settings set value='1' where key in ('practice_min','homework_size','quiz_size');
update public.settings set value='false' where key='device_header_required';
insert into public.courses(id,code,title,slug,is_published) values
 (pg_temp.fp(1),'SAT','Preview','fp-preview',true),
 (pg_temp.fp(2),'EST','No free topics','fp-none',true);
insert into public.topics(id,course_id,title,slug,sort,is_published,is_free_preview) values
 (pg_temp.fp(11),pg_temp.fp(1),'Free','fp-free',1,true,true),
 (pg_temp.fp(12),pg_temp.fp(1),'Paid','fp-paid',2,true,false),
 (pg_temp.fp(13),pg_temp.fp(1),'Later','fp-later',3,true,false),
 (pg_temp.fp(14),pg_temp.fp(2),'First paid','fp-none-first',1,true,false),
 (pg_temp.fp(15),pg_temp.fp(2),'Second paid','fp-none-second',2,true,false),
 (pg_temp.fp(16),pg_temp.fp(1),'Unpublished free','fp-draft',4,false,true);
insert into public.subtopics(id,topic_id,title) values(pg_temp.fp(21),pg_temp.fp(11),'Section');
insert into public.enrollments(user_id,course_id,status,starts_at,expires_at) values
 (tests.get_supabase_uid('fp_expired'),pg_temp.fp(1),'active',now()-interval '2 days',now()-interval '1 day'),
 (tests.get_supabase_uid('fp_inactive'),pg_temp.fp(1),'expired',now()-interval '2 days',now()+interval '1 day'),
 (tests.get_supabase_uid('fp_elsewhere'),pg_temp.fp(2),'active',now(),now()+interval '1 day'),
 (tests.get_supabase_uid('fp_full'),pg_temp.fp(1),'active',now(),now()+interval '1 day');
insert into public.topic_progress(user_id,topic_id,unlocked_at)
values(tests.get_supabase_uid('fp_elsewhere'),pg_temp.fp(13),now());
insert into public.questions(id,topic_id,subtopic_id,type,difficulty,stem_md,pool,status) values
 (pg_temp.fp(31),pg_temp.fp(11),pg_temp.fp(21),'mcq','E','Practice','practice','published'),
 (pg_temp.fp(32),pg_temp.fp(11),pg_temp.fp(21),'mcq','E','Quiz','quiz','published');
insert into public.question_choices(question_id,label,body_md)
select q,l,'Choice '||l from unnest(array[pg_temp.fp(31),pg_temp.fp(32)]) q cross join unnest(array['A','B']) l;
insert into private.question_keys(question_id,correct_answer,explanation_md)
select q,'{"choice":"B"}','Worked solution' from unnest(array[pg_temp.fp(31),pg_temp.fp(32)]) q;
insert into public.topic_assets(id,topic_id,kind,title,storage_path,page_count,ready) values
 (pg_temp.fp(41),pg_temp.fp(11),'notes','Free notes',pg_temp.fp(11)||'/'||pg_temp.fp(41)||'.pdf',1,true),
 (pg_temp.fp(42),pg_temp.fp(12),'notes','Private paid notes',pg_temp.fp(12)||'/'||pg_temp.fp(42)||'.pdf',1,true);
insert into public.topic_assets(id,topic_id,kind,title,provider,video_provider_id,duration_s,ready) values
 (pg_temp.fp(43),pg_temp.fp(11),'video','Free video','youtube','abcdefghijk',10,true),
 (pg_temp.fp(44),pg_temp.fp(12),'video','Private paid video','youtube','abcdefghijk',10,true);
insert into storage.objects(bucket_id,name,owner)
select 'notes',a.storage_path,tests.get_supabase_uid('fp_full') from public.topic_assets a
where a.id in (pg_temp.fp(41),pg_temp.fp(42));
create temp table fp_ctx(k text primary key,v jsonb);
grant select,insert on fp_ctx to authenticated;
create function pg_temp.fp_att(k text) returns uuid language sql set search_path='' as $$
 select (c.v->>'attempt_id')::uuid from pg_temp.fp_ctx c where c.k=$1;
$$;
grant execute on function pg_temp.fp_att(text) to authenticated;

select tests.authenticate_as('fp_preview');
select throws_ok('select public.get_course_map()','P0001','not_enrolled','CRS-06: slugless map without enrolment still not_enrolled');
select is(public.get_course_map('fp-preview')->>'access','preview','CRS-06: non-enrolled can run free topic loop - preview map');
select is(public.get_course_map('fp-preview')#>>'{units,0,topics,0,status}','open','CRS-06: free topic is open');
select is(public.get_course_map('fp-preview')#>>'{units,0,topics,1,status}','locked','CRS-06: non-free topic refused - map status');
select is(public.get_course_map('fp-preview')#>>'{units,0,topics,1,locked_reason}','needs_access','CRS-06: non-free topic refused - map reason');
select throws_ok('select public.start_quiz(pg_temp.fp(12))','P0001','not_enrolled','CRS-06: non-free topic refused');
select throws_ok('select public.get_topic(pg_temp.fp(12))','P0001','not_enrolled','CRS-06: get_topic does not leak locked assets');
select throws_ok('select public.get_topic(pg_temp.fp(16))','P0001','invalid_input','CRS-06: unpublished free topic refused');
select is(public.get_course_map('fp-none')->>'access','preview','CRS-06: preview with no free topic - access');
select is((select count(*)::int from jsonb_array_elements(public.get_course_map('fp-none')->'units') u,
 jsonb_array_elements(u->'topics') t where t->>'status'='locked' and t->>'locked_reason'='needs_access'),2,
 'CRS-06: preview with no free topic - every topic locked');
select is((select count(*)::int from storage.objects where bucket_id='notes' and name=pg_temp.fp(11)||'/'||pg_temp.fp(41)||'.pdf'),1,
 'CRS-06: notes readable only for free topic - allowed');
select is((select count(*)::int from storage.objects where bucket_id='notes' and name=pg_temp.fp(12)||'/'||pg_temp.fp(42)||'.pdf'),0,
 'CRS-06: notes readable only for free topic - denied');
select is(public.video_playback_grant(pg_temp.fp(43))->>'ok','true','CRS-06: non-enrolled can run free topic loop - video grant');
select lives_ok('select public.save_video_progress(pg_temp.fp(43),0,10,10)','CRS-06: preview video progress');
select lives_ok('select public.mark_notes_opened(pg_temp.fp(41))','CRS-06: preview notes progress');
select lives_ok($$insert into fp_ctx values('practice',public.get_practice_questions(pg_temp.fp(11)))$$,
 'CRS-06: non-enrolled can run free topic loop - practice');
select lives_ok($$select public.check_practice_answer(pg_temp.fp_att('practice'),pg_temp.fp(31),'B',1)$$,
 'CRS-06: non-enrolled can run free topic loop - practice answer');
select lives_ok($$insert into fp_ctx values('homework',public.start_homework(pg_temp.fp(11)))$$,
 'CRS-06: non-enrolled can run free topic loop - homework start');
select lives_ok($$select public.save_answer(pg_temp.fp_att('homework'),pg_temp.fp(31),'B',0,false,null,1)$$,'CRS-06: preview homework answer');
select lives_ok($$select public.submit_attempt(pg_temp.fp_att('homework'))$$,'CRS-06: non-enrolled can run free topic loop - homework submit');
select lives_ok($$select public.get_attempt_review(pg_temp.fp_att('homework'))$$,'CRS-06: preview homework review');
select lives_ok($$insert into fp_ctx values('quiz',public.start_quiz(pg_temp.fp(11)))$$,
 'CRS-06: non-enrolled can run free topic loop - quiz start');
select ok(not exists(select 1 from fp_ctx where k in ('quiz','practice','homework')
 and (v::text like '%explanation%' or v::text like '%"key"%')),'CRS-06: starts never expose keys');
select lives_ok($$select public.save_answer(pg_temp.fp_att('quiz'),pg_temp.fp(32),'B',0,false,null,1)$$,'CRS-06: preview quiz answer');
select lives_ok($$insert into fp_ctx values('report',public.submit_attempt(pg_temp.fp_att('quiz')))$$,
 'CRS-06: non-enrolled can run free topic loop - quiz submit');
select is((select v->>'passed' from fp_ctx where k='report'),'true','CRS-06: free topic quiz passed');
select is((select v->>'next_needs_access' from fp_ctx where k='report'),'true','CRS-06: next_needs_access true in preview');
select is(public.get_course_map('fp-preview')#>>'{units,0,topics,1,status}','locked','CRS-06: preview quiz pass cannot open paid next topic');
select is(public.get_course_map('fp-preview')#>>'{units,0,topics,1,locked_reason}','needs_access','CRS-06: paid next topic still needs access after preview pass');
select lives_ok($$select public.get_attempt_review(pg_temp.fp_att('quiz'))$$,'CRS-06: non-enrolled can run free topic loop - quiz review');
select is(public.submit_attempt(pg_temp.fp_att('quiz')),(select v from fp_ctx where k='report'),'CRS-06: quiz result replay unchanged');

select tests.authenticate_as('fp_elsewhere');
select is(public.get_course_map('fp-preview')->>'access','preview','CRS-06: enrolled elsewhere still previews');
select is(public.get_course_map('fp-preview')#>>'{units,0,topics,2,status}','locked','CRS-06: teacher unlock cannot open paid preview topic');
select lives_ok('select public.get_topic(pg_temp.fp(11))','CRS-06: enrolled elsewhere can read free topic');
select tests.authenticate_as('fp_expired');
select throws_ok($$select public.get_course_map('fp-preview')$$,'P0001','access_expired','CRS-06: expired enrolment is not preview - map');
select tests.clear_authentication();
reset role;
select throws_ok($$select private.practice_access(tests.get_supabase_uid('fp_expired'),pg_temp.fp(11))$$,
 'P0001','access_expired','CRS-06: expired enrolment is not preview - practice_access');
select tests.authenticate_as('fp_expired');
select is((select count(*)::int from storage.objects where bucket_id='notes' and name=pg_temp.fp(11)||'/'||pg_temp.fp(41)||'.pdf'),0,'CRS-06: expired enrolment cannot read free notes');
select tests.authenticate_as('fp_inactive');
select throws_ok($$select public.get_course_map('fp-preview')$$,'P0001','access_expired','CRS-06: inactive enrolment is not preview');
select throws_ok('select public.get_topic(pg_temp.fp(11))','P0001','access_expired','CRS-06: inactive enrolment cannot read free topic');
select tests.clear_authentication();
reset role;
insert into public.enrollments(user_id,course_id,status,starts_at,expires_at)
values(tests.get_supabase_uid('fp_preview'),pg_temp.fp(1),'active',now(),now()+interval '1 day');
select tests.authenticate_as('fp_preview');
select is(public.get_course_map('fp-preview')->>'access','full','CRS-06: progress carries over after enrolment - full access');
select is(public.get_course_map('fp-preview')#>>'{units,0,topics,0,status}','completed','CRS-06: progress carries over after enrolment - completed');
select is(public.get_course_map('fp-preview')#>>'{units,0,topics,1,status}','open','CRS-06: progress carries over after enrolment - next open');
select is(public.get_course_map('fp-preview')#>>'{units,0,topics,2,locked_reason}','previous_quiz','CRS-06: enrolled lock reason preserved');
select lives_ok($$insert into fp_ctx values('full_quiz',public.start_quiz(pg_temp.fp(11)))$$,'CRS-06: enrolled retake');
select public.save_answer(pg_temp.fp_att('full_quiz'),pg_temp.fp(32),'B',0,false,null,1);
select is(coalesce(public.submit_attempt(pg_temp.fp_att('full_quiz'))->>'next_needs_access','false'),'false','CRS-06: next_needs_access false when enrolled');
select tests.clear_authentication();
reset role;
select ok(not has_function_privilege('authenticated','private.topic_states(uuid,uuid)','execute'),'CRS-06: topic_states stays private');
select ok(not has_function_privilege('anon','public.get_course_map(text)','execute'),'CRS-06: anon cannot preview');
select * from finish();
rollback;
