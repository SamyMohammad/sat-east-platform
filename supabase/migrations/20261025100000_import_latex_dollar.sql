-- C-4 / QB-05 / QB-06. From supabase/templates/rpc.sql.
-- Internal validation helpers run inside the existing teacher-authorized RPCs.
create or replace function private.has_dollar_latex(p_text text)
returns boolean language sql immutable set search_path='' as $$
 select coalesce(p_text ~ $regex$\$[^$]*[\\^_{}][^$]*\$$regex$, false);
$$;
revoke all on function private.has_dollar_latex(text) from public,anon,authenticated,service_role;

create or replace function private.validate_question_row(p_row jsonb,p_index int)
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
 foreach f in array array['stem_md','hint_md','explanation_md'] loop
  if pg_catalog.jsonb_typeof(p_row->f)='string' and private.has_dollar_latex(p_row->>f) then
   return next private.import_problem(p_row,p_index,f,'latex_dollar:'||f);
  end if;
 end loop;
 if pg_catalog.jsonb_typeof(p_row->'choices')='array' then
  for c in select pg_catalog.jsonb_array_elements(p_row->'choices') loop
   if pg_catalog.jsonb_typeof(c->'body_md')='string' and private.has_dollar_latex(c->>'body_md') then
    return next private.import_problem(p_row,p_index,'choices','latex_dollar:choices');
   end if;
  end loop;
 end if;
end;
$$;
revoke all on function private.validate_question_row(jsonb,int) from public,anon,authenticated,service_role;
