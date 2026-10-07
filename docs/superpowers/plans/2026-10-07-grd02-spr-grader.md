# F-2 row 4 — SPR grader (GRD-02) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A server-side SPR grader (`private.grade_spr`) and a Dart input parser (`parseSprAnswer`) that agree on every case in one shared fixture.

**Architecture:** One fixture `supabase/tests/fixtures/spr_cases.json` drives both sides. SQL: `private.spr_parse` (exact rational parse) + `private.grade_spr` (equality, tolerance, fill rule) in one migration; pgTAP test embeds the fixture JSON verbatim. Dart: pure `lib/core/grading/spr_answer.dart` (validation + rational value for the Answer Preview, never grades); its test reads the fixture file and also asserts the SQL test's embedded copy equals it (drift guard).

**Tech Stack:** Postgres 17 / pgTAP; Dart 3 (sealed classes, `BigInt`), `flutter_test`.

**Spec:** written in Task 0 to `docs/superpowers/specs/2026-10-07-grd02-spr-grader-design.md` (plan mode blocked writing it during brainstorm; its content is the "Design" section below, approved in chat 2026-10-07).

## Context
Row 4 of `docs/15` §1. SPR answers are graded only on the server (rule 1, GRD-03); the client needs the same input rules to block invalid typing and show the Answer Preview (`docs/08` §5). One fixture keeps them from drifting. Brainstorm decisions approved 2026-10-07.

## Design (approved; becomes the spec + `docs/08` §6 text)
1. **Accepted forms:** integer `12`; decimal `1.5`, `.5`, `5.`; fraction `a/b` (integers, `b ≠ 0`); optional single leading `-`. Rejected: inner spaces, letters, `%`, `$`, `,`, `+`, mixed numbers (`3 1/2`), decimals in fractions (`1.5/2`). Only outer ASCII spaces are trimmed (tab, newline, NBSP make the input invalid on both sides).
2. **Length:** ≤ 5 characters, ≤ 6 when it starts with `-`; `.`, `/`, `-` count.
3. **Fill rule:** if the value is not exactly a key, it is still correct when the answer is a decimal of exactly the maximum length and equals the key truncated or rounded (half away from zero) to that many decimal places. `2/3` → `.6666`, `.6667`, `0.666`, `0.667` correct; `.67`, `0.66`, `.666` incorrect.
4. **Exact maths:** values are reduced rationals (`numeric` pairs in SQL, `BigInt` in Dart); tolerance compares `|v − k| ≤ t`.
5. **Key:** `{"accepted": ["1/2", ...], "tolerance": t?}` (`docs/06`); any accepted value matches. A key value that does not parse raises `invalid_key` (new `docs/07` §9 code) instead of silently failing.
6. **Placement:** SQL in `private` (called by future definer RPCs; no grants). Dart in `lib/core/grading/` (pure Dart, shared by practice/homework/quiz/mock). Dart never sees keys.
7. **Fixture:** `[{input, key, expected: correct|incorrect|invalid}]`; covers `docs/08` §6 + `docs/12` §2 plus edge cases.
8. **Fixture in SQL:** embedded in the pgTAP file between `$json$` delimiters (pg_prove cannot read repo files reliably); the Dart test fails if the embedded copy differs from the file.

