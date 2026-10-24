-- LRN-02 / SEC-01 / C-2. From supabase/templates/test.sql; tests precede the migration.
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();
create function pg_temp.v(i int) returns uuid language sql immutable set search_path='' as $fn$
 select ('40000000-0000-0000-0000-' || pg_catalog.lpad(i::text,12,'0'))::uuid;
$fn$;
grant execute on function pg_temp.v(int) to authenticated;
select tests.create_supabase_user('video_teacher');
select tests.create_supabase_user('video_student');
select tests.create_supabase_user('video_other');
select tests.create_supabase_user('video_finished');
select tests.create_supabase_user('video_passed');
select tests.create_supabase_user('video_rate');
update public.profiles set role='teacher' where id=tests.get_supabase_uid('video_teacher');
update public.profiles set full_name='Video Student' where id=tests.get_supabase_uid('video_student');
update public.settings set value='3' where key='practice_min';
update public.settings set value='100' where key='video_storage_cap_mb';
update public.settings set value='false' where key='device_header_required';
insert into public.courses(id,code,title,slug,is_published)
values(pg_temp.v(1),'SAT','Video tests','video-tests',true);
insert into public.topics(id,course_id,title,slug,sort,is_published,is_free_preview) values
 (pg_temp.v(11),pg_temp.v(1),'Open','video-open',1,true,false),
 (pg_temp.v(12),pg_temp.v(1),'Locked','video-locked',2,true,false),
 (pg_temp.v(13),pg_temp.v(1),'No video','video-none',3,true,true);
insert into public.subtopics(id,topic_id,title) values
 (pg_temp.v(21),pg_temp.v(11),'Section'),(pg_temp.v(22),pg_temp.v(12),'Other'),
 (pg_temp.v(23),pg_temp.v(13),'No video');
insert into public.enrollments(user_id,course_id,status,starts_at,expires_at)
select tests.get_supabase_uid(name),pg_temp.v(1),'active',now(),now()+interval '1 day'
from unnest(array['video_student','video_finished','video_passed','video_rate']) name;
insert into public.topic_progress(user_id,topic_id,practice_count,quiz_passed_at) values
 (tests.get_supabase_uid('video_finished'),pg_temp.v(11),3,null),
 (tests.get_supabase_uid('video_passed'),pg_temp.v(11),0,now());
insert into public.questions(id,topic_id,subtopic_id,type,difficulty,stem_md,pool,status)
select pg_temp.v(30+i),pg_temp.v(10+i),pg_temp.v(20+i),'mcq','M','One?','practice','published'
from unnest(array[1,3]) i;
insert into public.question_choices(question_id,label,body_md)
select pg_temp.v(30+i),label,'Choice' from unnest(array[1,3]) i cross join unnest(array['A','B']) label;
insert into private.question_keys(question_id,correct_answer,explanation_md)
select pg_temp.v(30+i),'{"choice":"B"}','Two.' from unnest(array[1,3]) i;

select tests.authenticate_as('video_teacher');
select is(public.teacher_video_quota(),'{"used_mb":0,"cap_mb":100}'::jsonb,'C-2: initial quota');
select set_config('test.video_a',public.teacher_create_video_asset(pg_temp.v(11),pg_temp.v(21),' First ',100,60)->>'asset_id',true);
select is(public.teacher_video_quota(),'{"used_mb":60,"cap_mb":100}'::jsonb,'C-2: unready reservation counts under cap');
select set_config('test.video_b',public.teacher_create_video_asset(pg_temp.v(11),null,'Second',100,40)->>'asset_id',true);
select is(public.teacher_video_quota(),'{"used_mb":100,"cap_mb":100}'::jsonb,'C-2: exactly at cap allowed');
select is(public.teacher_create_video_asset(pg_temp.v(11),null,'Over',100,1),
 '{"ok":false,"error":"quota_exceeded","used_mb":100,"cap_mb":100}'::jsonb,'C-2: one MB over returned, not raised');
