-- P1 demo seed 30: topic 3 "Systems of Equations" - 12 practice + 12 quiz questions.
--
-- STAGING AND LOCAL ONLY. NEVER RUN AGAINST PROD. Requires 00_structure.sql
-- (course, topic, subtopic, skills and private.demo_upsert_question).
-- Original SAT-style content; idempotent (each call upserts by fixed id).
--
-- Question ids 00000000-0000-4000-8de0-0000000TPNNN: T = 3 (topic 3),
-- P = 1 practice / 2 quiz, NNN = 001-012.
-- SPR keys: terminating answers list the fraction and decimal forms; repeating
-- answers are keyed as the exact fraction only (docs/08 s6 authoring rule).

set client_min_messages = warning;

do $do$
begin

-- ---------------------------------------------------------------------------
-- Practice (hints on every item): 9 MCQ + 3 SPR, difficulty 4 E / 5 M / 3 H
-- ---------------------------------------------------------------------------

-- P1 (E, MCQ)
perform private.demo_upsert_question(
  '00000000-0000-4000-8de0-000000031001',
  '00000000-0000-4000-8de0-000000000013', '00000000-0000-4000-8de0-000000000023',
  'practice', 'mcq', 'E',
  $q$\(y = 2x\)

\(x + y = 12\)

The solution of the system above is \((x, y)\). What is the value of \(x\)?$q$,
  $q$Replace \(y\) in the second equation with \(2x\).$q$,
  jsonb_build_object(
    'A', $q$\(6\)$q$,
    'B', $q$\(8\)$q$,
    'C', $q$\(4\)$q$,
    'D', $q$\(12\)$q$),
  '{"choice":"C"}',
  $q$Substitute \(y = 2x\) into \(x + y = 12\): \(x + 2x = 12\).

So \(3x = 12\) and \(x = 4\). Then \(y = 2(4) = 8\).

Check: \(4 + 8 = 12\).$q$,
  null,
  array['DEMO.SYS.SOLVE']);

-- P2 (E, MCQ)
perform private.demo_upsert_question(
  '00000000-0000-4000-8de0-000000031002',
  '00000000-0000-4000-8de0-000000000013', '00000000-0000-4000-8de0-000000000023',
  'practice', 'mcq', 'E',
  $q$\(x + y = 10\)

\(x - y = 4\)

Which ordered pair \((x, y)\) is the solution of the system above?$q$,
  $q$Add the two equations: the \(y\)-terms cancel.$q$,
  jsonb_build_object(
    'A', $q$\((7, 3)\)$q$,
    'B', $q$\((3, 7)\)$q$,
    'C', $q$\((7, -3)\)$q$,
    'D', $q$\((14, -4)\)$q$),
  '{"choice":"A"}',
  $q$Add the equations: \(2x = 14\), so \(x = 7\).

Substitute into \(x + y = 10\): \(y = 3\).

Check: \(7 + 3 = 10\) and \(7 - 3 = 4\).$q$,
  jsonb_build_object(
    'B', $q$The values are swapped: \((3, 7)\) gives \(x - y = -4\), not 4.$q$,
    'D', $q$You found \(2x = 14\) but did not divide by 2.$q$),
  array['DEMO.SYS.SOLVE']);

-- P3 (E, MCQ)
perform private.demo_upsert_question(
  '00000000-0000-4000-8de0-000000031003',
  '00000000-0000-4000-8de0-000000000013', '00000000-0000-4000-8de0-000000000023',
  'practice', 'mcq', 'E',
  $q$At a museum, adult tickets cost $8 and child tickets cost $5. A family bought 7 tickets for a total of $44. Which system can be used to find the number of adult tickets \(a\) and child tickets \(c\)?$q$,
  $q$One equation counts the tickets; the other adds up the money.$q$,
  jsonb_build_object(
    'A', $q$\(a + c = 44\) and \(8a + 5c = 7\)$q$,
    'B', $q$\(a + c = 7\) and \(5a + 8c = 44\)$q$,
    'C', $q$\(8a + 5c = 44\) and \(a - c = 7\)$q$,
    'D', $q$\(a + c = 7\) and \(8a + 5c = 44\)$q$),
  '{"choice":"D"}',
  $q$The number of tickets is 7: \(a + c = 7\).

Adult tickets bring in \(8a\) dollars and child tickets \(5c\) dollars, for a total of 44: \(8a + 5c = 44\).

(The solution is \(a = 3\), \(c = 4\): \(24 + 20 = 44\).)$q$,
  jsonb_build_object(
    'B', $q$You swapped the prices. Each adult ticket costs $8, so 8 multiplies \(a\); this system gives 4 adults and 3 children, which costs \(32 + 15 = 47\) dollars.$q$),
  array['DEMO.SYS.MODEL']);

