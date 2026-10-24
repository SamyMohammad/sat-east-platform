-- C-2 / SEC-01. From supabase/templates/test.sql.
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();
create function pg_temp.u(i int) returns uuid language sql immutable set search_path='' as $fn$
 select ('41000000-0000-0000-0000-' || pg_catalog.lpad(i::text,12,'0'))::uuid;
$fn$;
grant execute on function pg_temp.u(int) to authenticated;
select tests.create_supabase_user('upload_teacher');
select tests.create_supabase_user('upload_student');
update public.profiles set role='teacher' where id=tests.get_supabase_uid('upload_teacher');
insert into public.courses(id,code,title,slug) values(pg_temp.u(1),'SAT','Upload tests','upload-tests');
insert into public.topics(id,course_id,title,slug) values(pg_temp.u(2),pg_temp.u(1),'Upload topic','upload-topic');
insert into public.topic_assets(id,topic_id,kind,title,provider,ready,size_mb,duration_s) values
 (pg_temp.u(11),pg_temp.u(2),'video','Pending','r2_hls',false,1,30),
 (pg_temp.u(12),pg_temp.u(2),'video','Ready','r2_hls',true,1,30),
 (pg_temp.u(13),pg_temp.u(2),'video','YouTube','youtube',false,0,30),
 (pg_temp.u(14),pg_temp.u(2),'notes','Notes',null,false,null,null);
select tests.authenticate_as('upload_student');
select throws_ok('select public.teacher_video_upload_grant(pg_temp.u(11))','P0001','forbidden','C-2: student cannot request upload grant');
select tests.authenticate_as('upload_teacher');
select throws_ok('select public.teacher_video_upload_grant(pg_temp.u(12))','P0001','invalid_input','C-2: ready assets cannot be overwritten');
select throws_ok('select public.teacher_video_upload_grant(pg_temp.u(13))','P0001','invalid_input','C-2: YouTube cannot receive HLS upload');
select throws_ok('select public.teacher_video_upload_grant(pg_temp.u(14))','P0001','invalid_input','C-2: notes are not video');
select throws_ok('select public.teacher_video_upload_grant(pg_temp.u(99))','P0001','invalid_input','C-2: unknown asset refused');
select is(public.teacher_video_upload_grant(pg_temp.u(11)),jsonb_build_object('r2_prefix','videos/'||pg_temp.u(11),'ttl_s',900),
 'C-2: pending HLS asset receives canonical prefix and configured TTL');
select tests.clear_authentication();
reset role;
update public.settings set value='600' where key='video_upload_url_ttl_s';
select tests.authenticate_as('upload_teacher');
select is(public.teacher_video_upload_grant(pg_temp.u(11))->'ttl_s','600'::jsonb,'C-2: upload TTL is read from settings');
select tests.clear_authentication();
reset role;
set local role authenticated;
select throws_ok('select public.teacher_video_upload_grant(null)','P0001','not_authenticated','SEC-01: grant requires authentication');
reset role;
set local role anon;
select throws_ok('select public.teacher_video_upload_grant(null)','42501',null,'SEC-01: anon cannot execute grant');
reset role;
select ok(has_function_privilege('authenticated','public.teacher_video_upload_grant(uuid)','execute'),'SEC-01: authenticated execute granted');
select * from finish();
rollback;
