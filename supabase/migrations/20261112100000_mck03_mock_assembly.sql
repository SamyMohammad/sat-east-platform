-- MCK-03: SAT mock form assembly (server). Spec: docs/superpowers/specs/2026-11-12-mock-sat-design.md Part 1.
-- Sections: 1 form status | 2 blueprint setting | 3 template guard | 4 private helpers
-- (later tasks append: eligibility/shortage, teacher RPCs).

-- 1. Form status -------------------------------------------------------------------------------
alter table public.mock_forms
  add column status text not null default 'draft' check (status in ('draft', 'published')),
  add column published_at timestamptz;

-- 2. Blueprint setting (docs/08 section 3, verbatim; teacher edits are by migration, so it is
--    deliberately not in private.teacher_setting_spec()) ------------------------------------------
insert into public.settings (key, value)
values ('mock_blueprint_sat', '{
  "modules": {
    "M1":  {"count": 22, "time_s": 2100, "difficulty": {"E": 7, "M": 9, "H": 6}},
    "M2E": {"count": 22, "time_s": 2100, "difficulty": {"E": 10, "M": 9, "H": 3}},
    "M2H": {"count": 22, "time_s": 2100, "difficulty": {"E": 3, "M": 9, "H": 10}}
  },
  "domains": {"Algebra": 0.35, "Advanced Math": 0.35, "PSDA": 0.15, "Geometry & Trig": 0.15},
  "spr_ratio": 0.25,
  "routing": {"threshold_correct_m1": 14},
  "ordering": "difficulty_ascending_within_module"
}'::jsonb)
on conflict (key) do nothing;

-- 3. One adaptive template per course ------------------------------------------------------------
create unique index mock_templates_one_adaptive_per_course
  on public.mock_templates (course_id) where adaptive;

-- 4. Private helpers (no grants: not reachable over the API) -------------------------------------

-- True only for a blueprint assembly can use. Never raises.
create function private.mock_blueprint_ok(p_blueprint jsonb)
returns boolean
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_mod   text;
  v_m     jsonb;
  v_count numeric;
  v_sum   numeric;
  v_ratio numeric;
  v_thr   numeric;
  v_dom   record;
  v_n     int := 0;