## Global Constraints
- SQL follows `supabase/templates/` + README checklist; functions `immutable`, `set search_path = ''`, no `security definer` (pure), no grants.
- Dart: no `package:flutter` in `lib/core/grading/` (pure logic); sealed class + exhaustive switch; `very_good_analysis`, `flutter analyze --fatal-infos` clean; `dart format`.
- Test names start with `GRD-02:`. `*_test.dart` files are written by the `test-writer` agent (CLAUDE.md A.9) with the exact content below.
- Commits end with a blank line + `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Branch `feat/GRD-02-spr-grader` from `main`.

## Review Focus
1. Negative answers at full length (`-.6666`, `-10000`) → valid; fill rule rounds half away from zero for negatives.
2. A key longer than 5 characters (`3.14159`) → parses (length limit is for students only).
3. `0`, `-0`, `5.` → valid and equal to their integer keys.
4. Dart and SQL disagree on any fixture input's validity → Dart test fails.
5. A malformed key (bad value, no `accepted`, non-numeric `tolerance`) → `invalid_key`, not a silent `false`.
6. Input with tab/newline/NBSP → invalid on both sides (fixture rows pin it).

---

### Task 0: Branch, docs, spec

**Files:** `docs/08-exam-engine-spec.md` §6, `docs/07-backend-logic-and-api.md` §9, `docs/superpowers/specs/2026-10-07-grd02-spr-grader-design.md`, `docs/superpowers/plans/2026-10-07-grd02-spr-grader.md`

- [ ] **Step 1:** `git switch -c feat/GRD-02-spr-grader main`
- [ ] **Step 2:** In `docs/08` §6, after the grader algorithm block, add:

```markdown
Precise rules (row 4, 2026-10-07):
- Forms: integer, decimal (`1.5`, `.5`, `5.`), fraction `a/b` of integers with `b ≠ 0`; one optional
  leading `-`. Rejected: inner spaces, letters, `%`, `$`, `,`, `+`, mixed numbers, `1.5/2`.
- Fill rule: when the value is not exactly a key, it is correct only if the answer is a decimal of
  exactly the maximum length (5, or 6 with `-`) and equals the key truncated or rounded half away
  from zero at that many decimal places (`.666` for 2/3 is incorrect: 4 characters).
- Values are exact rationals; tolerance is `|v − k| ≤ t`. Key values are not length-limited.
- A key value that cannot be parsed, or a key without an `accepted` array, raises `invalid_key`.
- Authoring rule: a non-terminating answer must be keyed as the exact fraction (`2/3`, not
  `0.6667`); a rounded key makes correct answers like `.6666` grade wrong.
- Only outer ASCII spaces are trimmed; tab, newline or NBSP make the input invalid.
- Implementations: `private.grade_spr` / `private.spr_parse` (server, grades) and
  `lib/core/grading/spr_answer.dart` (client, validation + Answer Preview only). Shared cases:
  `supabase/tests/fixtures/spr_cases.json`.
```

- [ ] **Step 3:** In `docs/07` §9 add `` `invalid_key` (malformed answer key — content error) `` before `` `internal` ``.
- [ ] **Step 4:** Write the spec file: header `# GRD-02 — SPR grader (design)`, then the Context and Design sections of this plan verbatim, then `## Testing` = "fixture-driven pgTAP + Dart tests; drift guard".
- [ ] **Step 5:** Copy this plan to `docs/superpowers/plans/2026-10-07-grd02-spr-grader.md`; commit all four files: `docs(GRD-02): SPR grading rules, invalid_key code, design and plan`.

---

### Task 1: Fixture + SQL grader

**Files:**
- Create: `supabase/tests/fixtures/spr_cases.json`, `supabase/tests/12_spr_grader.test.sql`
- Create: `supabase/migrations/<ts>_grd02_spr_grader.sql` (`supabase migration new grd02_spr_grader < /dev/null`)

**Interfaces:**
- Produces: `private.spr_parse(p_answer text, p_enforce_length boolean default true) returns numeric[]` (`{num, den}` reduced, den > 0; `null` = invalid); `private.grade_spr(p_answer text, p_key jsonb) returns boolean`.

- [ ] **Step 1: Write `supabase/tests/fixtures/spr_cases.json`**

