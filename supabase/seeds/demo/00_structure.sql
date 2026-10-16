-- P1 demo seed 00: course structure, helper function, enrolment trigger.
--
-- STAGING AND LOCAL ONLY. NEVER RUN AGAINST PROD. This is demo content, not a
-- migration: it lives in supabase/seeds/demo/ and is delivered by
-- scripts/db-seed-demo.ps1 (local) and the "Seed staging demo data" CI step.
-- It is deliberately NOT in config.toml sql_paths (existing pgTAP tests insert
-- their own SAT course).
--
-- Idempotent: every statement is an upsert / create or replace; running it
-- twice leaves all row counts unchanged.
--
-- Course code note: courses.code is unique, so the demo course uses code 'SAT'.
-- When the real SAT course arrives on staging, rename or remove this demo
-- course first (see STATUS Open).
--
-- Fixed UUID prefix 00000000-0000-4000-8de0-:
--   course ...0001, unit ...0002, topics ...0011-13, subtopics ...0021-23,
--   skills ...0031-36, questions ...0TPNNN (see later files).

-- Course
insert into public.courses (id, code, title, slug, description, is_published)
values (
  '00000000-0000-4000-8de0-000000000001', 'SAT', 'SAT Math (Demo)', 'sat-demo',
  'Demo content for the staging vertical slice.', true
)
on conflict (id) do update set
  title        = excluded.title,
  slug         = excluded.slug,
  is_published = excluded.is_published,
  description  = excluded.description;

-- Unit
insert into public.units (id, course_id, title, sort)
values (
  '00000000-0000-4000-8de0-000000000002',
  '00000000-0000-4000-8de0-000000000001', 'Algebra (Demo)', 1
)
on conflict (id) do update set
  course_id = excluded.course_id,
  title     = excluded.title,
  sort      = excluded.sort;

-- Topics
insert into public.topics (id, course_id, unit_id, title, slug, sort, is_free_preview, is_published)
values
  ('00000000-0000-4000-8de0-000000000011', '00000000-0000-4000-8de0-000000000001',
   '00000000-0000-4000-8de0-000000000002', 'Linear Equations', 'linear-equations', 1, true, true),
  ('00000000-0000-4000-8de0-000000000012', '00000000-0000-4000-8de0-000000000001',
   '00000000-0000-4000-8de0-000000000002', 'Linear Inequalities', 'linear-inequalities', 2, false, true),
  ('00000000-0000-4000-8de0-000000000013', '00000000-0000-4000-8de0-000000000001',
   '00000000-0000-4000-8de0-000000000002', 'Systems of Equations', 'systems-of-equations', 3, false, true)
on conflict (id) do update set
  course_id       = excluded.course_id,
  unit_id         = excluded.unit_id,
  title           = excluded.title,
  slug            = excluded.slug,
  sort            = excluded.sort,
  is_free_preview = excluded.is_free_preview,
  is_published    = excluded.is_published;

-- Subtopics (one per topic, same title)
insert into public.subtopics (id, topic_id, title, sort)
values
  ('00000000-0000-4000-8de0-000000000021', '00000000-0000-4000-8de0-000000000011', 'Linear Equations', 1),
  ('00000000-0000-4000-8de0-000000000022', '00000000-0000-4000-8de0-000000000012', 'Linear Inequalities', 1),
  ('00000000-0000-4000-8de0-000000000023', '00000000-0000-4000-8de0-000000000013', 'Systems of Equations', 1)
on conflict (id) do update set
  topic_id = excluded.topic_id,
  title    = excluded.title,
  sort     = excluded.sort;

-- Skills
insert into public.skills (id, code, name, domain, course_scope)
values
  ('00000000-0000-4000-8de0-000000000031', 'DEMO.LE.SOLVE',  'Solve linear equations',      'Algebra', '{SAT}'),
  ('00000000-0000-4000-8de0-000000000032', 'DEMO.LE.MODEL',  'Model with linear equations', 'Algebra', '{SAT}'),
  ('00000000-0000-4000-8de0-000000000033', 'DEMO.LI.SOLVE',  'Solve linear inequalities',   'Algebra', '{SAT}'),
  ('00000000-0000-4000-8de0-000000000034', 'DEMO.LI.GRAPH',  'Graph linear inequalities',   'Algebra', '{SAT}'),
  ('00000000-0000-4000-8de0-000000000035', 'DEMO.SYS.SOLVE', 'Solve systems of equations',  'Algebra', '{SAT}'),
  ('00000000-0000-4000-8de0-000000000036', 'DEMO.SYS.MODEL', 'Model with systems',          'Algebra', '{SAT}')
on conflict (id) do update set
  code         = excluded.code,
  name         = excluded.name,
  domain       = excluded.domain,
  course_scope = excluded.course_scope;

