-- C-7 / ADM-06: teacher settings. From supabase/templates/test.sql.
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

select tests.create_supabase_user('settings_student');
select tests.create_supabase_user('settings_teacher');
update public.profiles set role = 'teacher'
where id = tests.get_supabase_uid('settings_teacher');

-- Independent contract fixture: do not derive expected ranges from the RPC.
create temp table setting_cases (
  key text, grp text, label text, unit text, min int, max int, sort int, value int
);
insert into setting_cases values
  ('pass_mark','Quiz','Pass mark','%',1,100,1,75),
  ('cooldown_h','Quiz','Retake cooldown','hours',0,168,2,12),
  ('quiz_size','Quiz','Questions per quiz','questions',1,60,3,12),
  ('quiz_time_per_q_s','Quiz','Time per question','seconds',15,600,4,90),
  ('quiz_warn_s','Quiz','Time warning at','seconds left',0,1800,5,300),
  ('practice_min','Practice','Practice before quiz','questions',0,50,6,10),
  ('homework_size','Practice','Homework size','questions',1,60,7,20),
  ('review_max','Practice','Review set max','questions',1,30,8,10),
  ('review_per_skill','Practice','Review per skill','questions',1,10,9,2),
  ('access_grace_days','Access','Days after test date','days',0,60,10,14),
  ('access_min_days','Access','Minimum access','days',1,365,11,60),
  ('test_date_max_days','Access','Latest test date','days ahead',30,730,12,548),
  ('device_limit','Devices','Devices per student','devices',1,5,13,2),
  ('ai_daily_cap','AI','AI questions per day','per day',0,200,14,20);
grant select on setting_cases to authenticated;
update public.settings s set value = to_jsonb(c.value),
  updated_at = '2020-01-01'::timestamptz from setting_cases c where s.key = c.key;
select is((select count(*)::int from public.settings s join setting_cases c using(key)),
  14,'ADM-06: every editable setting already exists');

select tests.authenticate_as('settings_student');
select throws_ok($$ select public.teacher_get_settings() $$,
  'P0001','forbidden','ADM-06: student cannot read teacher settings');
select throws_ok($$ select public.teacher_update_settings('{"pass_mark":80}') $$,
  'P0001','forbidden','ADM-06: student cannot save teacher settings');
select tests.clear_authentication();
set local role anon;
select throws_ok($$ select public.teacher_get_settings() $$,
  '42501',null,'ADM-06: anon has no execute on reads');
select throws_ok($$ select public.teacher_update_settings('{}') $$,
  '42501',null,'ADM-06: anon has no execute on writes');
reset role;
set local role authenticated;
select throws_ok($$ select public.teacher_get_settings() $$,
  'P0001','not_authenticated','ADM-06: read checks auth uid');
select throws_ok($$ select public.teacher_update_settings('{}') $$,
  'P0001','not_authenticated','ADM-06: write checks auth uid');
reset role;
select ok(not has_function_privilege('authenticated',
  'private.teacher_setting_spec()','execute') and not has_function_privilege(
  'anon','private.teacher_setting_spec()','execute'),
  'ADM-06: allow-list helper is private');

select tests.authenticate_as('settings_teacher');
select is(public.teacher_get_settings(),
  (select jsonb_agg(jsonb_build_object('key',key,'group',grp,'label',label,
    'unit',unit,'min',min,'max',max,'value',value) order by sort) from setting_cases),
  'ADM-06: returns exact ordered allow-list metadata and values');
select set_config('test.settings_before', (select jsonb_object_agg(key,to_jsonb(s))::text
  from public.settings s),true);
select is(public.teacher_update_settings('{}'),'{"ok":true,"updated":[]}'::jsonb,
  'ADM-06: empty patch is a no-op');
select is((select jsonb_object_agg(key,to_jsonb(s)) from public.settings s),
  current_setting('test.settings_before')::jsonb,'ADM-06: no-op leaves timestamps alone');
select is(public.teacher_update_settings('{"pass_mark":80,"device_limit":3}'),
  '{"ok":true,"updated":["device_limit","pass_mark"]}'::jsonb,
  'ADM-06: saves two keys and returns deterministic updated keys');
select is((select value from public.settings where key='pass_mark'),'80'::jsonb,
  'ADM-06: pass mark changed');
select is((select value from public.settings where key='device_limit'),'3'::jsonb,
  'ADM-06: device limit changed');
select is_empty($$ select key from public.settings s where key not in ('pass_mark','device_limit')
  and to_jsonb(s) is distinct from current_setting('test.settings_before')::jsonb -> key $$,
  'ADM-06: other values and timestamps stay untouched');
select is((select count(*)::int from public.settings where key in ('pass_mark','device_limit')
  and updated_at = now()),2,'ADM-06: updated_at changes for saved keys');
