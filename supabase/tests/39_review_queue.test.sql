-- C-6 / QB-04 / QB-08 / T-08. From supabase/templates/test.sql.
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();
create function pg_temp.r(i int) returns uuid language sql immutable as $$
  select ('39000000-0000-0000-0000-' || lpad(i::text,12,'0'))::uuid;
$$;
grant execute on function pg_temp.r(int) to authenticated;
select tests.create_supabase_user('report_a');
select tests.create_supabase_user('report_b');
select tests.create_supabase_user('report_rate');
select tests.create_supabase_user('report_outsider');
select tests.create_supabase_user('report_teacher');
update public.profiles set role='teacher' where id=tests.get_supabase_uid('report_teacher');
update public.profiles set full_name='Student A39' where id=tests.get_supabase_uid('report_a');
update public.profiles set full_name='Student B39' where id=tests.get_supabase_uid('report_b');
-- Isolate queue assertions from seed content; the enclosing rollback restores it.
update public.question_reports set status='resolved_dismissed' where status='open';
update public.questions set status='draft' where status='needs_review';
update public.settings set value='5'::jsonb where key='rate_report_per_min';
update public.settings set value='1'::jsonb where key='bank_page_size';
insert into public.courses(code,title,slug,is_published) values
  ('SAT','Reports SAT','reports-sat',true),('EST','Reports EST','reports-est',true)
on conflict(code) do update set is_published=true;
insert into public.topics(id,course_id,title,slug,sort,is_published)
select pg_temp.r(1),id,'Reports topic','reports-topic',1,true from public.courses where code='SAT';
insert into public.topics(id,course_id,title,slug,sort,is_published)
select pg_temp.r(2),id,'No access','reports-no-access',1,true from public.courses where code='EST';
insert into public.subtopics(id,topic_id,title) values
  (pg_temp.r(11),pg_temp.r(1),'Reports section'),(pg_temp.r(12),pg_temp.r(2),'No access');
insert into public.enrollments(user_id,course_id,status,starts_at,expires_at)
select tests.get_supabase_uid(name),c.id,'active',now(),now()+interval '1 day'
from public.courses c cross join unnest(array['report_a','report_b','report_rate']) name where c.code='SAT';
insert into public.questions(id,topic_id,subtopic_id,type,difficulty,stem_md,pool,status,external_ref) values
  (pg_temp.r(21),pg_temp.r(1),pg_temp.r(11),'mcq','M',E'First line\nSECRET_SECOND_LINE','practice','published','REPORT_1'),
  (pg_temp.r(22),pg_temp.r(1),pg_temp.r(11),'mcq','M','Second','practice','published','REPORT_2'),
  (pg_temp.r(23),pg_temp.r(1),pg_temp.r(11),'mcq','M','Draft','practice','draft','REPORT_DRAFT'),
  (pg_temp.r(24),pg_temp.r(2),pg_temp.r(12),'mcq','M','No access','practice','published','REPORT_DENIED'),
  (pg_temp.r(25),pg_temp.r(1),pg_temp.r(11),'mcq','M','Review one','practice','needs_review','REPORT_REVIEW_1'),
  (pg_temp.r(26),pg_temp.r(1),pg_temp.r(11),'mcq','M','Review two','practice','needs_review','REPORT_REVIEW_2');

select tests.authenticate_as('report_a');
select throws_ok('insert into public.question_reports(question_id,user_id,reason) values(pg_temp.r(21),auth.uid(),''typo'')',
  '42501',null,'QB-04: students cannot insert reports directly');
select throws_ok('select public.report_question(pg_temp.r(21),''bogus'',null)','P0001','invalid_input','QB-04: reason allow-list');
select throws_ok('select public.report_question(pg_temp.r(21),null,null)','P0001','invalid_input','QB-04: null reason rejected');
select throws_ok('select public.report_question(pg_temp.r(21),''typo'',repeat(''x'',501))','P0001','invalid_input','QB-04: long note rejected');
select throws_ok('select public.report_question(pg_temp.r(23),''typo'',null)','P0001','invalid_input','QB-04: unpublished question rejected');
select throws_ok('select public.report_question(pg_temp.r(24),''typo'',null)','P0001','invalid_input','QB-04: no-access topic rejected');
select throws_ok('select public.report_question(null,''typo'',null)','P0001','invalid_input','QB-04: unknown question rejected');
select tests.clear_authentication();
reset role;
select is((select count(*)::int from private.rate_limits where key='report_question:'||tests.get_supabase_uid('report_a')),0,
  'QB-04: invalid input/access checks run before quota');
