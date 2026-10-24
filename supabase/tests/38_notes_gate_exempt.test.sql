-- L-3: later notes do not re-lock completed practice. From supabase/templates/test.sql.
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

create function pg_temp.n(i int) returns uuid language sql immutable as $$
  select ('38000000-0000-0000-0000-' || lpad(i::text,12,'0'))::uuid;
$$;
grant execute on function pg_temp.n(int) to authenticated;

select tests.create_supabase_user('notes_exempt_practice');
select tests.create_supabase_user('notes_exempt_quiz');
select tests.create_supabase_user('notes_exempt_fresh');
update public.settings set value='3'::jsonb where key='practice_min';
insert into public.courses(id,code,title,slug,is_published)
values(pg_temp.n(1),'SAT','Notes exemption','notes-exempt-test',true);
insert into public.topics(id,course_id,title,slug,sort,is_published,is_free_preview) values
  (pg_temp.n(11),pg_temp.n(1),'Later notes','later-notes',1,true,false),
  (pg_temp.n(12),pg_temp.n(1),'No notes','no-notes-exempt',2,true,true);
insert into public.subtopics(id,topic_id,title) values
  (pg_temp.n(21),pg_temp.n(11),'Notes section'),
  (pg_temp.n(22),pg_temp.n(12),'No notes section');
insert into public.enrollments(user_id,course_id,status,starts_at,expires_at)
select tests.get_supabase_uid(name),pg_temp.n(1),'active',now(),now()+interval '1 day'
from unnest(array['notes_exempt_practice','notes_exempt_quiz','notes_exempt_fresh']) name;
insert into public.questions(id,topic_id,subtopic_id,type,difficulty,stem_md,pool,status)
select pg_temp.n(30+i),pg_temp.n(10+i),pg_temp.n(20+i),'mcq','M','One?','practice','published'
from unnest(array[1,2]) i;
insert into public.question_choices(question_id,label,body_md)
select pg_temp.n(30+i),label,'Choice' from unnest(array[1,2]) i cross join unnest(array['A','B']) label;
insert into private.question_keys(question_id,correct_answer,explanation_md)
select pg_temp.n(30+i),'{"choice":"B"}'::jsonb,'Two.' from unnest(array[1,2]) i;

-- Existing completion predates the ready notes asset. No student has opened it.
insert into public.topic_progress(user_id,topic_id,practice_count,quiz_passed_at) values
  (tests.get_supabase_uid('notes_exempt_practice'),pg_temp.n(11),3,null),
  (tests.get_supabase_uid('notes_exempt_quiz'),pg_temp.n(11),0,now());
insert into public.topic_assets(id,topic_id,kind,title,sort,storage_path,page_count,ready)
values(pg_temp.n(41),pg_temp.n(11),'notes','Added later',1,pg_temp.n(11)||'/'||pg_temp.n(41)||'.pdf',2,true);

select tests.authenticate_as('notes_exempt_practice');
select is(public.get_topic(pg_temp.n(11))->'notes_done','true'::jsonb,
  'L-3: practice count exactly at configured minimum satisfies notes');
select lives_ok('select public.get_practice_questions(pg_temp.n(11))',
  'L-3: later notes do not re-lock finished practice');

select tests.authenticate_as('notes_exempt_quiz');
select is(public.get_topic(pg_temp.n(11))->'notes_done','true'::jsonb,
  'L-3: passed quiz satisfies notes even below practice minimum');
select lives_ok('select public.get_practice_questions(pg_temp.n(11))',
  'L-3: later notes do not re-lock a passed topic');

select tests.authenticate_as('notes_exempt_fresh');
select is(public.get_topic(pg_temp.n(11))->'notes_done','false'::jsonb,
  'L-3: a fresh student does not inherit another student''s exemption');
select throws_ok('select public.get_practice_questions(pg_temp.n(11))','P0001','notes_needed',
  'L-3: a fresh student must still open notes');
select is(public.get_topic(pg_temp.n(12))->'notes_done','true'::jsonb,
  'L-3: no notes still skips the notes step');
select lives_ok('select public.get_practice_questions(pg_temp.n(12))',
  'L-3: no-notes practice is unaffected');

select tests.clear_authentication();
reset role;
insert into public.topic_progress(user_id,topic_id,practice_count)
values(tests.get_supabase_uid('notes_exempt_fresh'),pg_temp.n(11),2);
select tests.authenticate_as('notes_exempt_fresh');
select is(public.get_topic(pg_temp.n(11))->'notes_done','false'::jsonb,
  'L-3: partial practice below the minimum does not satisfy notes');
select throws_ok('select public.get_practice_questions(pg_temp.n(11))','P0001','notes_needed',
  'L-3: partial practice is still gated');

select tests.clear_authentication();
reset role;
update public.settings set value='4'::jsonb where key='practice_min';
select tests.authenticate_as('notes_exempt_practice');
select is(public.get_topic(pg_temp.n(11))->'notes_done','false'::jsonb,
  'L-3: exemption reads the current practice_min setting');
select throws_ok('select public.get_practice_questions(pg_temp.n(11))','P0001','notes_needed',
  'L-3: practice gate uses the same configured minimum as notes_done');

select tests.clear_authentication();
reset role;
update public.topic_progress set notes_opened_at=now()
where user_id=tests.get_supabase_uid('notes_exempt_fresh') and topic_id=pg_temp.n(11);
select tests.authenticate_as('notes_exempt_fresh');
select is(public.get_topic(pg_temp.n(11))->'notes_done','true'::jsonb,
  'L-3: opened notes remain satisfied below the practice minimum');
select lives_ok('select public.get_practice_questions(pg_temp.n(11))',
  'L-3: opened notes still allow practice');

select tests.clear_authentication();
reset role;
select ok(not has_function_privilege(role_name,'private.notes_satisfied(uuid,uuid)','execute'),
  'L-3: notes_satisfied is internal for '||role_name)
from unnest(array['anon','authenticated','service_role']) role_name;
select ok(not has_function_privilege(role_name,'private.require_notes_opened(uuid,uuid)','execute'),
  'L-3: require_notes_opened remains internal for '||role_name)
from unnest(array['anon','authenticated','service_role']) role_name;
select ok(has_function_privilege('authenticated','public.get_topic(uuid)','execute'),
  'L-3: authenticated keeps get_topic execute');
select ok(not has_function_privilege('anon','public.get_topic(uuid)','execute'),
  'L-3: anon still cannot call get_topic');
select * from finish();
rollback;
