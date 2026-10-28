-- ANL-02: per-skill quiz report. Security envelope from templates/rpc.sql.
-- Latest finish_quiz body: 20261017200100_prc03_quiz.sql; only adds report.skills.
create or replace function private.finish_quiz(p_attempt_id uuid, p_submitted_at timestamptz)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_att public.attempts%rowtype;
  v_raw int;
  v_total int;
  v_pct numeric;
  v_pass_mark int := private.setting_int('pass_mark');
  v_passed boolean;
  v_next jsonb;
  v_retake_at timestamptz;
  v_report jsonb;
  v_skills jsonb;
begin
  select a.* into v_att from public.attempts a where a.id = p_attempt_id and a.kind = 'quiz' for update;
  if not found then
    raise exception 'invalid_input';
  end if;
  if v_att.status = 'submitted' then
    return v_att.meta -> 'report';
  end if;
  if v_att.status <> 'in_progress' then
    raise exception 'invalid_input';
  end if;

  insert into public.attempt_answers (attempt_id, question_id, answer, is_correct, answered_at)
  select aq.attempt_id, aq.question_id, jsonb_build_object('value', null), false, p_submitted_at
  from public.attempt_questions aq where aq.attempt_id = p_attempt_id
  on conflict (attempt_id, question_id) do nothing;
  update public.attempt_answers aa
  set is_correct = private.grade_answer(aa.question_id, aa.answer ->> 'value')
  where aa.attempt_id = p_attempt_id;
  select count(*)::int, count(*) filter (where aa.is_correct)::int into v_total, v_raw
  from public.attempt_questions aq
  join public.attempt_answers aa on aa.attempt_id = aq.attempt_id and aa.question_id = aq.question_id
  where aq.attempt_id = p_attempt_id;
  if v_total = 0 then
    raise exception 'invalid_input';
  end if;
  v_pct := round(100::numeric * v_raw / v_total, 2);
  v_passed := v_pct >= v_pass_mark;

  insert into public.topic_progress (user_id, topic_id, quiz_best_score)
  values (v_att.user_id, v_att.topic_id, v_pct)
  on conflict (user_id, topic_id) do update
    set quiz_best_score = greatest(public.topic_progress.quiz_best_score, excluded.quiz_best_score);
  if v_passed then
    update public.topic_progress tp set quiz_passed_at = coalesce(tp.quiz_passed_at, p_submitted_at)
    where tp.user_id = v_att.user_id and tp.topic_id = v_att.topic_id;
  else
    update public.topic_progress tp set quiz_last_failed_at = p_submitted_at
    where tp.user_id = v_att.user_id and tp.topic_id = v_att.topic_id;
    v_retake_at := p_submitted_at + make_interval(hours => private.setting_int('cooldown_h'));
  end if;

  select jsonb_build_object('id', ts.topic_id, 'title', ts.title) into v_next
  from private.topic_states(v_att.user_id, v_att.course_id) ts
  where ts.pos = (select cur.pos + 1 from private.topic_states(v_att.user_id, v_att.course_id) cur
                  where cur.topic_id = v_att.topic_id)
    and ts.status = 'open';
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
    join public.attempt_answers aa
      on aa.attempt_id = aq.attempt_id and aa.question_id = aq.question_id
    where aq.attempt_id = p_attempt_id
    group by s.id, s.code, s.name
  ) sk;

  v_report := jsonb_build_object(
    'score_raw', v_raw, 'score_total', v_total, 'score_pct', v_pct, 'pass_mark', v_pass_mark,
    'passed', v_passed, 'next_topic', v_next, 'retake_at', v_retake_at, 'skills', v_skills);
  update public.attempts a
  set status = 'submitted', submitted_at = p_submitted_at,
      score_raw = v_raw, score_total = v_total, score_pct = v_pct,
      meta = a.meta || jsonb_build_object('report', v_report)
  where a.id = p_attempt_id;
  return v_report;
end;
$$;
revoke execute on function private.finish_quiz(uuid, timestamptz) from public, anon, authenticated;
