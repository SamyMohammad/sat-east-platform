-- PRC-02 / PRC-05 / LRN-01: from supabase/templates/test.sql; tests written first.
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();
create function pg_temp.h(i int) returns uuid language sql immutable set search_path='' as $fn$
  select ('43000000-0000-0000-0000-' || pg_catalog.lpad(i::text,12,'0'))::uuid;
$fn$;
grant execute on function pg_temp.h(int) to authenticated;
select tests.create_supabase_user('hw_owner');
select tests.create_supabase_user('hw_other');
select tests.create_supabase_user('hw_passed');
update public.settings set value='2' where key='practice_min';
update public.settings set value='2' where key='homework_size';
insert into public.courses(id,code,title,slug,is_published)
values(pg_temp.h(1),'SAT','Homework','homework',true);
insert into public.topics(id,course_id,title,slug,sort,is_published,is_free_preview)
select pg_temp.h(10+i),pg_temp.h(1),'Topic '||i,'hw-'||i,i,true,true from generate_series(1,3) i;
insert into public.subtopics(id,topic_id,title)
select pg_temp.h(20+i),pg_temp.h(10+i),'Section' from generate_series(1,3) i;
insert into public.enrollments(user_id,course_id,status,starts_at,expires_at)
select tests.get_supabase_uid(u),pg_temp.h(1),'active',now(),now()+interval '30 days'
from unnest(array['hw_owner','hw_other','hw_passed']) u;
insert into public.questions(id,topic_id,subtopic_id,type,difficulty,stem_md,pool,status)
select pg_temp.h(30+i),pg_temp.h(11),pg_temp.h(21),'mcq','E','Question '||i,'practice','published'
from generate_series(1,3) i;
insert into public.questions(id,topic_id,subtopic_id,type,difficulty,stem_md,pool,status) values
(pg_temp.h(34),pg_temp.h(12),pg_temp.h(22),'spr','M','Small pool','practice','published');
insert into public.questions(id,topic_id,subtopic_id,type,difficulty,stem_md,pool,status)
select pg_temp.h(40+i),pg_temp.h(10+i),pg_temp.h(20+i),'mcq','E','Quiz','quiz','published'
from generate_series(1,3) i;
insert into public.question_choices(question_id,label,body_md)
select q.id,c,'Choice '||c from public.questions q cross join unnest(array['A','B']) c
where q.topic_id in (pg_temp.h(11),pg_temp.h(12),pg_temp.h(13)) and q.type='mcq';
insert into private.question_keys(question_id,correct_answer,explanation_md)
select q.id,case when q.type='spr' then '{"accepted":["1/2","0.5"],"tolerance":0}'::jsonb
else '{"choice":"B"}'::jsonb end,'Worked solution' from public.questions q
where q.topic_id in (pg_temp.h(11),pg_temp.h(12),pg_temp.h(13));
insert into public.topic_progress(user_id,topic_id,practice_count,quiz_passed_at)
select tests.get_supabase_uid(u),pg_temp.h(10+i),case when u='hw_owner' and i=1 then 0 else 2 end,
case when u='hw_passed' then now() end
from unnest(array['hw_owner','hw_other','hw_passed']) u cross join generate_series(1,3) i;
-- Only question 31 has been answered in practice; exposure alone is not an answer.
insert into public.attempts(id,user_id,kind,course_id,topic_id)
values(pg_temp.h(50),tests.get_supabase_uid('hw_owner'),'practice',pg_temp.h(1),pg_temp.h(11));
insert into public.attempt_questions(attempt_id,question_id,position) values(pg_temp.h(50),pg_temp.h(31),1);
insert into public.attempt_answers(attempt_id,question_id,answer,answered_at)
values(pg_temp.h(50),pg_temp.h(31),'{"value":"B"}',now());
insert into public.question_exposure(user_id,question_id,first_seen_at)
values(tests.get_supabase_uid('hw_owner'),pg_temp.h(32),now()-interval '2 days');
create temp table hw_ctx(k text primary key,v jsonb);
grant select,insert on hw_ctx to authenticated;
create function pg_temp.hatt(k text) returns uuid language sql set search_path='' as $fn$
 select (c.v->>'attempt_id')::uuid from pg_temp.hw_ctx c where c.k=$1;