```json
[
  {"input": "1/2",    "key": {"accepted": ["0.5"]},  "expected": "correct"},
  {"input": ".5",     "key": {"accepted": ["1/2"]},  "expected": "correct"},
  {"input": "0.5",    "key": {"accepted": ["1/2"]},  "expected": "correct"},
  {"input": "2/4",    "key": {"accepted": ["1/2"]},  "expected": "correct"},
  {"input": " 1/2 ",  "key": {"accepted": ["0.5"]},  "expected": "correct"},
  {"input": "-3/4",   "key": {"accepted": ["-0.75"]}, "expected": "correct"},
  {"input": "-.75",   "key": {"accepted": ["-0.75"]}, "expected": "correct"},
  {"input": ".6666",  "key": {"accepted": ["2/3"]},  "expected": "correct"},
  {"input": ".6667",  "key": {"accepted": ["2/3"]},  "expected": "correct"},
  {"input": "0.666",  "key": {"accepted": ["2/3"]},  "expected": "correct"},
  {"input": "0.667",  "key": {"accepted": ["2/3"]},  "expected": "correct"},
  {"input": ".666",   "key": {"accepted": ["2/3"]},  "expected": "incorrect"},
  {"input": ".67",    "key": {"accepted": ["2/3"]},  "expected": "incorrect"},
  {"input": "0.66",   "key": {"accepted": ["2/3"]},  "expected": "incorrect"},
  {"input": ".6668",  "key": {"accepted": ["2/3"]},  "expected": "incorrect"},
  {"input": "-.6666", "key": {"accepted": ["-2/3"]}, "expected": "correct"},
  {"input": "-.6667", "key": {"accepted": ["-2/3"]}, "expected": "correct"},
  {"input": "-0.66",  "key": {"accepted": ["-2/3"]}, "expected": "incorrect"},
  {"input": "7/2",    "key": {"accepted": ["7/2"]},  "expected": "correct"},
  {"input": "3.5",    "key": {"accepted": ["7/2"]},  "expected": "correct"},
  {"input": "3 1/2",  "key": {"accepted": ["7/2"]},  "expected": "invalid"},
  {"input": "10000",  "key": {"accepted": ["10000"]}, "expected": "correct"},
  {"input": "100000", "key": {"accepted": ["100000"]}, "expected": "invalid"},
  {"input": "-10000", "key": {"accepted": ["-10000"]}, "expected": "correct"},
  {"input": "5.",     "key": {"accepted": ["5"]},    "expected": "correct"},
  {"input": "0",      "key": {"accepted": ["0"]},    "expected": "correct"},
  {"input": "-0",     "key": {"accepted": ["0"]},    "expected": "correct"},
  {"input": "2",      "key": {"accepted": ["2", "-5"]}, "expected": "correct"},
  {"input": "-5",     "key": {"accepted": ["2", "-5"]}, "expected": "correct"},
  {"input": "3",      "key": {"accepted": ["2", "-5"]}, "expected": "incorrect"},
  {"input": "3.14",   "key": {"accepted": ["3.14159"], "tolerance": 0.01}, "expected": "correct"},
  {"input": "3.2",    "key": {"accepted": ["3.14159"], "tolerance": 0.01}, "expected": "incorrect"},
  {"input": "1/0",    "key": {"accepted": ["1"]},    "expected": "invalid"},
  {"input": "+5",     "key": {"accepted": ["5"]},    "expected": "invalid"},
  {"input": "5%",     "key": {"accepted": ["5"]},    "expected": "invalid"},
  {"input": "$5",     "key": {"accepted": ["5"]},    "expected": "invalid"},
  {"input": "1,000",  "key": {"accepted": ["1000"]}, "expected": "invalid"},
  {"input": "1.5/2",  "key": {"accepted": ["0.75"]}, "expected": "invalid"},
  {"input": "1/2/3",  "key": {"accepted": ["1"]},    "expected": "invalid"},
  {"input": "--5",    "key": {"accepted": ["5"]},    "expected": "invalid"},
  {"input": ".",      "key": {"accepted": ["0"]},    "expected": "invalid"},
  {"input": "-",      "key": {"accepted": ["0"]},    "expected": "invalid"},
  {"input": "abc",    "key": {"accepted": ["1"]},    "expected": "invalid"},
  {"input": "",       "key": {"accepted": ["1"]},    "expected": "invalid"},
  {"input": "\t1/2",  "key": {"accepted": ["0.5"]},  "expected": "invalid"},
  {"input": "1/2\u00a0", "key": {"accepted": ["0.5"]}, "expected": "invalid"},
  {"input": ".6666",  "key": {"accepted": ["0.6667"]}, "expected": "incorrect"}
]
```