select results_eq($$ select action,entity,diff from public.audit_log where actor=auth.uid()
  order by entity $$,
  $$ values ('settings.update'::text,'device_limit'::text,'{"before":2,"after":3}'::jsonb),
    ('settings.update','pass_mark','{"before":75,"after":80}'::jsonb) $$,
  'ADM-06: exactly one complete before/after audit per saved key');

-- Every boundary is tested with a safe quiz triple in the same transaction.
select lives_ok(format('select public.teacher_update_settings(%L::jsonb)',
  (jsonb_build_object('quiz_size',60,'quiz_time_per_q_s',600,'quiz_warn_s',0)
   || jsonb_build_object(c.key,b.value))::text),
  'ADM-06: accepts ' || c.key || ' ' || b.label)
from setting_cases c cross join lateral (values ('min',c.min),('max',c.max)) b(label,value);
select is(public.teacher_update_settings('{"pass_mark":75.0}') -> 'ok','true'::jsonb,
  'ADM-06: mathematically integral JSON numbers are accepted');

select set_config('test.settings_before',(select jsonb_object_agg(key,to_jsonb(s))::text
  from public.settings s),true);
select set_config('test.settings_audits',(select count(*)::text from public.audit_log),true);
select throws_ok(format('select public.teacher_update_settings(%L::jsonb)',
  jsonb_build_object(c.key,b.value)::text),'P0001','invalid_input',
  'ADM-06: rejects ' || c.key || ' ' || b.label)
from setting_cases c cross join lateral (values ('below',c.min-1),('above',c.max+1)) b(label,value);
select throws_ok(format('select public.teacher_update_settings(%L::jsonb)',payload),
  'P0001','invalid_input','ADM-06: rejects malformed or mixed patch ' || coalesce(payload,'SQL NULL'))
from (values (null::text),('null'),('[]'),('1'),('true'),('"text"'),
  ('{"pass_mark":"80"}'),('{"pass_mark":75.5}'),('{"pass_mark":null}'),
  ('{"pass_mark":true}'),('{"pass_mark":[]}'),('{"pass_mark":{}}'),
  ('{"pass_mark":1e100}'),('{"pass_mark":80,"device_limit":6}'),
  ('{"pass_mark":80,"unknown":1}')) v(payload);
select throws_ok(format('select public.teacher_update_settings(%L::jsonb)',
  jsonb_build_object('pass_mark',80,k,1)::text),'P0001','invalid_input',
  'ADM-06: teacher cannot edit hidden key ' || k)
from (values ('currency_by_country'),('rate_start_per_min'),('device_header_required'),
  ('practice_stale_h'),('save_grace_s'),('video_done_pct'),('pool_split')) v(k);
select is((select jsonb_object_agg(key,to_jsonb(s)) from public.settings s),
  current_setting('test.settings_before')::jsonb,'ADM-06: invalid patches change no values or timestamps');
select is((select count(*)::text from public.audit_log),current_setting('test.settings_audits'),
  'ADM-06: invalid patches and mixed valid/invalid patches emit no audits');

select lives_ok($$ select public.teacher_update_settings(
  '{"quiz_size":10,"quiz_time_per_q_s":60,"quiz_warn_s":599}') $$,
  'ADM-06: warning strictly below duration is accepted');
select set_config('test.settings_before',(select jsonb_object_agg(key,to_jsonb(s))::text
  from public.settings s),true);
select set_config('test.settings_audits',(select count(*)::text from public.audit_log),true);
select throws_ok(format('select public.teacher_update_settings(%L::jsonb)',p),
  'P0001','invalid_input','ADM-06: rejects cross-field violation ' || p)
from (values ('{"quiz_warn_s":600}'),('{"quiz_size":9}'),('{"quiz_time_per_q_s":59}'),
  ('{"pass_mark":80,"quiz_size":1,"quiz_time_per_q_s":15,"quiz_warn_s":15}')) v(p);
select is((select jsonb_object_agg(key,to_jsonb(s)) from public.settings s),
  current_setting('test.settings_before')::jsonb,'ADM-06: cross-field failure is atomic');
select is((select count(*)::text from public.audit_log),current_setting('test.settings_audits'),
  'ADM-06: cross-field failure is not audited');
select lives_ok($$ select public.teacher_update_settings(
  '{"quiz_size":12,"quiz_time_per_q_s":60,"quiz_warn_s":700}') $$,
  'ADM-06: cross-field validation uses all proposed values');
select lives_ok($$ select public.teacher_update_settings(
  '{"quiz_size":1,"quiz_time_per_q_s":15,"quiz_warn_s":14}') $$,
  'ADM-06: duration and warning can decrease together');

select * from finish();
rollback;