$fn$;
grant execute on function pg_temp.hatt(text) to authenticated;
select ok(not has_function_privilege('authenticated','private.homework_state(uuid,uuid)','execute'),'PRC-02: homework helper is private');
select ok(has_function_privilege('authenticated','public.start_homework(uuid)','execute'),'PRC-02: authenticated can execute');
select ok(not has_function_privilege('anon','public.start_homework(uuid)','execute'),'PRC-02: anon has no execute');
select tests.clear_authentication();
reset role;
set local role anon;
select throws_ok('select public.start_homework(null)','42501',null,'PRC-02: anon cannot start');
reset role;
set local role authenticated;
select throws_ok('select public.start_homework(null)','P0001','not_authenticated','PRC-02: session required');
reset role;
select tests.authenticate_as('hw_owner');
select throws_ok('select public.start_homework(null)','P0001','invalid_input','PRC-02: null topic rejected');
select is(public.get_topic(pg_temp.h(11))#>>'{homework,state}','locked_by_practice','PRC-02: homework initially locked');
select throws_ok('select public.start_homework(pg_temp.h(11))','P0001','practice_needed','PRC-02: practice threshold enforced');
select tests.clear_authentication();
reset role;
update public.topic_progress set practice_count=2 where user_id=tests.get_supabase_uid('hw_owner');
select tests.authenticate_as('hw_owner');
select is(public.get_topic(pg_temp.h(11))#>>'{homework,state}','available','PRC-02: practice opens homework');
select is(public.get_topic(pg_temp.h(11))#>>'{quiz,state}','homework_needed','LRN-01: quiz needs homework');
select throws_ok('select public.start_quiz(pg_temp.h(11))','P0001','homework_needed','LRN-01: quiz start enforces homework');
insert into hw_ctx values('start',public.start_homework(pg_temp.h(11)));
select is(jsonb_array_length(v->'questions'),2,'PRC-02: homework_size caps draw') from hw_ctx where k='start';
select is((v#>>'{questions,0,id}')::uuid,pg_temp.h(33),'PRC-02: unseen precedes exposed unanswered') from hw_ctx where k='start';
select ok(not exists(select 1 from hw_ctx,jsonb_array_elements(v->'questions') q where k='start' and (q->>'id')::uuid=pg_temp.h(31)),
 'PRC-02: practice answered question drawn last');
select ok(not(v::text like '%explanation%') and not(v::text like '%"key"%'),'PRC-02: start leaks no grading data') from hw_ctx where k='start';
select is((public.start_homework(pg_temp.h(11))->>'attempt_id')::uuid,pg_temp.hatt('start'),'PRC-02: second start resumes same attempt');
select is(public.get_topic(pg_temp.h(11))#>>'{homework,state}','in_progress','PRC-02: topic shows ongoing homework');
select throws_ok('select public.get_attempt_review(pg_temp.hatt(''start''))','P0001','attempt_not_submitted','PRC-02: cannot review before submit');
-- Age the homework to prove saves/submits have no deadline.
select tests.clear_authentication();
reset role;
update public.attempts set started_at=now()-interval '1 year' where id=pg_temp.hatt('start');
select is((select time_limit_s from public.attempts where id=pg_temp.hatt('start')),null::int,'PRC-02: no homework timer');
select is((select count(*)::int from public.question_exposure where user_id=tests.get_supabase_uid('hw_owner') and question_id in(pg_temp.h(32),pg_temp.h(33))),2,'PRC-02: draw records exposure');
select tests.authenticate_as('hw_owner');
insert into hw_ctx values('save',public.save_answer(pg_temp.hatt('start'),pg_temp.h(33),'B',100,true,array['A'],1));
select is(v,'{"ok":true}'::jsonb,'PRC-05: homework saves without deadline') from hw_ctx where k='save';
select ok(not(v::text like '%explanation%') and not(v ? 'key'),'PRC-02: save leaks no keys') from hw_ctx where k='save';
select is(public.save_answer(pg_temp.hatt('start'),pg_temp.h(33),'A',100,false,null,0),'{"ok":true,"stale":true}'::jsonb,'PRC-05: stale homework save ignored');
select tests.clear_authentication();
reset role;
select tests.authenticate_as('hw_owner');
insert into hw_ctx values('resume',public.start_homework(pg_temp.h(11)));
select is(v#>'{answers,0}','{"question_id":"43000000-0000-0000-0000-000000000033","answer":"B","marked":true}'::jsonb,'PRC-05: new session restores answer and mark') from hw_ctx where k='resume';
select is(v->>'client_seq','1','PRC-05: resume restores sequence') from hw_ctx where k='resume';
insert into hw_ctx values('report',public.submit_attempt(pg_temp.hatt('start')));
select is(v,jsonb_build_object('attempt_id',pg_temp.hatt('start'),'kind','homework','score_raw',1,'score_total',2,'score_pct',50.00),'PRC-02: grades saved and unanswered questions') from hw_ctx where k='report';
select is(public.submit_attempt(pg_temp.hatt('start')),v,'PRC-02: resubmit returns identical report') from hw_ctx where k='report';
select ok(not(v::text like '%explanation%') and not(v ? 'key'),'PRC-02: submit returns no keys') from hw_ctx where k='report';
select throws_ok('select public.save_answer(pg_temp.hatt(''start''),pg_temp.h(33),''A'',0,false,null,2)','P0001','invalid_input','PRC-05: autosave after submit rejected');
select is(public.submit_attempt(pg_temp.hatt('start')),v,'PRC-02: rejected autosave leaves report intact') from hw_ctx where k='report';
select throws_ok('select public.start_homework(pg_temp.h(11))','P0001','attempt_closed','PRC-02: submitted homework cannot restart');
select is(public.get_topic(pg_temp.h(11))#>>'{homework,state}','submitted','PRC-02: topic shows submission');
insert into hw_ctx values('review',public.get_attempt_review(pg_temp.hatt('start')));
select is(v#>'{summary,keys_visible}','true'::jsonb,'PRC-02: homework review reveals keys without quiz pass') from hw_ctx where k='review';
select is(v#>'{summary,pass_mark}','null'::jsonb,'PRC-02: homework has no pass mark') from hw_ctx where k='review';
select is(v#>'{summary,passed}','null'::jsonb,'PRC-02: homework has no pass/fail') from hw_ctx where k='review';
select ok(q ? 'key' and q->>'explanation_md'='Worked solution','PRC-02: review includes key and explanation') from hw_ctx,jsonb_array_elements(v->'questions') q where k='review';
select lives_ok('select public.start_quiz(pg_temp.h(11))','LRN-01: homework submission opens quiz');
select tests.clear_authentication();
reset role;
select ok(homework_submitted_at is not null and homework_score=50 and homework_attempt_id=pg_temp.hatt('start'),'PRC-02: submission persists progress')
from public.topic_progress where user_id=tests.get_supabase_uid('hw_owner') and topic_id=pg_temp.h(11);
select ok(practice_count=2 and quiz_passed_at is null and quiz_last_failed_at is null and unlocked_at is null,'PRC-02: homework changes no practice/pass/cooldown/unlock fields')
from public.topic_progress where user_id=tests.get_supabase_uid('hw_owner') and topic_id=pg_temp.h(11);
select is((select count(*)::int from public.attempts where user_id=tests.get_supabase_uid('hw_owner') and topic_id=pg_temp.h(11) and kind='homework'),1,'PRC-02: only one homework attempt');
select tests.authenticate_as('hw_other');
select throws_ok('select public.get_attempt_review(pg_temp.hatt(''start''))','P0001','forbidden','PRC-02: other student cannot review');
select throws_ok('select public.save_answer(pg_temp.hatt(''start''),pg_temp.h(33),''B'',0,false,null,2)','P0001','invalid_input','PRC-02: other student cannot save');
select throws_ok('select public.submit_attempt(pg_temp.hatt(''start''))','P0001','invalid_input','PRC-02: other student cannot submit');
select tests.clear_authentication();
reset role;
update public.settings set value='3' where key='homework_size';
insert into public.attempts(id,user_id,kind,course_id,topic_id)
values(pg_temp.h(51),tests.get_supabase_uid('hw_other'),'practice',pg_temp.h(1),pg_temp.h(11));
insert into public.attempt_questions(attempt_id,question_id,position) values(pg_temp.h(51),pg_temp.h(31),1);
insert into public.attempt_answers(attempt_id,question_id,answer,answered_at)
values(pg_temp.h(51),pg_temp.h(31),'{"value":"B"}',now());
select tests.authenticate_as('hw_other');
insert into hw_ctx values('full',public.start_homework(pg_temp.h(11)));
select is((v#>>'{questions,2,id}')::uuid,pg_temp.h(31),'PRC-02: practice answered question fills only last position') from hw_ctx where k='full';
select tests.authenticate_as('hw_owner');
select throws_ok('select public.get_attempt_review(pg_temp.hatt(''full''))','P0001','forbidden','PRC-02: ownership checked before unsubmitted status');
insert into hw_ctx values('small',public.start_homework(pg_temp.h(12)));
select is(jsonb_array_length(v->'questions'),1,'PRC-02: small pool draws everything') from hw_ctx where k='small';
select public.save_answer(pg_temp.hatt('small'),pg_temp.h(34),'.5',0,false,null,1);
select is(public.submit_attempt(pg_temp.hatt('small'))->>'score_pct','100.00','PRC-02: homework uses shared SPR grader');
select is(public.get_topic(pg_temp.h(13))#>>'{homework,state}','skipped','PRC-02: empty practice pool skips homework');
select is(public.get_topic(pg_temp.h(13))#>>'{quiz,state}','available','LRN-01: empty practice pool has no homework gate');
select lives_ok('select public.start_quiz(pg_temp.h(13))','LRN-01: empty practice pool does not block quiz');
select throws_ok('select public.start_homework(pg_temp.h(13))','P0001','pool_exhausted','PRC-02: empty homework draw rejected');
select tests.authenticate_as('hw_passed');
select is(public.get_topic(pg_temp.h(11))#>>'{homework,state}','skipped','PRC-02: prior quiz pass skips homework');
select is(public.get_topic(pg_temp.h(11))#>>'{quiz,state}','available','LRN-01: prior quiz pass has no homework gate');
select lives_ok('select public.start_quiz(pg_temp.h(11))','LRN-01: prior passer can start quiz without homework');
select tests.clear_authentication();
reset role;
insert into public.skills (id, code, name, domain) values
  (pg_temp.h(70), 'HW-Z', 'Algebra', 'Algebra'),
  (pg_temp.h(71), 'HW-A', 'Algebra', 'Algebra'),
  (pg_temp.h(72), 'HW-F', 'Fractions', 'Algebra');
insert into public.question_skills (question_id, skill_id) values
  (pg_temp.h(31),pg_temp.h(71)), (pg_temp.h(32),pg_temp.h(71)), (pg_temp.h(33),pg_temp.h(71)),
  (pg_temp.h(33),pg_temp.h(70)), (pg_temp.h(31),pg_temp.h(72));
select tests.authenticate_as('hw_other');
select public.save_answer(pg_temp.hatt('full'),pg_temp.h(31),'B',0,false,null,1);
select public.save_answer(pg_temp.hatt('full'),pg_temp.h(32),'A',0,false,null,2);
select public.submit_attempt(pg_temp.hatt('full'));
select is(public.get_attempt_review(pg_temp.hatt('full')) #> '{summary,skills}',
  '[{"code":"HW-A","name":"Algebra","correct":1,"total":3},
    {"code":"HW-Z","name":"Algebra","correct":0,"total":1},
    {"code":"HW-F","name":"Fractions","correct":1,"total":1}]'::jsonb,
  'ANL-02: review_summary_has_skills_homework');
select tests.authenticate_as('hw_owner');
select is(public.get_attempt_review(pg_temp.hatt('small')) #> '{summary,skills}', '[]'::jsonb,
  'ANL-02: review_summary_skills_empty_when_untagged');
select * from finish();
rollback;
