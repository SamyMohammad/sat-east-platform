-- PRC-02 / PRC-05 / LRN-01: homework lifecycle. From supabase/templates/rpc.sql.
-- Private helpers trust ownership-checked public entry points; keys stay in private.

create or replace function private.homework_state(p_uid uuid, p_topic_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_progress public.topic_progress%rowtype;
  v_att public.attempts%rowtype;
  v_total int;
  v_answered int;
begin
  perform private.practice_access(p_uid, p_topic_id);
  select tp.* into v_progress from public.topic_progress tp
  where tp.user_id = p_uid and tp.topic_id = p_topic_id;
  if v_progress.quiz_passed_at is not null or not exists (
    select 1 from public.questions q
    where q.topic_id = p_topic_id and q.pool = 'practice' and q.status = 'published'
  ) then
    return pg_catalog.jsonb_build_object('state', 'skipped');
  end if;
  select a.* into v_att from public.attempts a
  where a.user_id = p_uid and a.topic_id = p_topic_id and a.kind = 'homework'
  order by a.started_at, a.id limit 1;
  if found then
    select pg_catalog.count(*)::int, pg_catalog.count(*) filter (where aa.answer ->> 'value' is not null)::int
    into v_total, v_answered from public.attempt_questions aq
    left join public.attempt_answers aa on aa.attempt_id = aq.attempt_id and aa.question_id = aq.question_id
    where aq.attempt_id = v_att.id;
    return pg_catalog.jsonb_build_object(
      'state', case when v_att.status = 'submitted' then 'submitted' else 'in_progress' end,
      'attempt_id', v_att.id, 'score_pct', v_att.score_pct, 'total', v_total, 'answered', v_answered);
  end if;
  if coalesce(v_progress.practice_count, 0) < private.setting_int('practice_min') then
    return pg_catalog.jsonb_build_object('state', 'locked_by_practice');
  end if;
  return pg_catalog.jsonb_build_object('state', 'available');
end;
$fn$;
revoke execute on function private.homework_state(uuid, uuid) from public, anon, authenticated;

create or replace function public.start_homework(p_topic_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_uid uuid := auth.uid();
  v_course uuid;
  v_att public.attempts%rowtype;
  v_questions jsonb;
  v_answers jsonb;
  v_seq int;
  v_n int;
  v_topic record;
  v_label text;
begin
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;
  if p_topic_id is null then
    raise exception 'invalid_input';
  end if;
  v_course := private.practice_access(v_uid, p_topic_id);
  perform private.require_notes_opened(v_uid, p_topic_id);
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('homework:' || v_uid::text || p_topic_id::text, 0));
  select a.* into v_att from public.attempts a
  where a.user_id = v_uid and a.topic_id = p_topic_id and a.kind = 'homework'
  order by a.started_at, a.id limit 1;
  if found then
    if v_att.status <> 'in_progress' then
      raise exception 'attempt_closed';
    end if;
  else
    if not exists (select 1 from public.topic_progress tp
      where tp.user_id = v_uid and tp.topic_id = p_topic_id
        and (tp.practice_count >= private.setting_int('practice_min') or tp.quiz_passed_at is not null)) then
      raise exception 'practice_needed';
    end if;
    insert into public.attempts(user_id, kind, course_id, topic_id)
    values(v_uid, 'homework', v_course, p_topic_id) returning * into v_att;
    insert into public.attempt_questions(attempt_id, question_id, position)
    select v_att.id, d.id, pg_catalog.row_number() over(order by d.practice_answered, d.first_seen_at nulls first, d.r)
    from (
      select q.id, exists (
        select 1 from public.attempt_answers aa join public.attempts a on a.id = aa.attempt_id
        where a.user_id = v_uid and a.kind = 'practice' and aa.question_id = q.id
          and aa.answered_at is not null
      ) as practice_answered, x.first_seen_at, pg_catalog.random() as r
      from public.questions q
      left join public.question_exposure x on x.user_id = v_uid and x.question_id = q.id
      where q.topic_id = p_topic_id and q.pool = 'practice' and q.status = 'published'
      order by practice_answered, x.first_seen_at nulls first, r
      limit private.setting_int('homework_size')
    ) d;
    get diagnostics v_n = row_count;
    if v_n = 0 then
      raise exception 'pool_exhausted';
    end if;
    insert into public.question_exposure(user_id, question_id)
    select v_uid, aq.question_id from public.attempt_questions aq where aq.attempt_id = v_att.id
    on conflict(user_id, question_id) do nothing;
  end if;
  select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
    'id', q.id, 'type', q.type, 'difficulty', q.difficulty, 'stem_md', q.stem_md,
    'choices', coalesce((select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
      'label', c.label, 'body_md', c.body_md) order by c.label)
      from public.question_choices c where c.question_id = q.id), '[]'::jsonb)) order by aq.position)
  into v_questions from public.attempt_questions aq join public.questions q on q.id = aq.question_id
  where aq.attempt_id = v_att.id;
  select coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('question_id', aa.question_id,
    'answer', aa.answer -> 'value', 'marked', aa.marked_for_review) order by aq.position), '[]'::jsonb),
    coalesce(pg_catalog.max(aa.client_seq), 0)
  into v_answers, v_seq from public.attempt_answers aa
  join public.attempt_questions aq on aq.attempt_id = aa.attempt_id and aq.question_id = aa.question_id
  where aa.attempt_id = v_att.id;
  select ts.* into v_topic from private.topic_states(v_uid, v_course) ts where ts.topic_id = p_topic_id;
  v_label := v_topic.topic_no::text;
  if v_topic.unit_id is not null then
    v_label := v_topic.unit_no || '.' || v_topic.topic_no;
  end if;
  return pg_catalog.jsonb_build_object('attempt_id', v_att.id, 'title', v_label || ' ' || v_topic.title,
    'questions', v_questions, 'answers', v_answers, 'client_seq', v_seq);
