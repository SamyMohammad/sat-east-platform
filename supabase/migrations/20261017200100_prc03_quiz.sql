-- PRC-03 / LRN-03: quiz lifecycle. From templates/rpc.sql.
-- Private helpers trust the authenticated, ownership-checked public entry points.
create or replace function private.quiz_state(p_uid uuid, p_topic_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_progress public.topic_progress%rowtype;
  v_attempt uuid;
  v_min int := private.setting_int('practice_min');
  v_available_at timestamptz;
  v_state jsonb;
begin
  perform private.practice_access(p_uid, p_topic_id);
  select tp.* into v_progress from public.topic_progress tp
  where tp.user_id = p_uid and tp.topic_id = p_topic_id;
  v_state := jsonb_build_object(
    'practice_count', coalesce(v_progress.practice_count, 0), 'practice_min', v_min,
    'best_score_pct', v_progress.quiz_best_score, 'passed', v_progress.quiz_passed_at is not null);

  select a.id into v_attempt from public.attempts a
  where a.user_id = p_uid and a.topic_id = p_topic_id and a.kind = 'quiz'
    and a.status = 'in_progress'
    and a.started_at + make_interval(secs => a.time_limit_s + private.setting_int('save_grace_s')) >= now()
  order by a.started_at, a.id limit 1;
  if found then
    return v_state || jsonb_build_object('state', 'in_progress', 'attempt_id', v_attempt);
  end if;
  if coalesce(v_progress.practice_count, 0) < v_min then
    return v_state || jsonb_build_object('state', 'practice_needed');
  end if;
  v_available_at := v_progress.quiz_last_failed_at + make_interval(hours => private.setting_int('cooldown_h'));
  if v_available_at > now() then
    return v_state || jsonb_build_object('state', 'cooldown', 'available_at', v_available_at);
  end if;
  return v_state || jsonb_build_object('state', 'available');
end;
$$;
revoke execute on function private.quiz_state(uuid, uuid) from public, anon, authenticated;

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
  v_report := jsonb_build_object(
    'score_raw', v_raw, 'score_total', v_total, 'score_pct', v_pct, 'pass_mark', v_pass_mark,
    'passed', v_passed, 'next_topic', v_next, 'retake_at', v_retake_at);
  update public.attempts a
  set status = 'submitted', submitted_at = p_submitted_at,
      score_raw = v_raw, score_total = v_total, score_pct = v_pct,
      meta = a.meta || jsonb_build_object('report', v_report)
  where a.id = p_attempt_id;
  return v_report;
end;
$$;
revoke execute on function private.finish_quiz(uuid, timestamptz) from public, anon, authenticated;

create or replace function private.expire_quiz(p_uid uuid, p_topic_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_att public.attempts%rowtype;
begin
  -- One lock order for start/save/submit/read prevents duplicate starts and save/submit races.
  perform pg_advisory_xact_lock(hashtextextended('quiz:' || p_uid::text || p_topic_id::text, 0));
  for v_att in select a.* from public.attempts a
    where a.user_id = p_uid and a.topic_id = p_topic_id and a.kind = 'quiz'
      and a.status = 'in_progress'
      and a.started_at + make_interval(secs => a.time_limit_s + private.setting_int('save_grace_s')) < now()
    order by a.started_at, a.id for update
  loop
    perform private.finish_quiz(v_att.id, v_att.started_at + make_interval(secs => v_att.time_limit_s));
  end loop;
end;
$$;
revoke execute on function private.expire_quiz(uuid, uuid) from public, anon, authenticated;

create or replace function public.get_topic(p_topic_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_quiz jsonb;
  v_topic record;
  v_label text;
begin
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;
  if p_topic_id is null then
    raise exception 'invalid_input';
  end if;
  perform private.expire_quiz(v_uid, p_topic_id);
  v_quiz := private.quiz_state(v_uid, p_topic_id);
  select ts.* into v_topic from public.topics t
  cross join lateral private.topic_states(v_uid, t.course_id) ts
  where t.id = p_topic_id and ts.topic_id = t.id;
  v_label := v_topic.topic_no::text;
  if v_topic.unit_id is not null then
    v_label := v_topic.unit_no || '.' || v_topic.topic_no;
  end if;
  return jsonb_build_object('id', p_topic_id, 'title', v_topic.title, 'slug', v_topic.slug,
    'sort_label', v_label, 'status', v_topic.status,
    'practice', jsonb_build_object('count', v_quiz -> 'practice_count', 'min', v_quiz -> 'practice_min'),
    'quiz', v_quiz);
end;
$$;
revoke execute on function public.get_topic(uuid) from public, anon;
grant execute on function public.get_topic(uuid) to authenticated;

create or replace function public.start_quiz(p_topic_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_state jsonb;
  v_att public.attempts%rowtype;
  v_course uuid;
  v_n int;
  v_questions jsonb;
  v_answers jsonb;
  v_seq int;
  v_topic record;
  v_label text;
begin
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;
  if p_topic_id is null then
    raise exception 'invalid_input';
  end if;
  perform private.expire_quiz(v_uid, p_topic_id);
  v_state := private.quiz_state(v_uid, p_topic_id);
  if v_state ->> 'state' = 'practice_needed' then
    raise exception 'practice_needed';
  end if;
  if v_state ->> 'state' = 'cooldown' then
    raise exception 'cooldown_active';
  end if;

  select t.course_id into v_course from public.topics t where t.id = p_topic_id;
  if v_state ->> 'state' = 'in_progress' then
    select a.* into v_att from public.attempts a where a.id = (v_state ->> 'attempt_id')::uuid;
  else
    insert into public.attempts (user_id, kind, course_id, topic_id, started_at)
    values (v_uid, 'quiz', v_course, p_topic_id, now()) returning * into v_att;
    insert into public.attempt_questions (attempt_id, question_id, position)
    select v_att.id, d.id, row_number() over (order by d.unseen desc, d.r)
    from (
      select q.id, (x.question_id is null) as unseen, random() as r
      from public.questions q
      left join public.question_exposure x on x.user_id = v_uid and x.question_id = q.id
      where q.topic_id = p_topic_id and q.pool = 'quiz' and q.status = 'published'
      order by unseen desc, r limit private.setting_int('quiz_size')
    ) d;
    get diagnostics v_n = row_count;
    if v_n = 0 then
      raise exception 'pool_exhausted';
    end if;
    update public.attempts a set time_limit_s = v_n * private.setting_int('quiz_time_per_q_s')
    where a.id = v_att.id returning a.* into v_att;
    insert into public.question_exposure (user_id, question_id)
    select v_uid, aq.question_id from public.attempt_questions aq where aq.attempt_id = v_att.id
    on conflict (user_id, question_id) do nothing;
  end if;

  select jsonb_agg(jsonb_build_object('id', q.id, 'type', q.type, 'difficulty', q.difficulty,
    'stem_md', q.stem_md, 'choices', coalesce((select jsonb_agg(
      jsonb_build_object('label', c.label, 'body_md', c.body_md) order by c.label)
      from public.question_choices c where c.question_id = q.id), '[]'::jsonb)) order by aq.position)
  into v_questions from public.attempt_questions aq join public.questions q on q.id = aq.question_id
  where aq.attempt_id = v_att.id;
  select coalesce(jsonb_agg(jsonb_build_object('question_id', aa.question_id,
    'answer', aa.answer -> 'value', 'marked', aa.marked_for_review) order by aq.position), '[]'::jsonb),
    coalesce(max(aa.client_seq), 0)
  into v_answers, v_seq from public.attempt_answers aa
  join public.attempt_questions aq on aq.attempt_id = aa.attempt_id and aq.question_id = aa.question_id
  where aa.attempt_id = v_att.id;
  select ts.* into v_topic from private.topic_states(v_uid, v_course) ts where ts.topic_id = p_topic_id;
  v_label := v_topic.topic_no::text;
  if v_topic.unit_id is not null then
    v_label := v_topic.unit_no || '.' || v_topic.topic_no;
  end if;
  return jsonb_build_object('attempt_id', v_att.id, 'title', v_label || ' ' || v_topic.title,
    'time_limit_s', v_att.time_limit_s, 'deadline', v_att.started_at + make_interval(secs => v_att.time_limit_s),
    'server_now', now(), 'warn_s', private.setting_int('quiz_warn_s'),
    'questions', v_questions, 'answers', v_answers, 'client_seq', v_seq);
end;
$$;
revoke execute on function public.start_quiz(uuid) from public, anon;
grant execute on function public.start_quiz(uuid) to authenticated;

create or replace function public.save_answer(
  p_attempt_id uuid, p_question_id uuid, p_answer text, p_time_ms int,
  p_marked boolean, p_eliminated text[], p_client_seq int
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_att public.attempts%rowtype;
  v_written int;
begin
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;
  select a.* into v_att from public.attempts a
  where a.id = p_attempt_id and a.user_id = v_uid and a.kind = 'quiz';
  if not found then
    raise exception 'invalid_input';
  end if;
  perform private.expire_quiz(v_uid, v_att.topic_id);
  perform private.practice_access(v_uid, v_att.topic_id);
  select a.* into v_att from public.attempts a where a.id = p_attempt_id for update;
  if p_question_id is null or p_client_seq is null or p_marked is null or length(p_answer) > 32
     or not exists (select 1 from public.attempt_questions aq
                    where aq.attempt_id = p_attempt_id and aq.question_id = p_question_id) then
    raise exception 'invalid_input';
  end if;
  if v_att.started_at + make_interval(secs => v_att.time_limit_s + private.setting_int('save_grace_s')) < now() then
    raise exception 'deadline_passed';
  end if;
  if v_att.status <> 'in_progress' then
    raise exception 'invalid_input';
  end if;
  insert into public.attempt_answers as aa
    (attempt_id, question_id, answer, time_ms, marked_for_review, eliminated, client_seq, answered_at)
  values (p_attempt_id, p_question_id, jsonb_build_object('value', p_answer),
          greatest(0, least(coalesce(p_time_ms, 0), 3600000)), p_marked, to_jsonb(p_eliminated), p_client_seq, now())
  on conflict (attempt_id, question_id) do update
    set answer = excluded.answer, time_ms = excluded.time_ms, marked_for_review = excluded.marked_for_review,
        eliminated = excluded.eliminated, client_seq = excluded.client_seq, answered_at = excluded.answered_at
    where excluded.client_seq > aa.client_seq;
  get diagnostics v_written = row_count;
  if v_written = 0 then
    return jsonb_build_object('ok', true, 'stale', true);
  end if;
  return jsonb_build_object('ok', true);
end;
$$;
revoke execute on function public.save_answer(uuid, uuid, text, int, boolean, text[], int) from public, anon;
grant execute on function public.save_answer(uuid, uuid, text, int, boolean, text[], int) to authenticated;

create or replace function public.submit_attempt(p_attempt_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_att public.attempts%rowtype;
begin
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;
  select a.* into v_att from public.attempts a
  where a.id = p_attempt_id and a.user_id = v_uid and a.kind = 'quiz';
  if not found then
    raise exception 'invalid_input';
  end if;
  if v_att.status = 'submitted' then
    return v_att.meta -> 'report';
  end if;
  perform private.expire_quiz(v_uid, v_att.topic_id);
  perform private.practice_access(v_uid, v_att.topic_id);
  select a.* into v_att from public.attempts a where a.id = p_attempt_id for update;
  return private.finish_quiz(p_attempt_id, least(now(), v_att.started_at + make_interval(secs => v_att.time_limit_s)));
end;
$$;
revoke execute on function public.submit_attempt(uuid) from public, anon;
grant execute on function public.submit_attempt(uuid) to authenticated;