- [ ] **Step 2: Write `supabase/tests/12_spr_grader.test.sql`** — build it so the JSON block is the fixture file byte-for-byte:

```bash
F=supabase/tests/12_spr_grader.test.sql
{
cat <<'SQL'
-- GRD-02 — docs/08 §6: SPR grading. Cases are supabase/tests/fixtures/spr_cases.json, embedded
-- verbatim in the dollar-quoted literal below (the Dart test fails if this copy drifts from the file;
-- it splits on that delimiter, so do not write the delimiter anywhere else in this file).
begin;
create extension if not exists pgtap with schema extensions;

create temp table spr_cases on commit drop as
select c from jsonb_array_elements($json$
SQL
cat supabase/tests/fixtures/spr_cases.json
cat <<'SQL'
$json$::jsonb) as c;

select plan((select count(*)::int * 2 + 3 from spr_cases));

select is(private.spr_parse(c ->> 'input') is null, c ->> 'expected' = 'invalid',
          format('GRD-02: %L validity', c ->> 'input'))
from spr_cases;

select is(private.grade_spr(c ->> 'input', c -> 'key'), c ->> 'expected' = 'correct',
          format('GRD-02: %L vs %s is %s', c ->> 'input', c -> 'key', c ->> 'expected'))
from spr_cases;

select throws_ok($$ select private.grade_spr('1', '{"accepted": ["abc"]}') $$, 'P0001', 'invalid_key',
                 'GRD-02: a malformed key value raises invalid_key');
select throws_ok($$ select private.grade_spr('1', '{"choice": "B"}') $$, 'P0001', 'invalid_key',
                 'GRD-02: a key without accepted values raises invalid_key');

select is(private.spr_parse('3.14159', false), array[314159, 100000]::numeric[],
          'GRD-02: key values are not length-limited');

select * from finish();
rollback;
SQL
} > "$F"
```

- [ ] **Step 3: Run — expect failure.** `supabase test db < /dev/null` → `12` errors: `function private.spr_parse(text) does not exist`.

- [ ] **Step 4: Write the migration**

```sql
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
begin
  if s is null or s = '' then
    return null;
  end if;
  if p_enforce_length and length(s) > case when left(s, 1) = '-' then 6 else 5 end then
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
begin
  -- A malformed key is a content error: fail loudly, never grade it as wrong.
  if case when jsonb_typeof(p_key -> 'accepted') = 'array'
          then jsonb_array_length(p_key -> 'accepted') = 0
          else true end
     or (p_key ? 'tolerance' and jsonb_typeof(p_key -> 'tolerance') <> 'number') then
    raise exception 'invalid_key';
  end if;
  if v is null then
    return false;
  end if;

  t := coalesce((p_key ->> 'tolerance')::numeric, 0);

  -- Fill rule applies only to a decimal answer of exactly the maximum length.
  fills := position('.' in s) > 0
           and length(s) = case when left(s, 1) = '-' then 6 else 5 end;
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
```

- [ ] **Step 5: Run — expect pass.** `supabase db reset < /dev/null; supabase test db < /dev/null` → all files PASS (`12`: 47 × 2 + 3 = 97 assertions).

- [ ] **Step 6: Commit** — `git add supabase/tests/fixtures/spr_cases.json supabase/tests/12_spr_grader.test.sql supabase/migrations/*_grd02_spr_grader.sql` → `feat(GRD-02): server-side SPR grader with shared fixture`.

