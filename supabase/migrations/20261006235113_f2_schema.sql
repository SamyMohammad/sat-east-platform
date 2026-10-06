-- F-2 row 2b (docs/15 §1): starting schema from docs/06 §§2–3.
-- Locked until row 3: RLS on, no grants to anon/authenticated, no policies.
-- FK rules, not-null and sign-up rules: docs/06 conventions.

-- Enums (docs/06 §2)
create type public.user_role         as enum ('student','teacher','parent');
create type public.course_code       as enum ('SAT','EST');
create type public.question_type     as enum ('mcq','spr');
create type public.difficulty        as enum ('E','M','H');
create type public.question_status   as enum ('draft','solved','needs_review','approved','published','retired');
create type public.question_pool     as enum ('practice','quiz','mock_reserve');
create type public.attempt_kind      as enum ('practice','homework','quiz','review','mock_module','drill','diagnostic');
create type public.attempt_status    as enum ('in_progress','submitted','expired','abandoned');
create type public.step_kind         as enum ('video','notes','practice','homework','quiz');
create type public.enrollment_status as enum ('active','expired','refunded','suspended');
create type public.order_status      as enum ('pending','paid','failed','refunded');
create type public.error_type        as enum ('concept','careless','time');

-- Identity & access
create table public.profiles (
  id         uuid primary key references auth.users (id) on delete cascade,
  role       public.user_role not null default 'student',
  full_name  text not null,
  phone      text,
  country    char(2),
  school     text,
  grade      text,
  timezone   text,
  created_at timestamptz not null default now()
);

create table public.devices (
  id                 uuid primary key default gen_random_uuid(),
  user_id            uuid not null references public.profiles (id) on delete cascade,
  device_fingerprint text not null,
  platform           text,
  label              text,
  last_seen_at       timestamptz,
  revoked_at         timestamptz,
  created_at         timestamptz not null default now(),
  unique (user_id, device_fingerprint)
);

create table public.device_changes (
  id         bigint generated always as identity primary key,
  user_id    uuid not null references public.profiles (id) on delete cascade,
  changed_at timestamptz not null default now()
);

-- Catalogue & commerce
create table public.courses (
  id           uuid primary key default gen_random_uuid(),
  code         public.course_code not null unique,
  title        text not null,
  slug         text not null unique,
  description  text,
  owner_id     uuid references public.profiles (id) on delete set null,
  is_published boolean not null default false,
  sort         int not null default 0,
  created_at   timestamptz not null default now()
);

create table public.prices (
  id           uuid primary key default gen_random_uuid(),
  course_id    uuid not null references public.courses (id) on delete restrict,
  currency     char(3) not null,
  amount_minor int not null check (amount_minor >= 0),
  kind         text not null check (kind in ('full','renewal','bundle')),
  active       boolean not null default true,
  created_at   timestamptz not null default now()
);

create table public.coupons (
  id               uuid primary key default gen_random_uuid(),
  code             text not null unique,
  course_id        uuid references public.courses (id) on delete restrict,
  percent_off      int check (percent_off between 1 and 100),
  amount_off_minor int check (amount_off_minor > 0),
  currency         char(3),
  max_uses         int,
  used_count       int not null default 0,
  expires_at       timestamptz,
  active           boolean not null default true,
  created_at       timestamptz not null default now(),
  check ((percent_off is null) <> (amount_off_minor is null))
);

create table public.orders (
  id               uuid primary key default gen_random_uuid(),
  user_id          uuid not null references public.profiles (id) on delete restrict,
  course_id        uuid not null references public.courses (id) on delete restrict,
  price_id         uuid not null references public.prices (id) on delete restrict,
  coupon_id        uuid references public.coupons (id) on delete restrict,
  amount_minor     int not null check (amount_minor >= 0),
  currency         char(3) not null,
  status           public.order_status not null default 'pending',
  gateway          text not null,
  gateway_order_id text,
  gateway_txn_id   text unique,
  raw_payload      jsonb,
  created_at       timestamptz not null default now(),
  paid_at          timestamptz
);

create table public.activation_codes (
  id          uuid primary key default gen_random_uuid(),
  code        text not null unique,
  course_id   uuid not null references public.courses (id) on delete restrict,
  created_by  uuid references public.profiles (id) on delete set null,
  redeemed_by uuid references public.profiles (id) on delete set null,
  redeemed_at timestamptz,
  note        text,
  created_at  timestamptz not null default now()
);

