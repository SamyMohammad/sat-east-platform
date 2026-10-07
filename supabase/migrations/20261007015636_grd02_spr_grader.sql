-- GRD-02 (docs/08 §6): SPR parsing and grading. Internal: called by security-definer RPCs
-- (check_practice_answer, submit_attempt); no grants. Mirror: apps/client lib/core/grading/spr_answer.dart.

-- Parse an SPR answer into a reduced rational {numerator, denominator}; null when invalid.
-- p_enforce_length = false parses key values, which are not length-limited.
create function private.spr_parse(p_answer text, p_enforce_length boolean default true)
returns numeric[]
language plpgsql
immutable
set search_path = ''
as $$
declare
  s text := btrim(p_answer);
  m text[];
  n numeric;
  d numeric;
  g numeric;
  max_len int := 5;
begin
  if s is null or s = '' then
    return null;
  end if;
  if left(s, 1) = '-' then
    max_len := 6;  -- the minus sign counts
  end if;
  if p_enforce_length and length(s) > max_len then
    return null;
  end if;

  m := regexp_match(s, '^(-?)([0-9]+)/([0-9]+)$');
  if m is not null then
    n := m[2]::numeric;
    d := m[3]::numeric;
    if d = 0 then
      return null;
    end if;
  else
    m := regexp_match(s, '^(-?)([0-9]*)(?:\.([0-9]*))?$');
    if m is null or (m[2] = '' and coalesce(m[3], '') = '') then
      return null;
    end if;
    n := (coalesce(nullif(m[2], ''), '0') || coalesce(m[3], ''))::numeric;
    d := power(10::numeric, length(coalesce(m[3], '')));
  end if;

  if m[1] = '-' then
    n := -n;
  end if;
  g := gcd(n, d);
  return array[n / g, d / g];
end;
$$;

-- Grade an SPR answer against a key {"accepted": [...], "tolerance": t?}.
create function private.grade_spr(p_answer text, p_key jsonb)
returns boolean
language plpgsql
immutable
set search_path = ''
as $$
declare
  s text := btrim(p_answer);
  v numeric[] := private.spr_parse(p_answer);
  t numeric;
  fills boolean;
  dp int;
  scale numeric;
  sv numeric;
  k_text text;
  k numeric[];
  q numeric;
  max_len int := 5;
begin
  -- A malformed key is a content error: fail loudly, never grade it as wrong.
  -- (No CASE expressions in function bodies: the CLI's migration splitter mis-parses CASE ... END.)
  if jsonb_typeof(p_key -> 'accepted') is distinct from 'array' then
    raise exception 'invalid_key';
  end if;
  if jsonb_array_length(p_key -> 'accepted') = 0
     or (p_key ? 'tolerance' and jsonb_typeof(p_key -> 'tolerance') <> 'number') then
    raise exception 'invalid_key';
  end if;
  if v is null then
    return false;
  end if;

  t := coalesce((p_key ->> 'tolerance')::numeric, 0);

  -- Fill rule applies only to a decimal answer of exactly the maximum length.
  if left(s, 1) = '-' then
    max_len := 6;
  end if;
  fills := position('.' in s) > 0 and length(s) = max_len;
  dp := length(s) - position('.' in s);
  scale := power(10::numeric, dp);
  sv := v[1] * scale / v[2];  -- exact: a decimal with dp places times 10^dp is an integer

  for k_text in select jsonb_array_elements_text(p_key -> 'accepted') loop
    k := private.spr_parse(k_text, false);
    if k is null then
      raise exception 'invalid_key';
    end if;

    if v[1] * k[2] = k[1] * v[2] then
      return true;
    end if;
    if t > 0 and abs(v[1] / v[2] - k[1] / k[2]) <= t then
      return true;
    end if;
    if fills and dp > 0 then
      q := sign(k[1]) * div(abs(k[1]) * scale, k[2]);                    -- truncated
      if sv = q then
        return true;
      end if;
      q := sign(k[1]) * div(2 * abs(k[1]) * scale + k[2], 2 * k[2]);     -- rounded half away from zero
      if sv = q then
        return true;
      end if;
    end if;
  end loop;

  return false;
end;
$$;
