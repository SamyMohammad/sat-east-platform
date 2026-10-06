-- TEMPLATE (docs/16 §2) — copy into a migration created with `supabase migration new <name>`,
-- rename example_items, delete this header, then walk supabase/templates/README.md checklist.
-- Needs: public.profiles (docs/15 §1 row 2b), public.is_teacher() (row 3).
-- Secrets or answer data? Then this table belongs in `private`, not `public` (checklist #1).

create table public.example_items (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references public.profiles (id) on delete cascade,
  -- columns …
  created_at timestamptz not null default now()
);

-- Auto-enabled by the ensure_rls event trigger; repeated so the file is correct on its own.
alter table public.example_items enable row level security;

-- Data API access: nothing is granted by default (hardening migration, Layer 3).
-- Students write through RPCs (CLAUDE.md rule 2); RLS limits direct writes to teachers.
grant select, insert, update, delete on public.example_items to authenticated;
grant select, insert, update, delete on public.example_items to service_role;
-- No anon grant unless the data is genuinely public (e.g. published catalogue).

create policy "example_items: student selects own"
  on public.example_items for select
  to authenticated
  using ((select auth.uid()) = user_id);

create policy "example_items: teacher manages all"
  on public.example_items for all
  to authenticated
  using ((select public.is_teacher()))
  with check ((select public.is_teacher()));

-- Only if students may update their own rows directly — UPDATE needs USING and WITH CHECK:
-- create policy "example_items: student updates own"
--   on public.example_items for update
--   to authenticated
--   using ((select auth.uid()) = user_id)
--   with check ((select auth.uid()) = user_id);

create index example_items_user_id_idx on public.example_items (user_id);