-- Subtopic <-> skill links (two per subtopic)
insert into public.subtopic_skills (subtopic_id, skill_id)
values
  ('00000000-0000-4000-8de0-000000000021', '00000000-0000-4000-8de0-000000000031'),
  ('00000000-0000-4000-8de0-000000000021', '00000000-0000-4000-8de0-000000000032'),
  ('00000000-0000-4000-8de0-000000000022', '00000000-0000-4000-8de0-000000000033'),
  ('00000000-0000-4000-8de0-000000000022', '00000000-0000-4000-8de0-000000000034'),
  ('00000000-0000-4000-8de0-000000000023', '00000000-0000-4000-8de0-000000000035'),
  ('00000000-0000-4000-8de0-000000000023', '00000000-0000-4000-8de0-000000000036')
on conflict (subtopic_id, skill_id) do nothing;

-- Helper: upsert one demo question with its choices, course/skill links and key.
-- p_choices: {"A":"..","B":"..","C":"..","D":".."} for MCQ, null for SPR.
-- p_key: MCQ {"choice":"B"}; SPR {"accepted":["2/3"],"tolerance":0}.
create or replace function private.demo_upsert_question(
  p_id uuid,
  p_topic uuid,
  p_subtopic uuid,
  p_pool public.question_pool,
  p_type public.question_type,
  p_difficulty public.difficulty,
  p_stem text,
  p_hint text,
  p_choices jsonb,
  p_key jsonb,
  p_explanation text,
  p_misconceptions jsonb,
  p_skill_codes text[]
) returns void
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_course constant uuid := '00000000-0000-4000-8de0-000000000001';
  v_label  text;
begin
  if p_type = 'mcq' then
    if p_choices is null
       or jsonb_typeof(p_choices) <> 'object'
       or (select array_agg(k order by k) from jsonb_object_keys(p_choices) as k)
          is distinct from array['A', 'B', 'C', 'D'] then
      raise exception 'demo question %: MCQ choices must have exactly keys A-D', p_id;
    end if;
    if (p_key ->> 'choice') is null or (p_key ->> 'choice') not in ('A', 'B', 'C', 'D') then
      raise exception 'demo question %: MCQ key choice must be one of A-D', p_id;
    end if;
  elsif p_choices is not null then
    raise exception 'demo question %: SPR question must not have choices', p_id;
  end if;

  insert into public.questions (
    id, external_ref, topic_id, subtopic_id, type, difficulty,
    stem_md, hint_md, pool, status, source
  ) values (
    p_id, 'demo-' || p_id, p_topic, p_subtopic, p_type, p_difficulty,
    p_stem, p_hint, p_pool, 'published', 'demo'
  )
  on conflict (id) do update set
    external_ref = excluded.external_ref,
    topic_id     = excluded.topic_id,
    subtopic_id  = excluded.subtopic_id,
    type         = excluded.type,
    difficulty   = excluded.difficulty,
    stem_md      = excluded.stem_md,
    hint_md      = excluded.hint_md,
    pool         = excluded.pool,
    status       = excluded.status,
    source       = excluded.source;

  delete from public.question_choices where question_id = p_id;
  if p_choices is not null then
    for v_label in select k from jsonb_object_keys(p_choices) as k order by k loop
      insert into public.question_choices (question_id, label, body_md)
      values (p_id, v_label, p_choices ->> v_label);
    end loop;
  end if;

  insert into public.question_courses (question_id, course_id)
  values (p_id, v_course)
  on conflict (question_id, course_id) do nothing;

  delete from public.question_skills where question_id = p_id;
  insert into public.question_skills (question_id, skill_id)
  select p_id, s.id from public.skills s where s.code = any (p_skill_codes);

  insert into private.question_keys (
    question_id, correct_answer, explanation_md, misconceptions, solved_by
  ) values (
    p_id, p_key, p_explanation, p_misconceptions, 'teacher'
  )
  on conflict (question_id) do update set
    correct_answer = excluded.correct_answer,
    explanation_md = excluded.explanation_md,
    misconceptions = excluded.misconceptions,
    solved_by      = excluded.solved_by;
end;
$fn$;

revoke all on function private.demo_upsert_question(
  uuid, uuid, uuid, public.question_pool, public.question_type, public.difficulty,
  text, text, jsonb, jsonb, text, jsonb, text[]
) from public, anon, authenticated;

-- Enrol existing students in the demo course
insert into public.enrollments (user_id, course_id, status, expires_at)
select id, '00000000-0000-4000-8de0-000000000001', 'active', now() + interval '1 year'
from public.profiles
where role = 'student'
on conflict (user_id, course_id) do nothing;

-- Auto-enrol new students (staging/local only; installed by this seed)
create or replace function private.demo_enroll_new_student()
returns trigger
language plpgsql
security definer
set search_path = ''
as $fn$
begin
  if new.role = 'student'
     and exists (select 1 from public.courses where id = '00000000-0000-4000-8de0-000000000001') then
    insert into public.enrollments (user_id, course_id, status, expires_at)
    values (new.id, '00000000-0000-4000-8de0-000000000001', 'active', now() + interval '1 year')
    on conflict (user_id, course_id) do nothing;
  end if;
  return new;
end;
$fn$;

revoke all on function private.demo_enroll_new_student() from public, anon, authenticated;

drop trigger if exists demo_enroll_new_student on public.profiles;
create trigger demo_enroll_new_student
  after insert on public.profiles
  for each row execute function private.demo_enroll_new_student();
