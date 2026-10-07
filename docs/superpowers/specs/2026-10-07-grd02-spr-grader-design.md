# GRD-02 — SPR grader (design)

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

## Testing
Fixture-driven pgTAP (`supabase/tests/12_spr_grader.test.sql`) and Dart (`apps/client/test/core/grading/spr_answer_test.dart`) tests over `supabase/tests/fixtures/spr_cases.json`; the Dart test also guards against drift between the fixture and the copy embedded in the SQL test.
