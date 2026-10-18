-- PAY-06 / PAY-07: activation-code enrollment. From templates/rpc.sql + setting.sql.
insert into public.settings (key, value) values
  ('access_grace_days', '14'::jsonb),
  ('access_min_days', '60'::jsonb),
  ('test_date_max_days', '548'::jsonb),
  ('rate_redeem_per_min', '5'::jsonb)
on conflict (key) do nothing;

create or replace function public.redeem_activation_code(
  p_code text,
  p_target_test_date date
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_code text;
  v_activation public.activation_codes%rowtype;
  v_course public.courses%rowtype;
  v_enrollment_id uuid;
  v_expires_at timestamptz;
begin
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;
  perform private.hit_rate_limit('redeem:' || v_uid,
    private.setting_int('rate_redeem_per_min'), 60);

  v_code := upper(translate(btrim(p_code), '- ', ''));
  if v_code is null or v_code = '' or p_target_test_date is null
     or p_target_test_date < current_date - 1
     or p_target_test_date > current_date + private.setting_int('test_date_max_days') then
    raise exception 'invalid_input';
  end if;

  select a.* into v_activation
  from public.activation_codes a
  where a.code = v_code
  for update;
  if not found then
    -- Raising would roll back the quota increment, allowing unlimited wrong guesses.
    return jsonb_build_object('ok', false, 'error', 'code_invalid');
  end if;
  select c.* into v_course from public.courses c
  where c.id = v_activation.course_id and c.is_published;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'code_invalid');
  end if;
  if v_activation.redeemed_by is not null or v_activation.redeemed_at is not null then
    return jsonb_build_object('ok', false, 'error', 'code_used');
  end if;

  v_expires_at := greatest(
    (p_target_test_date + private.setting_int('access_grace_days') + 1)::timestamp
      at time zone 'UTC',
    now() + make_interval(days => private.setting_int('access_min_days'))
  );
  -- The unique constraint also handles concurrent use of DIFFERENT codes for one course.
  -- No exception block: a duplicate must retain its rate-limit increment too.
  insert into public.enrollments
    (user_id, course_id, activation_code_id, status, target_test_date, starts_at, expires_at)
  values
    (v_uid, v_course.id, v_activation.id, 'active', p_target_test_date, now(), v_expires_at)
  on conflict (user_id, course_id) do nothing
  returning id into v_enrollment_id;
  if v_enrollment_id is null then
    return jsonb_build_object('ok', false, 'error', 'already_enrolled');
  end if;

  update public.activation_codes
  set redeemed_by = v_uid, redeemed_at = now()
  where id = v_activation.id;

  return jsonb_build_object(
    'ok', true, 'course_id', v_course.id, 'course_slug', v_course.slug,
    'course_title', v_course.title, 'target_test_date', p_target_test_date,
    'expires_at', v_expires_at
  );
end;
$$;
revoke execute on function public.redeem_activation_code(text, date) from public, anon;
grant execute on function public.redeem_activation_code(text, date) to authenticated;

-- SQL-editor administration only; no teacher or service-role API endpoint.
create or replace function private.generate_activation_codes(
  p_course_id uuid,
  p_count int,
  p_note text
)
returns setof text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_alphabet constant text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  v_code text;
  v_byte int;
  v_created int := 0;
  v_inserted int;
begin
  -- This helper has no caller identity: only the migration owner can execute it.
  if p_course_id is null or p_count is null or p_count < 1
     or not exists (select 1 from public.courses c where c.id = p_course_id) then
    raise exception 'invalid_input';
  end if;

  while v_created < p_count loop
    v_code := '';
    while length(v_code) < 12 loop
      -- UUID v4's first byte is cryptographically random (no version/variant bits).
      -- Rejection sampling avoids modulo bias without another extension dependency.
      v_byte := get_byte(decode(replace(gen_random_uuid()::text, '-', ''), 'hex'), 0);
      if v_byte < (256 / length(v_alphabet)) * length(v_alphabet) then
        v_code := v_code || substr(v_alphabet, (v_byte % length(v_alphabet)) + 1, 1);
      end if;
    end loop;
    insert into public.activation_codes (code, course_id, created_by, note)
    values (v_code, p_course_id, null, p_note)
    on conflict (code) do nothing;
    get diagnostics v_inserted = row_count;
    if v_inserted = 1 then
      v_created := v_created + 1;
      return next v_code;
    end if;
  end loop;
  return;
end;
$$;
revoke execute on function private.generate_activation_codes(uuid, int, text)
  from public, anon, authenticated, service_role;
