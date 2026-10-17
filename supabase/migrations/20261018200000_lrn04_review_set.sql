-- LRN-04 / L-7: targeted review sets. From templates/rpc.sql + setting.sql.
insert into public.settings (key, value) values
  ('review_per_skill', '2'::jsonb),
  ('review_max', '10'::jsonb)
on conflict (key) do nothing;

-- Internal: callers own authentication and topic access checks.
create or replace function private.review_status(p_uid uuid, p_topic_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_progress public.topic_progress%rowtype;
  v_required boolean;
  v_attempt uuid;
  v_answered int;
  v_total int;
begin
  select tp.* into v_progress from public.topic_progress tp
  where tp.user_id = p_uid and tp.topic_id = p_topic_id;
  v_required := v_progress.quiz_passed_at is null and v_progress.quiz_last_failed_at is not null
    and not exists (select 1 from public.attempts a
      where a.user_id = p_uid and a.topic_id = p_topic_id and a.kind = 'review'
        and a.status = 'submitted' and a.submitted_at >= v_progress.quiz_last_failed_at);

  select a.id into v_attempt from public.attempts a
  where a.user_id = p_uid and a.topic_id = p_topic_id and a.kind = 'review'
    and a.status in ('in_progress', 'submitted')
    and a.meta ->> 'source_attempt_id' = (
      select q.id::text from public.attempts q
      where q.user_id = p_uid and q.topic_id = p_topic_id and q.kind = 'quiz' and q.status = 'submitted'
      order by q.submitted_at desc, q.id desc limit 1)
  order by a.started_at desc, a.id desc limit 1;

  select pg_catalog.count(*)::int,
    pg_catalog.count(*) filter (where aa.is_correct is true
      or pg_catalog.jsonb_array_length(coalesce(aa.answer -> 'tries', '[]'::jsonb)) >= 2)::int
  into v_total, v_answered
  from public.attempt_questions aq
  left join public.attempt_answers aa on aa.attempt_id = aq.attempt_id and aa.question_id = aq.question_id
  where aq.attempt_id = v_attempt;
  return pg_catalog.jsonb_build_object('required', v_required, 'attempt_id', v_attempt,
    'answered', v_answered, 'total', v_total);
end;
$$;
revoke execute on function private.review_status(uuid, uuid) from public, anon, authenticated;

create or replace function public.start_review(p_topic_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_course uuid;
  v_status jsonb;
  v_attempt uuid;
  v_source uuid;
  v_skills uuid[];
  v_skill uuid;
  v_ids uuid[] := array[]::uuid[];
  v_pick uuid[];
  v_per int := private.setting_int('review_per_skill');
  v_max int := private.setting_int('review_max');
  v_target int;
  v_questions jsonb;
  v_answered jsonb;
begin
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;
  perform private.hit_rate_limit('start_review:' || v_uid, private.setting_int('rate_start_per_min'), 60);
  if p_topic_id is null then
    raise exception 'invalid_input';
  end if;
  v_course := private.practice_access(v_uid, p_topic_id);
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('review:' || v_uid::text || p_topic_id::text, 0));
  perform private.expire_quiz(v_uid, p_topic_id);
  v_status := private.review_status(v_uid, p_topic_id);
  if not (v_status ->> 'required')::boolean then
    raise exception 'invalid_input';
  end if;

  select a.id into v_attempt from public.attempts a
  where a.id = (v_status ->> 'attempt_id')::uuid and a.status = 'in_progress'
  for update;
  if not found then
    v_status := private.review_status(v_uid, p_topic_id);
    if not (v_status ->> 'required')::boolean then
      raise exception 'invalid_input';
    end if;
    select a.id into v_source from public.attempts a
    where a.user_id = v_uid and a.topic_id = p_topic_id and a.kind = 'quiz' and a.status = 'submitted'
    order by a.submitted_at desc, a.id desc limit 1;
    if not found then
      raise exception 'invalid_input';
    end if;

    select coalesce(pg_catalog.array_agg(distinct qs.skill_id order by qs.skill_id), array[]::uuid[]) into v_skills
    from public.attempt_answers aa
    join public.question_skills qs on qs.question_id = aa.question_id
    where aa.attempt_id = v_source and aa.is_correct is false;
    -- Untagged misses still get a topic-pool batch (spec §7 fallback).
    v_target := least(v_max, v_per * greatest(pg_catalog.cardinality(v_skills), 1));
    foreach v_skill in array v_skills loop
      select coalesce(pg_catalog.array_agg(d.id), array[]::uuid[]) into v_pick
      from (
        select q.id from public.questions q
        left join public.question_exposure x on x.question_id = q.id and x.user_id = v_uid
        where q.topic_id = p_topic_id and q.pool = 'practice' and q.status = 'published'
          and not (q.id = any(v_ids))
          and exists (select 1 from public.question_skills qs where qs.question_id = q.id and qs.skill_id = v_skill)
        order by (x.question_id is null) desc, pg_catalog.random()
        limit least(v_per, v_target - pg_catalog.cardinality(v_ids))
      ) d;
      v_ids := v_ids || v_pick;
      exit when pg_catalog.cardinality(v_ids) >= v_target;
    end loop;

    select coalesce(pg_catalog.array_agg(d.id), array[]::uuid[]) into v_pick
    from (
      select q.id from public.questions q
      left join public.question_exposure x on x.question_id = q.id and x.user_id = v_uid
      where q.topic_id = p_topic_id and q.pool = 'practice' and q.status = 'published'
        and not (q.id = any(v_ids))
      order by (x.question_id is null) desc, pg_catalog.random()
      limit v_target - pg_catalog.cardinality(v_ids)
    ) d;
    v_ids := v_ids || v_pick;
    if pg_catalog.cardinality(v_ids) = 0 then
      raise exception 'pool_exhausted';
    end if;

    insert into public.attempts (user_id, kind, course_id, topic_id, meta)
    values (v_uid, 'review', v_course, p_topic_id, pg_catalog.jsonb_build_object('source_attempt_id', v_source))
    returning id into v_attempt;
    insert into public.attempt_questions (attempt_id, question_id, position)
    select v_attempt, q.id, q.pos from pg_catalog.unnest(v_ids) with ordinality q(id, pos);
    insert into public.question_exposure (user_id, question_id)
    select v_uid, aq.question_id from public.attempt_questions aq where aq.attempt_id = v_attempt
    on conflict (user_id, question_id) do nothing;
  end if;

  select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
    'id', q.id, 'type', q.type, 'difficulty', q.difficulty, 'stem_md', q.stem_md,
    'choices', coalesce((select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('label', c.label, 'body_md', c.body_md) order by c.label)
      from public.question_choices c where c.question_id = q.id), '[]'::jsonb)) order by aq.position)
  into v_questions from public.attempt_questions aq join public.questions q on q.id = aq.question_id
  where aq.attempt_id = v_attempt;
  select coalesce(pg_catalog.jsonb_agg(aq.question_id order by aq.position), '[]'::jsonb) into v_answered
  from public.attempt_questions aq join public.attempt_answers aa on aa.attempt_id = aq.attempt_id and aa.question_id = aq.question_id
  where aq.attempt_id = v_attempt and (aa.is_correct is true
    or pg_catalog.jsonb_array_length(coalesce(aa.answer -> 'tries', '[]'::jsonb)) >= 2);
  return pg_catalog.jsonb_build_object('attempt_id', v_attempt, 'rep_target', pg_catalog.jsonb_array_length(v_questions),
    'questions', v_questions, 'answered', v_answered);