-- P4 (E, SPR)
perform private.demo_upsert_question(
  '00000000-0000-4000-8de0-000000031004',
  '00000000-0000-4000-8de0-000000000013', '00000000-0000-4000-8de0-000000000023',
  'practice', 'spr', 'E',
  $q$\(y = 3x - 5\)

\(y = x + 2\)

The solution of the system above is \((x, y)\). What is the value of \(x\)?$q$,
  $q$Both expressions equal \(y\), so set them equal to each other.$q$,
  null,
  '{"accepted":["7/2","3.5"],"tolerance":0}',
  $q$Set the expressions equal: \(3x - 5 = x + 2\).

Subtract \(x\) and add 5: \(2x = 7\), so \(x = \frac{7}{2} = 3.5\).

Check: \(3(3.5) - 5 = 5.5\) and \(3.5 + 2 = 5.5\).$q$,
  null,
  array['DEMO.SYS.SOLVE']);

-- P5 (M, MCQ)
perform private.demo_upsert_question(
  '00000000-0000-4000-8de0-000000031005',
  '00000000-0000-4000-8de0-000000000013', '00000000-0000-4000-8de0-000000000023',
  'practice', 'mcq', 'M',
  $q$\(2x + 3y = 13\)

\(x - y = -1\)

The solution of the system above is \((x, y)\). What is the value of \(x\)?$q$,
  $q$Solve the second equation for \(x\) and substitute it into the first.$q$,
  jsonb_build_object(
    'A', $q$\(3\)$q$,
    'B', $q$\(2\)$q$,
    'C', $q$\(5\)$q$,
    'D', $q$\(\frac{16}{5}\)$q$),
  '{"choice":"B"}',
  $q$From \(x - y = -1\): \(x = y - 1\).

Substitute: \(2(y - 1) + 3y = 13\), so \(5y - 2 = 13\), \(5y = 15\), \(y = 3\).

Then \(x = 3 - 1 = 2\).

Check: \(2(2) + 3(3) = 13\) and \(2 - 3 = -1\).$q$,
  jsonb_build_object(
    'A', $q$3 is the value of \(y\), not \(x\).$q$,
    'D', $q$From \(x - y = -1\), \(x = y - 1\), not \(y + 1\).$q$),
  array['DEMO.SYS.SOLVE']);

-- P6 (M, MCQ)
perform private.demo_upsert_question(
  '00000000-0000-4000-8de0-000000031006',
  '00000000-0000-4000-8de0-000000000013', '00000000-0000-4000-8de0-000000000023',
  'practice', 'mcq', 'M',
  $q$\(3x + 2y = 16\)

\(5x - 2y = 8\)

The solution of the system above is \((x, y)\). What is the value of \(y\)?$q$,
  $q$The \(y\)-terms have opposite coefficients. Add the equations to eliminate \(y\) first.$q$,
  jsonb_build_object(
    'A', $q$\(3\)$q$,
    'B', $q$\(7\)$q$,
    'C', $q$\(-\frac{7}{2}\)$q$,
    'D', $q$\(\frac{7}{2}\)$q$),
  '{"choice":"D"}',
  $q$Add the equations: \(8x = 24\), so \(x = 3\).

Substitute into \(3x + 2y = 16\): \(9 + 2y = 16\), so \(2y = 7\) and \(y = \frac{7}{2}\).

Check: \(5(3) - 2(3.5) = 15 - 7 = 8\).

Key step: add the equations to eliminate \(y\) because its coefficients are opposites, giving \(8x = 24\), so \(x = 3\). Substitute to find \(y = \frac{7}{2}\).$q$,
  jsonb_build_object(
    'A', $q$3 is the value of \(x\), not \(y\).$q$,
    'B', $q$7 is the value of \(2y\). Divide by 2 to find \(y\).$q$),
  array['DEMO.SYS.SOLVE']);