select throws_ok('select public.teacher_confirm_video_asset(current_setting(''test.video_a'')::uuid,''bad'')','P0001','invalid_input','C-2: key must be 32 hex characters');
select throws_ok('select public.teacher_confirm_video_asset(current_setting(''test.video_a'')::uuid,repeat(''z'',32))','P0001','invalid_input','C-2: nonhex key refused');
select is(public.teacher_confirm_video_asset(current_setting('test.video_a')::uuid,'00112233445566778899aabbccddeeff'),'{"ok":true}'::jsonb,'C-2: confirm ready video');
select is(public.teacher_confirm_video_asset(current_setting('test.video_a')::uuid,'00112233445566778899aabbccddeeff'),'{"ok":true}'::jsonb,'C-2: confirmation retry is idempotent');
select throws_ok('select public.teacher_confirm_video_asset(current_setting(''test.video_a'')::uuid,repeat(''f'',32))','P0001','invalid_input','SEC-01: confirmation cannot rotate a ready key');
select set_config('test.video_y',public.teacher_add_youtube_video(pg_temp.v(11),null,'YouTube','abcdefgh_-1',100)->>'asset_id',true);
select throws_ok('select public.teacher_add_youtube_video(pg_temp.v(11),null,''Bad'',''bad'',100)','P0001','invalid_input','C-2: YouTube ID validated');
select throws_ok('select public.teacher_create_video_asset(pg_temp.v(11),pg_temp.v(22),''Wrong subtopic'',100,0)','P0001','invalid_input','C-2: subtopic belongs to topic');
select throws_ok('select public.teacher_create_video_asset(pg_temp.v(11),null,''Bad duration'',0,0)','P0001','invalid_input','C-2: positive duration required');
select throws_ok('select public.teacher_create_video_asset(pg_temp.v(11),null,''Bad size'',100,-1)','P0001','invalid_input','C-2: negative size refused');
select is(public.teacher_update_video(current_setting('test.video_y')::uuid,' Renamed ',pg_temp.v(21)),'{"ok":true}'::jsonb,'C-2: rename and move within topic');
select throws_ok('select public.teacher_update_video(current_setting(''test.video_y'')::uuid,''Wrong'',pg_temp.v(22))','P0001','invalid_input','C-2: update cannot cross topics');
select is(public.teacher_reorder_videos(pg_temp.v(11),array[current_setting('test.video_y')::uuid,current_setting('test.video_b')::uuid,current_setting('test.video_a')::uuid]),'{"ok":true}'::jsonb,'C-2: reorder complete set including pending');
select throws_ok('select public.teacher_reorder_videos(pg_temp.v(11),array[current_setting(''test.video_a'')::uuid])','P0001','invalid_input','C-2: partial reorder rejected');
select is(public.teacher_list_videos(pg_temp.v(11))->0->>'title','Renamed','C-2: teacher list follows order');
select is(jsonb_array_length(public.teacher_list_videos(pg_temp.v(11))),3,'C-2: teacher list includes pending');
select is(public.teacher_video_prefix(current_setting('test.video_a')::uuid)->>'r2_prefix','videos/'||current_setting('test.video_a'),'C-2: canonical R2 prefix');
select tests.clear_authentication();
reset role;
select ok(not has_function_privilege(r,'public.service_video_key(uuid)','execute'),'SEC-01: key execution denied to '||r)
from unnest(array['anon','authenticated']) r;
select ok(has_function_privilege('service_role','public.service_video_key(uuid)','execute'),'SEC-01: service role has key execution');
set local role service_role;
select is(public.service_video_key(current_setting('test.video_a')::uuid),
 jsonb_build_object('key_hex','00112233445566778899aabbccddeeff','r2_prefix','videos/'||current_setting('test.video_a')),
 'SEC-01: service role receives key hex and prefix');
select is(public.service_video_key('40000000-0000-0000-0000-000000000099'::uuid),null::jsonb,
 'SEC-01: missing key returns SQL null');
