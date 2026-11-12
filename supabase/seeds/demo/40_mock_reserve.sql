-- P1 demo seed 40: mock_reserve bank - one SAT mock form plus one spare per cell (85 questions).
--
-- STAGING AND LOCAL ONLY. NEVER RUN AGAINST PROD. Requires 00_structure.sql (course, topic,
-- subtopic, private.demo_upsert_question) and the MCK-03 migration (settings key
-- mock_blueprint_sat, private.mock_module_slots).
-- Original, parameterised English content; idempotent (every question is upserted by a fixed id).
--
-- The cells come from the blueprint slots (private.mock_module_slots over the mock_blueprint_sat
-- setting), so the seed always stocks exactly one form's need per (domain, difficulty, type) cell
-- plus one spare. Per domain a counter k numbers the questions; the parameters are derived from k
-- and are distinct for every k used here, so no two stems repeat.
--
-- Skills: four demo skills, one per blueprint domain (exact domain strings, docs/09 s4).
-- Question ids 00000000-0000-4000-8de0-00000004DKKK: D = domain 1-4 (Algebra, Advanced Math,
-- PSDA, Geometry & Trig), KKK = counter k. external_ref DEMO-MOCK-<ALG|ADV|PSD|GEO>-<KKK>.
-- Pool mock_reserve, all attached to demo topic 1 (the mock ignores topics). source is 'demo-mock'
-- so the structure checks on source 'demo' (72 practice/quiz questions) stay untouched.

set client_min_messages = warning;

insert into public.skills (id, code, name, domain, course_scope)
values
  ('00000000-0000-4000-8de0-000000000041', 'DEMO.MOCK.ALG', 'Mock: Algebra',         'Algebra',         '{SAT}'),
  ('00000000-0000-4000-8de0-000000000042', 'DEMO.MOCK.ADV', 'Mock: Advanced Math',   'Advanced Math',   '{SAT}'),
  ('00000000-0000-4000-8de0-000000000043', 'DEMO.MOCK.PSD', 'Mock: PSDA',            'PSDA',            '{SAT}'),
  ('00000000-0000-4000-8de0-000000000044', 'DEMO.MOCK.GEO', 'Mock: Geometry & Trig', 'Geometry & Trig', '{SAT}')
on conflict (id) do update set
  code         = excluded.code,
  name         = excluded.name,
  domain       = excluded.domain,
  course_scope = excluded.course_scope;

do $do$
declare
  v_topic    constant uuid := '00000000-0000-4000-8de0-000000000011';
  v_subtopic constant uuid := '00000000-0000-4000-8de0-000000000021';
  v_bp       jsonb;
  r          record;
  j          int;
  k          int;
  cnt        int[] := array[0, 0, 0, 0];
  dom_no     int;
  codes      constant text[] := array['ALG', 'ADV', 'PSD', 'GEO'];
  a int; b int; c int; d int; m int; p int; q int; x0 int; rt int; tt int; n int; len int; wid int;
  stem       text;
  expl       text;
  correct    int;
  vals       int[];
  i          int;
  x          int;
  pos        int;
  nextd      int;
  choices    jsonb;
  key        jsonb;
  v_id       uuid;
  v_ref      text;