select tests.authenticate_as('report_a');
select set_config('test.report_a',public.report_question(pg_temp.r(21),'answer_key','  A note  ')::text,true);
select is(current_setting('test.report_a')::jsonb-'report_id','{"ok":true,"existing":false}'::jsonb,'QB-04: accessible published report created');
select is(public.report_question(pg_temp.r(21),'other','Replacement')->>'report_id',current_setting('test.report_a')::jsonb->>'report_id','QB-04: duplicate returns existing id');
select is(public.report_question(pg_temp.r(21),'typo',null)->'existing','true'::jsonb,'QB-04: duplicate is explicitly existing');
select is((select count(*)::int from public.question_reports where question_id=pg_temp.r(21)),1,'QB-04: duplicate creates no row');
select is((select note from public.question_reports where question_id=pg_temp.r(21)),'A note','QB-04: optional note trimmed and duplicate does not overwrite it');
select is(public.report_question(pg_temp.r(22),'math_display','<b>literal plain text</b>')->'ok','true'::jsonb,'QB-04: math_display and plain-text note accepted');

select tests.authenticate_as('report_b');
select is(public.report_question(pg_temp.r(21),'typo',null)->'ok','true'::jsonb,'QB-04: another student may report the same question');
select is((select count(*)::int from public.question_reports where question_id=pg_temp.r(21)),1,'QB-04: student reads only their own reports');
select throws_ok('select public.teacher_list_review_queue(''reported'',1)','P0001','forbidden','T-08: student cannot read queue');
select throws_ok('select public.teacher_list_question_reports(pg_temp.r(21))','P0001','forbidden','T-08: student cannot read names');
select throws_ok('select public.teacher_review_counts()','P0001','forbidden','T-08: student cannot read counts');
select throws_ok('select public.teacher_resolve_reports(pg_temp.r(21),''fixed'',null)','P0001','forbidden','T-08: student cannot resolve');

select is(public.report_question(pg_temp.r(21),'other',repeat('x',500))->'existing','true'::jsonb,
  'QB-04: 500-character note is allowed even on an existing report');
select tests.clear_authentication();
reset role;
-- Fixed dates make count/oldest ordering deterministic.
update public.question_reports set created_at='2026-01-02 00:00:00+00' where question_id=pg_temp.r(21);
update public.question_reports set created_at='2026-01-01 00:00:00+00' where question_id=pg_temp.r(22);
select tests.authenticate_as('report_teacher');
select is(public.teacher_review_counts(),'{"reported":2,"needs_review":2}'::jsonb,'T-08: counts are grouped questions, not individual reports');
select set_config('test.queue_page',public.teacher_list_review_queue('reported',1)::text,true);
select is(current_setting('test.queue_page')::jsonb-'rows','{"total":2,"page":1,"page_size":1}'::jsonb,'T-08: paging uses bank_page_size');
select is(current_setting('test.queue_page')::jsonb->'rows'->0->>'question_id',pg_temp.r(21)::text,'T-08: higher report count beats older report');
select is(current_setting('test.queue_page')::jsonb->'rows'->0->'reasons','{"answer_key":1,"typo":1}'::jsonb,'T-08: reasons breakdown');
select is(current_setting('test.queue_page')::jsonb->'rows'->0->>'latest_note','A note','T-08: latest nonempty note');
select is(current_setting('test.queue_page')::jsonb->'rows'->0->>'stem_preview','First line','T-08: stem preview matches question bank first-line convention');
select is(public.teacher_list_review_queue('reported',2)->'rows'->0->>'question_id',pg_temp.r(22)::text,'T-08: second page');
select is(public.teacher_list_review_queue('reported',3)->'rows','[]'::jsonb,'T-08: out-of-range page empty');
select is(public.teacher_list_review_queue('needs_review',1)->'total','2'::jsonb,'T-08: needs_review includes unreported questions');
select is(public.teacher_list_review_queue('needs_review',2)->'rows'->0->>'question_id',pg_temp.r(26)::text,'T-08: needs_review paging is deterministic');
select is(jsonb_array_length(public.teacher_list_question_reports(pg_temp.r(21))),2,'T-08: panel lists all open reports for this question');
select is((select string_agg(r->>'full_name',',' order by r->>'full_name') from jsonb_array_elements(public.teacher_list_question_reports(pg_temp.r(21))) r),
  'Student A39,Student B39','T-08: only teacher report panel receives student names');
select throws_ok('select public.teacher_list_review_queue(''other'',1)','P0001','invalid_input','T-08: invalid section rejected');
select throws_ok('select public.teacher_list_review_queue(''reported'',0)','P0001','invalid_input','T-08: invalid page rejected');
select throws_ok('select public.teacher_list_question_reports(pg_temp.r(99))','P0001','invalid_input','T-08: unknown question rejected');
select throws_ok('select public.teacher_resolve_reports(pg_temp.r(21),''wrong'',null)','P0001','invalid_input','T-08: invalid outcome rejected');
select throws_ok('select public.teacher_resolve_reports(pg_temp.r(21),''fixed'',repeat(''x'',501))','P0001','invalid_input','T-08: teacher note limit');
select is(public.teacher_resolve_reports(pg_temp.r(21),'fixed','  Corrected  '),'{"closed":2}'::jsonb,'T-08: resolve closes all open reports');
select is(public.teacher_list_question_reports(pg_temp.r(21)),'[]'::jsonb,'T-08: closed reports leave the open panel');
select is(public.teacher_review_counts(),'{"reported":1,"needs_review":2}'::jsonb,'T-08: resolving reports leaves needs_review status alone');
select tests.clear_authentication();
reset role;
select is((select count(*)::int from public.question_reports where question_id=pg_temp.r(21) and status='resolved_fixed'
  and resolved_at is not null and resolved_by=tests.get_supabase_uid('report_teacher') and teacher_note='Corrected'),2,'T-08: resolution fields persisted');