reset role;
set local role anon;
select throws_ok('select public.service_video_key(current_setting(''test.video_a'')::uuid)','42501',null,'SEC-01: anon key invocation denied');
reset role;
select ok(not exists(select 1 from public.audit_log where actor=tests.get_supabase_uid('video_teacher')
 and (diff::text like '%key_hex%' or diff::text like '%00112233445566778899aabbccddeeff%')),'SEC-01: audits contain no key');
select ok(has_column_privilege('authenticated','public.topic_assets',c,'select'),'LRN-02: metadata column grant '||c)
from unnest(array['provider','size_mb','duration_s']) c;
insert into public.topic_assets(id,topic_id,kind,title,duration_s,provider,size_mb,ready)
values(pg_temp.v(41),pg_temp.v(12),'video','Locked video',100,'youtube',0,true);
insert into public.topic_assets(id,topic_id,kind,title,page_count,ready)
values(pg_temp.v(42),pg_temp.v(11),'notes','Notes after video',2,true);

select tests.authenticate_as('video_other');
select throws_ok('select public.video_playback_grant(current_setting(''test.video_a'')::uuid)','P0001','forbidden','SEC-01: no enrollment');
select tests.authenticate_as('video_student');
select throws_ok('select public.service_video_key(current_setting(''test.video_a'')::uuid)','42501',null,'SEC-01: student key invocation denied');
select throws_ok('select public.video_playback_grant(pg_temp.v(41))','P0001','topic_locked','SEC-01: locked topic');
select throws_ok('select public.video_playback_grant(current_setting(''test.video_b'')::uuid)','P0001','forbidden','SEC-01: unready hidden');
select throws_ok('select public.video_playback_grant(pg_temp.v(99))','P0001','forbidden','SEC-01: unknown hidden');
select is((select count(*)::int from public.topic_assets where id=current_setting('test.video_b')::uuid),0,'SEC-01: RLS hides unready video');
select is(public.video_playback_grant(current_setting('test.video_y')::uuid),
 '{"ok":true,"provider":"youtube","youtube_id":"abcdefgh_-1","resume_s":0}'::jsonb,'SEC-01: YouTube grant has no protected fields');
select is(public.video_playback_grant(current_setting('test.video_a')::uuid),jsonb_build_object(
 'ok',true,'provider','r2_hls','asset_id',current_setting('test.video_a')::uuid,'user_id',auth.uid(),
 'watermark',jsonb_build_object('name','Video Student','short_id',upper(left(replace(auth.uid()::text,'-',''),6))),
 'key_ttl_s',300,'playlist_ttl_s',14400,'resume_s',0),'SEC-01: protected grant shape');