begin
  select s.value into v_bp from public.settings s where s.key = 'mock_blueprint_sat';
  if not private.mock_blueprint_ok(v_bp) then
    raise exception 'demo mock seed: mock_blueprint_sat is missing or invalid';
  end if;

  for r in
    select s.domain, s.difficulty, s.qtype, count(*)::int + 1 as n   -- one form + one spare
    from unnest(array['M1', 'M2E', 'M2H']) as mm(module),
         lateral private.mock_module_slots(v_bp, mm.module) s
    group by 1, 2, 3
    order by s.domain collate "C", s.difficulty, s.qtype
  loop
    dom_no := case r.domain
                when 'Algebra' then 1 when 'Advanced Math' then 2
                when 'PSDA' then 3 when 'Geometry & Trig' then 4 end;
    if dom_no is null then
      raise exception 'demo mock seed: no templates for blueprint domain %', r.domain;
    end if;

    for j in 1 .. r.n loop
      cnt[dom_no] := cnt[dom_no] + 1;
      k := cnt[dom_no];

      if r.qtype = 'mcq' then
        if dom_no = 1 then
          a := 2 + (k % 7); x0 := 3 + (k % 11); b := 1 + (k % 13); c := a * x0 + b;
          stem := format('If \(%s x + %s = %s\), what is the value of \(x\)?', a, b, c);
          correct := x0; vals := array[x0, x0 + 1, x0 - 1, x0 + 2];
          expl := format('Subtract %s from both sides: \(%s x = %s\).' || E'\n\n' ||
                         'Divide both sides by %s: \(x = %s\).', b, a, c - b, a, x0);
        elsif dom_no = 2 then
          rt := 1 + (k % 6); tt := rt + 1 + (k % 7);
          stem := format('The equation \(x^2 - %s x + %s = 0\) has two positive solutions. What is the larger solution?',
                         rt + tt, rt * tt);
          correct := tt; vals := array[tt, rt, rt + tt, rt + tt + 1];
          expl := format('Factor the quadratic: \((x - %s)(x - %s) = 0\).' || E'\n\n' ||
                         'The solutions are \(%s\) and \(%s\), so the larger one is \(%s\).', rt, tt, rt, tt, tt);
        elsif dom_no = 3 then
          n := 4 + k; m := 10 + 2 * k;
          stem := format('A data set of %s values has a mean of %s. What is the sum of all the values in the data set?', n, m);
          correct := n * m; vals := array[n * m, n + m, m, n * m + n];
          expl := format('The mean is the sum divided by the number of values, so the sum is the mean times the count.' ||
                         E'\n\n' || '\(%s \times %s = %s\).', m, n, n * m);
        else
          len := 4 + k; wid := 2 + (k % 5);
          stem := format('A rectangle has a length of %s units and a width of %s units. What is its perimeter, in units?', len, wid);
          correct := 2 * (len + wid); vals := array[2 * (len + wid), len * wid, len + wid, 2 * len + wid];
          expl := format('The perimeter is twice the sum of the length and the width.' || E'\n\n' ||
                         '\(2(%s + %s) = %s\).', len, wid, 2 * (len + wid));
        end if;

        -- Make the four values distinct without ever moving the correct one (index 1).
        for i in 2 .. 4 loop
          while vals[i] = any (vals[1 : i - 1]) loop
            vals[i] := vals[i] + 1;
          end loop;
        end loop;

        pos := k % 4;                       -- index (0-3) of the correct letter: it varies with k
        nextd := 2;
        choices := '{}'::jsonb;
        for i in 0 .. 3 loop
          if i = pos then
            x := vals[1];
          else
            x := vals[nextd];
            nextd := nextd + 1;
          end if;
          choices := choices || jsonb_build_object(chr(65 + i), '\(' || x || '\)');
        end loop;
        key := jsonb_build_object('choice', chr(65 + pos));
      else
        if dom_no = 1 then
          a := 2 + (k % 6); m := 2 + (k % 7); d := 1 + (k % 5);
          stem := format('If \(%s(x - %s) = %s\), what is the value of \(x\)?', a, d, a * m);
          correct := m + d;
          expl := format('Divide both sides by %s: \(x - %s = %s\).' || E'\n\n' ||
                         'Add %s to both sides: \(x = %s\).', a, d, m, d, m + d);
        elsif dom_no = 2 then
          a := 2 + (k % 4); b := 1 + (k % 5); c := 2 + (k % 7);
          stem := format('If \(f(x) = %s x^2 + %s\), what is the value of \(f(%s)\)?', a, b, c);
          correct := a * c * c + b;
          expl := format('Substitute \(x = %s\): \(f(%s) = %s(%s)^2 + %s = %s\).', c, c, a, c, b, correct);
        elsif dom_no = 3 then
          a := 1 + (k % 9); b := 1 + (k % 7); p := 5 * a; q := 20 * b;
          stem := format('What is \(%s\%%\) of \(%s\)?', p, q);
          correct := a * b;
          expl := format('\(%s\%%\) of \(%s\) is \(\frac{%s}{100} \times %s = %s\).', p, q, p, q, correct);
        else
          d := 2 * (2 + k); m := 3 + (k % 4);
          stem := format('A triangle has a base of %s units and a height of %s units. What is its area, in square units?', d, m);
          correct := (d / 2) * m;
          expl := format('The area is half the base times the height: \(\frac{1}{2} \times %s \times %s = %s\).', d, m, correct);
        end if;
        choices := null;
        key := jsonb_build_object('accepted', jsonb_build_array(correct::text), 'tolerance', 0);
      end if;

      v_id := ('00000000-0000-4000-8de0-00000004' || lpad((dom_no * 100 + k)::text, 4, '0'))::uuid;
      v_ref := 'DEMO-MOCK-' || codes[dom_no] || '-' || lpad(k::text, 3, '0');

      perform private.demo_upsert_question(
        v_id, v_topic, v_subtopic, 'mock_reserve', r.qtype, r.difficulty,
        stem, null, choices, key, expl, '{}'::jsonb,
        array['DEMO.MOCK.' || codes[dom_no]]);

      -- The helper stamps external_ref 'demo-<id>' and source 'demo'; mock questions use their own.
      update public.questions
         set external_ref = v_ref, source = 'demo-mock'
       where id = v_id;
    end loop;
  end loop;
end;
$do$;
