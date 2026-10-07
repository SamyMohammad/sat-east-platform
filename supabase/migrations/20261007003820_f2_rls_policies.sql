-- F-2 row 3: RLS baseline (docs/06 §4). Teacher: all on every public table except audit_log.
-- Students/anon: only the rows below. Grants: authenticated gets full DML because the teacher is
-- an authenticated user; RLS is the student gate; column grants narrow profiles/notifications/orders.

-- 1. Grants
grant select on public.courses, public.units, public.topics, public.subtopics, public.prices to anon;

grant select, insert, update, delete on all tables in schema public to authenticated;
grant usage, select on all sequences in schema public to authenticated;

revoke insert, update on public.profiles from authenticated;  -- profiles come from the sign-up trigger
grant update (full_name, phone, country, school, grade, timezone) on public.profiles to authenticated;

revoke update on public.notifications from authenticated;
grant update (read_at) on public.notifications to authenticated;

revoke select on public.orders from authenticated;
grant select (id, user_id, course_id, price_id, coupon_id, amount_minor, currency, status, gateway,
              gateway_order_id, gateway_txn_id, created_at, paid_at)
  on public.orders to authenticated;

revoke insert, update, delete on public.audit_log from authenticated;

-- 2. Teacher manages all (one permissive policy per table)
do $$
declare
  t record;
begin
  for t in
    select c.relname
    from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind = 'r' and c.relname <> 'audit_log'
  loop
    execute format(
      'create policy %I on public.%I for all to authenticated '
      'using ((select public.is_teacher())) with check ((select public.is_teacher()))',
      t.relname || ': teacher manages all', t.relname);
  end loop;
end;
$$;

create policy "audit_log: teacher reads" on public.audit_log
  for select to authenticated using ((select public.is_teacher()));

-- 3. Public catalogue (PAY-01)
create policy "courses: published catalogue" on public.courses
  for select to anon, authenticated using (is_published);
create policy "units: published catalogue" on public.units
  for select to anon, authenticated
  using (exists (select 1 from public.courses c where c.id = course_id and c.is_published));
create policy "topics: published catalogue" on public.topics
  for select to anon, authenticated
  using (is_published and exists (select 1 from public.courses c where c.id = course_id and c.is_published));
create policy "subtopics: published catalogue" on public.subtopics
  for select to anon, authenticated
  using (exists (select 1 from public.topics t join public.courses c on c.id = t.course_id
                 where t.id = topic_id and t.is_published and c.is_published));
create policy "prices: active catalogue" on public.prices
  for select to anon, authenticated
  using (active and exists (select 1 from public.courses c where c.id = course_id and c.is_published));

-- 4. Student: own rows
create policy "profiles: student selects own" on public.profiles
  for select to authenticated using ((select auth.uid()) = id);
create policy "profiles: student updates own" on public.profiles
  for update to authenticated
  using ((select auth.uid()) = id) with check ((select auth.uid()) = id);

create policy "devices: student selects own" on public.devices
  for select to authenticated using ((select auth.uid()) = user_id);
create policy "enrollments: student selects own" on public.enrollments
  for select to authenticated using ((select auth.uid()) = user_id);
create policy "orders: student selects own" on public.orders
  for select to authenticated using ((select auth.uid()) = user_id);
create policy "attempts: student selects own" on public.attempts
  for select to authenticated using ((select auth.uid()) = user_id);
create policy "attempt_answers: student selects own submitted" on public.attempt_answers
  for select to authenticated
  using (exists (select 1 from public.attempts a
                 where a.id = attempt_id and a.user_id = (select auth.uid())
                   and a.status <> 'in_progress'));
create policy "topic_progress: student selects own" on public.topic_progress
  for select to authenticated using ((select auth.uid()) = user_id);
create policy "video_progress: student selects own" on public.video_progress
  for select to authenticated using ((select auth.uid()) = user_id);
create policy "skill_mastery: student selects own" on public.skill_mastery
  for select to authenticated using ((select auth.uid()) = user_id);
create policy "mistake_notebook: student selects own" on public.mistake_notebook
  for select to authenticated using ((select auth.uid()) = user_id);
create policy "mock_results: student selects own" on public.mock_results
  for select to authenticated using ((select auth.uid()) = user_id);

create policy "official_scores: student selects own" on public.official_scores
  for select to authenticated using ((select auth.uid()) = user_id);
create policy "official_scores: student inserts own" on public.official_scores
  for insert to authenticated with check ((select auth.uid()) = user_id);
create policy "question_reports: student selects own" on public.question_reports
  for select to authenticated using ((select auth.uid()) = user_id);
create policy "question_reports: student inserts own" on public.question_reports
  for insert to authenticated with check ((select auth.uid()) = user_id);

create policy "ai_threads: student selects own" on public.ai_threads
  for select to authenticated using ((select auth.uid()) = user_id);
create policy "ai_messages: student selects own" on public.ai_messages
  for select to authenticated
  using (exists (select 1 from public.ai_threads t where t.id = thread_id and t.user_id = (select auth.uid())));
create policy "escalations: student selects own" on public.escalations
  for select to authenticated
  using (exists (select 1 from public.ai_threads t where t.id = thread_id and t.user_id = (select auth.uid())));

create policy "notifications: student selects own" on public.notifications
  for select to authenticated using ((select auth.uid()) = user_id);
create policy "notifications: student marks own read" on public.notifications
  for update to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

create policy "push_tokens: student selects own" on public.push_tokens
  for select to authenticated using ((select auth.uid()) = user_id);
create policy "push_tokens: student inserts own" on public.push_tokens
  for insert to authenticated with check ((select auth.uid()) = user_id);
create policy "push_tokens: student deletes own" on public.push_tokens
  for delete to authenticated using ((select auth.uid()) = user_id);

-- 5. Student: access-gated content and shared reference data
create policy "topic_assets: student with topic access" on public.topic_assets
  for select to authenticated using (public.has_access_topic(topic_id));
create policy "video_chapters: student with topic access" on public.video_chapters
  for select to authenticated
  using (exists (select 1 from public.topic_assets a
                 where a.id = asset_id and public.has_access_topic(a.topic_id)));
create policy "live_sessions: student with course access" on public.live_sessions
  for select to authenticated using (public.has_access(course_id));
create policy "announcements: student with course access" on public.announcements
  for select to authenticated using (public.has_access(course_id));
create policy "skills: signed-in reads" on public.skills
  for select to authenticated using (true);
create policy "subtopic_skills: signed-in reads" on public.subtopic_skills
  for select to authenticated using (true);
create policy "settings: signed-in reads" on public.settings
  for select to authenticated using (true);

-- 6. Indexes for "select own" filters not already led by a PK/unique (docs/06 §4 traps)
create index orders_user_id_idx          on public.orders (user_id);
create index mock_results_user_id_idx    on public.mock_results (user_id);
create index official_scores_user_id_idx on public.official_scores (user_id);
create index question_reports_user_id_idx on public.question_reports (user_id);
create index ai_threads_user_id_idx      on public.ai_threads (user_id);
create index ai_messages_thread_id_idx   on public.ai_messages (thread_id);
create index escalations_thread_id_idx   on public.escalations (thread_id);
create index notifications_user_id_idx   on public.notifications (user_id);