select set_config('request.headers','{"x-device-id":"revoked_video_device"}',true);
select throws_ok('select public.video_playback_grant(current_setting(''test.video_a'')::uuid)','P0001','forbidden','SEC-01: revoked device refused');
select set_config('request.headers','{}',true);
select throws_ok('select public.get_practice_questions(pg_temp.v(11))','P0001','video_needed','LRN-02: video gates practice first');
select is(public.save_video_progress(current_setting('test.video_a')::uuid,0,0,0),'{"pct":0,"done":false}'::jsonb,'LRN-02: empty interval adds no coverage');
select is(public.save_video_progress(current_setting('test.video_a')::uuid,-5,20,-10),'{"pct":20,"done":false}'::jsonb,'LRN-02: lower clamp');
select is(public.video_playback_grant(current_setting('test.video_a')::uuid)->'resume_s','0'::jsonb,'LRN-02: lower position clamp');
select is(public.save_video_progress(current_setting('test.video_a')::uuid,10,35,35)->'pct','35'::jsonb,'LRN-02: overlapping ranges count once');
select is(public.save_video_progress(current_setting('test.video_a')::uuid,60,80,80)->'pct','55'::jsonb,'LRN-02: disjoint ranges sum');
select is(public.save_video_progress(current_setting('test.video_a')::uuid,80,110,120)->'pct','75'::jsonb,'LRN-02: upper clamp');
select is(public.video_playback_grant(current_setting('test.video_a')::uuid)->'resume_s','100'::jsonb,'LRN-02: upper position clamp');
select throws_ok('select public.get_practice_questions(pg_temp.v(11))','P0001','video_needed','LRN-02: 75 percent remains gated');
select throws_ok('select public.save_video_progress(current_setting(''test.video_a'')::uuid,40,30,40)','P0001','invalid_input','LRN-02: reversed range rejected');
select throws_ok('select public.save_video_progress(current_setting(''test.video_a'')::uuid,0,36,36)','P0001','invalid_input','LRN-02: oversized heartbeat rejected');
select is(public.save_video_progress(current_setting('test.video_a')::uuid,35,40,40),'{"pct":80,"done":true}'::jsonb,'LRN-02: threshold at 80');
select throws_ok('select public.get_practice_questions(pg_temp.v(11))','P0001','video_needed','LRN-02: every ready video required');
select is(public.save_video_progress(current_setting('test.video_y')::uuid,0,35,35)->'pct','35'::jsonb,'LRN-02: YouTube progress supported');
select is(public.save_video_progress(current_setting('test.video_y')::uuid,35,70,70)->'pct','70'::jsonb,'LRN-02: progress accumulates');
select is(public.save_video_progress(current_setting('test.video_y')::uuid,70,80,80)->'done','true'::jsonb,'LRN-02: final ready video done');
select throws_ok('select public.get_practice_questions(pg_temp.v(11))','P0001','notes_needed','LRN-02: notes gate remains after video completion');
select lives_ok('select public.mark_notes_opened(pg_temp.v(42))','LRN-02: open notes after videos');
select lives_ok('select public.get_practice_questions(pg_temp.v(11))','LRN-02: practice after all videos reach 80');
select is(public.video_playback_grant(current_setting('test.video_y')::uuid)->'resume_s','80'::jsonb,'LRN-02: playback resumes');
select is(public.get_topic(pg_temp.v(11))->'video_done','true'::jsonb,'LRN-02: get_topic gate agrees');
select is(jsonb_array_length(public.get_topic(pg_temp.v(11))->'videos'),2,'LRN-02: get_topic ready videos only');
select is(public.get_topic(pg_temp.v(11))->'videos'->0,jsonb_build_object('asset_id',current_setting('test.video_y')::uuid,
 'title','Renamed','subtopic_title','Section','duration_s',100,'provider','youtube','pct',80,'last_position_s',80),'LRN-02: topic video fields and ordering');
select is(public.get_topic(pg_temp.v(13))->'video_done','true'::jsonb,'LRN-02: no video skips gate');
select lives_ok('select public.get_practice_questions(pg_temp.v(13))','LRN-02: no video practice unaffected');
select throws_ok(sql,'P0001','forbidden','C-2: student denied '||name) from (values
 ('quota','select public.teacher_video_quota()'),
 ('create','select public.teacher_create_video_asset(null,null,null,null,null)'),
 ('confirm','select public.teacher_confirm_video_asset(null,null)'),
 ('youtube','select public.teacher_add_youtube_video(null,null,null,null,null)'),
 ('update','select public.teacher_update_video(null,null,null)'),
 ('reorder','select public.teacher_reorder_videos(null,null)'),
 ('list','select public.teacher_list_videos(null)'),
 ('prefix','select public.teacher_video_prefix(null)'),
 ('delete','select public.teacher_delete_video(null)')) f(name,sql);
select tests.authenticate_as('video_finished');
select is(public.get_topic(pg_temp.v(11))->'video_done','true'::jsonb,'LRN-02: finished practice exemption');
select lives_ok('select public.get_practice_questions(pg_temp.v(11))','LRN-02: later videos do not relock finished practice');
select tests.authenticate_as('video_passed');
select is(public.get_topic(pg_temp.v(11))->'video_done','true'::jsonb,'LRN-02: passed quiz exemption');
select lives_ok('select public.get_practice_questions(pg_temp.v(11))','LRN-02: passed quiz keeps practice');
select tests.clear_authentication();
reset role;
select is((select watched_ranges from public.video_progress where user_id=tests.get_supabase_uid('video_student')
 and asset_id=current_setting('test.video_a')::uuid),array[int4range(0,40),int4range(60,100)],'LRN-02: canonical merged ranges persisted');
