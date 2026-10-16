-- P1 demo seed check. Run AFTER the numbered seed files (applied twice is fine).
-- Raises an exception with a clear message on the first violation; ends with
-- the notice 'demo seed OK'. Leaves no residue (check 7 deletes its test user).
-- Local/CI only: the numbered-file glob [0-9]*.sql deliberately excludes this file.
set client_min_messages = notice;

do $check$
declare
  c      constant uuid := '00000000-0000-4000-8de0-000000000001';
  n      int;
  r      record;
  s      text;
  v_user uuid := gen_random_uuid();
begin
  -- 1. Structure
  select count(*) into n from public.courses where id = c and is_published;
  if n <> 1 then raise exception 'check 1: expected 1 published demo course, got %', n; end if;
  select count(*) into n from public.topics where course_id = c and is_published;
  if n <> 3 then raise exception 'check 1: expected 3 published demo topics, got %', n; end if;
  select count(*) into n from public.subtopics st join public.topics t on t.id = st.topic_id where t.course_id = c;
  if n <> 3 then raise exception 'check 1: expected 3 demo subtopics, got %', n; end if;
  select count(*) into n from public.skills where code like 'DEMO.%';
  if n <> 6 then raise exception 'check 1: expected 6 demo skills, got %', n; end if;

  -- 2. Per topic: 12 practice + 12 quiz, all published, source demo
  for r in select id, slug from public.topics where course_id = c loop
    select count(*) into n from public.questions
      where topic_id = r.id and pool = 'practice' and status = 'published' and source = 'demo';
    if n <> 12 then raise exception 'check 2: topic % has % published practice questions, expected 12', r.slug, n; end if;
    select count(*) into n from public.questions
      where topic_id = r.id and pool = 'quiz' and status = 'published' and source = 'demo';
    if n <> 12 then raise exception 'check 2: topic % has % published quiz questions, expected 12', r.slug, n; end if;
  end loop;
  select count(*) into n from public.questions where source = 'demo';
  if n <> 72 then raise exception 'check 2: expected 72 demo questions, got %', n; end if;

  -- 3. Exactly one key row and one demo course link per question
  for r in
    select q.id,
           (select count(*) from private.question_keys k where k.question_id = q.id) as keys,
           (select count(*) from public.question_courses qc where qc.question_id = q.id and qc.course_id = c) as links
    from public.questions q where q.source = 'demo'
  loop
    if r.keys <> 1 then raise exception 'check 3: question % has % key rows', r.id, r.keys; end if;
    if r.links <> 1 then raise exception 'check 3: question % has % demo course links', r.id, r.links; end if;
  end loop;

  -- 4. MCQ: exactly A-D choices, key {"choice": X} with X among the labels
  for r in
    select q.id, k.correct_answer,
           (select array_agg(label::text order by label) from public.question_choices ch where ch.question_id = q.id) as labels
    from public.questions q join private.question_keys k on k.question_id = q.id
    where q.source = 'demo' and q.type = 'mcq'
  loop
    if r.labels is distinct from array['A','B','C','D'] then
      raise exception 'check 4: MCQ % has choice labels %, expected A-D', r.id, r.labels;
    end if;
    if jsonb_typeof(r.correct_answer) <> 'object'
       or (r.correct_answer ->> 'choice') is null
       or not ((r.correct_answer ->> 'choice') = any (r.labels)) then
      raise exception 'check 4: MCQ % has bad key %', r.id, r.correct_answer;
    end if;
  end loop;
  -- SPR must have no choices
  select count(*) into n from public.question_choices ch join public.questions q on q.id = ch.question_id
    where q.source = 'demo' and q.type = 'spr';
  if n <> 0 then raise exception 'check 4: SPR questions have % choice rows', n; end if;

  -- 5. SPR: accepted non-empty array and every accepted string grades true
  for r in
    select q.id, k.correct_answer
    from public.questions q join private.question_keys k on k.question_id = q.id
    where q.source = 'demo' and q.type = 'spr'
  loop
    if jsonb_typeof(r.correct_answer -> 'accepted') is distinct from 'array'
       or jsonb_array_length(r.correct_answer -> 'accepted') = 0 then
      raise exception 'check 5: SPR % accepted is not a non-empty array: %', r.id, r.correct_answer;
    end if;
    for s in select jsonb_array_elements_text(r.correct_answer -> 'accepted') loop
      if private.spr_parse(s, false) is null then
        raise exception 'check 5: SPR % accepted string "%" is not a parseable answer', r.id, s;
      end if;
      if not private.grade_spr(s, r.correct_answer) then
        raise exception 'check 5: SPR % accepted string "%" does not grade true against key %', r.id, s, r.correct_answer;
      end if;
    end loop;
  end loop;

  -- 6. At least 6 explanations contain Arabic
  select count(*) into n from private.question_keys k join public.questions q on q.id = k.question_id
    where q.source = 'demo' and k.explanation_md ~ '[؀-ۿ]';
  if n < 6 then raise exception 'check 6: only % explanations contain Arabic, expected at least 6', n; end if;

  -- 8. Every existing student has a demo enrolment (before check 7 adds its own user)
  select count(*) into n from public.profiles p
    where p.role = 'student'
      and not exists (select 1 from public.enrollments e where e.user_id = p.id and e.course_id = c);
  if n <> 0 then raise exception 'check 8: % student profiles lack the demo enrolment', n; end if;

  -- 9. Content quality
  select count(*) into n from public.questions
    where source = 'demo' and pool = 'practice' and btrim(coalesce(hint_md, '')) = '';
  if n <> 0 then raise exception 'check 9: % practice questions lack a hint', n; end if;
  select count(*) into n from public.questions q left join private.question_keys k on k.question_id = q.id
    where q.source = 'demo' and btrim(coalesce(k.explanation_md, '')) = '';
  if n <> 0 then raise exception 'check 9: % questions lack an explanation', n; end if;
  for r in
    select t.slug, q.pool,
           count(*) filter (where q.difficulty = 'E') as e,
           count(*) filter (where q.difficulty = 'M') as m,
           count(*) filter (where q.difficulty = 'H') as h
    from public.questions q join public.topics t on t.id = q.topic_id
    where q.source = 'demo' group by t.slug, q.pool
  loop
    if (r.e, r.m, r.h) <> (4, 5, 3) then
      raise exception 'check 9: topic % pool % difficulty mix is E%/M%/H%, expected 4/5/3', r.slug, r.pool, r.e, r.m, r.h;
    end if;
  end loop;
  for r in
    select t.slug, count(*) filter (where k.explanation_md ~ '[؀-ۿ]') as ar
    from public.topics t
    left join public.questions q on q.topic_id = t.id and q.source = 'demo'
    left join private.question_keys k on k.question_id = q.id
    where t.course_id = c group by t.slug
  loop
    if r.ar < 2 then raise exception 'check 9: topic % has % Arabic explanations, expected at least 2', r.slug, r.ar; end if;
  end loop;
  select count(*) into n from public.questions q
    where q.source = 'demo' and not exists (select 1 from public.question_skills qs where qs.question_id = q.id);
  if n <> 0 then raise exception 'check 9: % questions have no skill', n; end if;

  -- 10. Helper functions are not executable by anon/authenticated
  foreach s in array array[
    'private.demo_upsert_question(uuid,uuid,uuid,public.question_pool,public.question_type,public.difficulty,text,text,jsonb,jsonb,text,jsonb,text[])',
    'private.demo_enroll_new_student()'
  ] loop
    if has_function_privilege('anon', s, 'execute') then raise exception 'check 10: anon can execute %', s; end if;
    if has_function_privilege('authenticated', s, 'execute') then raise exception 'check 10: authenticated can execute %', s; end if;
  end loop;

  -- 8b. If the CI fixture student exists, the seed must have enrolled it
  if exists (select 1 from auth.users where id = '00000000-0000-4000-8de0-0000000000f1') then
    select count(*) into n from public.enrollments
      where user_id = '00000000-0000-4000-8de0-0000000000f1' and course_id = c and status = 'active';
    if n <> 1 then raise exception 'check 8: fixture student not enrolled by the seed (% rows)', n; end if;
  end if;

  -- 7. Trigger: a new auth user becomes a student profile and is auto-enrolled
  insert into auth.users (id, email, raw_user_meta_data, raw_app_meta_data, created_at, updated_at)
  values (v_user, v_user || '@demo-check.test', '{}'::jsonb, '{}'::jsonb, now(), now());
  select count(*) into n from public.enrollments
    where user_id = v_user and course_id = c and status = 'active';
  if n <> 1 then
    raise exception 'check 7: new student got % demo enrolments (trigger demo_enroll_new_student not working)', n;
  end if;
  delete from auth.users where id = v_user;
  select count(*) into n from public.profiles where id = v_user;
  if n <> 0 then raise exception 'check 7: test profile residue after cleanup'; end if;
  select count(*) into n from public.enrollments where user_id = v_user;
  if n <> 0 then raise exception 'check 7: test enrolment residue after cleanup'; end if;

  raise notice 'demo seed OK';
end;
$check$;
