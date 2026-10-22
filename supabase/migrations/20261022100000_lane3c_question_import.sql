-- C-4 / QB-05. From templates/rpc.sql and templates/setting.sql.
insert into public.settings(key,value) values ('import_max_rows','500'::jsonb)
on conflict(key) do nothing;

create function private.import_problem(p_row jsonb,p_index int,p_field text,p_problem text)
returns jsonb language sql immutable set search_path='' as $$
 select pg_catalog.jsonb_build_object('row',p_index,'external_ref',p_row->>'external_ref',
 'field',p_field,'problem',p_problem);
$$;
revoke all on function private.import_problem(jsonb,int,text,text) from public,anon,authenticated,service_role;

create function private.validate_question_row(p_row jsonb,p_index int)
returns setof jsonb language plpgsql stable set search_path='' as $$
declare
 f text; v jsonb; c jsonb; labels text[] := '{}';
 topic uuid; sub_count int; bad boolean := false;
begin
 if pg_catalog.jsonb_typeof(p_row) is distinct from 'object' then
  return next private.import_problem(p_row,p_index,'row','missing:row'); return;
 end if;
 foreach f in array array['external_ref','course_codes','topic_slug','subtopic_slug','type','difficulty','stem_md','key','pool','status'] loop
  v := p_row->f;
  if v is null or v='null'::jsonb or v='""'::jsonb or v='[]'::jsonb or v='{}'::jsonb
   or (pg_catalog.jsonb_typeof(v)='string' and pg_catalog.btrim(v #>> '{}')='') then
   return next private.import_problem(p_row,p_index,f,'missing:'||f);
  end if;
 end loop;
 foreach f in array array['external_ref','topic_slug','subtopic_slug','stem_md','explanation_md','hint_md','source','solved_by'] loop
  if p_row ? f and p_row->f <> 'null'::jsonb and pg_catalog.jsonb_typeof(p_row->f) <> 'string' then
   return next private.import_problem(p_row,p_index,f,'missing:'||f);
  end if;
 end loop;
 foreach f in array array['type','difficulty','pool','status','solved_by'] loop
  if not (p_row ? f) or p_row->f='null'::jsonb then continue; end if;
  bad := true;
  if f='type' then bad := (p_row->>f) not in ('mcq','spr'); end if;
  if f='difficulty' then bad := (p_row->>f) not in ('E','M','H'); end if;
  if f='pool' then bad := (p_row->>f) not in ('practice','quiz','mock_reserve'); end if;
  if f='status' then bad := (p_row->>f) not in ('draft','solved','needs_review','approved','published'); end if;
  if f='solved_by' then bad := (p_row->>f) not in ('teacher','ai_double_agree','ai_teacher_fixed'); end if;
  if bad then return next private.import_problem(p_row,p_index,f,'bad_enum:'||f); end if;
 end loop;
 foreach f in array array['course_codes','skill_codes','images'] loop
  if not (p_row ? f) and f <> 'course_codes' then continue; end if;
  if pg_catalog.jsonb_typeof(p_row->f) is distinct from 'array' then
   return next private.import_problem(p_row,p_index,f,'missing:'||f); continue;
  end if;
  for v in select pg_catalog.jsonb_array_elements(p_row->f) loop
   if pg_catalog.jsonb_typeof(v) <> 'string' or pg_catalog.btrim(v #>> '{}')='' then
    return next private.import_problem(p_row,p_index,f,'missing:'||f); continue;
   end if;
   if f='course_codes' and not exists(select 1 from public.courses where code::text=v #>> '{}') then
    return next private.import_problem(p_row,p_index,f,'unknown_course:'||(v #>> '{}'));
   end if;
   if f='skill_codes' and not exists(select 1 from public.skills where code=v #>> '{}') then
    return next private.import_problem(p_row,p_index,f,'unknown_skill:'||(v #>> '{}'));
   end if;
  end loop;
 end loop;
 select t.id into topic from public.topics t join public.courses c on c.id=t.course_id
 where c.code::text=p_row->'course_codes'->>0 and t.slug=p_row->>'topic_slug';
 if topic is null then
  return next private.import_problem(p_row,p_index,'topic_slug','unknown_topic');
 else
  select count(*) into sub_count from public.subtopics s where s.topic_id=topic
   and private.slugify(s.title)=p_row->>'subtopic_slug';
  if sub_count <> 1 then return next private.import_problem(p_row,p_index,'subtopic_slug','unknown_subtopic'); end if;
 end if;
 if p_row->>'type'='mcq' then
  bad := true;
  if pg_catalog.jsonb_typeof(p_row->'choices')='array' then
   bad := pg_catalog.jsonb_array_length(p_row->'choices') not between 2 and 5;
   for c in select pg_catalog.jsonb_array_elements(p_row->'choices') loop
    if pg_catalog.jsonb_typeof(c) <> 'object' or pg_catalog.jsonb_typeof(c->'label') is distinct from 'string'
     or coalesce(c->>'label','') not in ('A','B','C','D','E') or c->>'label'=any(labels)
     or pg_catalog.jsonb_typeof(c->'body_md') is distinct from 'string' or pg_catalog.btrim(c->>'body_md')='' then bad := true; end if;
    labels := pg_catalog.array_append(labels,c->>'label');
    if pg_catalog.length(c->>'body_md')>1000 then return next private.import_problem(p_row,p_index,'choices','too_long:choices'); end if;
   end loop;
  end if;
  if bad then return next private.import_problem(p_row,p_index,'choices','mcq_choices'); end if;
  if pg_catalog.jsonb_typeof(p_row->'key'->'choice') is distinct from 'string'
   or not coalesce(p_row->'key'->>'choice'=any(labels),false) then
   return next private.import_problem(p_row,p_index,'key','key_not_in_choices');
  end if;
 elsif p_row->>'type'='spr' then
  if p_row ? 'choices' and p_row->'choices' <> '[]'::jsonb then
   return next private.import_problem(p_row,p_index,'choices','spr_has_choices');
  end if;
  bad := true;
  if pg_catalog.jsonb_typeof(p_row->'key'->'accepted')='array' then
   bad := pg_catalog.jsonb_array_length(p_row->'key'->'accepted')=0;
   for v in select pg_catalog.jsonb_array_elements(p_row->'key'->'accepted') loop
    if pg_catalog.jsonb_typeof(v) <> 'string' then bad := true;
    else
     begin
      if private.spr_parse(v #>> '{}',false) is null then bad := true; end if;
     exception when numeric_value_out_of_range or invalid_text_representation then bad := true;
     end;
    end if;
   end loop;
  end if;
  if p_row->'key' ? 'tolerance' then
   if pg_catalog.jsonb_typeof(p_row->'key'->'tolerance') is distinct from 'number' then bad := true;
   elsif (p_row->'key'->>'tolerance')::numeric < 0 then bad := true;
   end if;
  end if;
  if bad then return next private.import_problem(p_row,p_index,'key','spr_key'); end if;
 end if;
 if pg_catalog.length(p_row->>'stem_md')>5000 then return next private.import_problem(p_row,p_index,'stem_md','too_long:stem_md'); end if;
 if pg_catalog.length(p_row->>'explanation_md')>5000 then return next private.import_problem(p_row,p_index,'explanation_md','too_long:explanation_md'); end if;
 if p_row ? 'desmos_friendly' and pg_catalog.jsonb_typeof(p_row->'desmos_friendly') is distinct from 'boolean' then
  return next private.import_problem(p_row,p_index,'desmos_friendly','missing:desmos_friendly');
 end if;
 if p_row ? 'source_page' and p_row->'source_page' <> 'null'::jsonb then
  if pg_catalog.jsonb_typeof(p_row->'source_page') is distinct from 'number' then bad := true;
  else
   v := p_row->'source_page';
   bad := v::numeric <> pg_catalog.trunc(v::numeric) or v::numeric not between -2147483648 and 2147483647;
  end if;
  if bad then return next private.import_problem(p_row,p_index,'source_page','missing:source_page'); end if;
 end if;
end;
$$;
revoke all on function private.validate_question_row(jsonb,int) from public,anon,authenticated,service_role;

create function public.teacher_import_questions(p_items jsonb,p_commit boolean)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
 n int; max_rows int; created int; updated int; total_errors int;
 errors jsonb; report jsonb; ids uuid[];
begin
 if auth.uid() is null then raise exception 'not_authenticated'; end if;
 if not public.is_teacher() then raise exception 'forbidden'; end if;
 if pg_catalog.jsonb_typeof(p_items) is distinct from 'array' or p_commit is null then raise exception 'invalid_input'; end if;
 n := pg_catalog.jsonb_array_length(p_items);
 select s.value::int into max_rows from public.settings s where s.key='import_max_rows';
 if max_rows is null or max_rows<1 then raise exception 'invalid_input'; end if;
 if n>max_rows then
  if p_commit then raise exception 'invalid_input'; end if;
  select count(*) filter(where q.id is null),count(*) filter(where q.id is not null) into created,updated
  from pg_catalog.jsonb_array_elements(p_items) r
  left join public.questions q on q.external_ref=r->>'external_ref';
  return pg_catalog.jsonb_build_object('ok',false,'rows',n,'new',created,'updated',updated,
   'errors',pg_catalog.jsonb_build_array(private.import_problem('{}',0,'rows','too_many_rows')),'truncated',false);
 end if;
 -- Serialize commits so counts and replacement writes agree across concurrent imports.
 -- Dry runs do not acquire a write lock or create any database objects.
 if p_commit then perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('teacher_import_questions',0)); end if;
 select count(*) filter(where q.id is null),count(*) filter(where q.id is not null) into created,updated
 from pg_catalog.jsonb_array_elements(p_items) r
 left join public.questions q on q.external_ref=r->>'external_ref';
 with rows as (
  select r,ord::int as idx,count(*) over(partition by r->>'external_ref') as refs
  from pg_catalog.jsonb_array_elements(p_items) with ordinality a(r,ord)
 ), problems as (
  select idx,p from rows cross join lateral private.validate_question_row(r,idx) p
  union all
  select idx,private.import_problem(r,idx,'external_ref','duplicate_ref') from rows
   where refs>1 and pg_catalog.jsonb_typeof(r->'external_ref')='string' and r->>'external_ref'<>''
 ), numbered as (select p,row_number() over(order by idx,p->>'field',p->>'problem') rn from problems)
 select count(*),coalesce(pg_catalog.jsonb_agg(p order by rn) filter(where rn<=200),'[]'::jsonb)
 into total_errors,errors from numbered;
 report := pg_catalog.jsonb_build_object('ok',total_errors=0,'rows',n,'new',created,'updated',updated,'errors',errors,'truncated',total_errors>200);
 if total_errors>0 then
  if p_commit then raise exception 'invalid_input'; end if;
  return report;
 end if;
 if not p_commit or n=0 then return report; end if;
 with saved as (
 insert into public.questions as q (external_ref,topic_id,subtopic_id,type,difficulty,stem_md,image_paths,hint_md,desmos_friendly,pool,status,source,source_page)
 select r->>'external_ref',t.id,s.id,(r->>'type')::public.question_type,(r->>'difficulty')::public.difficulty,
 r->>'stem_md',array(select pg_catalog.jsonb_array_elements_text(coalesce(r->'images','[]'))),
 r->>'hint_md',coalesce((r->>'desmos_friendly')::boolean,false),(r->>'pool')::public.question_pool,
 (r->>'status')::public.question_status,r->>'source',(r->>'source_page')::numeric::int
 from pg_catalog.jsonb_array_elements(p_items) r
 join public.courses c on c.code::text=r->'course_codes'->>0
 join public.topics t on t.course_id=c.id and t.slug=r->>'topic_slug'
 join public.subtopics s on s.topic_id=t.id and private.slugify(s.title)=r->>'subtopic_slug'
 order by r->>'external_ref'
 on conflict(external_ref) do update set topic_id=excluded.topic_id,subtopic_id=excluded.subtopic_id,
 type=excluded.type,difficulty=excluded.difficulty,stem_md=excluded.stem_md,image_paths=excluded.image_paths,
 hint_md=excluded.hint_md,desmos_friendly=excluded.desmos_friendly,pool=excluded.pool,status=excluded.status,
 source=excluded.source,source_page=excluded.source_page,version=q.version+1,updated_at=pg_catalog.now()
 returning id)
 select pg_catalog.array_agg(id) into ids from saved;
 delete from public.question_choices where question_id=any(ids);
 delete from public.question_courses where question_id=any(ids);
 delete from public.question_skills where question_id=any(ids);
 insert into public.question_choices(question_id,label,body_md)
 select q.id,c->>'label',c->>'body_md' from pg_catalog.jsonb_array_elements(p_items) r
 join public.questions q on q.external_ref=r->>'external_ref'
 cross join lateral pg_catalog.jsonb_array_elements(coalesce(r->'choices','[]')) c;
 insert into public.question_courses(question_id,course_id)
 select distinct q.id,c.id from pg_catalog.jsonb_array_elements(p_items) r
 join public.questions q on q.external_ref=r->>'external_ref'
 cross join lateral pg_catalog.jsonb_array_elements_text(r->'course_codes') course_codes(course_code)
 join public.courses c on c.code::text=course_codes.course_code;
 insert into public.question_skills(question_id,skill_id)
 select distinct q.id,s.id from pg_catalog.jsonb_array_elements(p_items) r
 join public.questions q on q.external_ref=r->>'external_ref'
 cross join lateral pg_catalog.jsonb_array_elements_text(coalesce(r->'skill_codes','[]')) skill_codes(skill_code)
 join public.skills s on s.code=skill_codes.skill_code;
 insert into private.question_keys(question_id,correct_answer,explanation_md,misconceptions,solved_by)
 select q.id,r->'key',r->>'explanation_md',r->'misconceptions',r->>'solved_by'
 from pg_catalog.jsonb_array_elements(p_items) r join public.questions q on q.external_ref=r->>'external_ref'
 on conflict(question_id) do update set correct_answer=excluded.correct_answer,explanation_md=excluded.explanation_md,
 misconceptions=excluded.misconceptions,solved_by=excluded.solved_by,updated_at=pg_catalog.now();
 insert into public.audit_log(actor,action,entity,diff) values(auth.uid(),'questions.import','questions',
 pg_catalog.jsonb_build_object('created',created,'updated',updated,'refs',
 (select pg_catalog.jsonb_agg(r->>'external_ref' order by ord) from pg_catalog.jsonb_array_elements(p_items) with ordinality a(r,ord))));
 return report;
end;
$$;
revoke execute on function public.teacher_import_questions(jsonb,boolean) from public,anon;
grant execute on function public.teacher_import_questions(jsonb,boolean) to authenticated;