end;
$fn$;
revoke execute on function public.start_homework(uuid) from public, anon;
grant execute on function public.start_homework(uuid) to authenticated;

create or replace function private.quiz_state(p_uid uuid, p_topic_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_progress public.topic_progress%rowtype;
  v_attempt uuid;
  v_min int := private.setting_int('practice_min');
  v_available_at timestamptz;
  v_state jsonb;
  v_review jsonb;
begin
  perform private.practice_access(p_uid, p_topic_id);
  select tp.* into v_progress from public.topic_progress tp
  where tp.user_id = p_uid and tp.topic_id = p_topic_id;
  v_review := private.review_status(p_uid, p_topic_id);
  v_state := pg_catalog.jsonb_build_object(
    'practice_count', coalesce(v_progress.practice_count, 0), 'practice_min', v_min,
    'best_score_pct', v_progress.quiz_best_score, 'passed', v_progress.quiz_passed_at is not null, 'review', v_review);

  select a.id into v_attempt from public.attempts a
  where a.user_id = p_uid and a.topic_id = p_topic_id and a.kind = 'quiz'
    and a.status = 'in_progress'
    and a.started_at + pg_catalog.make_interval(secs => a.time_limit_s + private.setting_int('save_grace_s')) >= pg_catalog.now()
  order by a.started_at, a.id limit 1;
  if found then
    return v_state || pg_catalog.jsonb_build_object('state', 'in_progress', 'attempt_id', v_attempt);
  end if;
  if coalesce(v_progress.practice_count, 0) < v_min then
    return v_state || pg_catalog.jsonb_build_object('state', 'practice_needed');
  end if;
  if v_progress.homework_submitted_at is null
     and private.homework_state(p_uid, p_topic_id) ->> 'state' <> 'skipped' then
    return v_state || pg_catalog.jsonb_build_object('state', 'homework_needed');
  end if;
  v_available_at := v_progress.quiz_last_failed_at + pg_catalog.make_interval(hours => private.setting_int('cooldown_h'));
  if (v_review ->> 'required')::boolean then
    return v_state || pg_catalog.jsonb_build_object('state', 'review_needed')
      || case when v_available_at > pg_catalog.now() then pg_catalog.jsonb_build_object('available_at', v_available_at) else '{}'::jsonb end;
  end if;
  if v_available_at > pg_catalog.now() then
    return v_state || pg_catalog.jsonb_build_object('state', 'cooldown', 'available_at', v_available_at);
  end if;
  return v_state || pg_catalog.jsonb_build_object('state', 'available');
end;
$fn$;
revoke execute on function private.quiz_state(uuid, uuid) from public, anon, authenticated;

create or replace function public.start_quiz(p_topic_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
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
  perform private.hit_rate_limit('start_quiz:' || v_uid, private.setting_int('rate_start_per_min'), 60);
  if p_topic_id is null then
    raise exception 'invalid_input';
  end if;
  perform private.expire_quiz(v_uid, p_topic_id);
  v_state := private.quiz_state(v_uid, p_topic_id);
  if v_state ->> 'state' = 'practice_needed' then
    raise exception 'practice_needed';
  end if;
  if v_state ->> 'state' = 'homework_needed' then
    raise exception 'homework_needed';
  end if;
  if v_state ->> 'state' = 'review_needed' then
    raise exception 'review_needed';
  end if;
  if v_state ->> 'state' = 'cooldown' then
    raise exception 'cooldown_active';
  end if;

  select t.course_id into v_course from public.topics t where t.id = p_topic_id;
  if v_state ->> 'state' = 'in_progress' then
    select a.* into v_att from public.attempts a where a.id = (v_state ->> 'attempt_id')::uuid;
  else
    insert into public.attempts (user_id, kind, course_id, topic_id, started_at)
    values (v_uid, 'quiz', v_course, p_topic_id, pg_catalog.now()) returning * into v_att;
    insert into public.attempt_questions (attempt_id, question_id, position)
    select v_att.id, d.id, pg_catalog.row_number() over (order by d.unseen desc, d.r)
    from (
      select q.id, (x.question_id is null) as unseen, pg_catalog.random() as r
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

  select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('id', q.id, 'type', q.type, 'difficulty', q.difficulty,
    'stem_md', q.stem_md, 'choices', coalesce((select pg_catalog.jsonb_agg(
      pg_catalog.jsonb_build_object('label', c.label, 'body_md', c.body_md) order by c.label)
      from public.question_choices c where c.question_id = q.id), '[]'::jsonb)) order by aq.position)
  into v_questions from public.attempt_questions aq join public.questions q on q.id = aq.question_id
  where aq.attempt_id = v_att.id;
  select coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('question_id', aa.question_id,
    'answer', aa.answer -> 'value', 'marked', aa.marked_for_review) order by aq.position), '[]'::jsonb),
    coalesce(pg_catalog.max(aa.client_seq), 0)
  into v_answers, v_seq from public.attempt_answers aa
  join public.attempt_questions aq on aq.attempt_id = aa.attempt_id and aq.question_id = aa.question_id
  where aa.attempt_id = v_att.id;
  select ts.* into v_topic from private.topic_states(v_uid, v_course) ts where ts.topic_id = p_topic_id;
  v_label := v_topic.topic_no::text;
  if v_topic.unit_id is not null then
    v_label := v_topic.unit_no || '.' || v_topic.topic_no;
  end if;
  return pg_catalog.jsonb_build_object('attempt_id', v_att.id, 'title', v_label || ' ' || v_topic.title,
    'time_limit_s', v_att.time_limit_s, 'deadline', v_att.started_at + pg_catalog.make_interval(secs => v_att.time_limit_s),
    'server_now', pg_catalog.now(), 'warn_s', private.setting_int('quiz_warn_s'),
    'questions', v_questions, 'answers', v_answers, 'client_seq', v_seq);
