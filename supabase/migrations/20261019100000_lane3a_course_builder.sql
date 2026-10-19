-- C-1 / ADM-01: teacher course builder. From supabase/templates/rpc.sql.
-- unaccent supplies ASCII transliteration without client-side slug generation.
create extension if not exists unaccent with schema extensions;

create function private.slugify(p_title text)
returns text
language sql
stable
set search_path = ''
as $$
  select coalesce(nullif(pg_catalog.btrim(pg_catalog.regexp_replace(
    pg_catalog.lower(extensions.unaccent('extensions.unaccent'::regdictionary,
      coalesce(p_title, '')) collate "C"),
    '[^a-z0-9]+', '-', 'g'), '-'), ''), 'topic');
$$;
revoke all on function private.slugify(text)
  from public, anon, authenticated, service_role;

-- All direct FKs to these nodes (schema F-2). question_courses and
-- question_exposure reference questions, so the questions check covers both.
-- Use the same predicate for the tree and deletion; the FK remains the final
-- concurrency guard if a reference is inserted after this check.
create function private.builder_node_in_use(p_kind text, p_id uuid)
returns boolean
language sql
stable
set search_path = ''
as $$
  select case p_kind
    when 'unit' then exists (
      select 1 from public.topics t where t.unit_id = p_id)
    when 'topic' then
      exists (select 1 from public.subtopics s where s.topic_id = p_id)
      or exists (select 1 from public.topic_assets a where a.topic_id = p_id)
      or exists (select 1 from public.questions q where q.topic_id = p_id)
      or exists (select 1 from public.attempts a where a.topic_id = p_id)
      or exists (select 1 from public.topic_progress p where p.topic_id = p_id)
    when 'subtopic' then
      exists (select 1 from public.topic_assets a where a.subtopic_id = p_id)
      or exists (select 1 from public.video_chapters c where c.subtopic_id = p_id)
      or exists (select 1 from public.subtopic_skills s where s.subtopic_id = p_id)
      or exists (select 1 from public.questions q where q.subtopic_id = p_id)
    else false
  end;
$$;
revoke all on function private.builder_node_in_use(text, uuid)
  from public, anon, authenticated, service_role;

create function public.teacher_list_courses()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  if not public.is_teacher() then raise exception 'forbidden'; end if;
  return (select coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
    'id', c.id, 'code', c.code, 'title', c.title, 'slug', c.slug,
    'is_published', c.is_published) order by c.sort, c.id), '[]'::jsonb)
    from public.courses c);
end;
$$;
revoke execute on function public.teacher_list_courses() from public, anon;
grant execute on function public.teacher_list_courses() to authenticated;

create function public.teacher_get_course_tree(p_course_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_course jsonb;
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  if not public.is_teacher() then raise exception 'forbidden'; end if;
  select pg_catalog.jsonb_build_object('id', c.id, 'title', c.title, 'code', c.code)
  into v_course from public.courses c where c.id = p_course_id;
  if not found then raise exception 'invalid_input'; end if;

  return pg_catalog.jsonb_build_object('course', v_course, 'units', (
    select coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
      'id', u.id, 'title', u.title, 'sort', u.sort,
      'in_use', private.builder_node_in_use('unit', u.id), 'topics', (
        select coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
          'id', t.id, 'title', t.title, 'slug', t.slug, 'sort', t.sort,
          'is_published', t.is_published, 'is_free_preview', t.is_free_preview,
          'subtopic_count', (select count(*) from public.subtopics s
            where s.topic_id = t.id),
          'in_use', private.builder_node_in_use('topic', t.id), 'subtopics', (
            select coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
              'id', s.id, 'title', s.title, 'sort', s.sort,
              'in_use', private.builder_node_in_use('subtopic', s.id))
              order by s.sort, s.id), '[]'::jsonb)
            from public.subtopics s where s.topic_id = t.id))
          order by t.sort, t.id), '[]'::jsonb)
        from public.topics t where t.unit_id = u.id))
      order by u.sort, u.id), '[]'::jsonb)
    from public.units u where u.course_id = p_course_id));
