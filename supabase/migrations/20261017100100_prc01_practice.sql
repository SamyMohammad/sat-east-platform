-- PRC-01 / PRC-04 / LRN-02: practice read + check (docs/07 §1). From templates/rpc.sql.
-- Spec: docs/superpowers/specs/2026-10-17-p1-practice-design.md §1.2–1.6.
-- Keys, explanations and misconceptions stay in private.question_keys; check_practice_answer
-- reveals the key + explanation only on a correct try or a wrong try 2 (CLAUDE.md rule 1).
-- Errors (docs/07 §9): not_authenticated, invalid_input, not_enrolled, access_expired,
-- topic_locked, pool_exhausted (and invalid_key from private.grade_spr for a broken key).

-- Internal: may p_uid practise p_topic_id? Returns the topic's course id or raises.
create or replace function private.practice_access(p_uid uuid, p_topic_id uuid)
returns uuid
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_course_id uuid;
  v_enr       public.enrollments%rowtype;
  v_status    text;
begin
  select t.course_id into v_course_id
  from public.topics t
  join public.courses c on c.id = t.course_id
  where t.id = p_topic_id and t.is_published and c.is_published;
  if not found then
    raise exception 'invalid_input';
  end if;

  select e.* into v_enr
  from public.enrollments e
  where e.user_id = p_uid and e.course_id = v_course_id;
  if not found then
    raise exception 'not_enrolled';
  end if;
  if v_enr.status <> 'active' or v_enr.expires_at <= now() then
    raise exception 'access_expired';
  end if;

  select ts.status into v_status
  from private.topic_states(p_uid, v_course_id) ts
  where ts.topic_id = p_topic_id;
  if v_status is distinct from 'open' and v_status is distinct from 'completed' then
    raise exception 'topic_locked';
  end if;

  return v_course_id;
end;
$$;

revoke execute on function private.practice_access(uuid, uuid) from public, anon, authenticated;

-- A new practice set for one topic: never-seen questions first, then random.
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

-- Grade one practice try. Try 1 → hint (+ misconception) when wrong; correct or wrong try 2 →
-- key + explanation. An answer equal to the last stored try is a replay (lost reply): same
-- response, nothing logged or counted.
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

  select q.* into v_q from public.questions q where q.id = p_question_id;
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
    if v_q.type = 'mcq' then
      v_correct := v_ans = (v_key.correct_answer ->> 'choice');
    else
      v_correct := private.grade_spr(v_ans, v_key.correct_answer);  -- false for a malformed answer
    end if;

    if v_try = 1 then
      -- practice_count = distinct questions answered in any practice set (spec §1.6).
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
