-- ANL-01: update skill mastery from graded answers, and replay history once.
-- Triggers (not edits to check_practice_answer / save_answer / submit_attempt) so each graded
-- answer counts exactly once:
--   * practice/review: the INSERT of attempt_answers is the first try (check_practice_answer);
--     a second try is an UPDATE and a replay writes nothing.
--   * quiz/homework: the in_progress -> submitted transition, reached by manual submit, the
--     timer path (expire_quiz) and the expire cron alike; a second submit changes no status.
-- No answer keys are read here: is_correct was already written by the grading paths.

create or replace function private.attempt_answers_mastery()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_kind public.attempt_kind;
  v_user uuid;
begin
  select a.kind, a.user_id into v_kind, v_user from public.attempts a where a.id = new.attempt_id;
  if v_kind in ('practice', 'review') and jsonb_typeof(new.answer -> 'tries') = 'array' then
    perform private.apply_mastery(v_user, new.question_id, v_kind, coalesce(new.is_correct, false),
                                  new.time_ms, coalesce(new.answered_at, now()));
  end if;
  return null;
end;
$$;
revoke execute on function private.attempt_answers_mastery() from public, anon, authenticated;

create trigger attempt_answers_mastery
  after insert on public.attempt_answers
  for each row execute function private.attempt_answers_mastery();

create or replace function private.attempts_mastery()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  r record;
begin
  for r in
    select aq.question_id, coalesce(aa.is_correct, false) as is_correct,
           case when (aa.answer ->> 'value') is null then null else aa.time_ms end as time_ms
    from public.attempt_questions aq
    left join public.attempt_answers aa
      on aa.attempt_id = aq.attempt_id and aa.question_id = aq.question_id
    where aq.attempt_id = new.id
    order by aq.position
  loop
    perform private.apply_mastery(new.user_id, r.question_id, new.kind, r.is_correct, r.time_ms,
                                  coalesce(new.submitted_at, now()));
  end loop;
  return null;
end;
$$;
revoke execute on function private.attempts_mastery() from public, anon, authenticated;

create trigger attempts_mastery
  after update of status on public.attempts
  for each row
  when (old.status = 'in_progress' and new.status = 'submitted' and new.kind in ('quiz', 'homework'))
  execute function private.attempts_mastery();

-- Rebuilds skill_mastery and skill_mastery_daily from history, in time order. Deterministic:
-- skill_mastery is derived data, so it is cleared first and a second run gives the same rows.
-- Practice/review: first try only (one try stored = its own result; two tries = first was wrong,
-- no regrading). Quiz/homework: every question of a submitted attempt, unanswered = incorrect.
create or replace function private.backfill_mastery()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  r record;
begin
  delete from public.skill_mastery_daily where true;
  delete from public.skill_mastery where true;
  for r in
    select * from (
      select a.user_id, aa.question_id, a.kind,
             (jsonb_array_length(aa.answer -> 'tries') = 1 and coalesce(aa.is_correct, false)) as correct,
             aa.time_ms as time_ms, aa.answered_at as at, a.id as aid, 0 as pos
      from public.attempt_answers aa
      join public.attempts a on a.id = aa.attempt_id
      where a.kind in ('practice', 'review') and jsonb_typeof(aa.answer -> 'tries') = 'array'
      union all
      select a.user_id, aq.question_id, a.kind, coalesce(aa.is_correct, false),
             case when (aa.answer ->> 'value') is null then null else aa.time_ms end,
             coalesce(a.submitted_at, aa.answered_at), a.id, aq.position
      from public.attempts a
      join public.attempt_questions aq on aq.attempt_id = a.id
      left join public.attempt_answers aa on aa.attempt_id = aq.attempt_id and aa.question_id = aq.question_id
      where a.kind in ('quiz', 'homework') and a.status = 'submitted'
    ) ev
    where ev.at is not null
    order by ev.at, ev.aid, ev.pos, ev.question_id
  loop
    perform private.apply_mastery(r.user_id, r.question_id, r.kind, r.correct, r.time_ms, r.at);
  end loop;
end;
$$;
revoke execute on function private.backfill_mastery() from public, anon, authenticated;

select private.backfill_mastery();
