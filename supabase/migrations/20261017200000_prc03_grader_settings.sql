-- PRC-03: shared grading and practice hardening. From templates/rpc.sql.
-- Seed defaults without overwriting values changed by the teacher.
insert into public.settings (key, value) values
  ('quiz_size',         '12'),
  ('quiz_time_per_q_s', '90'),
  ('quiz_warn_s',       '300')
on conflict (key) do nothing;

-- Internal only: the calling RPC owns authentication and access checks.
create or replace function private.grade_answer(p_question_id uuid, p_answer text)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_type public.questions.type%type;
  v_key  jsonb;
begin
  if p_answer is null or btrim(p_answer) = '' then
    return false;
  end if;

  select q.type, k.correct_answer into v_type, v_key
  from public.questions q
  join private.question_keys k on k.question_id = q.id
  where q.id = p_question_id;
  if not found then
    raise exception 'invalid_key';
  end if;

  if v_type = 'mcq' then
    return upper(btrim(p_answer)) = (v_key ->> 'choice');
  end if;
  return private.grade_spr(btrim(p_answer), v_key);
end;
$$;

revoke execute on function private.grade_answer(uuid, text) from public, anon, authenticated;

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

  select q.* into v_q from public.questions q
  where q.id = p_question_id and q.pool = 'practice' and q.status = 'published';
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