select is((select count(*)::int from public.question_reports where question_id=pg_temp.r(22) and status='open'),1,'T-08: other question untouched');
select is((select count(*)::int from public.audit_log where actor=tests.get_supabase_uid('report_teacher') and action='question_reports.resolve'),1,'T-08: one audit row per resolve');
select is((select diff from public.audit_log where actor=tests.get_supabase_uid('report_teacher') and action='question_reports.resolve'),
  '{"outcome":"fixed","closed":2}'::jsonb,'T-08: audit diff contains only outcome/count, no student PII');

select tests.authenticate_as('report_outsider');
select throws_ok('select public.report_question(pg_temp.r(21),''other'',null)','P0001','invalid_input',
  'QB-04: another student without enrollment cannot report');
select tests.authenticate_as('report_a');
select is(public.report_question(pg_temp.r(21),'other','Again')->'existing','false'::jsonb,'QB-04: a resolved question can be reported again');
select tests.authenticate_as('report_teacher');
select is(public.teacher_list_review_queue('reported',1)->'rows'->0->>'question_id',pg_temp.r(22)::text,
  'T-08: equal counts order by oldest report');
select is(public.teacher_resolve_reports(pg_temp.r(21),'dismissed',null),'{"closed":1}'::jsonb,'T-08: dismissed outcome closes the new report only');
select tests.clear_authentication();
reset role;
select is((select count(*)::int from public.question_reports where question_id=pg_temp.r(21) and status='resolved_dismissed'),1,'T-08: dismissed status persisted');
update public.settings set value='1'::jsonb where key='rate_report_per_min';
select tests.authenticate_as('report_rate');
select is(public.report_question(pg_temp.r(22),'other',' ')->'ok','true'::jsonb,'QB-04: first rate-limited user report allowed');
select is(public.report_question(pg_temp.r(21),'typo',null),'{"ok":false,"error":"rate_limited"}'::jsonb,'QB-04: quota excess is returned, never raised');
select is(public.report_question(pg_temp.r(22),'other',null),'{"ok":false,"error":"rate_limited"}'::jsonb,'QB-04: quota runs before duplicate lookup');
select tests.clear_authentication();
reset role;
select is((select count from private.rate_limits where key='report_question:'||tests.get_supabase_uid('report_rate')),3,'QB-04: denied calls retain their quota increments');
select is((select count(*)::int from public.question_reports where user_id=tests.get_supabase_uid('report_rate')),1,'QB-04: quota rejection inserts no report');
select is((select note from public.question_reports where user_id=tests.get_supabase_uid('report_rate')),null::text,'QB-04: blank note normalized to null');
select throws_ok('insert into public.question_reports(question_id,user_id,reason) values(pg_temp.r(22),tests.get_supabase_uid(''report_rate''),''other'')',
  '23505',null,'QB-04: unique index enforces duplicate race safety');
select throws_ok('insert into public.question_reports(question_id,user_id,reason) values(pg_temp.r(21),tests.get_supabase_uid(''report_teacher''),''bad'')',
  '23514',null,'QB-04: reason constraint enforced');
select throws_ok('insert into public.question_reports(question_id,user_id,reason,status) values(pg_temp.r(21),tests.get_supabase_uid(''report_teacher''),''other'',''bad'')',
  '23514',null,'QB-04: status constraint enforced');
select ok((select relrowsecurity from pg_class where oid='public.question_reports'::regclass),'QB-04: existing RLS remains enabled');
select ok(not exists(select 1 from pg_policies where schemaname='public' and tablename='question_reports' and policyname='question_reports: student inserts own'),
  'QB-04: direct student insert policy removed');
select ok(not has_function_privilege('anon',p.oid,'execute'),'T-08: anon cannot execute '||p.proname)
from pg_proc p where p.pronamespace='public'::regnamespace and p.proname in
  ('report_question','teacher_list_review_queue','teacher_list_question_reports','teacher_resolve_reports','teacher_review_counts');
set local role authenticated;
select throws_ok('select public.report_question(null,null,null)','P0001','not_authenticated','QB-04: report requires auth');
select throws_ok('select public.teacher_review_counts()','P0001','not_authenticated','T-08: teacher RPC requires auth');
reset role;
select * from finish();
rollback;
