-- GRD-02 — docs/08 §6: SPR grading. Cases are supabase/tests/fixtures/spr_cases.json, embedded
-- verbatim in the dollar-quoted literal below (the Dart test fails if this copy drifts from the file;
-- it splits on that delimiter, so do not write the delimiter anywhere else in this file).
begin;
create extension if not exists pgtap with schema extensions;

create temp table spr_cases on commit drop as
select c from jsonb_array_elements($json$
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
  {"input": ".6666",  "key": {"accepted": ["0.6667"]}, "expected": "incorrect"},
  {"input": "00.67",  "key": {"accepted": ["2/3"]},  "expected": "incorrect"},
  {"input": "000.7",  "key": {"accepted": ["2/3"]},  "expected": "incorrect"},
  {"input": "-00.67", "key": {"accepted": ["-2/3"]}, "expected": "incorrect"}
]
$json$::jsonb) as c;

select plan((select count(*)::int * 2 + 10 from spr_cases));

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
select throws_ok($$ select private.grade_spr('1', null) $$, 'P0001', 'invalid_key',
                 'GRD-02: a null key raises invalid_key');
select throws_ok($$ select private.grade_spr('1', '{"accepted": []}') $$, 'P0001', 'invalid_key',
                 'GRD-02: an empty accepted list raises invalid_key');
select throws_ok($$ select private.grade_spr('1', '{"accepted": [null]}') $$, 'P0001', 'invalid_key',
                 'GRD-02: a null accepted value raises invalid_key');
select throws_ok($$ select private.grade_spr('1', '{"accepted": [1]}') $$, 'P0001', 'invalid_key',
                 'GRD-02: a non-string accepted value raises invalid_key');
select throws_ok($$ select private.grade_spr('1', '{"accepted": ["1"], "tolerance": "0.1"}') $$, 'P0001', 'invalid_key',
                 'GRD-02: a non-numeric tolerance raises invalid_key');
select throws_ok($$ select private.grade_spr('abc', '{"accepted": ["abc"]}') $$, 'P0001', 'invalid_key',
                 'GRD-02: a bad key raises even when the answer is invalid');
select throws_ok($$ select private.grade_spr('1', '{"accepted": ["1", "abc"]}') $$, 'P0001', 'invalid_key',
                 'GRD-02: a bad key raises even when an earlier value matches');

select is(private.spr_parse('3.14159', false), array[314159, 100000]::numeric[],
          'GRD-02: key values are not length-limited');

select * from finish();
rollback;