end;
$fn$;
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
as $fn$
declare
  v_uid uuid := auth.uid();
  v_att public.attempts%rowtype;
  v_written int;
begin
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;
  perform private.hit_rate_limit('save_answer:' || v_uid, private.setting_int('rate_save_per_min'), 60);
  select a.* into v_att from public.attempts a
  where a.id = p_attempt_id and a.user_id = v_uid and a.kind in ('quiz', 'homework');
  if not found then
    raise exception 'invalid_input';
  end if;
  if v_att.kind = 'quiz' then
    perform private.expire_quiz(v_uid, v_att.topic_id);
  end if;
  perform private.practice_access(v_uid, v_att.topic_id);
  select a.* into v_att from public.attempts a where a.id = p_attempt_id for update;
  if p_question_id is null or p_client_seq is null or p_marked is null or pg_catalog.length(p_answer) > 32
     or not exists (select 1 from public.attempt_questions aq
                    where aq.attempt_id = p_attempt_id and aq.question_id = p_question_id) then
    raise exception 'invalid_input';
  end if;
  if v_att.kind = 'quiz' and v_att.started_at + pg_catalog.make_interval(secs => v_att.time_limit_s + private.setting_int('save_grace_s')) < pg_catalog.now() then
    raise exception 'deadline_passed';
  end if;
  if v_att.status <> 'in_progress' then
    raise exception 'invalid_input';
  end if;
  insert into public.attempt_answers as aa
    (attempt_id, question_id, answer, time_ms, marked_for_review, eliminated, client_seq, answered_at)
  values (p_attempt_id, p_question_id, pg_catalog.jsonb_build_object('value', p_answer),
          greatest(0, least(coalesce(p_time_ms, 0), 3600000)), p_marked, pg_catalog.to_jsonb(p_eliminated), p_client_seq, pg_catalog.now())
  on conflict (attempt_id, question_id) do update
    set answer = excluded.answer, time_ms = excluded.time_ms, marked_for_review = excluded.marked_for_review,
        eliminated = excluded.eliminated, client_seq = excluded.client_seq, answered_at = excluded.answered_at
    where excluded.client_seq > aa.client_seq;
  get diagnostics v_written = row_count;
  if v_written = 0 then
    return pg_catalog.jsonb_build_object('ok', true, 'stale', true);
  end if;
  return pg_catalog.jsonb_build_object('ok', true);
