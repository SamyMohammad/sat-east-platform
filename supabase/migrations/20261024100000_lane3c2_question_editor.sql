-- C-5 / QB-06. From supabase/templates/rpc.sql and setting.sql.
insert into public.settings(key, value) values ('bank_page_size', '25'::jsonb)
on conflict (key) do nothing;

-- A custom escape marker also leaves backslashes in search text literal.
create function private.bank_search_pattern(p_q text)
returns text language sql immutable set search_path = '' as $$
  select '%' || pg_catalog.replace(pg_catalog.replace(pg_catalog.replace(
    p_q, '!', '!!'), '%', '!%'), '_', '!_') || '%';
$$;
revoke all on function private.bank_search_pattern(text)
  from public, anon, authenticated, service_role;

create function private.question_status_change_allowed(p_from text, p_to text)
returns boolean language plpgsql immutable set search_path = '' as $$
declare
  lifecycle text[] := array['draft','solved','needs_review','approved','published'];
begin
  if p_to = 'retired' then return true; end if;
  if p_from is null then return p_to = any(lifecycle); end if;
  if p_from = 'retired' then return p_to = 'draft'; end if;
  return coalesce(pg_catalog.array_position(lifecycle, p_to) >=
    pg_catalog.array_position(lifecycle, p_from), false);
end;
$$;
revoke all on function private.question_status_change_allowed(text,text)
  from public, anon, authenticated, service_role;

create function public.teacher_list_questions(p_filter jsonb, p_page int)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_filter jsonb := coalesce(p_filter, '{}'::jsonb);
  v_pair record;
  v_topic uuid;
  v_subtopic uuid;
  v_page_size int;
  v_result jsonb;
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  if not public.is_teacher() then raise exception 'forbidden'; end if;
  if pg_catalog.jsonb_typeof(v_filter) <> 'object' or p_page is null or p_page < 1 then
    raise exception 'invalid_input';
  end if;
  for v_pair in select * from pg_catalog.jsonb_each(v_filter) loop
    if v_pair.key not in ('course_code','topic_id','subtopic_id','status','pool','difficulty','type','q')
      or (v_pair.value <> 'null'::jsonb and pg_catalog.jsonb_typeof(v_pair.value) <> 'string') then
      raise exception 'invalid_input';
    end if;
  end loop;
  begin
    v_topic := (v_filter ->> 'topic_id')::uuid;
    v_subtopic := (v_filter ->> 'subtopic_id')::uuid;
  exception when invalid_text_representation then raise exception 'invalid_input';
  end;
  select s.value::int into v_page_size from public.settings s where s.key = 'bank_page_size';
  if v_page_size is null or v_page_size < 1 then raise exception 'invalid_input'; end if;
  with matching as materialized (
    select q.id, q.external_ref, pg_catalog.split_part(q.stem_md, pg_catalog.chr(10), 1) as stem_preview,
      q.type, t.title as topic_title, st.title as subtopic_title, q.difficulty,
      q.pool, q.status, q.version, q.updated_at
    from public.questions q join public.topics t on t.id = q.topic_id
    join public.subtopics st on st.id = q.subtopic_id
    where (v_topic is null or q.topic_id = v_topic)
      and (v_subtopic is null or q.subtopic_id = v_subtopic)
      and (v_filter ->> 'status' is null or q.status::text = v_filter ->> 'status')
      and (v_filter ->> 'pool' is null or q.pool::text = v_filter ->> 'pool')
      and (v_filter ->> 'difficulty' is null or q.difficulty::text = v_filter ->> 'difficulty')
      and (v_filter ->> 'type' is null or q.type::text = v_filter ->> 'type')
      and (v_filter ->> 'course_code' is null or exists (
        select 1 from public.question_courses qc join public.courses c on c.id = qc.course_id
        where qc.question_id = q.id and c.code::text = v_filter ->> 'course_code'))
      and (v_filter ->> 'q' is null
        or q.external_ref ilike private.bank_search_pattern(v_filter ->> 'q') escape '!'
        or q.stem_md ilike private.bank_search_pattern(v_filter ->> 'q') escape '!')
  ), page_rows as (
    select * from matching order by updated_at desc, id
    limit v_page_size offset ((p_page::bigint - 1) * v_page_size)
  )
  select pg_catalog.jsonb_build_object('total', (select count(*) from matching),
    'page', p_page, 'page_size', v_page_size,
    'rows', coalesce((select pg_catalog.jsonb_agg(pg_catalog.to_jsonb(r)
      order by r.updated_at desc, r.id) from page_rows r), '[]'::jsonb)) into v_result;
  return v_result;