-- P7 (M, MCQ)
perform private.demo_upsert_question(
  '00000000-0000-4000-8de0-000000031007',
  '00000000-0000-4000-8de0-000000000013', '00000000-0000-4000-8de0-000000000023',
  'practice', 'mcq', 'M',
  $q$A shop sells notebooks for $3 each and pens for $1.50 each. Sam bought 12 items and paid $30. How many notebooks did Sam buy?$q$,
  $q$Write one equation for the number of items and one for the cost, then substitute.$q$,
  jsonb_build_object(
    'A', $q$\(8\)$q$,
    'B', $q$\(4\)$q$,
    'C', $q$\(10\)$q$,
    'D', $q$\(6\)$q$),
  '{"choice":"A"}',
  $q$Let \(n\) be notebooks and \(p\) pens: \(n + p = 12\) and \(3n + 1.5p = 30\).

Substitute \(p = 12 - n\): \(3n + 18 - 1.5n = 30\), so \(1.5n = 12\) and \(n = 8\).

Then \(p = 4\). Check: \(3(8) + 1.5(4) = 24 + 6 = 30\).$q$,
  jsonb_build_object(
    'B', $q$4 is the number of pens, not notebooks.$q$,
    'C', $q$You divided 30 by 3, as if every item were a notebook.$q$),
  array['DEMO.SYS.MODEL']);

-- P8 (M, SPR)
perform private.demo_upsert_question(
  '00000000-0000-4000-8de0-000000031008',
  '00000000-0000-4000-8de0-000000000013', '00000000-0000-4000-8de0-000000000023',
  'practice', 'spr', 'M',
  $q$\(4x - 3y = 5\)

\(2x + 3y = 4\)

The solution of the system above is \((x, y)\). What is the value of \(x\)?$q$,
  $q$Add the equations to eliminate \(y\).$q$,
  null,
  '{"accepted":["3/2","1.5"],"tolerance":0}',
  $q$Add the equations: \(6x = 9\), so \(x = \frac{3}{2} = 1.5\).

(Then \(2(1.5) + 3y = 4\) gives \(y = \frac{1}{3}\).)

Check: \(4(1.5) - 3 \cdot \frac{1}{3} = 6 - 1 = 5\).$q$,
  null,
  array['DEMO.SYS.SOLVE']);

-- P9 (M, MCQ)
perform private.demo_upsert_question(
  '00000000-0000-4000-8de0-000000031009',
  '00000000-0000-4000-8de0-000000000013', '00000000-0000-4000-8de0-000000000023',
  'practice', 'mcq', 'M',
  $q$\(y = 2x + 3\)

\(4x - 2y = 6\)

How many solutions does the system above have?$q$,
  $q$Rewrite the second equation in the form \(y = mx + b\) and compare slopes and intercepts.$q$,
  jsonb_build_object(
    'A', $q$Exactly one$q$,
    'B', $q$Exactly one, at \((0, 3)\)$q$,
    'C', $q$No solution$q$,
    'D', $q$Infinitely many$q$),
  '{"choice":"C"}',
  $q$Solve the second equation for \(y\): \(-2y = -4x + 6\), so \(y = 2x - 3\).

Both lines have slope 2, but their \(y\)-intercepts are 3 and \(-3\). Parallel lines never meet.

Substituting confirms it: \(4x - 2(2x + 3) = 6\) gives \(-6 = 6\), which is false. The system has no solution.$q$,
  jsonb_build_object(
    'D', $q$The slopes match but the intercepts (3 and \(-3\)) do not, so the lines are parallel, not the same line.$q$),
  array['DEMO.SYS.SOLVE']);