end;
$fn$;
revoke execute on function public.save_answer(uuid, uuid, text, int, boolean, text[], int) from public, anon;
grant execute on function public.save_answer(uuid, uuid, text, int, boolean, text[], int) to authenticated;

create or replace function public.submit_attempt(p_attempt_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_uid uuid := auth.uid();
  v_att public.attempts%rowtype;
  v_raw int;
  v_total int;
  v_pct numeric;
  v_report jsonb;
begin
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;
  perform private.hit_rate_limit('submit_attempt:' || v_uid, private.setting_int('rate_submit_per_min'), 60);
  select a.* into v_att from public.attempts a
  where a.id = p_attempt_id and a.user_id = v_uid and a.kind in ('quiz', 'homework');
  if not found then
    raise exception 'invalid_input';
  end if;
  if v_att.status = 'submitted' then
    return v_att.meta -> 'report';
  end if;
  if v_att.kind = 'quiz' then
    perform private.expire_quiz(v_uid, v_att.topic_id);
  end if;
  perform private.practice_access(v_uid, v_att.topic_id);
  select a.* into v_att from public.attempts a where a.id = p_attempt_id for update;
  if v_att.kind = 'homework' then
    if v_att.status = 'submitted' then
      return v_att.meta -> 'report';
    end if;
    if v_att.status <> 'in_progress' then
      raise exception 'invalid_input';
    end if;
    insert into public.attempt_answers(attempt_id, question_id, answer, is_correct, answered_at)
    select aq.attempt_id, aq.question_id, pg_catalog.jsonb_build_object('value', null), false, pg_catalog.now()
    from public.attempt_questions aq where aq.attempt_id = p_attempt_id
    on conflict(attempt_id, question_id) do nothing;
    update public.attempt_answers aa
    set is_correct = private.grade_answer(aa.question_id, aa.answer ->> 'value')
    where aa.attempt_id = p_attempt_id;
    select pg_catalog.count(*)::int, pg_catalog.count(*) filter(where aa.is_correct)::int into v_total, v_raw
    from public.attempt_questions aq
    join public.attempt_answers aa on aa.attempt_id = aq.attempt_id and aa.question_id = aq.question_id
    where aq.attempt_id = p_attempt_id;
    if v_total = 0 then
      raise exception 'invalid_input';
    end if;
    v_pct := pg_catalog.round(100::numeric * v_raw / v_total, 2);
    v_report := pg_catalog.jsonb_build_object('attempt_id', p_attempt_id, 'kind', 'homework',
      'score_raw', v_raw, 'score_total', v_total, 'score_pct', v_pct);
    update public.attempts a set status = 'submitted', submitted_at = pg_catalog.now(),
      score_raw = v_raw, score_total = v_total, score_pct = v_pct,
      meta = a.meta || pg_catalog.jsonb_build_object('report', v_report)
    where a.id = p_attempt_id;
    insert into public.topic_progress(user_id, topic_id, homework_attempt_id, homework_score, homework_submitted_at)
    values(v_uid, v_att.topic_id, p_attempt_id, v_pct, pg_catalog.now())
    on conflict(user_id, topic_id) do update set homework_attempt_id = excluded.homework_attempt_id,
      homework_score = excluded.homework_score, homework_submitted_at = excluded.homework_submitted_at;
    return v_report;
  end if;
  return private.finish_quiz(p_attempt_id, least(pg_catalog.now(), v_att.started_at + pg_catalog.make_interval(secs => v_att.time_limit_s)));
end;
$fn$;
revoke execute on function public.submit_attempt(uuid) from public, anon;
grant execute on function public.submit_attempt(uuid) to authenticated;

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
  v_report := v_att.meta -> 'report';
  v_summary := pg_catalog.jsonb_build_object(
    'score_raw', v_report -> 'score_raw', 'score_total', v_report -> 'score_total',
    'score_pct', v_report -> 'score_pct', 'pass_mark', case when v_att.kind = 'quiz' then v_report -> 'pass_mark' else 'null'::jsonb end,
    'passed', case when v_att.kind = 'quiz' then v_report -> 'passed' else 'null'::jsonb end, 'keys_visible', v_keys_visible);

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

create or replace function public.get_topic(p_topic_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_uid uuid := auth.uid();
  v_quiz jsonb;
  v_topic record;
  v_label text;
  v_notes jsonb;
  v_videos jsonb;
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
  select coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('asset_id', a.id, 'title', a.title,
    'subtopic_title', s.title, 'page_count', a.page_count) order by a.sort, a.id), '[]'::jsonb)
  into v_notes from public.topic_assets a left join public.subtopics s on s.id = a.subtopic_id
  where a.topic_id = p_topic_id and a.kind = 'notes' and a.ready;
  select coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
    'asset_id',a.id,'title',a.title,'subtopic_title',s.title,'duration_s',a.duration_s,
    'provider',a.provider,'pct',coalesce(p.pct,0),'last_position_s',coalesce(p.last_position_s,0)
    ) order by a.sort,a.id),'[]'::jsonb)
  into v_videos from public.topic_assets a
  left join public.subtopics s on s.id=a.subtopic_id
  left join public.video_progress p on p.asset_id=a.id and p.user_id=v_uid
  where a.topic_id=p_topic_id and a.kind='video' and a.ready;
  return pg_catalog.jsonb_build_object('id', p_topic_id, 'title', v_topic.title, 'slug', v_topic.slug,
    'sort_label', v_label, 'status', v_topic.status,
    'practice', pg_catalog.jsonb_build_object('count', v_quiz -> 'practice_count', 'min', v_quiz -> 'practice_min'),
    'quiz', v_quiz, 'homework', private.homework_state(v_uid, p_topic_id),
    'videos',v_videos,'video_done',private.video_satisfied(v_uid,p_topic_id),
    'notes', v_notes, 'notes_done', private.notes_satisfied(v_uid, p_topic_id));
end;
$fn$;
revoke execute on function public.get_topic(uuid) from public, anon;
grant execute on function public.get_topic(uuid) to authenticated;