---

### Task 2: Dart input parser (Answer Preview)

**Files:**
- Create: `apps/client/lib/core/grading/spr_answer.dart`
- Create (via `test-writer` agent, exact content below): `apps/client/test/core/grading/spr_answer_test.dart`

**Interfaces:**
- Consumes: `supabase/tests/fixtures/spr_cases.json`, `supabase/tests/12_spr_grader.test.sql` (drift guard).
- Produces: `sealed class SprAnswer`; `SprValid(BigInt numerator, BigInt denominator)`; `SprInvalid(SprInvalidReason reason)`; `enum SprInvalidReason { empty, tooLong, mixedNumber, zeroDenominator, format }`; `SprAnswer parseSprAnswer(String input)`.

- [ ] **Step 1: Dispatch `test-writer` to create `spr_answer_test.dart` with this content**

```dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/grading/spr_answer.dart';

// Shared with the SQL grader (docs/08 §6). flutter test runs from apps/client.
const _fixture = '../../supabase/tests/fixtures/spr_cases.json';
const _sqlTest = '../../supabase/tests/12_spr_grader.test.sql';

void main() {
  final cases = (jsonDecode(File(_fixture).readAsStringSync()) as List<dynamic>)
      .cast<Map<String, dynamic>>();

  group('GRD-02: parseSprAnswer matches the shared fixture', () {
    for (final c in cases) {
      final input = c['input'] as String;
      final invalid = c['expected'] == 'invalid';
      test('GRD-02: "$input" is ${invalid ? 'invalid' : 'valid'}', () {
        expect(parseSprAnswer(input) is SprInvalid, invalid);
      });
    }
  });

  test('GRD-02: values are reduced rationals', () {
    final answer = parseSprAnswer('-2/4');
    expect(answer, isA<SprValid>());
    final valid = answer as SprValid;
    expect(valid.numerator, BigInt.from(-1));
    expect(valid.denominator, BigInt.two);
  });

  test('GRD-02: decimals become exact fractions', () {
    final valid = parseSprAnswer('.75') as SprValid;
    expect(valid.numerator, BigInt.from(3));
    expect(valid.denominator, BigInt.from(4));
  });

  test('GRD-02: reasons for invalid input', () {
    SprInvalidReason reason(String s) => (parseSprAnswer(s) as SprInvalid).reason;
    expect(reason('   '), SprInvalidReason.empty);
    expect(reason('100000'), SprInvalidReason.tooLong);
    expect(reason('3 1/2'), SprInvalidReason.mixedNumber);
    expect(reason('1/0'), SprInvalidReason.zeroDenominator);
    expect(reason('5%'), SprInvalidReason.format);
  });

  test('GRD-02: the SQL test embeds the same fixture', () {
    final sql = File(_sqlTest).readAsStringSync();
    final embedded = sql.split(r'$json$')[1];
    expect(jsonDecode(embedded), jsonDecode(File(_fixture).readAsStringSync()));
  });
}
```

- [ ] **Step 2: Run — expect failure.** `cd apps/client && flutter test test/core/grading/spr_answer_test.dart` → compile error: `spr_answer.dart` not found.

- [ ] **Step 3: Write `apps/client/lib/core/grading/spr_answer.dart`**