-- P10 (H, MCQ)
perform private.demo_upsert_question(
  '00000000-0000-4000-8de0-000000031010',
  '00000000-0000-4000-8de0-000000000013', '00000000-0000-4000-8de0-000000000023',
  'practice', 'mcq', 'H',
  $q$\(kx + 6y = 9\)

\(2x + 3y = 5\)

In the system above, \(k\) is a constant. For what value of \(k\) does the system have no solution?$q$,
  $q$Multiply the second equation so its \(y\)-coefficient matches the first, then compare.$q$,
  jsonb_build_object(
    'A', $q$\(2\)$q$,
    'B', $q$\(4\)$q$,
    'C', $q$\(-4\)$q$,
    'D', $q$\(\frac{18}{5}\)$q$),
  '{"choice":"B"}',
  $q$Multiply the second equation by 2: \(4x + 6y = 10\).

If \(k = 4\), the first equation is \(4x + 6y = 9\). The same left side cannot equal both 9 and 10, so there is no solution.

For any other \(k\), the \(x\)-coefficients differ and the lines cross once.$q$,
  jsonb_build_object(
    'A', $q$You matched \(k\) to the coefficient 2 without scaling. The \(y\)-coefficient 6 is twice 3, so \(k\) must be twice 2.$q$,
    'D', $q$You matched the ratio of the constants (\(\frac{k}{2} = \frac{9}{5}\)). For no solution, the \(x\)- and \(y\)-coefficients must be in the same ratio (\(\frac{k}{2} = \frac{6}{3}\)) while the constants are not.$q$),
  array['DEMO.SYS.SOLVE']);

-- P11 (H, MCQ)
perform private.demo_upsert_question(
  '00000000-0000-4000-8de0-000000031011',
  '00000000-0000-4000-8de0-000000000013', '00000000-0000-4000-8de0-000000000023',
  'practice', 'mcq', 'H',
  $q$A chemist mixes a 10% salt solution with a 30% salt solution to make 40 liters of a 25% salt solution. How many liters of the 10% solution does she use?$q$,
  $q$One equation adds the volumes; the other adds the amounts of salt.$q$,
  jsonb_build_object(
    'A', $q$\(30\)$q$,
    'B', $q$\(20\)$q$,
    'C', $q$\(10\)$q$,
    'D', $q$\(25\)$q$),
  '{"choice":"C"}',
  $q$Let \(x\) liters be 10% solution and \(y\) liters be 30% solution.

Volume: \(x + y = 40\). Salt: \(0.10x + 0.30y = 0.25(40) = 10\).

Substitute \(y = 40 - x\): \(0.10x + 12 - 0.30x = 10\), so \(-0.20x = -2\) and \(x = 10\).

Check: \(y = 30\), and \(0.10(10) + 0.30(30) = 1 + 9 = 10\).$q$,
  null,
  array['DEMO.SYS.MODEL']);

-- P12 (H, SPR)
perform private.demo_upsert_question(
  '00000000-0000-4000-8de0-000000031012',
  '00000000-0000-4000-8de0-000000000013', '00000000-0000-4000-8de0-000000000023',
  'practice', 'spr', 'H',
  $q$\(3x + 5y = 7\)

\(5x + 3y = 18\)

If \((x, y)\) is the solution of the system above, what is the value of \(x - y\)?$q$,
  $q$You do not need \(x\) and \(y\) separately. Try subtracting one equation from the other.$q$,
  null,
  '{"accepted":["11/2","5.5"],"tolerance":0}',
  $q$Subtract the first equation from the second: \((5x + 3y) - (3x + 5y) = 18 - 7\).

So \(2x - 2y = 11\), and \(x - y = \frac{11}{2} = 5.5\).

Check by solving fully: \(x = \frac{69}{16}\), \(y = -\frac{19}{16}\); then \(3x + 5y = \frac{207 - 95}{16} = 7\), and \(x - y = \frac{88}{16} = 5.5\).$q$,
  null,
  array['DEMO.SYS.SOLVE']);

-- ---------------------------------------------------------------------------
-- Quiz (no hints): 9 MCQ + 3 SPR, difficulty 4 E / 5 M / 3 H
-- ---------------------------------------------------------------------------

-- Q1 (E, MCQ)
perform private.demo_upsert_question(
  '00000000-0000-4000-8de0-000000032001',
  '00000000-0000-4000-8de0-000000000013', '00000000-0000-4000-8de0-000000000023',
  'quiz', 'mcq', 'E',
  $q$\(x = 3y\)

\(x + 2y = 15\)

The solution of the system above is \((x, y)\). What is the value of \(x\)?$q$,
  null,
  jsonb_build_object(
    'A', $q$\(9\)$q$,
    'B', $q$\(3\)$q$,
    'C', $q$\(5\)$q$,
    'D', $q$\(45\)$q$),
  '{"choice":"A"}',
  $q$Substitute \(x = 3y\): \(3y + 2y = 15\), so \(5y = 15\) and \(y = 3\).

Then \(x = 3(3) = 9\).

Check: \(9 + 2(3) = 15\).$q$,
  null,
  array['DEMO.SYS.SOLVE']);

