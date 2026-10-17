-- SEC / PRC-01 / PRC-03: per-user RPC quotas. From templates/rpc.sql + setting.sql.
insert into public.settings (key, value) values
  ('rate_answer_per_min', '30'::jsonb),
  ('rate_start_per_min', '10'::jsonb),
  ('rate_save_per_min', '120'::jsonb),
  ('rate_submit_per_min', '10'::jsonb)
on conflict (key) do nothing;

-- Internal only: authenticated RPCs supply the user/RPC key and settings-backed limit.
create or replace function private.hit_rate_limit(p_key text, p_limit int, p_window_s int)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_window_start timestamptz := pg_catalog.to_timestamp(
    pg_catalog.floor(extract(epoch from pg_catalog.now()) / p_window_s) * p_window_s);
  v_count int;
begin
  insert into private.rate_limits as r (key, window_start, count)
  values (p_key, v_window_start, 1)
  on conflict (key, window_start) do update
    set count = r.count + 1
  returning count into v_count;

  if v_count > p_limit then
    raise exception 'rate_limited';
  end if;
end;
$$;
revoke execute on function private.hit_rate_limit(text, int, int) from public, anon, authenticated;

create or replace function public.get_practice_questions(p_topic_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid       uuid := auth.uid();
  v_course_id uuid;
  v_size      int;
  v_attempt   uuid;
  v_n         int;
  v_questions jsonb;
begin
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;
  perform private.hit_rate_limit('get_practice_questions:' || v_uid, private.setting_int('rate_start_per_min'), 60);

  if p_topic_id is null then
    raise exception 'invalid_input';
  end if;

  v_course_id := private.practice_access(v_uid, p_topic_id);
  v_size := private.setting_int('practice_min');

  insert into public.attempts (user_id, kind, course_id, topic_id, status)
  values (v_uid, 'practice', v_course_id, p_topic_id, 'in_progress')
  returning id into v_attempt;

  -- random() is evaluated once per row in the inner query; positions follow the same order.
  insert into public.attempt_questions (attempt_id, question_id, position)
  select v_attempt, d.id, row_number() over (order by d.unseen desc, d.r)
  from (
    select q.id, (x.question_id is null) as unseen, random() as r
    from public.questions q
    left join public.question_exposure x on x.question_id = q.id and x.user_id = v_uid
    where q.topic_id = p_topic_id and q.pool = 'practice' and q.status = 'published'
    order by unseen desc, r
    limit v_size
  ) d;
  get diagnostics v_n = row_count;

  if v_n = 0 then
    raise exception 'pool_exhausted';  -- rolls back the attempt row
  end if;

  insert into public.question_exposure (user_id, question_id)
  select v_uid, aq.question_id
  from public.attempt_questions aq
  where aq.attempt_id = v_attempt
  on conflict (user_id, question_id) do nothing;

  -- No key, explanation, hint or misconceptions here.
  select jsonb_agg(
           jsonb_build_object(
             'id', q.id,
             'type', q.type,
             'difficulty', q.difficulty,
             'stem_md', q.stem_md,
             'choices', coalesce((
               select jsonb_agg(jsonb_build_object('label', c.label, 'body_md', c.body_md) order by c.label)
               from public.question_choices c
               where c.question_id = q.id), '[]'::jsonb)
           ) order by aq.position)
  into v_questions
  from public.attempt_questions aq
  join public.questions q on q.id = aq.question_id
  where aq.attempt_id = v_attempt;

  return jsonb_build_object('attempt_id', v_attempt, 'rep_target', v_n, 'questions', v_questions);
end;
$$;

revoke execute on function public.get_practice_questions(uuid) from public, anon;
grant execute on function public.get_practice_questions(uuid) to authenticated;

create or replace function public.check_practice_answer(
  p_attempt_id  uuid,
  p_question_id uuid,
  p_answer      text,
  p_time_ms     int
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid     uuid := auth.uid();
  v_att     public.attempts%rowtype;
  v_q       public.questions%rowtype;
  v_key     private.question_keys%rowtype;
  v_row     public.attempt_answers%rowtype;
  v_ans     text;
  v_time    int;
  v_tries   jsonb;
  v_try     int;
  v_correct boolean;
  v_counts  boolean;
  v_replay  boolean := false;
  v_show    jsonb;
begin
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;
  perform private.hit_rate_limit('check_practice_answer:' || v_uid, private.setting_int('rate_answer_per_min'), 60);

  if p_attempt_id is null or p_question_id is null or p_answer is null then
    raise exception 'invalid_input';
  end if;

  -- Locks the attempt so a retried request waits and then replays.
  select a.* into v_att
  from public.attempts a
  where a.id = p_attempt_id
    and a.user_id = v_uid
    and a.kind = 'practice'
    and a.status = 'in_progress'
    and exists (select 1 from public.attempt_questions aq
                where aq.attempt_id = a.id and aq.question_id = p_question_id)
  for update;
  if not found then
    raise exception 'invalid_input';
  end if;

  perform private.practice_access(v_uid, v_att.topic_id);

  select q.* into v_q from public.questions q
  where q.id = p_question_id and q.pool = 'practice' and q.status = 'published' and q.topic_id = v_att.topic_id;
  if not found then
    raise exception 'invalid_input';
  end if;

  select k.* into v_key from private.question_keys k where k.question_id = p_question_id;
  if not found then
    raise exception 'invalid_key';
  end if;

  v_ans := btrim(p_answer);
  if v_q.type = 'mcq' then
    v_ans := upper(v_ans);
  end if;
  if v_ans = '' or length(v_ans) > 32 then
    raise exception 'invalid_input';
  end if;
  v_time := greatest(0, least(coalesce(p_time_ms, 0), 3600000));

  select aa.* into v_row
  from public.attempt_answers aa
  where aa.attempt_id = p_attempt_id and aa.question_id = p_question_id;

  if found then
    v_tries := coalesce(v_row.answer -> 'tries', '[]'::jsonb);
    if jsonb_array_length(v_tries) > 0 and v_tries ->> -1 = v_ans then
      -- Replay: rebuild the stored result, write nothing.
      v_replay := true;
      v_try := jsonb_array_length(v_tries);
      v_correct := coalesce(v_row.is_correct, false);
    elsif v_row.is_correct or jsonb_array_length(v_tries) <> 1 then
      raise exception 'invalid_input';
    else
      v_try := 2;
    end if;
  else
    v_tries := '[]'::jsonb;
    v_try := 1;
  end if;

  if not v_replay then
    -- A new try: grade it on the server.
    v_correct := private.grade_answer(p_question_id, v_ans);

    if v_try = 1 then
      -- practice_count = distinct questions answered in any practice set (spec §1.6).
      perform pg_advisory_xact_lock(hashtextextended(v_uid::text || p_question_id::text, 0));
      v_counts := not exists (
        select 1
        from public.attempt_answers aa
        join public.attempts a on a.id = aa.attempt_id
        where a.user_id = v_uid and a.kind = 'practice' and aa.question_id = p_question_id);

      insert into public.attempt_answers (attempt_id, question_id, answer, is_correct, time_ms, answered_at)
      values (p_attempt_id, p_question_id, jsonb_build_object('tries', jsonb_build_array(v_ans)),
              v_correct, v_time, now());

      if v_counts then
        insert into public.topic_progress (user_id, topic_id, practice_count)
        values (v_uid, v_att.topic_id, 1)
        on conflict (user_id, topic_id)
        do update set practice_count = public.topic_progress.practice_count + 1;
      end if;
    else
      update public.attempt_answers aa
      set answer      = jsonb_build_object('tries', v_tries || to_jsonb(v_ans)),
          is_correct  = v_correct,
          time_ms     = aa.time_ms + v_time,
          answered_at = now()
      where aa.attempt_id = p_attempt_id and aa.question_id = p_question_id;
    end if;
  end if;

  if v_correct or v_try = 2 then
    if v_q.type = 'mcq' then
      v_show := jsonb_build_object('choice', v_key.correct_answer ->> 'choice');
    else
      v_show := jsonb_build_object('text', v_key.correct_answer -> 'accepted' ->> 0);
    end if;
    return jsonb_build_object('is_correct', v_correct, 'try', v_try,
                              'key', v_show, 'explanation_md', v_key.explanation_md);
  end if;

  if v_q.type = 'mcq' then
    return jsonb_build_object('is_correct', false, 'try', 1, 'hint_md', v_q.hint_md,
                              'misconception_md', v_key.misconceptions ->> v_ans);
  end if;
  return jsonb_build_object('is_correct', false, 'try', 1, 'hint_md', v_q.hint_md,
                            'misconception_md', null);
end;
$$;

revoke execute on function public.check_practice_answer(uuid, uuid, text, int) from public, anon;
grant execute on function public.check_practice_answer(uuid, uuid, text, int) to authenticated;

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
  perform private.hit_rate_limit('start_quiz:' || v_uid, private.setting_int('rate_start_per_min'), 60);
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
  perform private.hit_rate_limit('save_answer:' || v_uid, private.setting_int('rate_save_per_min'), 60);
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
  perform private.hit_rate_limit('submit_attempt:' || v_uid, private.setting_int('rate_submit_per_min'), 60);
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