create table public.enrollments (
  id                 uuid primary key default gen_random_uuid(),
  user_id            uuid not null references public.profiles (id) on delete cascade,
  course_id          uuid not null references public.courses (id) on delete restrict,
  order_id           uuid references public.orders (id) on delete restrict,
  activation_code_id uuid references public.activation_codes (id) on delete restrict,
  status             public.enrollment_status not null default 'active',
  target_test_date   date,
  starts_at          timestamptz not null default now(),
  expires_at         timestamptz not null,
  mock_set_no        int not null default 1,
  created_at         timestamptz not null default now(),
  unique (user_id, course_id)
);

-- Course structure & content
create table public.units (
  id        uuid primary key default gen_random_uuid(),
  course_id uuid not null references public.courses (id) on delete restrict,
  title     text not null,
  sort      int not null default 0
);

create table public.topics (
  id              uuid primary key default gen_random_uuid(),
  course_id       uuid not null references public.courses (id) on delete restrict,
  unit_id         uuid references public.units (id) on delete restrict,
  title           text not null,
  slug            text not null,
  sort            int not null default 0,
  is_free_preview boolean not null default false,
  is_published    boolean not null default false,
  unique (course_id, slug)
);

create table public.subtopics (
  id       uuid primary key default gen_random_uuid(),
  topic_id uuid not null references public.topics (id) on delete restrict,
  title    text not null,
  sort     int not null default 0
);

create table public.topic_assets (
  id                uuid primary key default gen_random_uuid(),
  topic_id          uuid not null references public.topics (id) on delete restrict,
  subtopic_id       uuid references public.subtopics (id) on delete restrict,
  kind              text not null check (kind in ('video','notes','book')),
  title             text not null,
  sort              int not null default 0,
  video_provider_id text,
  duration_s        int,
  storage_path      text,
  page_count        int,
  created_at        timestamptz not null default now()
);

create table public.video_chapters (
  id          uuid primary key default gen_random_uuid(),
  asset_id    uuid not null references public.topic_assets (id) on delete restrict,
  subtopic_id uuid not null references public.subtopics (id) on delete restrict,
  start_s     int not null check (start_s >= 0),
  label       text not null
);

create table private.video_keys (
  asset_id   uuid primary key references public.topic_assets (id) on delete restrict,
  key        bytea not null,
  r2_prefix  text not null,
  created_at timestamptz not null default now()
);

create table public.skills (
  id           uuid primary key default gen_random_uuid(),
  code         text not null unique,
  name         text not null,
  domain       text not null,
  course_scope public.course_code[] not null default '{}'
);

create table public.subtopic_skills (
  subtopic_id uuid not null references public.subtopics (id) on delete restrict,
  skill_id    uuid not null references public.skills (id) on delete restrict,
  primary key (subtopic_id, skill_id)
);