-- Q2 (E, MCQ)
perform private.demo_upsert_question(
  '00000000-0000-4000-8de0-000000032002',
  '00000000-0000-4000-8de0-000000000013', '00000000-0000-4000-8de0-000000000023',
  'quiz', 'mcq', 'E',
  $q$\(2x + y = 7\)

\(x - y = 2\)

Which ordered pair \((x, y)\) is the solution of the system above?$q$,
  null,
  jsonb_build_object(
    'A', $q$\((1, 3)\)$q$,
    'B', $q$\((3, -1)\)$q$,
    'C', $q$\((2, 3)\)$q$,
    'D', $q$\((3, 1)\)$q$),
  '{"choice":"D"}',
  $q$Add the equations: \(3x = 9\), so \(x = 3\).

Substitute into \(x - y = 2\): \(y = 1\).

Check: \(2(3) + 1 = 7\) and \(3 - 1 = 2\).$q$,
  jsonb_build_object(
    'C', $q$\((2, 3)\) satisfies the first equation only: \(2 - 3 = -1\), not 2. A solution must satisfy both.$q$),
  array['DEMO.SYS.SOLVE']);

-- Q3 (E, MCQ)
perform private.demo_upsert_question(
  '00000000-0000-4000-8de0-000000032003',
  '00000000-0000-4000-8de0-000000000013', '00000000-0000-4000-8de0-000000000023',
  'quiz', 'mcq', 'E',
  $q$The sum of two numbers is 30, and the larger number \(x\) is 6 more than the smaller number \(y\). Which system describes the two numbers?$q$,
  null,
  jsonb_build_object(
    'A', $q$\(x + y = 30\) and \(x = 6y\)$q$,
    'B', $q$\(x + y = 30\) and \(x = y + 6\)$q$,
    'C', $q$\(x - y = 30\) and \(x = y + 6\)$q$,
    'D', $q$\(x + y = 6\) and \(x = y + 30\)$q$),
  '{"choice":"B"}',
  $q$"The sum is 30": \(x + y = 30\).

"\(x\) is 6 more than \(y\)": \(x = y + 6\).

(Solving gives \(y = 12\), \(x = 18\).)$q$,
  null,
  array['DEMO.SYS.MODEL']);

-- Q4 (E, SPR)
perform private.demo_upsert_question(
  '00000000-0000-4000-8de0-000000032004',
  '00000000-0000-4000-8de0-000000000013', '00000000-0000-4000-8de0-000000000023',
  'quiz', 'spr', 'E',
  $q$\(y = 4x\)

\(y = x + 5\)

The solution of the system above is \((x, y)\). What is the value of \(x\)?$q$,
  null,
  null,
  '{"accepted":["5/3"],"tolerance":0}',
  $q$Set the expressions equal: \(4x = x + 5\).

Subtract \(x\): \(3x = 5\), so \(x = \frac{5}{3}\).

Check: \(4 \cdot \frac{5}{3} = \frac{20}{3}\) and \(\frac{5}{3} + 5 = \frac{20}{3}\).

As a decimal, \(\frac{5}{3} = 1.666\ldots\); enter it filling all five characters, as 1.666 or 1.667.$q$,
  null,
  array['DEMO.SYS.SOLVE']);

-- Q5 (M, MCQ)
perform private.demo_upsert_question(
  '00000000-0000-4000-8de0-000000032005',
  '00000000-0000-4000-8de0-000000000013', '00000000-0000-4000-8de0-000000000023',
  'quiz', 'mcq', 'M',
  $q$\(3x - 2y = 1\)

\(x + 2y = 11\)

If \((x, y)\) is the solution of the system above, what is the value of \(x + y\)?$q$,
  null,
  jsonb_build_object(
    'A', $q$\(3\)$q$,
    'B', $q$\(4\)$q$,
    'C', $q$\(7\)$q$,
    'D', $q$\(12\)$q$),
  '{"choice":"C"}',
  $q$Add the equations: \(4x = 12\), so \(x = 3\).

Substitute into \(x + 2y = 11\): \(2y = 8\), so \(y = 4\).

So \(x + y = 7\). Check: \(3(3) - 2(4) = 1\).$q$,
  jsonb_build_object(
    'A', $q$3 is the value of \(x\). The question asks for \(x + y\).$q$,
    'D', $q$12 is the value of \(4x\) after adding the equations, not \(x + y\).$q$),
  array['DEMO.SYS.SOLVE']);