insert into public.devices(user_id,device_fingerprint,revoked_at)
values(tests.get_supabase_uid('video_student'),'revoked_video_device',now());
select tests.authenticate_as('video_student');
select set_config('request.headers','{"x-device-id":"revoked_video_device"}',true);
select throws_ok('select public.video_playback_grant(current_setting(''test.video_a'')::uuid)','P0001','forbidden','SEC-01: recorded revoked device refused');
select set_config('request.headers','{}',true);
select tests.clear_authentication();
reset role;
update public.settings set value='1' where key='rate_video_otp_per_min';
select tests.authenticate_as('video_rate');
select is(public.video_playback_grant(current_setting('test.video_y')::uuid)->'ok','true'::jsonb,'SEC-01: first OTP allowed');
select is(public.video_playback_grant(current_setting('test.video_y')::uuid),'{"ok":false,"error":"rate_limited"}'::jsonb,'SEC-01: OTP quota returned');
select is(public.video_playback_grant(current_setting('test.video_y')::uuid),'{"ok":false,"error":"rate_limited"}'::jsonb,'SEC-01: denied OTP still counts');
select tests.clear_authentication();
reset role;
select is((select count from private.rate_limits where key='video_playback_grant:'||tests.get_supabase_uid('video_rate')),3,'SEC-01: quota increments persist');
insert into public.video_chapters(asset_id,subtopic_id,start_s,label)
values(current_setting('test.video_a')::uuid,pg_temp.v(21),0,'Start');
select tests.authenticate_as('video_teacher');
select is(public.teacher_delete_video(current_setting('test.video_a')::uuid),'{"ok":true}'::jsonb,'C-2: delete video dependencies');
select is(public.teacher_video_quota(),'{"used_mb":40,"cap_mb":100}'::jsonb,'C-2: delete releases reserved quota');
select tests.clear_authentication();
reset role;
select is((select count(*)::int from private.video_keys where asset_id=current_setting('test.video_a')::uuid),0,'C-2: key deleted');
select is((select count(*)::int from public.video_progress where asset_id=current_setting('test.video_a')::uuid),0,'C-2: progress deleted');
select is((select count(*)::int from public.video_chapters where asset_id=current_setting('test.video_a')::uuid),0,'C-2: chapters deleted');
select ok(not has_function_privilege('anon',p.oid,'execute'),'SEC-01: anon denied '||p.proname)
from pg_proc p where p.pronamespace='public'::regnamespace and p.proname in
 ('teacher_video_quota','teacher_create_video_asset','teacher_confirm_video_asset','teacher_add_youtube_video',
 'teacher_update_video','teacher_reorder_videos','teacher_list_videos','teacher_video_prefix','teacher_delete_video',
 'video_playback_grant','save_video_progress');
select ok(has_function_privilege('authenticated',p.oid,'execute'),'SEC-01: authenticated granted '||p.proname)
from pg_proc p where p.pronamespace='public'::regnamespace and p.proname in
 ('teacher_video_quota','teacher_create_video_asset','teacher_confirm_video_asset','teacher_add_youtube_video',
 'teacher_update_video','teacher_reorder_videos','teacher_list_videos','teacher_video_prefix','teacher_delete_video',
 'video_playback_grant','save_video_progress');
set local role authenticated;
select throws_ok('select public.video_playback_grant(null)','P0001','not_authenticated','SEC-01: grant requires auth');
select throws_ok('select public.save_video_progress(null,0,1,1)','P0001','not_authenticated','LRN-02: progress requires auth');
reset role;
select * from finish();
rollback;
