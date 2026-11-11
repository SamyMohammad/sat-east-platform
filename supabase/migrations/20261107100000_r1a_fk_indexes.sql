-- R1a / NFR-01, NFR-02: FK indexes, expire-cron index, cron history purge. From templates/setting.sql + rpc.sql.

-- FK columns with no leading index (plain create: migrations run in a transaction).
create index if not exists courses_owner_id_idx on public.courses (owner_id);
create index if not exists prices_course_id_idx on public.prices (course_id);
create index if not exists coupons_course_id_idx on public.coupons (course_id);
create index if not exists orders_course_id_idx on public.orders (course_id);
create index if not exists orders_price_id_idx on public.orders (price_id);
create index if not exists orders_coupon_id_idx on public.orders (coupon_id);
create index if not exists activation_codes_course_id_idx on public.activation_codes (course_id);
create index if not exists activation_codes_created_by_idx on public.activation_codes (created_by);
create index if not exists activation_codes_redeemed_by_idx on public.activation_codes (redeemed_by);
create index if not exists enrollments_course_id_idx on public.enrollments (course_id);
create index if not exists enrollments_order_id_idx on public.enrollments (order_id);
create index if not exists enrollments_activation_code_id_idx on public.enrollments (activation_code_id);
create index if not exists units_course_id_idx on public.units (course_id);
create index if not exists topics_unit_id_idx on public.topics (unit_id);
create index if not exists subtopics_topic_id_idx on public.subtopics (topic_id);
create index if not exists topic_assets_topic_id_idx on public.topic_assets (topic_id);
create index if not exists topic_assets_subtopic_id_idx on public.topic_assets (subtopic_id);
create index if not exists video_chapters_asset_id_idx on public.video_chapters (asset_id);
create index if not exists video_chapters_subtopic_id_idx on public.video_chapters (subtopic_id);
create index if not exists subtopic_skills_skill_id_idx on public.subtopic_skills (skill_id);
create index if not exists questions_subtopic_id_idx on public.questions (subtopic_id);
create index if not exists question_courses_course_id_idx on public.question_courses (course_id);
create index if not exists question_skills_skill_id_idx on public.question_skills (skill_id);
create index if not exists mock_templates_course_id_idx on public.mock_templates (course_id);
create index if not exists mock_results_template_id_idx on public.mock_results (template_id);
create index if not exists official_scores_course_id_idx on public.official_scores (course_id);
create index if not exists attempts_course_id_idx on public.attempts (course_id);
create index if not exists attempts_topic_id_idx on public.attempts (topic_id);
create index if not exists attempts_mock_form_id_idx on public.attempts (mock_form_id);
create index if not exists attempt_questions_question_id_idx on public.attempt_questions (question_id);
create index if not exists topic_progress_topic_id_idx on public.topic_progress (topic_id);
create index if not exists topic_progress_homework_attempt_id_idx on public.topic_progress (homework_attempt_id);
create index if not exists topic_progress_unlocked_by_idx on public.topic_progress (unlocked_by);
create index if not exists video_progress_asset_id_idx on public.video_progress (asset_id);
create index if not exists question_exposure_question_id_idx on public.question_exposure (question_id);
create index if not exists skill_mastery_skill_id_idx on public.skill_mastery (skill_id);
create index if not exists mistake_notebook_question_id_idx on public.mistake_notebook (question_id);
create index if not exists live_sessions_course_id_idx on public.live_sessions (course_id);
create index if not exists live_sessions_recording_asset_id_idx on public.live_sessions (recording_asset_id);
create index if not exists ai_threads_question_id_idx on public.ai_threads (question_id);
create index if not exists ai_threads_attempt_id_idx on public.ai_threads (attempt_id);
create index if not exists escalations_live_session_id_idx on public.escalations (live_session_id);
create index if not exists announcements_course_id_idx on public.announcements (course_id);
create index if not exists audit_log_actor_idx on public.audit_log (actor);
create index if not exists question_reports_resolved_by_idx on public.question_reports (resolved_by);
create index if not exists skill_mastery_daily_skill_id_idx on public.skill_mastery_daily (skill_id);
create index if not exists question_reports_question_id_idx on public.question_reports (question_id);

-- Matches private.expire_overdue_attempts() (every-minute cron).
create index if not exists attempts_quiz_in_progress_idx
  on public.attempts (started_at, id) where kind = 'quiz' and status = 'in_progress';

-- pg_cron never prunes cron.job_run_details; purge it nightly.
insert into public.settings (key, value)
values ('cron_history_keep_days', '7'::jsonb)
on conflict (key) do nothing;

create or replace function private.nightly_cleanup()
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.attempts a
  set status = 'abandoned'
  where a.kind = 'practice' and a.status = 'in_progress'
    and coalesce((select pg_catalog.max(aa.answered_at) from public.attempt_answers aa where aa.attempt_id = a.id), a.started_at)
      < pg_catalog.now() - pg_catalog.make_interval(hours => private.setting_int('practice_stale_h'));

  delete from private.rate_limits r
  where r.window_start < pg_catalog.now() - interval '1 day';

  delete from cron.job_run_details d
  where d.end_time < pg_catalog.now() - pg_catalog.make_interval(days => private.setting_int('cron_history_keep_days'));
end;
$$;
revoke execute on function private.nightly_cleanup() from public, anon, authenticated;