end;
$$;
revoke execute on function public.teacher_list_questions(jsonb,int) from public, anon;
grant execute on function public.teacher_list_questions(jsonb,int) to authenticated;

create function public.teacher_get_question(p_id uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_result jsonb;
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  if not public.is_teacher() then raise exception 'forbidden'; end if;
  select pg_catalog.jsonb_build_object(
    'id', q.id, 'version', q.version, 'updated_at', q.updated_at,
    'external_ref', q.external_ref, 'topic_slug', t.slug,
    'subtopic_slug', private.slugify(st.title), 'type', q.type,
    'difficulty', q.difficulty, 'stem_md', q.stem_md, 'images', q.image_paths,
    'hint_md', q.hint_md, 'desmos_friendly', q.desmos_friendly,
    'pool', q.pool, 'status', q.status, 'source', q.source, 'source_page', q.source_page,
    'key', k.correct_answer, 'explanation_md', k.explanation_md,
    'misconceptions', k.misconceptions, 'solved_by', k.solved_by,
    -- Resolution uses the first course; the topic's course must lead this array.
    'course_codes', coalesce((select pg_catalog.jsonb_agg(c.code::text
      order by (c.id = t.course_id) desc, c.code::text)
      from public.question_courses qc join public.courses c on c.id = qc.course_id
      where qc.question_id = q.id), '[]'::jsonb),
    'skill_codes', coalesce((select pg_catalog.jsonb_agg(s.code order by s.code)
      from public.question_skills qs join public.skills s on s.id = qs.skill_id
      where qs.question_id = q.id), '[]'::jsonb),
    'choices', coalesce((select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
      'label', ch.label::text, 'body_md', ch.body_md) order by ch.label)
      from public.question_choices ch where ch.question_id = q.id), '[]'::jsonb)
  ) into v_result from public.questions q
  join public.topics t on t.id = q.topic_id join public.subtopics st on st.id = q.subtopic_id
  left join private.question_keys k on k.question_id = q.id where q.id = p_id;
  if v_result is null then raise exception 'invalid_input'; end if;
  return v_result;
end;
$$;
revoke execute on function public.teacher_get_question(uuid) from public, anon;
grant execute on function public.teacher_get_question(uuid) to authenticated;

