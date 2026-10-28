-- ANL-01: skill mastery engine. From templates/setting.sql and templates/table.sql.
-- Mastery math lives only here (CLAUDE.md rule 2); every tunable is a setting (rule 5).

insert into public.settings (key, value) values
  ('mastery_alpha',             '0.15'::jsonb),
  ('mastery_weights',           '{"practice":0.5,"homework":1.0,"quiz":1.2,"mock":1.5}'::jsonb),
  ('mastery_difficulty',        '{"E":0.8,"M":1.0,"H":1.2}'::jsonb),
  ('mastery_start',             '50'::jsonb),
  ('mastery_weak_below',        '50'::jsonb),
  ('mastery_min_attempts',      '5'::jsonb),
  ('mastery_trend_min_answers', '10'::jsonb)
on conflict (key) do nothing;

-- One row per student, skill and day: the mastery value after the day's last answer (trend chart).
create table public.skill_mastery_daily (
  user_id  uuid not null references public.profiles (id) on delete cascade,
  skill_id uuid not null references public.skills (id) on delete restrict,
  day      date not null,
  mastery  numeric(5,2) not null check (mastery between 0 and 100),
  primary key (user_id, skill_id, day)
);

alter table public.skill_mastery_daily enable row level security;

-- Written only by private.apply_mastery (security definer); clients read their own rows.
grant select on public.skill_mastery_daily to authenticated;
grant select, insert, update, delete on public.skill_mastery_daily to service_role;

create policy "skill_mastery_daily: student selects own"
  on public.skill_mastery_daily for select
  to authenticated
  using ((select auth.uid()) = user_id);

create policy "skill_mastery_daily: teacher selects all"
  on public.skill_mastery_daily for select
  to authenticated
  using ((select public.is_teacher()));

-- EWMA update of skill_mastery for every skill tagged on the question, plus today's history row.
-- Weight key: practice and review use 'practice', mock_module uses 'mock'; other kinds do nothing.
-- Missing time contributes zero to the running mean over all graded answers.
create or replace function private.apply_mastery(
  p_user     uuid,
  p_question uuid,
  p_kind     public.attempt_kind,
  p_correct  boolean,
  p_time_ms  int,
  p_at       timestamptz
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_wkey    text;
  v_diff    public.difficulty;
  v_alpha   numeric;
  v_start   numeric;
  v_weight  numeric;
  v_dweight numeric;
  v_a       numeric;
  v_x       numeric := case when coalesce(p_correct, false) then 100 else 0 end;
begin
  v_wkey := case p_kind
    when 'practice'    then 'practice'
    when 'review'      then 'practice'
    when 'homework'    then 'homework'
    when 'quiz'        then 'quiz'
    when 'mock_module' then 'mock'
    else null end;
  if v_wkey is null or p_user is null or p_question is null or p_at is null then
    return;
  end if;

  select q.difficulty into v_diff from public.questions q where q.id = p_question;
  if not found then
    return;
  end if;
  if not exists (select 1 from public.question_skills qs where qs.question_id = p_question) then
    return;
  end if;

  select (s.value #>> '{}')::numeric into v_alpha from public.settings s where s.key = 'mastery_alpha';
  select (s.value #>> '{}')::numeric into v_start from public.settings s where s.key = 'mastery_start';
  select (s.value ->> v_wkey)::numeric into v_weight from public.settings s where s.key = 'mastery_weights';
  select (s.value ->> v_diff::text)::numeric into v_dweight from public.settings s where s.key = 'mastery_difficulty';
  if v_alpha is null or v_start is null or v_weight is null or v_dweight is null then
    raise exception 'internal';
  end if;
  v_a := v_alpha * v_weight * v_dweight;

  with upd as (
    insert into public.skill_mastery as sm (user_id, skill_id, mastery, attempts, correct, avg_time_ms, updated_at)
    select p_user, qs.skill_id,
           greatest(0, least(100, round(v_start + v_a * (v_x - v_start), 2))),
           1, case when coalesce(p_correct, false) then 1 else 0 end, coalesce(p_time_ms, 0), p_at
    from public.question_skills qs
    where qs.question_id = p_question
    on conflict (user_id, skill_id) do update
      set mastery     = greatest(0, least(100, round(sm.mastery + v_a * (v_x - sm.mastery), 2))),
          attempts    = sm.attempts + 1,
          correct     = sm.correct + case when coalesce(p_correct, false) then 1 else 0 end,
          avg_time_ms = round((coalesce(sm.avg_time_ms, 0)::numeric * sm.attempts
                               + coalesce(p_time_ms, 0)) / (sm.attempts + 1))::int,
          updated_at  = p_at
    returning sm.skill_id, sm.mastery
  )
  insert into public.skill_mastery_daily as d (user_id, skill_id, day, mastery)
  select p_user, upd.skill_id, (p_at at time zone 'UTC')::date, upd.mastery from upd
  on conflict (user_id, skill_id, day) do update set mastery = excluded.mastery;
end;
$$;

revoke execute on function private.apply_mastery(uuid, uuid, public.attempt_kind, boolean, int, timestamptz)
  from public, anon, authenticated;