-- Question bank
create table public.questions (
  id              uuid primary key default gen_random_uuid(),
  external_ref    text unique,
  topic_id        uuid not null references public.topics (id) on delete restrict,
  subtopic_id     uuid not null references public.subtopics (id) on delete restrict,
  type            public.question_type not null,
  difficulty      public.difficulty not null,
  stem_md         text not null,
  image_paths     text[] not null default '{}',
  hint_md         text,
  desmos_friendly boolean not null default false,
  pool            public.question_pool not null,
  status          public.question_status not null default 'draft',
  source          text,
  source_page     int,
  version         int not null default 1,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

create table private.question_keys (
  question_id    uuid primary key references public.questions (id) on delete restrict,
  correct_answer jsonb not null,
  explanation_md text,
  misconceptions jsonb,
  solved_by      text check (solved_by in ('teacher','ai_double_agree','ai_teacher_fixed')),
  updated_at     timestamptz not null default now()
);

create table public.question_courses (
  question_id uuid not null references public.questions (id) on delete restrict,
  course_id   uuid not null references public.courses (id) on delete restrict,
  primary key (question_id, course_id)
);

create table public.question_choices (
  id          uuid primary key default gen_random_uuid(),
  question_id uuid not null references public.questions (id) on delete restrict,
  label       char(1) not null,
  body_md     text not null,
  unique (question_id, label)
);

create table public.question_skills (
  question_id uuid not null references public.questions (id) on delete restrict,
  skill_id    uuid not null references public.skills (id) on delete restrict,
  primary key (question_id, skill_id)
);

create table public.question_reports (
  id          uuid primary key default gen_random_uuid(),
  question_id uuid not null references public.questions (id) on delete restrict,
  user_id     uuid not null references public.profiles (id) on delete cascade,
  reason      text not null,
  status      text not null default 'open',
  created_at  timestamptz not null default now()
);

-- Mocks (before attempts: attempts.mock_form_id)
create table public.mock_templates (
  id         uuid primary key default gen_random_uuid(),
  course_id  uuid not null references public.courses (id) on delete restrict,
  name       text not null,
  adaptive   boolean not null default false,
  blueprint  jsonb not null,
  created_at timestamptz not null default now()
);

create table public.mock_forms (
  id           uuid primary key default gen_random_uuid(),
  template_id  uuid not null references public.mock_templates (id) on delete restrict,
  set_no       int not null,
  form_no      int not null,
  module       text not null check (module in ('M1','M2E','M2H','EST1','EST2')),
  question_ids uuid[] not null,
  created_at   timestamptz not null default now(),
  unique (template_id, set_no, form_no, module)
);

create table public.mock_results (
  id               uuid primary key default gen_random_uuid(),
  user_id          uuid not null references public.profiles (id) on delete cascade,
  template_id      uuid not null references public.mock_templates (id) on delete restrict,
  group_id         uuid not null,
  route            text,
  raw_m1           int,
  raw_m2           int,
  est_low          int,
  est_high         int,
  domain_breakdown jsonb,
  created_at       timestamptz not null default now()
);

create table public.official_scores (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references public.profiles (id) on delete cascade,
  course_id  uuid not null references public.courses (id) on delete restrict,
  source     text,
  score      int not null,
  taken_on   date not null,
  created_at timestamptz not null default now()
);

-- Progress, attempts, analytics
create table public.attempts (
  id                 uuid primary key default gen_random_uuid(),
  user_id            uuid not null references public.profiles (id) on delete cascade,
  kind               public.attempt_kind not null,
  course_id          uuid not null references public.courses (id) on delete restrict,
  topic_id           uuid references public.topics (id) on delete restrict,
  mock_attempt_group uuid,
  mock_form_id       uuid references public.mock_forms (id) on delete restrict,
  module_no          int,
  status             public.attempt_status not null default 'in_progress',
  started_at         timestamptz not null default now(),
  submitted_at       timestamptz,
  time_limit_s       int,
  score_raw          int,
  score_total        int,
  score_pct          numeric,
  meta               jsonb not null default '{}'
);

create table public.attempt_questions (
  attempt_id  uuid not null references public.attempts (id) on delete cascade,
  question_id uuid not null references public.questions (id) on delete restrict,
  position    int not null,
  primary key (attempt_id, question_id),
  unique (attempt_id, position)
);

create table public.attempt_answers (
  attempt_id        uuid not null,
  question_id       uuid not null,
  answer            jsonb,
  is_correct        boolean,
  time_ms           int not null default 0,
  marked_for_review boolean not null default false,
  client_seq        int not null default 0,
  eliminated        jsonb,
  error_type        public.error_type,
  answered_at       timestamptz,
  primary key (attempt_id, question_id),
  foreign key (attempt_id, question_id)
    references public.attempt_questions (attempt_id, question_id) on delete cascade
);

create table public.topic_progress (
  user_id               uuid not null references public.profiles (id) on delete cascade,
  topic_id              uuid not null references public.topics (id) on delete restrict,
  video_pct             int not null default 0 check (video_pct between 0 and 100),
  notes_opened_at       timestamptz,
  practice_count        int not null default 0,
  homework_attempt_id   uuid references public.attempts (id) on delete set null,
  homework_score        numeric,
  homework_submitted_at timestamptz,
  quiz_best_score       numeric,
  quiz_passed_at        timestamptz,
  quiz_last_failed_at   timestamptz,
  unlocked_at           timestamptz,
  unlocked_by           uuid references public.profiles (id) on delete set null,
  primary key (user_id, topic_id)
);

create table public.video_progress (
  user_id         uuid not null references public.profiles (id) on delete cascade,
  asset_id        uuid not null references public.topic_assets (id) on delete restrict,
  watched_ranges  int4range[] not null default '{}',
  pct             int not null default 0 check (pct between 0 and 100),
  last_position_s int not null default 0,
  updated_at      timestamptz not null default now(),
  primary key (user_id, asset_id)
);

create table public.question_exposure (
  user_id       uuid not null references public.profiles (id) on delete cascade,
  question_id   uuid not null references public.questions (id) on delete restrict,
  first_seen_at timestamptz not null default now(),
  primary key (user_id, question_id)
);

create table public.skill_mastery (
  user_id     uuid not null references public.profiles (id) on delete cascade,
  skill_id    uuid not null references public.skills (id) on delete restrict,
  mastery     numeric not null default 0 check (mastery between 0 and 100),
  attempts    int not null default 0,
  correct     int not null default 0,
  avg_time_ms int,
  updated_at  timestamptz not null default now(),
  primary key (user_id, skill_id)
);

create table public.mistake_notebook (
  user_id        uuid not null references public.profiles (id) on delete cascade,
  question_id    uuid not null references public.questions (id) on delete restrict,
  added_at       timestamptz not null default now(),
  correct_streak int not null default 0,
  cleared_at     timestamptz,
  primary key (user_id, question_id)
);

-- AI, comms, ops
create table public.live_sessions (
  id                 uuid primary key default gen_random_uuid(),
  course_id          uuid not null references public.courses (id) on delete restrict,
  title              text not null,
  starts_at          timestamptz not null,
  duration_min       int not null check (duration_min > 0),
  join_url           text,
  recording_asset_id uuid references public.topic_assets (id) on delete set null,
  created_at         timestamptz not null default now()
);

create table public.ai_threads (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references public.profiles (id) on delete cascade,
  question_id uuid not null references public.questions (id) on delete restrict,
  attempt_id  uuid references public.attempts (id) on delete set null,
  created_at  timestamptz not null default now()
);

create table public.ai_messages (
  id         uuid primary key default gen_random_uuid(),
  thread_id  uuid not null references public.ai_threads (id) on delete cascade,
  role       text not null check (role in ('user','assistant')),
  content    text not null,
  tokens_in  int,
  tokens_out int,
  created_at timestamptz not null default now()
);

create table public.escalations (
  id              uuid primary key default gen_random_uuid(),
  thread_id       uuid not null references public.ai_threads (id) on delete cascade,
  status          text not null default 'open',
  teacher_reply   text,
  live_session_id uuid references public.live_sessions (id) on delete set null,
  created_at      timestamptz not null default now(),
  resolved_at     timestamptz
);

create table public.announcements (
  id         uuid primary key default gen_random_uuid(),
  course_id  uuid not null references public.courses (id) on delete restrict,
  title      text not null,
  body_md    text not null,
  created_at timestamptz not null default now()
);

create table public.notifications (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references public.profiles (id) on delete cascade,
  kind       text not null,
  payload    jsonb not null default '{}',
  read_at    timestamptz,
  created_at timestamptz not null default now()
);

create table public.push_tokens (
  user_id    uuid not null references public.profiles (id) on delete cascade,
  token      text not null,
  platform   text not null,
  created_at timestamptz not null default now(),
  primary key (user_id, token)
);

create table public.settings (
  key        text primary key,
  value      jsonb not null,
  updated_at timestamptz not null default now()
);

create table private.rate_limits (
  key          text not null,
  window_start timestamptz not null,
  count        int not null default 0,
  primary key (key, window_start)
);

create table public.audit_log (
  id         bigint generated always as identity primary key,
  actor      uuid references public.profiles (id) on delete set null,
  action     text not null,
  entity     text not null,
  entity_id  uuid,
  diff       jsonb,
  created_at timestamptz not null default now()
);

-- Indexes (docs/06 §5; uniques above cover orders.gateway_txn_id and enrollments)
create index attempt_answers_question_id_idx on public.attempt_answers (question_id);
create index attempts_user_kind_topic_idx    on public.attempts (user_id, kind, topic_id);
create index questions_draw_idx
  on public.questions (topic_id, subtopic_id, pool, status, difficulty);
create index device_changes_user_changed_idx on public.device_changes (user_id, changed_at);

-- RLS: auto-enabled in public by the ensure_rls event trigger; repeated so this file is correct
-- on its own, and enabled on private tables too (defence in depth).
do $$
declare
  t record;
begin
  for t in
    select n.nspname, c.relname
    from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname in ('public', 'private') and c.relkind = 'r'
  loop
    execute format('alter table %I.%I enable row level security', t.nspname, t.relname);
  end loop;
end;
$$;

-- Grants: none to anon/authenticated until row 3. service_role (Edge Functions) only.
grant select, insert, update, delete on all tables in schema public to service_role;
grant usage, select on all sequences in schema public to service_role;

-- updated_at (docs/06 conventions)
create function private.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create trigger set_updated_at before update on public.questions
  for each row execute function private.set_updated_at();
create trigger set_updated_at before update on private.question_keys
  for each row execute function private.set_updated_at();
create trigger set_updated_at before update on public.video_progress
  for each row execute function private.set_updated_at();
create trigger set_updated_at before update on public.skill_mastery
  for each row execute function private.set_updated_at();
create trigger set_updated_at before update on public.settings
  for each row execute function private.set_updated_at();

-- Sign-up → profile (docs/06 conventions). role is never read from client metadata.
create function private.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, full_name)
  values (
    new.id,
    coalesce(
      nullif(trim(new.raw_user_meta_data ->> 'full_name'), ''),
      nullif(split_part(coalesce(new.email, ''), '@', 1), ''),
      'Student'
    )
  );
  return new;
end;
$$;

create trigger on_auth_user_created after insert on auth.users
  for each row execute function private.handle_new_user();