-- Q6 (M, MCQ)
perform private.demo_upsert_question(
  '00000000-0000-4000-8de0-000000032006',
  '00000000-0000-4000-8de0-000000000013', '00000000-0000-4000-8de0-000000000023',
  'quiz', 'mcq', 'M',
  $q$\(2x + 3y = 12\)

\(3x - y = 7\)

The solution of the system above is \((x, y)\). What is the value of \(y\)?$q$,
  null,
  jsonb_build_object(
    'A', $q$\(2\)$q$,
    'B', $q$\(3\)$q$,
    'C', $q$\(16\)$q$,
    'D', $q$\(4\)$q$),
  '{"choice":"A"}',
  $q$From the second equation, \(y = 3x - 7\).

Substitute: \(2x + 3(3x - 7) = 12\), so \(11x - 21 = 12\), \(11x = 33\), \(x = 3\).

Then \(y = 3(3) - 7 = 2\).

Check: \(2(3) + 3(2) = 12\) and \(3(3) - 2 = 7\).$q$,
  jsonb_build_object(
    'B', $q$3 is the value of \(x\), not \(y\).$q$,
    'C', $q$From \(3x - y = 7\), \(y = 3x - 7\), not \(3x + 7\).$q$),
  array['DEMO.SYS.SOLVE']);

-- Q7 (M, MCQ)
perform private.demo_upsert_question(
  '00000000-0000-4000-8de0-000000032007',
  '00000000-0000-4000-8de0-000000000013', '00000000-0000-4000-8de0-000000000023',
  'quiz', 'mcq', 'M',
  $q$A theater sold 200 tickets for a total of $2,000. Adult tickets cost $12 and student tickets cost $7. How many student tickets were sold?$q$,
  null,
  jsonb_build_object(
    'A', $q$\(120\)$q$,
    'B', $q$\(80\)$q$,
    'C', $q$\(100\)$q$,
    'D', $q$\(400\)$q$),
  '{"choice":"B"}',
  $q$Let \(a\) be adult and \(s\) student tickets: \(a + s = 200\) and \(12a + 7s = 2000\).

Substitute \(a = 200 - s\): \(2400 - 12s + 7s = 2000\), so \(-5s = -400\) and \(s = 80\).

Then \(a = 120\). Check: \(12(120) + 7(80) = 1440 + 560 = 2000\).$q$,
  null,
  array['DEMO.SYS.MODEL']);

-- Q8 (M, SPR)
perform private.demo_upsert_question(
  '00000000-0000-4000-8de0-000000032008',
  '00000000-0000-4000-8de0-000000000013', '00000000-0000-4000-8de0-000000000023',
  'quiz', 'spr', 'M',
  $q$A rope 24 meters long is cut into two pieces. The longer piece is 2 meters shorter than three times the shorter piece. How long is the shorter piece, in meters?$q$,
  null,
  null,
  '{"accepted":["13/2","6.5"],"tolerance":0}',
  $q$Let \(s\) be the shorter piece and \(l\) the longer piece: \(s + l = 24\) and \(l = 3s - 2\).

Substitute: \(s + 3s - 2 = 24\), so \(4s = 26\) and \(s = 6.5\).

Check: \(l = 3(6.5) - 2 = 17.5\), and \(6.5 + 17.5 = 24\).$q$,
  null,
  array['DEMO.SYS.MODEL']);

-- Q9 (M, MCQ)
perform private.demo_upsert_question(
  '00000000-0000-4000-8de0-000000032009',
  '00000000-0000-4000-8de0-000000000013', '00000000-0000-4000-8de0-000000000023',
  'quiz', 'mcq', 'M',
  $q$\(6x - 4y = 10\)

\(3x - 2y = 5\)

How many solutions does the system above have?$q$,
  null,
  jsonb_build_object(
    'A', $q$Exactly one$q$,
    'B', $q$Exactly one, at \((1, -1)\)$q$,
    'C', $q$No solution$q$,
    'D', $q$Infinitely many$q$),
  '{"choice":"D"}',
  $q$Multiply the second equation by 2: \(6x - 4y = 10\), which is exactly the first equation.

Both equations describe the same line, so every point on that line is a solution: infinitely many.$q$,
  jsonb_build_object(
    'B', $q$\((1, -1)\) is a solution, but not the only one: \((3, 2)\) works too. The equations describe the same line.$q$,
    'C', $q$The first equation is twice the second, so they are the same line, not parallel lines.$q$),
  array['DEMO.SYS.SOLVE']);