create function public.teacher_save_question(p_id uuid, p_row jsonb, p_expected_version int)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_id uuid := p_id;
  v_existing public.questions%rowtype;
  v_errors jsonb;
  v_validation_row jsonb := p_row;
  v_topic uuid;
  v_subtopic uuid;
  v_version int;
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  if not public.is_teacher() then raise exception 'forbidden'; end if;
  if p_id is not null then
    select * into v_existing from public.questions q where q.id = p_id for update;
    if not found then raise exception 'invalid_input'; end if;
    if v_existing.version is distinct from p_expected_version then
      raise exception 'version_conflict';
    end if;
  end if;
  if exists (select 1 from public.questions q where q.external_ref = p_row ->> 'external_ref'
    and q.id is distinct from p_id) then raise exception 'invalid_input'; end if;
  -- Import excludes retired. Reuse all of its other validation rules unchanged.
  if p_row ->> 'status' = 'retired' then
    v_validation_row := p_row || '{"status":"draft"}'::jsonb;
  end if;
  select coalesce(pg_catalog.jsonb_agg(problem order by problem ->> 'field', problem ->> 'problem'),
    '[]'::jsonb) into v_errors from private.validate_question_row(v_validation_row, 1) problem;
  if p_row ->> 'status' in ('draft','solved','needs_review','approved','published','retired')
    and not private.question_status_change_allowed(v_existing.status::text, p_row ->> 'status') then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      private.import_problem(p_row, 1, 'status', 'bad_status_change'));
  end if;
  if v_errors <> '[]'::jsonb then
    return pg_catalog.jsonb_build_object('ok', false, 'errors', v_errors);
  end if;
  -- Locks prevent classification rows disappearing between validation and persistence.
  select t.id, st.id into v_topic, v_subtopic from public.courses c
    join public.topics t on t.course_id = c.id and t.slug = p_row ->> 'topic_slug'
    join public.subtopics st on st.topic_id = t.id and private.slugify(st.title) = p_row ->> 'subtopic_slug'
    where c.code::text = p_row -> 'course_codes' ->> 0 for share of c, t, st;
  if not found then
    return pg_catalog.jsonb_build_object('ok', false, 'errors', pg_catalog.jsonb_build_array(
      private.import_problem(p_row, 1, 'subtopic_slug', 'unknown_subtopic')));
  end if;
  if p_id is null then
    insert into public.questions(external_ref, topic_id, subtopic_id, type, difficulty, stem_md,
      image_paths, hint_md, desmos_friendly, pool, status, source, source_page)
    values(p_row ->> 'external_ref', v_topic, v_subtopic,
      (p_row ->> 'type')::public.question_type, (p_row ->> 'difficulty')::public.difficulty,
      p_row ->> 'stem_md', array(select pg_catalog.jsonb_array_elements_text(coalesce(p_row -> 'images','[]'))),
      p_row ->> 'hint_md', coalesce((p_row ->> 'desmos_friendly')::boolean, false),
      (p_row ->> 'pool')::public.question_pool, (p_row ->> 'status')::public.question_status,
      p_row ->> 'source', (p_row ->> 'source_page')::numeric::int)
    returning id, version into v_id, v_version;
  else
    update public.questions set external_ref = p_row ->> 'external_ref', topic_id = v_topic,
      subtopic_id = v_subtopic, type = (p_row ->> 'type')::public.question_type,
      difficulty = (p_row ->> 'difficulty')::public.difficulty, stem_md = p_row ->> 'stem_md',
      image_paths = array(select pg_catalog.jsonb_array_elements_text(coalesce(p_row -> 'images','[]'))),
      hint_md = p_row ->> 'hint_md', desmos_friendly = coalesce((p_row ->> 'desmos_friendly')::boolean, false),
      pool = (p_row ->> 'pool')::public.question_pool, status = (p_row ->> 'status')::public.question_status,
      source = p_row ->> 'source', source_page = (p_row ->> 'source_page')::numeric::int,
      version = v_existing.version + 1, updated_at = pg_catalog.now() where id = p_id
    returning version into v_version;
  end if;
  delete from public.question_choices where question_id = v_id;
  delete from public.question_courses where question_id = v_id;
  delete from public.question_skills where question_id = v_id;
  insert into public.question_choices(question_id, label, body_md)
    select v_id, ch ->> 'label', ch ->> 'body_md'
    from pg_catalog.jsonb_array_elements(coalesce(p_row -> 'choices','[]')) ch;
  insert into public.question_courses(question_id, course_id)
    select distinct v_id, c.id from pg_catalog.jsonb_array_elements_text(p_row -> 'course_codes') codes(code)
    join public.courses c on c.code::text = codes.code;
  insert into public.question_skills(question_id, skill_id)
    select distinct v_id, s.id from pg_catalog.jsonb_array_elements_text(coalesce(p_row -> 'skill_codes','[]')) codes(code)
    join public.skills s on s.code = codes.code;
  insert into private.question_keys(question_id, correct_answer, explanation_md, misconceptions, solved_by)
    values(v_id, p_row -> 'key', p_row ->> 'explanation_md', p_row -> 'misconceptions', p_row ->> 'solved_by')
    on conflict(question_id) do update set correct_answer = excluded.correct_answer,
      explanation_md = excluded.explanation_md, misconceptions = excluded.misconceptions,
      solved_by = excluded.solved_by, updated_at = pg_catalog.now();
  insert into public.audit_log(actor, action, entity, entity_id, diff)
    values(auth.uid(), 'question.save', 'questions', v_id, pg_catalog.jsonb_build_object(
      'from_version', v_existing.version, 'to_version', v_version,
      'status_from', v_existing.status, 'status_to', p_row ->> 'status'));
  return pg_catalog.jsonb_build_object('id', v_id, 'version', v_version);
exception when unique_violation then raise exception 'invalid_input';
end;
$$;
revoke execute on function public.teacher_save_question(uuid,jsonb,int) from public, anon;
grant execute on function public.teacher_save_question(uuid,jsonb,int) to authenticated;

create function public.teacher_list_topics_tree()
returns jsonb language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  if not public.is_teacher() then raise exception 'forbidden'; end if;
  return coalesce((select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
    'course_code', c.code, 'topics', coalesce((select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
      'id', t.id, 'slug', t.slug, 'title', t.title,
      'subtopics', coalesce((select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
        'id', st.id, 'slug', private.slugify(st.title), 'title', st.title) order by st.sort, st.id)
        from public.subtopics st where st.topic_id = t.id), '[]'::jsonb)) order by t.sort, t.id)
      from public.topics t where t.course_id = c.id), '[]'::jsonb)) order by c.sort, c.id)
    from public.courses c), '[]'::jsonb);
end;
$$;
revoke execute on function public.teacher_list_topics_tree() from public, anon;
grant execute on function public.teacher_list_topics_tree() to authenticated;
