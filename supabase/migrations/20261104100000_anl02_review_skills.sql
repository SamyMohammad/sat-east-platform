-- ANL-02: live review skill breakdown. Security envelope from templates/rpc.sql.
create or replace function public.get_attempt_review(p_attempt_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_uid uuid := auth.uid();
  v_att public.attempts%rowtype;
  v_keys_visible boolean;
  v_report jsonb;
  v_summary jsonb;
  v_skills jsonb;
  v_questions jsonb;
begin
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;
  if p_attempt_id is null then
    raise exception 'invalid_input';
  end if;

  select a.* into v_att from public.attempts a where a.id = p_attempt_id;
  if not found or v_att.kind not in ('quiz', 'homework') then
    raise exception 'invalid_input';
  end if;
  if v_att.user_id <> v_uid then
    raise exception 'forbidden';
  end if;
  if v_att.status <> 'submitted' then
    raise exception 'attempt_not_submitted';
  end if;

  select v_att.kind = 'homework' or exists (select 1 from public.topic_progress tp
    where tp.user_id = v_uid and tp.topic_id = v_att.topic_id and tp.quiz_passed_at is not null)
  into v_keys_visible;
  select coalesce(jsonb_agg(jsonb_build_object(
    'code', sk.code, 'name', sk.name, 'correct', sk.correct, 'total', sk.total)
    order by sk.name, sk.code), '[]'::jsonb)
  into v_skills
  from (
    select s.code, s.name, count(*) filter (where aa.is_correct)::int as correct,
           count(*)::int as total
    from public.attempt_questions aq
    join public.question_skills qs on qs.question_id = aq.question_id
    join public.skills s on s.id = qs.skill_id
    left join public.attempt_answers aa
      on aa.attempt_id = aq.attempt_id and aa.question_id = aq.question_id
    where aq.attempt_id = p_attempt_id
    group by s.id, s.code, s.name
  ) sk;

  v_report := v_att.meta -> 'report';
  v_summary := pg_catalog.jsonb_build_object(
    'score_raw', v_report -> 'score_raw', 'score_total', v_report -> 'score_total',
    'score_pct', v_report -> 'score_pct', 'pass_mark', case when v_att.kind = 'quiz' then v_report -> 'pass_mark' else 'null'::jsonb end,
    'passed', case when v_att.kind = 'quiz' then v_report -> 'passed' else 'null'::jsonb end, 'keys_visible', v_keys_visible, 'skills', v_skills);

  select coalesce(pg_catalog.jsonb_agg(
    pg_catalog.jsonb_build_object(
      'id', q.id, 'type', q.type, 'stem_md', q.stem_md,
      'choices', coalesce((
        select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('label', c.label, 'body_md', c.body_md) order by c.label)
        from public.question_choices c where c.question_id = q.id), '[]'::jsonb),
      'my_answer', aa.answer ->> 'value', 'is_correct', coalesce(aa.is_correct, false),
      'time_ms', coalesce(aa.time_ms, 0),
      'skills', coalesce((
        select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('code', s.code, 'name', s.name) order by s.code, s.id)
        from public.question_skills qs join public.skills s on s.id = qs.skill_id
        where qs.question_id = q.id), '[]'::jsonb))
    || case when v_keys_visible then pg_catalog.jsonb_build_object(
      'key', case when q.type = 'mcq'
        then pg_catalog.jsonb_build_object('choice', k.correct_answer ->> 'choice')
        else pg_catalog.jsonb_build_object('text', k.correct_answer -> 'accepted' ->> 0) end,
      'explanation_md', k.explanation_md)
      else '{}'::jsonb end
    order by aq.position), '[]'::jsonb)
  into v_questions
  from public.attempt_questions aq
  join public.questions q on q.id = aq.question_id
  left join public.attempt_answers aa on aa.attempt_id = aq.attempt_id and aa.question_id = aq.question_id
  left join private.question_keys k on v_keys_visible and k.question_id = q.id
  where aq.attempt_id = p_attempt_id;

  return pg_catalog.jsonb_build_object('summary', v_summary, 'questions', v_questions);
end;
$fn$;
revoke execute on function public.get_attempt_review(uuid) from public, anon;
grant execute on function public.get_attempt_review(uuid) to authenticated;