-- Q10 (H, MCQ)
perform private.demo_upsert_question(
  '00000000-0000-4000-8de0-000000032010',
  '00000000-0000-4000-8de0-000000000013', '00000000-0000-4000-8de0-000000000023',
  'quiz', 'mcq', 'H',
  $q$\(ax + 4y = 8\)

\(3x + 2y = c\)

In the system above, \(a\) and \(c\) are constants. The system has infinitely many solutions. What is the value of \(a + c\)?$q$,
  null,
  jsonb_build_object(
    'A', $q$\(7\)$q$,
    'B', $q$\(14\)$q$,
    'C', $q$\(10\)$q$,
    'D', $q$\(11\)$q$),
  '{"choice":"C"}',
  $q$Infinitely many solutions means the two equations describe the same line.

The \(y\)-coefficient 4 is twice 2, so the first equation must be twice the second: \(6x + 4y = 2c\).

Match: \(a = 6\) and \(2c = 8\), so \(c = 4\). Then \(a + c = 10\).

Key step: for the system to have infinitely many solutions, the first equation must be a multiple of the second. Multiply the second by 2 to find \(a = 6\) and \(c = 4\), so \(a + c = 10\).$q$,
  jsonb_build_object(
    'B', $q$You doubled the constant instead of halving it: \(2c = 8\) gives \(c = 4\), not 8.$q$,
    'A', $q$You took \(a = 3\) without scaling. Every coefficient of the second equation must be doubled to match \(4y\).$q$),
  array['DEMO.SYS.SOLVE']);

-- Q11 (H, MCQ)
perform private.demo_upsert_question(
  '00000000-0000-4000-8de0-000000032011',
  '00000000-0000-4000-8de0-000000000013', '00000000-0000-4000-8de0-000000000023',
  'quiz', 'mcq', 'H',
  $q$A boat travels 36 kilometers downstream in 2 hours and returns the same 36 kilometers upstream in 3 hours. The boat's speed in still water and the speed of the current are constant. What is the speed of the current, in kilometers per hour?$q$,
  null,
  jsonb_build_object(
    'A', $q$\(3\)$q$,
    'B', $q$\(15\)$q$,
    'C', $q$\(6\)$q$,
    'D', $q$\(12\)$q$),
  '{"choice":"A"}',
  $q$Downstream speed: \(36 \div 2 = 18\). Upstream speed: \(36 \div 3 = 12\).

With boat speed \(b\) and current \(c\): \(b + c = 18\) and \(b - c = 12\).

Subtract the equations: \(2c = 6\), so \(c = 3\) (and \(b = 15\)).$q$,
  null,
  array['DEMO.SYS.MODEL']);

-- Q12 (H, SPR)
perform private.demo_upsert_question(
  '00000000-0000-4000-8de0-000000032012',
  '00000000-0000-4000-8de0-000000000013', '00000000-0000-4000-8de0-000000000023',
  'quiz', 'spr', 'H',
  $q$\(\frac{x}{2} + \frac{y}{3} = 4\)

\(\frac{x}{4} - \frac{y}{6} = \frac{1}{2}\)

The solution of the system above is \((x, y)\). What is the value of \(y\)?$q$,
  null,
  null,
  '{"accepted":["9/2","4.5"],"tolerance":0}',
  $q$Clear the fractions. Multiply the first equation by 6: \(3x + 2y = 24\). Multiply the second by 12: \(3x - 2y = 6\).

Subtract the second from the first: \(4y = 18\), so \(y = \frac{9}{2} = 4.5\). (Then \(x = 5\).)

Check: \(\frac{5}{2} + \frac{4.5}{3} = 2.5 + 1.5 = 4\) and \(\frac{5}{4} - \frac{4.5}{6} = 1.25 - 0.75 = 0.5\).$q$,
  null,
  array['DEMO.SYS.SOLVE']);

end
$do$;