begin
  if p_blueprint is null or jsonb_typeof(p_blueprint) <> 'object' then
    return false;
  end if;

  foreach v_mod in array array['M1', 'M2E', 'M2H'] loop
    v_m := p_blueprint -> 'modules' -> v_mod;
    if v_m is null or jsonb_typeof(v_m) <> 'object'
       or jsonb_typeof(v_m -> 'count') <> 'number'
       or jsonb_typeof(v_m -> 'time_s') <> 'number'
       or jsonb_typeof(v_m -> 'difficulty') <> 'object' then
      return false;
    end if;
    v_count := (v_m ->> 'count')::numeric;
    if v_count <= 0 or v_count <> trunc(v_count) or (v_m ->> 'time_s')::numeric <= 0 then
      return false;
    end if;
    if jsonb_typeof(v_m -> 'difficulty' -> 'E') <> 'number'
       or jsonb_typeof(v_m -> 'difficulty' -> 'M') <> 'number'
       or jsonb_typeof(v_m -> 'difficulty' -> 'H') <> 'number' then
      return false;
    end if;
    if (v_m -> 'difficulty' ->> 'E')::numeric < 0 or (v_m -> 'difficulty' ->> 'M')::numeric < 0
       or (v_m -> 'difficulty' ->> 'H')::numeric < 0 then
      return false;
    end if;
    v_sum := (v_m -> 'difficulty' ->> 'E')::numeric + (v_m -> 'difficulty' ->> 'M')::numeric
           + (v_m -> 'difficulty' ->> 'H')::numeric;
    if v_sum <> v_count then
      return false;
    end if;
  end loop;

  if jsonb_typeof(p_blueprint -> 'domains') <> 'object' then
    return false;
  end if;
  v_sum := 0;
  for v_dom in select key as k, value as v from jsonb_each(p_blueprint -> 'domains') loop
    if jsonb_typeof(v_dom.v) <> 'number' or (v_dom.v #>> '{}')::numeric <= 0 then
      return false;
    end if;
    v_sum := v_sum + (v_dom.v #>> '{}')::numeric;
    v_n := v_n + 1;
  end loop;
  if v_n = 0 or abs(v_sum - 1) > 0.001 then
    return false;
  end if;

  if jsonb_typeof(p_blueprint -> 'spr_ratio') <> 'number' then
    return false;
  end if;
  v_ratio := (p_blueprint ->> 'spr_ratio')::numeric;
  if v_ratio < 0 or v_ratio > 1 then
    return false;
  end if;

  if jsonb_typeof(p_blueprint -> 'routing' -> 'threshold_correct_m1') <> 'number' then
    return false;
  end if;
  v_thr := (p_blueprint -> 'routing' ->> 'threshold_correct_m1')::numeric;
  if v_thr < 0 or v_thr > (p_blueprint -> 'modules' -> 'M1' ->> 'count')::numeric then
    return false;
  end if;

  return true;
exception when others then
  return false;
end;
$$;

-- The slot recipe of one module (docs/08 section 3, "slot rule"). Deterministic: ties go to the
-- domain name ascending (C collation). Slot difficulty is E, then M, then H.
create function private.mock_module_slots(p_blueprint jsonb, p_module text)
returns table (slot_no int, difficulty public.difficulty, domain text, qtype public.question_type)
language plpgsql
stable
set search_path = ''
as $$
declare
  v_mod      jsonb;
  v_n        int;
  v_e        int;
  v_m        int;
  v_names    text[];
  v_counts   int[];
  v_fracs    numeric[];
  v_assigned int[];
  v_rem      int;
  v_s        numeric;
  v_best     int;
  v_score    numeric;
  v_top      numeric;
begin
  if not private.mock_blueprint_ok(p_blueprint) or p_module is null
     or p_module not in ('M1', 'M2E', 'M2H') then
    raise exception 'internal';
  end if;

  v_mod := p_blueprint -> 'modules' -> p_module;
  v_n := (v_mod ->> 'count')::int;
  v_e := (v_mod -> 'difficulty' ->> 'E')::int;
  v_m := (v_mod -> 'difficulty' ->> 'M')::int;

  -- Domain counts: floor(share * N), then one extra each to the largest fractions.
  select array_agg(d.k order by d.k collate "C"),
         array_agg(floor(d.share * v_n)::int order by d.k collate "C"),
         array_agg(d.share * v_n - floor(d.share * v_n) order by d.k collate "C")
    into v_names, v_counts, v_fracs
  from (select key as k, (value #>> '{}')::numeric as share
        from jsonb_each(p_blueprint -> 'domains')) d;

  v_rem := v_n - (select coalesce(sum(c), 0) from unnest(v_counts) c);
  while v_rem > 0 loop
    v_best := 1;
    v_top := v_fracs[1];
    for v_j in 2 .. array_length(v_names, 1) loop
      if v_fracs[v_j] > v_top then
        v_best := v_j;
        v_top := v_fracs[v_j];
      end if;
    end loop;
    v_counts[v_best] := v_counts[v_best] + 1;
    v_fracs[v_best] := -1;
    v_rem := v_rem - 1;
  end loop;

  v_assigned := array_fill(0, array[array_length(v_names, 1)]);
  v_s := round(v_n * (p_blueprint ->> 'spr_ratio')::numeric);

  for v_i in 1 .. v_n loop
    -- Largest n_d * i / N - assigned_d, compared as n_d * i - assigned_d * N (exact integers).
    v_best := 1;
    v_top := v_counts[1] * v_i - v_assigned[1] * v_n;
    for v_j in 2 .. array_length(v_names, 1) loop
      v_score := v_counts[v_j] * v_i - v_assigned[v_j] * v_n;
      if v_score > v_top then
        v_best := v_j;
        v_top := v_score;
      end if;
    end loop;
    v_assigned[v_best] := v_assigned[v_best] + 1;

    slot_no := v_i;
    difficulty := case when v_i <= v_e then 'E' when v_i <= v_e + v_m then 'M' else 'H' end::public.difficulty;
    domain := v_names[v_best];
    qtype := case when floor(v_i * v_s / v_n) > floor((v_i - 1) * v_s / v_n) then 'spr'::public.question_type else 'mcq'::public.question_type end;
    return next;
  end loop;
end;
$$;

-- The course's SAT template; created from the setting on first use.
create function private.mock_template_for(p_course_id uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_code      text;
  v_blueprint jsonb;
  v_id        uuid;
begin
  if p_course_id is null then
    raise exception 'invalid_input';
  end if;
  select c.code into v_code from public.courses c where c.id = p_course_id;
  if v_code is distinct from 'SAT' then
    raise exception 'invalid_input';
  end if;

  select t.id into v_id
  from public.mock_templates t
  where t.course_id = p_course_id and t.adaptive;
  if v_id is not null then
    return v_id;
  end if;

  select s.value into v_blueprint from public.settings s where s.key = 'mock_blueprint_sat';
  if not private.mock_blueprint_ok(v_blueprint) then
    raise exception 'internal';
  end if;

  insert into public.mock_templates (course_id, name, adaptive, blueprint)
  values (p_course_id, 'SAT Math', true, v_blueprint)
  on conflict (course_id) where adaptive do nothing
  returning id into v_id;

  if v_id is null then  -- lost a race with another session
    select t.id into v_id
    from public.mock_templates t
    where t.course_id = p_course_id and t.adaptive;
  end if;
  return v_id;
end;
$$;

revoke execute on function private.mock_blueprint_ok(jsonb) from public, anon, authenticated;
revoke execute on function private.mock_module_slots(jsonb, text) from public, anon, authenticated;
revoke execute on function private.mock_template_for(uuid) from public, anon, authenticated;

-- 5. Eligibility, shortage (private helpers) ----------------------------------------------------
-- A question is eligible for a template when it is published mock_reserve, its topic belongs to the
-- template's course, its skills resolve to exactly one domain that is a key of the template's
-- blueprint domains, and it sits in no mock_forms.question_ids of that template (draft or published).
create function private.mock_eligible(p_template_id uuid)
returns table (question_id uuid, domain text, difficulty public.difficulty, qtype public.question_type)
language sql
stable
security definer
set search_path = ''
as $$
  select q.id, d.domain, q.difficulty, q.type
  from public.mock_templates t
  join public.topics tp on tp.course_id = t.course_id
  join public.questions q on q.topic_id = tp.id
  join lateral (
    select min(s.domain) as domain, count(distinct s.domain) as n
    from public.question_skills qs
    join public.skills s on s.id = qs.skill_id
    where qs.question_id = q.id
  ) d on true
  where t.id = p_template_id
    and q.pool = 'mock_reserve' and q.status = 'published'
    and d.n = 1
    and (t.blueprint -> 'domains') ? d.domain
    and not exists (
      select 1 from public.mock_forms f
      where f.template_id = t.id and q.id = any (f.question_ids)
    );
$$;

-- Published mock_reserve questions of the course that fail only the single-domain rule.
create function private.mock_no_domain_count(p_template_id uuid)
returns int
language sql
stable
security definer
set search_path = ''
as $$
  select count(*)::int
  from public.mock_templates t
  join public.topics tp on tp.course_id = t.course_id
  join public.questions q on q.topic_id = tp.id
  where t.id = p_template_id
    and q.pool = 'mock_reserve' and q.status = 'published'
    and not exists (
      select 1
      from (select count(distinct s.domain) as n, min(s.domain) as domain
            from public.question_skills qs
            join public.skills s on s.id = qs.skill_id
            where qs.question_id = q.id) d
      where d.n = 1 and (t.blueprint -> 'domains') ? d.domain
    );
$$;

-- Cells where the bank cannot supply one more form: [{domain, difficulty, type, needed, available,
-- modules:{M1:n,...}}] ordered by domain, difficulty, type. '[]' when a form can be built.
create function private.mock_shortage(p_template_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  with bp as (
    select t.blueprint as b from public.mock_templates t where t.id = p_template_id
  ), need as (
    select s.domain, s.difficulty, s.qtype, m.module, count(*)::int as n
    from bp, unnest(array['M1', 'M2E', 'M2H']) as m(module),
         lateral private.mock_module_slots(bp.b, m.module) s
    group by 1, 2, 3, 4
  ), cell as (
    select domain, difficulty, qtype, sum(n)::int as needed, jsonb_object_agg(module, n) as modules
    from need group by 1, 2, 3
  ), avail as (
    select e.domain, e.difficulty, e.qtype, count(*)::int as c
    from private.mock_eligible(p_template_id) e group by 1, 2, 3
  )
  select coalesce(jsonb_agg(jsonb_build_object(
           'domain', c.domain, 'difficulty', c.difficulty::text, 'type', c.qtype::text,
           'needed', c.needed, 'available', coalesce(a.c, 0), 'modules', c.modules)
         order by c.domain collate "C", c.difficulty, c.qtype), '[]'::jsonb)
  from cell c
  left join avail a on a.domain = c.domain and a.difficulty = c.difficulty and a.qtype = c.qtype
  where coalesce(a.c, 0) < c.needed;
$$;

revoke execute on function private.mock_eligible(uuid) from public, anon, authenticated;
revoke execute on function private.mock_no_domain_count(uuid) from public, anon, authenticated;
revoke execute on function private.mock_shortage(uuid) from public, anon, authenticated;

-- 6. Teacher RPCs: assemble, overview, read ------------------------------------------------------
create function public.teacher_assemble_mock_form(p_course_id uuid, p_set_no int)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tpl     uuid;
  v_bp      jsonb;
  v_missing jsonb;
  v_form_no int;
begin
  if auth.uid() is null then
    raise exception 'not_authenticated';
  end if;
  if not public.is_teacher() then
    raise exception 'forbidden';
  end if;
  if p_course_id is null or p_set_no is null or p_set_no < 1 then
    raise exception 'invalid_input';
  end if;

  v_tpl := private.mock_template_for(p_course_id);

  -- Serialise assemblers per template (two-key advisory lock: fixed namespace + hash of the
  -- template id) so no question is picked twice and form_no stays unique. Held until commit.
  perform pg_advisory_xact_lock(hashtext('mock_assemble'), hashtext(v_tpl::text));

  select t.blueprint into v_bp from public.mock_templates t where t.id = v_tpl;
  if not private.mock_blueprint_ok(v_bp) then
    raise exception 'internal';
  end if;

  v_missing := private.mock_shortage(v_tpl);
  if jsonb_array_length(v_missing) > 0 then
    return jsonb_build_object('ok', false, 'missing', v_missing,
                              'no_domain', private.mock_no_domain_count(v_tpl));
  end if;

  select coalesce(max(f.form_no), 0) + 1 into v_form_no
  from public.mock_forms f where f.template_id = v_tpl and f.set_no = p_set_no;

  -- Per cell, take a random sample as large as the cell's need, then deal it to the cell's slots
  -- in (module, slot) order.
  insert into public.mock_forms (template_id, set_no, form_no, module, question_ids)
  select v_tpl, p_set_no, v_form_no, d.module, array_agg(d.question_id order by d.slot_no)
  from (
    select sl.module, sl.slot_no, pk.question_id
    from (
      select m.module, m.ord, s.slot_no, s.domain, s.difficulty, s.qtype,
             row_number() over (partition by s.domain, s.difficulty, s.qtype order by m.ord, s.slot_no) as rn
      from unnest(array['M1', 'M2E', 'M2H']) with ordinality as m(module, ord),
           lateral private.mock_module_slots(v_bp, m.module) s
    ) sl
    join (
      select e.question_id, e.domain, e.difficulty, e.qtype,
             row_number() over (partition by e.domain, e.difficulty, e.qtype order by random()) as rn
      from private.mock_eligible(v_tpl) e
    ) pk on pk.domain = sl.domain and pk.difficulty = sl.difficulty and pk.qtype = sl.qtype and pk.rn = sl.rn
  ) d
  group by d.module;

  return jsonb_build_object('ok', true, 'set_no', p_set_no, 'form_no', v_form_no);
end;
$$;

create function public.teacher_mock_overview(p_course_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tpl uuid;
  v_t   public.mock_templates;
begin
  if auth.uid() is null then
    raise exception 'not_authenticated';
  end if;
  if not public.is_teacher() then
    raise exception 'forbidden';
  end if;
  if p_course_id is null then
    raise exception 'invalid_input';
  end if;

  v_tpl := private.mock_template_for(p_course_id);
  select * into v_t from public.mock_templates t where t.id = v_tpl;

  return jsonb_build_object(
    'template', jsonb_build_object('id', v_t.id, 'name', v_t.name, 'blueprint', v_t.blueprint),
    'need_per_form', (
      select coalesce(jsonb_agg(jsonb_build_object(
               'domain', x.domain, 'difficulty', x.difficulty::text, 'type', x.qtype::text, 'count', x.n)
             order by x.domain collate "C", x.difficulty, x.qtype), '[]'::jsonb)
      from (
        select s.domain, s.difficulty, s.qtype, count(*)::int as n
        from unnest(array['M1', 'M2E', 'M2H']) as m(module),
             lateral private.mock_module_slots(v_t.blueprint, m.module) s
        group by 1, 2, 3
      ) x),
    'forms', (
      select coalesce(jsonb_agg(jsonb_build_object(
               'set_no', g.set_no, 'form_no', g.form_no, 'status', g.status, 'published_at', g.published_at)
             order by g.set_no, g.form_no), '[]'::jsonb)
      from (
        select f.set_no, f.form_no, min(f.status) as status, max(f.published_at) as published_at
        from public.mock_forms f where f.template_id = v_tpl
        group by f.set_no, f.form_no
      ) g),
    'next_form', jsonb_build_object(
      'missing', private.mock_shortage(v_tpl),
      'no_domain', private.mock_no_domain_count(v_tpl))
  );
end;
$$;

-- Read one form for preview. No key, explanation or choices (use teacher_get_question for those).
create function public.teacher_get_mock_form(p_course_id uuid, p_set_no int, p_form_no int)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tpl uuid;
  v_hdr record;
begin
  if auth.uid() is null then
    raise exception 'not_authenticated';
  end if;
  if not public.is_teacher() then
    raise exception 'forbidden';
  end if;
  if p_course_id is null or p_set_no is null or p_form_no is null then
    raise exception 'invalid_input';
  end if;

  v_tpl := private.mock_template_for(p_course_id);

  select min(f.status) as status, max(f.published_at) as published_at, count(*) as n
    into v_hdr
  from public.mock_forms f
  where f.template_id = v_tpl and f.set_no = p_set_no and f.form_no = p_form_no;
  if v_hdr.n = 0 then
    raise exception 'invalid_input';
  end if;

  return jsonb_build_object(
    'set_no', p_set_no, 'form_no', p_form_no,
    'status', v_hdr.status, 'published_at', v_hdr.published_at,
    'modules', (
      select jsonb_agg(jsonb_build_object('module', f.module, 'questions', (
        select jsonb_agg(jsonb_build_object(
                 'slot_no', u.slot_no, 'id', q.id, 'external_ref', q.external_ref,
                 'type', q.type::text, 'difficulty', q.difficulty::text,
                 'domain', (select min(s.domain) from public.question_skills qs
                            join public.skills s on s.id = qs.skill_id where qs.question_id = q.id),
                 'stem_md', q.stem_md)
               order by u.slot_no)
        from unnest(f.question_ids) with ordinality as u(qid, slot_no)
        join public.questions q on q.id = u.qid))
        order by case f.module when 'M1' then 1 when 'M2E' then 2 else 3 end)
      from public.mock_forms f
      where f.template_id = v_tpl and f.set_no = p_set_no and f.form_no = p_form_no)
  );
end;
$$;

revoke execute on function public.teacher_assemble_mock_form(uuid, int) from public, anon;
revoke execute on function public.teacher_mock_overview(uuid) from public, anon;
revoke execute on function public.teacher_get_mock_form(uuid, int, int) from public, anon;
grant execute on function public.teacher_assemble_mock_form(uuid, int) to authenticated;
grant execute on function public.teacher_mock_overview(uuid) to authenticated;
grant execute on function public.teacher_get_mock_form(uuid, int, int) to authenticated;

-- 7. Draft editing: swap candidates, swap, delete, publish ---------------------------------------
-- Error code mock_form_published (docs/07 section 9): swap, delete or publish on a published form.

-- Shared prologue of the form RPCs: validates ids, finds the template, takes the same advisory lock
-- as teacher_assemble_mock_form (so edits never interleave with an assemble), checks that the form
-- exists and, when p_draft_only, that it is still a draft. Returns the template id.
create function private.mock_form_lock(p_course_id uuid, p_set_no int, p_form_no int, p_draft_only boolean)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tpl    uuid;
  v_n      int;
  v_status text;
begin
  if p_course_id is null or p_set_no is null or p_form_no is null then
    raise exception 'invalid_input';
  end if;
  v_tpl := private.mock_template_for(p_course_id);
  perform pg_advisory_xact_lock(hashtext('mock_assemble'), hashtext(v_tpl::text));

  select count(*), min(f.status) into v_n, v_status
  from public.mock_forms f
  where f.template_id = v_tpl and f.set_no = p_set_no and f.form_no = p_form_no;
  if v_n = 0 then
    raise exception 'invalid_input';
  end if;
  if p_draft_only and v_status = 'published' then
    raise exception 'mock_form_published';
  end if;
  return v_tpl;
end;
$$;

-- The cell (domain, difficulty, type) a question currently fills for a template, or no row when it
-- is not usable: published mock_reserve, topic in the template's course, one domain that is a
-- blueprint key. Same rule as mock_eligible minus the "not used in a form" clause.
create function private.mock_question_cell(p_template_id uuid, p_question_id uuid)
returns table (domain text, difficulty public.difficulty, qtype public.question_type)
language sql
stable
security definer
set search_path = ''
as $$
  select d.domain, q.difficulty, q.type
  from public.mock_templates t
  join public.questions q on q.id = p_question_id
  join public.topics tp on tp.id = q.topic_id and tp.course_id = t.course_id
  join lateral (
    select min(s.domain) as domain, count(distinct s.domain) as n
    from public.question_skills qs
    join public.skills s on s.id = qs.skill_id
    where qs.question_id = q.id
  ) d on true
  where t.id = p_template_id
    and q.pool = 'mock_reserve' and q.status = 'published'
    and d.n = 1 and (t.blueprint -> 'domains') ? d.domain;
$$;

revoke execute on function private.mock_form_lock(uuid, int, int, boolean) from public, anon, authenticated;
revoke execute on function private.mock_question_cell(uuid, uuid) from public, anon, authenticated;

create function public.teacher_mock_swap_candidates(p_course_id uuid, p_set_no int, p_form_no int, p_question_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tpl  uuid;
  v_bp   jsonb;
  v_mod  text;
  v_pos  int;
  v_cell record;
begin
  if auth.uid() is null then
    raise exception 'not_authenticated';
  end if;
  if not public.is_teacher() then
    raise exception 'forbidden';
  end if;
  if p_question_id is null then
    raise exception 'invalid_input';
  end if;

  v_tpl := private.mock_form_lock(p_course_id, p_set_no, p_form_no, false);
  select t.blueprint into v_bp from public.mock_templates t where t.id = v_tpl;

  select f.module, array_position(f.question_ids, p_question_id) into v_mod, v_pos
  from public.mock_forms f
  where f.template_id = v_tpl and f.set_no = p_set_no and f.form_no = p_form_no
    and p_question_id = any (f.question_ids);
  if v_mod is null then
    raise exception 'invalid_input';
  end if;

  -- The slot's cell, not the question's current attributes (it may have been edited since).
  select s.domain, s.difficulty, s.qtype into v_cell
  from private.mock_module_slots(v_bp, v_mod) s where s.slot_no = v_pos;

  return (
    select coalesce(jsonb_agg(jsonb_build_object(
             'id', q.id, 'external_ref', q.external_ref, 'stem_md', q.stem_md)
           order by q.external_ref, q.id), '[]'::jsonb)
    from private.mock_eligible(v_tpl) e
    join public.questions q on q.id = e.question_id
    where e.domain = v_cell.domain and e.difficulty = v_cell.difficulty and e.qtype = v_cell.qtype
  );
end;
$$;

create function public.teacher_swap_mock_question(p_course_id uuid, p_set_no int, p_form_no int, p_old_id uuid, p_new_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tpl  uuid;
  v_bp   jsonb;
  v_row  uuid;
  v_mod  text;
  v_pos  int;
  v_cell record;
begin
  if auth.uid() is null then
    raise exception 'not_authenticated';
  end if;
  if not public.is_teacher() then
    raise exception 'forbidden';
  end if;
  if p_old_id is null or p_new_id is null then
    raise exception 'invalid_input';
  end if;

  v_tpl := private.mock_form_lock(p_course_id, p_set_no, p_form_no, true);
  select t.blueprint into v_bp from public.mock_templates t where t.id = v_tpl;

  select f.id, f.module, array_position(f.question_ids, p_old_id) into v_row, v_mod, v_pos
  from public.mock_forms f
  where f.template_id = v_tpl and f.set_no = p_set_no and f.form_no = p_form_no
    and p_old_id = any (f.question_ids);
  if v_row is null then
    raise exception 'invalid_input';
  end if;

  select s.domain, s.difficulty, s.qtype into v_cell
  from private.mock_module_slots(v_bp, v_mod) s where s.slot_no = v_pos;

  -- Eligible already excludes questions used in any form of the template, this one included.
  if not exists (
    select 1 from private.mock_eligible(v_tpl) e
    where e.question_id = p_new_id
      and e.domain = v_cell.domain and e.difficulty = v_cell.difficulty and e.qtype = v_cell.qtype
  ) then
    raise exception 'invalid_input';
  end if;

  update public.mock_forms f
  set question_ids = f.question_ids[1 : v_pos - 1] || p_new_id || f.question_ids[v_pos + 1 : array_length(f.question_ids, 1)]
  where f.id = v_row;

  return jsonb_build_object('ok', true);
end;
$$;

create function public.teacher_delete_mock_draft(p_course_id uuid, p_set_no int, p_form_no int)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tpl uuid;
begin
  if auth.uid() is null then
    raise exception 'not_authenticated';
  end if;
  if not public.is_teacher() then
    raise exception 'forbidden';
  end if;

  v_tpl := private.mock_form_lock(p_course_id, p_set_no, p_form_no, true);

  delete from public.mock_forms f
  where f.template_id = v_tpl and f.set_no = p_set_no and f.form_no = p_form_no;

  return jsonb_build_object('ok', true);
end;
$$;

create function public.teacher_publish_mock_form(p_course_id uuid, p_set_no int, p_form_no int)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tpl   uuid;
  v_bp    jsonb;
  v_stale uuid[];
begin
  if auth.uid() is null then
    raise exception 'not_authenticated';
  end if;
  if not public.is_teacher() then
    raise exception 'forbidden';
  end if;

  v_tpl := private.mock_form_lock(p_course_id, p_set_no, p_form_no, true);
  select t.blueprint into v_bp from public.mock_templates t where t.id = v_tpl;

  -- Every question must still fill its slot's cell and satisfy the eligibility rule.
  select array_agg(x.qid order by x.ord, x.slot) into v_stale
  from (
    select u.qid, u.slot, case f.module when 'M1' then 1 when 'M2E' then 2 else 3 end as ord,
           f.module, s.domain, s.difficulty, s.qtype
    from public.mock_forms f
    cross join lateral unnest(f.question_ids) with ordinality as u(qid, slot)
    join lateral private.mock_module_slots(v_bp, f.module) s on s.slot_no = u.slot
    where f.template_id = v_tpl and f.set_no = p_set_no and f.form_no = p_form_no
  ) x
  where not exists (
    select 1 from private.mock_question_cell(v_tpl, x.qid) c
    where c.domain = x.domain and c.difficulty = x.difficulty and c.qtype = x.qtype
  );

  if v_stale is not null then
    return jsonb_build_object('ok', false, 'stale', to_jsonb(v_stale));
  end if;

  update public.mock_forms f
  set status = 'published', published_at = now()
  where f.template_id = v_tpl and f.set_no = p_set_no and f.form_no = p_form_no;

  return jsonb_build_object('ok', true);
end;
$$;

revoke execute on function public.teacher_mock_swap_candidates(uuid, int, int, uuid) from public, anon;
revoke execute on function public.teacher_swap_mock_question(uuid, int, int, uuid, uuid) from public, anon;
revoke execute on function public.teacher_delete_mock_draft(uuid, int, int) from public, anon;
revoke execute on function public.teacher_publish_mock_form(uuid, int, int) from public, anon;
grant execute on function public.teacher_mock_swap_candidates(uuid, int, int, uuid) to authenticated;
grant execute on function public.teacher_swap_mock_question(uuid, int, int, uuid, uuid) to authenticated;
grant execute on function public.teacher_delete_mock_draft(uuid, int, int) to authenticated;
grant execute on function public.teacher_publish_mock_form(uuid, int, int) to authenticated;