```dart
/// SPR (student-produced response) input rules — GRD-02, docs/08 §6.
///
/// Mirrors `private.spr_parse` on the server. Used for input validation and the
/// Answer Preview only; grading happens server-side (keys never reach the client).
library;

/// Maximum characters for a non-negative answer (official SAT format rule).
const int sprMaxLength = 5;

/// Maximum characters when the answer starts with `-`.
const int sprMaxLengthNegative = 6;

/// Why an SPR input cannot be submitted as typed.
enum SprInvalidReason { empty, tooLong, mixedNumber, zeroDenominator, format }

/// A parsed SPR input.
sealed class SprAnswer {
  const SprAnswer();
}

/// A valid input, as a reduced fraction ([denominator] > 0).
final class SprValid extends SprAnswer {
  const SprValid(this.numerator, this.denominator);

  final BigInt numerator;
  final BigInt denominator;
}

/// An input the grader would reject.
final class SprInvalid extends SprAnswer {
  const SprInvalid(this.reason);

  final SprInvalidReason reason;
}

final _fraction = RegExp(r'^(-?)(\d+)/(\d+)$');
final _decimal = RegExp(r'^(-?)(\d*)(?:\.(\d*))?$');
final _mixed = RegExp(r'^-?\d+\s+\d+/\d+$');
final _outerSpaces = RegExp(r'^ +| +$');

/// Parses [input] with the same rules as the server grader.
SprAnswer parseSprAnswer(String input) {
  // Trim ASCII spaces only, exactly like Postgres btrim on the server.
  final s = input.replaceAll(_outerSpaces, '');
  if (s.isEmpty) return const SprInvalid(SprInvalidReason.empty);
  if (_mixed.hasMatch(s)) return const SprInvalid(SprInvalidReason.mixedNumber);
  final max = s.startsWith('-') ? sprMaxLengthNegative : sprMaxLength;
  if (s.length > max) return const SprInvalid(SprInvalidReason.tooLong);

  final fraction = _fraction.firstMatch(s);
  if (fraction != null) {
    final denominator = BigInt.parse(fraction[3]!);
    if (denominator == BigInt.zero) {
      return const SprInvalid(SprInvalidReason.zeroDenominator);
    }
    return _reduced(fraction[1]!, BigInt.parse(fraction[2]!), denominator);
  }

  final decimal = _decimal.firstMatch(s);
  final whole = decimal?[2] ?? '';
  final digits = decimal?[3] ?? '';
  if (decimal == null || (whole.isEmpty && digits.isEmpty)) {
    return const SprInvalid(SprInvalidReason.format);
  }
  return _reduced(
    decimal[1]!,
    BigInt.parse('${whole.isEmpty ? '0' : whole}$digits'),
    BigInt.from(10).pow(digits.length),
  );
}

SprValid _reduced(String sign, BigInt magnitude, BigInt denominator) {
  final g = magnitude.gcd(denominator);
  final numerator = magnitude ~/ g;
  return SprValid(sign == '-' ? -numerator : numerator, denominator ~/ g);
}
```

- [ ] **Step 4: Run — expect pass.** Same command → all tests pass (47 fixture + 4).
- [ ] **Step 5:** `dart format .` and `flutter analyze --fatal-infos` (from `apps/client`) → clean.
- [ ] **Step 6: Commit** — `git add apps/client/lib/core/grading apps/client/test/core/grading` → `feat(GRD-02): client SPR input parser for the Answer Preview`.

---

### Task 3: Verify, review, ship

- [ ] **Step 1:** `/flutter-code-quality:review-gate` (format, analyze, full `flutter test`); `supabase db reset; supabase test db`; `supabase db lint`; advisors (expect only the accepted row-3 baseline).
- [ ] **Step 2:** Template checklist 1–9 on the migration; `/flutter-code-review`.
- [ ] **Step 3:** Final whole-branch review: `code-reviewer` (opus) with Review Focus; fix Critical/Important with RED→GREEN tests.
- [ ] **Step 4:** `graphify update .`; push `feat/GRD-02-spr-grader`; `gh pr create` titled `GRD-02: SPR grader (server) + input parser (client)`.

## Verification (end to end)
`supabase test db` → `12_spr_grader` 97/97 and all earlier files green; `flutter test` → all green incl. the drift guard; analyze/format clean.

## Execution
Native (superpowers:executing-plans), as in rows 2b and 3.