end;
$$;
revoke execute on function public.teacher_get_course_tree(uuid) from public, anon;
grant execute on function public.teacher_get_course_tree(uuid) to authenticated;

create function public.teacher_upsert_unit(
  p_id uuid, p_course_id uuid, p_title text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_title text := pg_catalog.regexp_replace(p_title,
    '^[[:space:]]+|[[:space:]]+$', '', 'g');
  v_id uuid;
  v_before jsonb;
  v_after jsonb;
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  if not public.is_teacher() then raise exception 'forbidden'; end if;
  if v_title is null or pg_catalog.char_length(v_title) not between 1 and 120 then
    raise exception 'invalid_input';
  end if;
  perform 1 from public.courses p where p.id = p_course_id for update;
  if not found then raise exception 'invalid_input'; end if;
  if p_id is null then
    insert into public.units (course_id, title, sort)
    select p_course_id, v_title, coalesce(max(n.sort), 0) + 1
    from public.units n where n.course_id = p_course_id
    returning id into v_id;
  else
    select pg_catalog.to_jsonb(n) into v_before from public.units n
    where n.id = p_id and n.course_id = p_course_id for update;
    if not found then raise exception 'invalid_input'; end if;
    update public.units set title = v_title where id = p_id returning id into v_id;
  end if;
  select pg_catalog.to_jsonb(n) into v_after from public.units n where n.id = v_id;
  insert into public.audit_log (actor, action, entity, entity_id, diff)
  values (auth.uid(), 'node.upsert', 'unit', v_id,
    pg_catalog.jsonb_build_object('before', v_before, 'after', v_after));
  return pg_catalog.jsonb_build_object('id', v_id);
end;
$$;
revoke execute on function public.teacher_upsert_unit(uuid, uuid, text)
  from public, anon;
grant execute on function public.teacher_upsert_unit(uuid, uuid, text)
  to authenticated;

create function public.teacher_upsert_topic(
  p_id uuid, p_unit_id uuid, p_title text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_title text := pg_catalog.regexp_replace(p_title,
    '^[[:space:]]+|[[:space:]]+$', '', 'g');
  v_id uuid;
  v_before jsonb;
  v_after jsonb;
  v_course_id uuid;
  v_base text;
  v_slug text;
  v_suffix int := 2;
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  if not public.is_teacher() then raise exception 'forbidden'; end if;
  if v_title is null or pg_catalog.char_length(v_title) not between 1 and 120 then
    raise exception 'invalid_input';
  end if;
  select u.course_id into v_course_id from public.units u where u.id = p_unit_id;
  if not found then raise exception 'invalid_input'; end if;
  perform 1 from public.courses c where c.id = v_course_id for update;
  perform 1 from public.units p where p.id = p_unit_id for update;
  if not found then raise exception 'invalid_input'; end if;
  if p_id is null then
    v_base := private.slugify(v_title);
    v_slug := v_base;
    while exists (select 1 from public.topics t
      where t.course_id = v_course_id and t.slug = v_slug) loop
      v_slug := v_base || '-' || v_suffix;
      v_suffix := v_suffix + 1;
    end loop;
    insert into public.topics (unit_id, course_id, title, slug, sort)
    select p_unit_id, v_course_id, v_title, v_slug, coalesce(max(t.sort), 0) + 1
    from public.topics t where t.unit_id = p_unit_id
    returning id into v_id;
  else
    select pg_catalog.to_jsonb(n) into v_before from public.topics n
    where n.id = p_id and n.unit_id = p_unit_id for update;
    if not found then raise exception 'invalid_input'; end if;
    update public.topics set title = v_title where id = p_id returning id into v_id;
  end if;
  select pg_catalog.to_jsonb(n) into v_after from public.topics n where n.id = v_id;
  insert into public.audit_log (actor, action, entity, entity_id, diff)
  values (auth.uid(), 'node.upsert', 'topic', v_id,
    pg_catalog.jsonb_build_object('before', v_before, 'after', v_after));
  return pg_catalog.jsonb_build_object('id', v_id);
end;
$$;
revoke execute on function public.teacher_upsert_topic(uuid, uuid, text)
  from public, anon;
grant execute on function public.teacher_upsert_topic(uuid, uuid, text)
  to authenticated;

create function public.teacher_upsert_subtopic(
  p_id uuid, p_topic_id uuid, p_title text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_title text := pg_catalog.regexp_replace(p_title,
    '^[[:space:]]+|[[:space:]]+$', '', 'g');
  v_id uuid;
  v_before jsonb;
  v_after jsonb;
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  if not public.is_teacher() then raise exception 'forbidden'; end if;
  if v_title is null or pg_catalog.char_length(v_title) not between 1 and 120 then
    raise exception 'invalid_input';
  end if;
  perform 1 from public.topics p where p.id = p_topic_id for update;
  if not found then raise exception 'invalid_input'; end if;
  if p_id is null then
    insert into public.subtopics (topic_id, title, sort)
    select p_topic_id, v_title, coalesce(max(n.sort), 0) + 1
    from public.subtopics n where n.topic_id = p_topic_id
    returning id into v_id;
  else
    select pg_catalog.to_jsonb(n) into v_before from public.subtopics n
    where n.id = p_id and n.topic_id = p_topic_id for update;
    if not found then raise exception 'invalid_input'; end if;
    update public.subtopics set title = v_title where id = p_id returning id into v_id;
  end if;
  select pg_catalog.to_jsonb(n) into v_after from public.subtopics n where n.id = v_id;
  insert into public.audit_log (actor, action, entity, entity_id, diff)
  values (auth.uid(), 'node.upsert', 'subtopic', v_id,
    pg_catalog.jsonb_build_object('before', v_before, 'after', v_after));
  return pg_catalog.jsonb_build_object('id', v_id);
end;
$$;
revoke execute on function public.teacher_upsert_subtopic(uuid, uuid, text)
  from public, anon;
grant execute on function public.teacher_upsert_subtopic(uuid, uuid, text)
  to authenticated;

create function public.teacher_reorder(
  p_kind text, p_parent_id uuid, p_ids uuid[])
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_table text;
  v_parent_table text;
  v_parent_column text;
  v_parent uuid;
  v_current uuid[];
  v_expected uuid[];
  v_before jsonb;
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  if not public.is_teacher() then raise exception 'forbidden'; end if;
  case p_kind
    when 'unit' then
      v_table := 'units'; v_parent_table := 'courses'; v_parent_column := 'course_id';
    when 'topic' then
      v_table := 'topics'; v_parent_table := 'units'; v_parent_column := 'unit_id';
    when 'subtopic' then
      v_table := 'subtopics'; v_parent_table := 'topics'; v_parent_column := 'topic_id';
    else raise exception 'invalid_input';
  end case;
  if p_ids is null or pg_catalog.array_ndims(p_ids) > 1 then
    raise exception 'invalid_input';
  end if;
  -- Identifiers come exclusively from the allow-list above; values are bound.
  execute pg_catalog.format('select id from public.%I where id = $1 for update',
    v_parent_table) into v_parent using p_parent_id;
  if v_parent is null then raise exception 'invalid_input'; end if;
  execute pg_catalog.format(
    'select coalesce(array_agg(id order by id), ''{}''::uuid[]), '
    'coalesce(jsonb_agg(jsonb_build_object(''id'',id,''sort'',sort) '
    'order by sort,id), ''[]''::jsonb) from public.%I where %I = $1',
    v_table, v_parent_column) into v_current, v_before using p_parent_id;
  select coalesce(pg_catalog.array_agg(i order by i), '{}'::uuid[])
  into v_expected from pg_catalog.unnest(p_ids) i;
  -- Array equality checks multiplicity as well as membership (including NULL).
  if v_expected is distinct from v_current then raise exception 'invalid_input'; end if;
  execute pg_catalog.format(
    'update public.%I n set sort = i.position::int '
    'from unnest($1::uuid[]) with ordinality i(id,position) where n.id = i.id',
    v_table) using p_ids;
  insert into public.audit_log (actor, action, entity, entity_id, diff)
  values (auth.uid(), 'node.reorder', p_kind, p_parent_id,
    pg_catalog.jsonb_build_object('before', v_before, 'after', p_ids));
  return pg_catalog.jsonb_build_object('ok', true);
end;
$$;
revoke execute on function public.teacher_reorder(text, uuid, uuid[]) from public, anon;
grant execute on function public.teacher_reorder(text, uuid, uuid[]) to authenticated;

create function public.teacher_delete_node(p_kind text, p_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_table text;
  v_parent_table text;
  v_parent_column text;
  v_parent_id uuid;
  v_before jsonb;
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  if not public.is_teacher() then raise exception 'forbidden'; end if;
  v_table := case p_kind when 'unit' then 'units' when 'topic' then 'topics'
    when 'subtopic' then 'subtopics' else null end;
  if v_table is null then raise exception 'invalid_input'; end if;
  v_parent_table := case p_kind when 'unit' then 'courses'
    when 'topic' then 'units' else 'topics' end;
  v_parent_column := case p_kind when 'unit' then 'course_id'
    when 'topic' then 'unit_id' else 'topic_id' end;
  execute pg_catalog.format('select %I from public.%I where id = $1',
    v_parent_column, v_table) into v_parent_id using p_id;
  -- Serialize deletion with appends and reorder before locking the child.
  -- Legacy topics may have no unit; the node lock still protects deletion.
  execute pg_catalog.format('select id from public.%I where id = $1 for update',
    v_parent_table) using v_parent_id;
  execute pg_catalog.format('select to_jsonb(n) from public.%I n where id = $1 for update',
    v_table) into v_before using p_id;
  if v_before is null then raise exception 'invalid_input'; end if;
  if private.builder_node_in_use(p_kind, p_id) then raise exception 'in_use'; end if;
  begin
    execute pg_catalog.format('delete from public.%I where id = $1', v_table) using p_id;
  exception when foreign_key_violation then
    raise exception 'in_use';
  end;
  insert into public.audit_log (actor, action, entity, entity_id, diff)
  values (auth.uid(), 'node.delete', p_kind, p_id,
    pg_catalog.jsonb_build_object('before', v_before, 'after', null));
  return pg_catalog.jsonb_build_object('ok', true);
end;
$$;
revoke execute on function public.teacher_delete_node(text, uuid) from public, anon;
grant execute on function public.teacher_delete_node(text, uuid) to authenticated;

create function public.teacher_set_topic_flags(
  p_id uuid, p_is_published boolean, p_is_free_preview boolean)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_before jsonb;
  v_after jsonb;
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  if not public.is_teacher() then raise exception 'forbidden'; end if;
  select pg_catalog.jsonb_build_object('is_published', t.is_published,
    'is_free_preview', t.is_free_preview) into v_before
  from public.topics t where t.id = p_id for update;
  if not found then raise exception 'invalid_input'; end if;
  update public.topics t
  set is_published = coalesce(p_is_published, t.is_published),
      is_free_preview = coalesce(p_is_free_preview, t.is_free_preview)
  where t.id = p_id
  returning pg_catalog.jsonb_build_object('is_published', t.is_published,
    'is_free_preview', t.is_free_preview) into v_after;
  insert into public.audit_log (actor, action, entity, entity_id, diff)
  values (auth.uid(), 'topic.flags', 'topic', p_id,
    pg_catalog.jsonb_build_object('before', v_before, 'after', v_after));
  return v_after;
end;
$$;
revoke execute on function public.teacher_set_topic_flags(uuid, boolean, boolean)
  from public, anon;
grant execute on function public.teacher_set_topic_flags(uuid, boolean, boolean)
  to authenticated;