end;
$$;
revoke execute on function public.start_review(uuid) from public, anon;
grant execute on function public.start_review(uuid) to authenticated;

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
    and a.kind in ('practice', 'review')
    and (a.status = 'in_progress' or (a.kind = 'review' and a.status = 'submitted'))
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

  if v_att.status = 'submitted' and not v_replay then
    raise exception 'invalid_input';
  end if;

  if not v_replay then
    -- A new try: grade it on the server.
    v_correct := private.grade_answer(p_question_id, v_ans);

    if v_try = 1 then
      -- practice_count = distinct questions answered in any practice set (spec §1.6).
      perform pg_advisory_xact_lock(hashtextextended(v_uid::text || p_question_id::text, 0));
      v_counts := v_att.kind = 'practice' and not exists (
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

  if v_att.kind = 'review' and v_att.status = 'in_progress' and (v_correct or v_try = 2) then
    if not exists (
      select 1 from public.attempt_questions aq
      left join public.attempt_answers aa on aa.attempt_id = aq.attempt_id and aa.question_id = aq.question_id
      where aq.attempt_id = p_attempt_id
        and not (coalesce(aa.is_correct, false)
          or pg_catalog.jsonb_array_length(coalesce(aa.answer -> 'tries', '[]'::jsonb)) >= 2)
    ) then
      update public.attempts set status = 'submitted', submitted_at = pg_catalog.now() where id = p_attempt_id;
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
  v_review jsonb;
begin
  perform private.practice_access(p_uid, p_topic_id);
  select tp.* into v_progress from public.topic_progress tp
  where tp.user_id = p_uid and tp.topic_id = p_topic_id;
  v_review := private.review_status(p_uid, p_topic_id);
  v_state := jsonb_build_object(
    'practice_count', coalesce(v_progress.practice_count, 0), 'practice_min', v_min,
    'best_score_pct', v_progress.quiz_best_score, 'passed', v_progress.quiz_passed_at is not null, 'review', v_review);

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
  if (v_review ->> 'required')::boolean then
    return v_state || jsonb_build_object('state', 'review_needed')
      || case when v_available_at > now() then jsonb_build_object('available_at', v_available_at) else '{}'::jsonb end;
  end if;
  if v_available_at > now() then
    return v_state || jsonb_build_object('state', 'cooldown', 'available_at', v_available_at);
  end if;
  return v_state || jsonb_build_object('state', 'available');
end;
$$;
revoke execute on function private.quiz_state(uuid, uuid) from public, anon, authenticated;

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
