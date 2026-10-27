-- P1 demo seed 20: topic 2 "Linear Inequalities" - 12 practice + 12 quiz questions.
--
-- STAGING AND LOCAL ONLY. NEVER RUN AGAINST PROD. Requires 00_structure.sql
-- (course, topic, subtopic, skills and private.demo_upsert_question).
-- Original SAT-style content; idempotent (each call upserts by fixed id).
--
-- Question ids 00000000-0000-4000-8de0-0000000TPNNN: T = 2 (topic 2),
-- P = 1 practice / 2 quiz, NNN = 001-012.
-- SPR items ask for a single number (a boundary value or the greatest/least
-- integer), since an SPR answer cannot hold an interval.

set client_min_messages = warning;

do $do$
begin

-- ---------------------------------------------------------------------------
-- Practice (hints on every item): 9 MCQ + 3 SPR, difficulty 4 E / 5 M / 3 H
-- ---------------------------------------------------------------------------

-- P1 (E, MCQ)
perform private.demo_upsert_question(
  '00000000-0000-4000-8de0-000000021001',
  '00000000-0000-4000-8de0-000000000012', '00000000-0000-4000-8de0-000000000022',
  'practice', 'mcq', 'E',
  $q$Which inequality describes all solutions of \(2x + 5 > 13\)?$q$,
  $q$Solve it like an equation: undo the \(+5\) first, then the \(2\).$q$,
  jsonb_build_object(
    'A', $q$\(x > 9\)$q$,
    'B', $q$\(x > 4\)$q$,
    'C', $q$\(x < 4\)$q$,
    'D', $q$\(x > 8\)$q$),
  '{"choice":"B"}',
  $q$Subtract 5 from both sides: \(2x > 8\).

Divide both sides by 2 (a positive number, so the sign stays): \(x > 4\).

Check: \(x = 5\) gives \(15 > 13\), true; \(x = 4\) gives \(13 > 13\), false.$q$,
  jsonb_build_object(
    'A', $q$You added 5 to 13 instead of subtracting it.$q$,
    'C', $q$You reversed the sign. Dividing by a positive number keeps the direction of the inequality.$q$),
  array['DEMO.LI.SOLVE']);

-- P2 (E, MCQ)
perform private.demo_upsert_question(
  '00000000-0000-4000-8de0-000000021002',
  '00000000-0000-4000-8de0-000000000012', '00000000-0000-4000-8de0-000000000022',
  'practice', 'mcq', 'E',
  $q$Which inequality describes all solutions of \(-3x \le 12\)?$q$,
  $q$You will divide by a negative number. What happens to the inequality sign?$q$,
  jsonb_build_object(
    'A', $q$\(x \le -4\)$q$,
    'B', $q$\(x \ge 4\)$q$,
    'C', $q$\(x \ge -4\)$q$,
    'D', $q$\(x \le 4\)$q$),
  '{"choice":"C"}',
  $q$Divide both sides by \(-3\). Dividing by a negative number reverses the inequality: \(x \ge -4\).

Check: \(x = 0\) gives \(0 \le 12\), true; \(x = -5\) gives \(15 \le 12\), false.

Key step: dividing both sides of an inequality by a negative number such as \(-3\) reverses the inequality sign, giving \(x \ge -4\).$q$,
  jsonb_build_object(
    'A', $q$You divided by \(-3\) without reversing the inequality sign.$q$,
    'D', $q$Dividing 12 by \(-3\) gives \(-4\), not 4, and the sign must also reverse.$q$),
  array['DEMO.LI.SOLVE']);

-- P3 (E, MCQ)
perform private.demo_upsert_question(
  '00000000-0000-4000-8de0-000000021003',
  '00000000-0000-4000-8de0-000000000012', '00000000-0000-4000-8de0-000000000022',
  'practice', 'mcq', 'E',
  $q$On a number line, the solutions of an inequality are drawn as a closed (filled) circle at \(-2\) with shading to the right. Which inequality is shown?$q$,
  $q$A closed circle means the endpoint is a solution. Shading to the right means larger numbers.$q$,
  jsonb_build_object(
    'A', $q$\(x \ge -2\)$q$,
    'B', $q$\(x > -2\)$q$,
    'C', $q$\(x \le -2\)$q$,
    'D', $q$\(x < -2\)$q$),
  '{"choice":"A"}',
  $q$Shading to the right shows numbers greater than \(-2\).

The closed circle shows that \(-2\) itself is included.

So the inequality is \(x \ge -2\).$q$,
  jsonb_build_object(
    'B', $q$\(x > -2\) leaves out \(-2\), which would be drawn with an open circle.$q$),
  array['DEMO.LI.GRAPH']);

-- P4 (E, SPR)
perform private.demo_upsert_question(
  '00000000-0000-4000-8de0-000000021004',
  '00000000-0000-4000-8de0-000000000012', '00000000-0000-4000-8de0-000000000022',
  'practice', 'spr', 'E',
  $q$What is the greatest integer \(x\) that satisfies \(4x - 7 < 10\)?$q$,
  $q$Solve the inequality first, then pick the largest whole number that fits.$q$,
  null,
  '{"accepted":["4"],"tolerance":0}',
  $q$Add 7 to both sides: \(4x < 17\).

Divide by 4: \(x < 4.25\).

The greatest integer less than 4.25 is 4.

Check: \(4(4) - 7 = 9 < 10\), but \(4(5) - 7 = 13\), which is not less than 10.$q$,
  null,
  array['DEMO.LI.SOLVE']);

-- P5 (M, MCQ)
perform private.demo_upsert_question(
  '00000000-0000-4000-8de0-000000021005',
  '00000000-0000-4000-8de0-000000000012', '00000000-0000-4000-8de0-000000000022',
  'practice', 'mcq', 'M',
  $q$Which inequality describes all solutions of \(5 - 2(x + 3) > 7\)?$q$,
  $q$Distribute the \(-2\) carefully, then remember the rule for dividing by a negative.$q$,
  jsonb_build_object(
    'A', $q$\(x > -4\)$q$,
    'B', $q$\(x < 2\)$q$,
    'C', $q$\(x > 2\)$q$,
    'D', $q$\(x < -4\)$q$),
  '{"choice":"D"}',
  $q$Distribute: \(5 - 2x - 6 > 7\), so \(-2x - 1 > 7\).

Add 1: \(-2x > 8\).

Divide by \(-2\) and reverse the sign: \(x < -4\).

Check: \(x = -5\) gives \(5 - 2(-2) = 9 > 7\), true; \(x = -4\) gives \(5 - 2(-1) = 7\), not greater than 7.$q$,
  jsonb_build_object(
    'A', $q$You divided by \(-2\) without reversing the inequality sign.$q$,
    'B', $q$\(-2(x + 3) = -2x - 6\), not \(-2x + 6\).$q$),
  array['DEMO.LI.SOLVE']);

-- P6 (M, MCQ)
perform private.demo_upsert_question(
  '00000000-0000-4000-8de0-000000021006',
  '00000000-0000-4000-8de0-000000000012', '00000000-0000-4000-8de0-000000000022',
  'practice', 'mcq', 'M',
  $q$Which inequality describes all solutions of \(\frac{x}{2} + 1 \le \frac{x}{3} + 2\)?$q$,
  $q$Multiply every term on both sides by 6 to clear the fractions.$q$,
  jsonb_build_object(
    'A', $q$\(x \le 6\)$q$,
    'B', $q$\(x \ge 6\)$q$,
    'C', $q$\(x \le 1\)$q$,
    'D', $q$\(x \le \frac{6}{5}\)$q$),
  '{"choice":"A"}',
  $q$Multiply every term by 6: \(3x + 6 \le 2x + 12\).

Subtract \(2x\) and 6: \(x \le 6\).

Check: \(x = 6\) gives \(3 + 1 = 4\) and \(2 + 2 = 4\), so \(4 \le 4\), true; \(x = 12\) gives \(7 \le 6\), false.$q$,
  null,
  array['DEMO.LI.SOLVE']);

-- P7 (M, MCQ)
perform private.demo_upsert_question(
  '00000000-0000-4000-8de0-000000021007',
  '00000000-0000-4000-8de0-000000000012', '00000000-0000-4000-8de0-000000000022',
  'practice', 'mcq', 'M',
  $q$A phone has 64 GB of storage, and 18 GB are already used. Each video Lina records uses 2.5 GB. What is the greatest number of videos she can record without going over the storage limit?$q$,
  $q$Write \(18 + 2.5v \le 64\). The number of videos must be a whole number.$q$,
  jsonb_build_object(
    'A', $q$\(32\)$q$,
    'B', $q$\(19\)$q$,
    'C', $q$\(18\)$q$,
    'D', $q$\(25\)$q$),
  '{"choice":"C"}',
  $q$The storage used after \(v\) videos is \(18 + 2.5v\), which must be at most 64: \(18 + 2.5v \le 64\).

Subtract 18: \(2.5v \le 46\). Divide by 2.5: \(v \le 18.4\).

The greatest whole number of videos is 18.

Check: 18 videos use \(18 + 45 = 63\) GB; 19 videos would use \(18 + 47.5 = 65.5\) GB.$q$,
  null,
  array['DEMO.LI.SOLVE']);

-- P8 (M, SPR)
perform private.demo_upsert_question(
  '00000000-0000-4000-8de0-000000021008',
  '00000000-0000-4000-8de0-000000000012', '00000000-0000-4000-8de0-000000000022',
  'practice', 'spr', 'M',
  $q$The solutions of \(3(2x - 1) \le 2x + 4\) are all values of \(x\) with \(x \le c\). What is the value of \(c\)?$q$,
  $q$Distribute the 3, collect the \(x\)-terms, and solve for the boundary value.$q$,
  null,
  '{"accepted":["7/4","1.75"],"tolerance":0}',
  $q$Distribute: \(6x - 3 \le 2x + 4\).

Subtract \(2x\) and add 3: \(4x \le 7\).

Divide by 4: \(x \le \frac{7}{4}\), so \(c = \frac{7}{4} = 1.75\).

Check at the boundary: \(3(3.5 - 1) = 7.5\) and \(2(1.75) + 4 = 7.5\).$q$,
  null,
  array['DEMO.LI.SOLVE']);

-- P9 (M, MCQ)
perform private.demo_upsert_question(
  '00000000-0000-4000-8de0-000000021009',
  '00000000-0000-4000-8de0-000000000012', '00000000-0000-4000-8de0-000000000022',
  'practice', 'mcq', 'M',
  $q$A number line shows an open circle at 3 with shading to the left. The graph shows all solutions of which inequality?$q$,
  $q$Solve each choice for \(x\), then compare it with the graph: open circle, numbers less than 3.$q$,
  jsonb_build_object(
    'A', $q$\(2x + 1 > 7\)$q$,
    'B', $q$\(4 - x > 1\)$q$,
    'C', $q$\(x - 3 \le 0\)$q$,
    'D', $q$\(3x \ge 9\)$q$),
  '{"choice":"B"}',
  $q$The graph shows \(x < 3\): the open circle excludes 3, and the shading covers smaller numbers.

Choice B: \(4 - x > 1\) gives \(-x > -3\), and dividing by \(-1\) reverses the sign: \(x < 3\).

The others give \(x > 3\) (A), \(x \le 3\) (C) and \(x \ge 3\) (D).$q$,
  jsonb_build_object(
    'C', $q$\(x - 3 \le 0\) means \(x \le 3\), which includes 3 and would need a closed circle.$q$),
  array['DEMO.LI.GRAPH']);

-- P10 (H, MCQ)
perform private.demo_upsert_question(
  '00000000-0000-4000-8de0-000000021010',
  '00000000-0000-4000-8de0-000000000012', '00000000-0000-4000-8de0-000000000022',
  'practice', 'mcq', 'H',
  $q$How many integers \(x\) satisfy \(-5 < 2x + 3 \le 11\)?$q$,
  $q$Do the same operation to all three parts, then check whether each endpoint is included.$q$,
  jsonb_build_object(
    'A', $q$\(7\)$q$,
    'B', $q$\(9\)$q$,
    'C', $q$\(5\)$q$,
    'D', $q$\(8\)$q$),
  '{"choice":"D"}',
  $q$Subtract 3 from all three parts: \(-8 < 2x \le 8\).

Divide all three parts by 2: \(-4 < x \le 4\).

The integers are \(-3, -2, -1, 0, 1, 2, 3, 4\): there are 8.

Check the ends: \(x = -4\) gives \(-5 < -5\), false; \(x = 4\) gives \(11 \le 11\), true.$q$,
  jsonb_build_object(
    'B', $q$You counted \(-4\). The left inequality is strict: \(2(-4) + 3 = -5\) is not greater than \(-5\).$q$,
    'A', $q$You left out 4. The right inequality allows equality: \(2(4) + 3 = 11\).$q$),
  array['DEMO.LI.SOLVE']);

-- P11 (H, MCQ)
perform private.demo_upsert_question(
  '00000000-0000-4000-8de0-000000021011',
  '00000000-0000-4000-8de0-000000000012', '00000000-0000-4000-8de0-000000000022',
  'practice', 'mcq', 'H',
  $q$In the inequality \(ax + 3 > 7\), \(a\) is a constant. The solutions of the inequality are exactly the values \(x < -2\). What is the value of \(a\)?$q$,
  $q$The solutions are "less than", so you must have divided by a negative number at the last step.$q$,
  jsonb_build_object(
    'A', $q$\(-2\)$q$,
    'B', $q$\(2\)$q$,
    'C', $q$\(-\frac{1}{2}\)$q$,
    'D', $q$\(\frac{1}{2}\)$q$),
  '{"choice":"A"}',
  $q$Subtract 3: \(ax > 4\).

For the result to be \(x < \ldots\), the sign must reverse, so \(a\) is negative and \(x < \frac{4}{a}\).

Set \(\frac{4}{a} = -2\): \(a = -2\).

Check: \(-2x + 3 > 7\) gives \(-2x > 4\), so \(x < -2\).$q$,
  jsonb_build_object(
    'B', $q$With \(a = 2\) you divide by a positive number, so the sign stays and the solutions are \(x > 2\).$q$,
    'C', $q$With \(a = -\frac{1}{2}\), \(-\frac{1}{2}x > 4\) gives \(x < -8\), not \(x < -2\).$q$),
  array['DEMO.LI.SOLVE']);

-- P12 (H, SPR)
perform private.demo_upsert_question(
  '00000000-0000-4000-8de0-000000021012',
  '00000000-0000-4000-8de0-000000000012', '00000000-0000-4000-8de0-000000000022',
  'practice', 'spr', 'H',
  $q$What is the least integer \(n\) for which \(7 - 3n < 2(n - 9)\)?$q$,
  $q$Solve for \(n\), and check whether the boundary value itself works, since the inequality is strict.$q$,
  null,
  '{"accepted":["6"],"tolerance":0}',
  $q$Distribute: \(7 - 3n < 2n - 18\).

Add \(3n\) and 18: \(25 < 5n\), so \(n > 5\).

Since \(n\) must be greater than 5 (not equal to it), the least integer is 6.

Check: \(n = 5\) gives \(-8 < -8\), false; \(n = 6\) gives \(-11 < -6\), true.$q$,
  null,
  array['DEMO.LI.SOLVE']);

-- ---------------------------------------------------------------------------
-- Quiz (no hints): 9 MCQ + 3 SPR, difficulty 4 E / 5 M / 3 H
-- ---------------------------------------------------------------------------

-- Q1 (E, MCQ)
perform private.demo_upsert_question(
  '00000000-0000-4000-8de0-000000022001',
  '00000000-0000-4000-8de0-000000000012', '00000000-0000-4000-8de0-000000000022',
  'quiz', 'mcq', 'E',
  $q$Which inequality describes all solutions of \(\frac{x}{5} - 2 \ge 1\)?$q$,
  null,
  jsonb_build_object(
    'A', $q$\(x \ge 3\)$q$,
    'B', $q$\(x \ge -5\)$q$,
    'C', $q$\(x \ge 15\)$q$,
    'D', $q$\(x \le 15\)$q$),
  '{"choice":"C"}',
  $q$Add 2 to both sides: \(\frac{x}{5} \ge 3\).

Multiply both sides by 5 (positive, so the sign stays): \(x \ge 15\).

Check: \(x = 15\) gives \(3 - 2 = 1 \ge 1\), true.$q$,
  jsonb_build_object(
    'A', $q$3 is the value of \(\frac{x}{5}\). Multiply by 5 to find \(x\).$q$,
    'D', $q$Multiplying by a positive number keeps the direction of the inequality.$q$),
  array['DEMO.LI.SOLVE']);

-- Q2 (E, MCQ)
perform private.demo_upsert_question(
  '00000000-0000-4000-8de0-000000022002',
  '00000000-0000-4000-8de0-000000000012', '00000000-0000-4000-8de0-000000000022',
  'quiz', 'mcq', 'E',
  $q$Which inequality describes all solutions of \(7 - x < 4\)?$q$,
  null,
  jsonb_build_object(
    'A', $q$\(x > 3\)$q$,
    'B', $q$\(x < 3\)$q$,
    'C', $q$\(x > -3\)$q$,
    'D', $q$\(x > 11\)$q$),
  '{"choice":"A"}',
  $q$Subtract 7 from both sides: \(-x < -3\).

Multiply both sides by \(-1\) and reverse the sign: \(x > 3\).

Check: \(x = 4\) gives \(3 < 4\), true; \(x = 3\) gives \(4 < 4\), false.$q$,
  jsonb_build_object(
    'B', $q$You multiplied by \(-1\) without reversing the inequality sign.$q$),
  array['DEMO.LI.SOLVE']);

-- Q3 (E, MCQ)
perform private.demo_upsert_question(
  '00000000-0000-4000-8de0-000000022003',
  '00000000-0000-4000-8de0-000000000012', '00000000-0000-4000-8de0-000000000022',
  'quiz', 'mcq', 'E',
  $q$Which description matches the graph of \(x < -1\) on a number line?$q$,
  null,
  jsonb_build_object(
    'A', $q$A closed circle at \(-1\), shaded to the right$q$,
    'B', $q$An open circle at \(-1\), shaded to the right$q$,
    'C', $q$A closed circle at \(-1\), shaded to the left$q$,
    'D', $q$An open circle at \(-1\), shaded to the left$q$),
  '{"choice":"D"}',
  $q$The sign \(<\) does not include \(-1\), so the circle is open.

The solutions are numbers less than \(-1\), which lie to the left.

So the graph is an open circle at \(-1\) with shading to the left.$q$,
  null,
  array['DEMO.LI.GRAPH']);

-- Q4 (E, SPR)
perform private.demo_upsert_question(
  '00000000-0000-4000-8de0-000000022004',
  '00000000-0000-4000-8de0-000000000012', '00000000-0000-4000-8de0-000000000022',
  'quiz', 'spr', 'E',
  $q$What is the greatest integer \(x\) that satisfies \(3x + 4 \le 20\)?$q$,
  null,
  null,
  '{"accepted":["5"],"tolerance":0}',
  $q$Subtract 4: \(3x \le 16\).

Divide by 3: \(x \le \frac{16}{3} = 5.33\ldots\)

The greatest integer that is at most \(5.33\ldots\) is 5.

Check: \(3(5) + 4 = 19 \le 20\), but \(3(6) + 4 = 22\), which is greater than 20.$q$,
  null,
  array['DEMO.LI.SOLVE']);

-- Q5 (M, MCQ)
perform private.demo_upsert_question(
  '00000000-0000-4000-8de0-000000022005',
  '00000000-0000-4000-8de0-000000000012', '00000000-0000-4000-8de0-000000000022',
  'quiz', 'mcq', 'M',
  $q$Which inequality describes all solutions of \(4(x - 2) > 6x + 2\)?$q$,
  null,
  jsonb_build_object(
    'A', $q$\(x > -5\)$q$,
    'B', $q$\(x < -5\)$q$,
    'C', $q$\(x < -2\)$q$,
    'D', $q$\(x > 5\)$q$),
  '{"choice":"B"}',
  $q$Distribute: \(4x - 8 > 6x + 2\).

Subtract \(6x\) and add 8: \(-2x > 10\).

Divide by \(-2\) and reverse the sign: \(x < -5\).

Check: \(x = -6\) gives \(-32 > -34\), true; \(x = -5\) gives \(-28 > -28\), false.$q$,
  jsonb_build_object(
    'A', $q$Dividing by \(-2\) reverses the inequality sign.$q$,
    'C', $q$\(4(x - 2) = 4x - 8\), not \(4x - 2\).$q$),
  array['DEMO.LI.SOLVE']);

-- Q6 (M, MCQ)
perform private.demo_upsert_question(
  '00000000-0000-4000-8de0-000000022006',
  '00000000-0000-4000-8de0-000000000012', '00000000-0000-4000-8de0-000000000022',
  'quiz', 'mcq', 'M',
  $q$Which inequality describes all solutions of \(0.5x + 3 \le 1.25x - 1.5\)?$q$,
  null,
  jsonb_build_object(
    'A', $q$\(x \le 6\)$q$,
    'B', $q$\(x \ge 2\)$q$,
    'C', $q$\(x \ge 6\)$q$,
    'D', $q$\(x \ge 3.6\)$q$),
  '{"choice":"C"}',
  $q$Subtract \(0.5x\) from both sides: \(3 \le 0.75x - 1.5\).

Add 1.5: \(4.5 \le 0.75x\).

Divide by 0.75 (positive, so the sign stays): \(6 \le x\), that is \(x \ge 6\).

Check: \(x = 6\) gives \(6 \le 6\), true; \(x = 0\) gives \(3 \le -1.5\), false.$q$,
  null,
  array['DEMO.LI.SOLVE']);

-- Q7 (M, MCQ)
perform private.demo_upsert_question(
  '00000000-0000-4000-8de0-000000022007',
  '00000000-0000-4000-8de0-000000000012', '00000000-0000-4000-8de0-000000000022',
  'quiz', 'mcq', 'M',
  $q$A delivery van can carry at most 1,200 kilograms, including its driver. The driver weighs 80 kilograms, and each box weighs 35 kilograms. Which inequality gives the numbers of boxes \(b\) the van can carry?$q$,
  null,
  jsonb_build_object(
    'A', $q$\(35b \le 1200\)$q$,
    'B', $q$\(80 + 35b \ge 1200\)$q$,
    'C', $q$\(80b + 35 \le 1200\)$q$,
    'D', $q$\(80 + 35b \le 1200\)$q$),
  '{"choice":"D"}',
  $q$The load is the driver plus the boxes: \(80 + 35b\).

"At most 1,200" means the load is less than or equal to 1,200: \(80 + 35b \le 1200\).

(Solving it gives \(b \le 32\), so the van can carry up to 32 boxes.)$q$,
  null,
  array['DEMO.LI.SOLVE']);

-- Q8 (M, SPR)
perform private.demo_upsert_question(
  '00000000-0000-4000-8de0-000000022008',
  '00000000-0000-4000-8de0-000000000012', '00000000-0000-4000-8de0-000000000022',
  'quiz', 'spr', 'M',
  $q$Ana scored 78, 85 and 90 on her first three tests. What is the least score she can get on the fourth test so that the average of the four scores is at least 85?$q$,
  null,
  null,
  '{"accepted":["87"],"tolerance":0}',
  $q$Let \(s\) be the fourth score. The average is \(\frac{78 + 85 + 90 + s}{4} = \frac{253 + s}{4}\).

Require \(\frac{253 + s}{4} \ge 85\). Multiply by 4: \(253 + s \ge 340\).

Subtract 253: \(s \ge 87\). The least score is 87.

Check: \(\frac{253 + 87}{4} = \frac{340}{4} = 85\).$q$,
  null,
  array['DEMO.LI.SOLVE']);

-- Q9 (M, MCQ)
perform private.demo_upsert_question(
  '00000000-0000-4000-8de0-000000022009',
  '00000000-0000-4000-8de0-000000000012', '00000000-0000-4000-8de0-000000000022',
  'quiz', 'mcq', 'M',
  $q$A number line shows a closed circle at \(-3\), an open circle at 2, and shading between them. Which inequality is shown?$q$,
  null,
  jsonb_build_object(
    'A', $q$\(-3 \le x < 2\)$q$,
    'B', $q$\(-3 < x \le 2\)$q$,
    'C', $q$\(-3 \le x \le 2\)$q$,
    'D', $q$\(x \le -3\) or \(x > 2\)$q$),
  '{"choice":"A"}',
  $q$The shading between the circles means \(x\) lies between \(-3\) and 2.

The closed circle includes \(-3\): \(-3 \le x\). The open circle excludes 2: \(x < 2\).

Together: \(-3 \le x < 2\).$q$,
  null,
  array['DEMO.LI.GRAPH']);

-- Q10 (H, MCQ)
perform private.demo_upsert_question(
  '00000000-0000-4000-8de0-000000022010',
  '00000000-0000-4000-8de0-000000000012', '00000000-0000-4000-8de0-000000000022',
  'quiz', 'mcq', 'H',
  $q$Which of the following describes all solutions of \(3 \le 2 - x < 7\)?$q$,
  null,
  jsonb_build_object(
    'A', $q$\(1 \le x < 5\)$q$,
    'B', $q$\(-5 < x \le -1\)$q$,
    'C', $q$\(-5 \le x < -1\)$q$,
    'D', $q$\(-1 < x \le 5\)$q$),
  '{"choice":"B"}',
  $q$Subtract 2 from all three parts: \(1 \le -x < 5\).

Multiply all three parts by \(-1\) and reverse both signs: \(-1 \ge x > -5\).

Written from smallest to largest: \(-5 < x \le -1\).

Check: \(x = -1\) gives \(2 - (-1) = 3\), and \(3 \le 3 < 7\) is true; \(x = -5\) gives 7, and \(7 < 7\) is false.

Key step: multiplying by \(-1\) reverses both inequality signs while each endpoint stays inclusive or exclusive as before, giving \(-5 < x \le -1\).$q$,
  jsonb_build_object(
    'A', $q$You did not multiply by \(-1\). The middle part is \(-x\), so the signs of the values and the inequalities must reverse.$q$,
    'C', $q$You moved the strictness to the wrong end. \(x = -5\) gives 7, and \(7 < 7\) is false, so \(-5\) is excluded.$q$),
  array['DEMO.LI.SOLVE']);

-- Q11 (H, MCQ)
perform private.demo_upsert_question(
  '00000000-0000-4000-8de0-000000022011',
  '00000000-0000-4000-8de0-000000000012', '00000000-0000-4000-8de0-000000000022',
  'quiz', 'mcq', 'H',
  $q$In the inequality \(2(3x - k) \ge 6x + 4\), \(k\) is a constant. The inequality is true for every real number \(x\). Which of the following could be the value of \(k\)?$q$,
  null,
  jsonb_build_object(
    'A', $q$\(2\)$q$,
    'B', $q$\(0\)$q$,
    'C', $q$\(-3\)$q$,
    'D', $q$\(-1\)$q$),
  '{"choice":"C"}',
  $q$Distribute: \(6x - 2k \ge 6x + 4\).

Subtract \(6x\): \(-2k \ge 4\). The \(x\)-terms are gone, so the inequality is true for every \(x\) exactly when this is true.

Divide by \(-2\) and reverse the sign: \(k \le -2\).

Of the choices, only \(-3\) satisfies \(k \le -2\). Check: \(-2(-3) = 6 \ge 4\).$q$,
  jsonb_build_object(
    'D', $q$You divided by \(-2\) without reversing the sign and got \(k \ge -2\). With \(k = -1\), \(-2k = 2\), which is not at least 4.$q$),
  array['DEMO.LI.SOLVE']);

-- Q12 (H, SPR)
perform private.demo_upsert_question(
  '00000000-0000-4000-8de0-000000022012',
  '00000000-0000-4000-8de0-000000000012', '00000000-0000-4000-8de0-000000000022',
  'quiz', 'spr', 'H',
  $q$What is the greatest value of \(x\) that satisfies \(\frac{2x + 1}{3} \le \frac{x + 5}{4}\)?$q$,
  null,
  null,
  '{"accepted":["11/5","2.2"],"tolerance":0}',
  $q$Multiply both sides by 12: \(4(2x + 1) \le 3(x + 5)\).

Distribute: \(8x + 4 \le 3x + 15\).

Subtract \(3x\) and 4: \(5x \le 11\), so \(x \le \frac{11}{5}\).

The greatest value is \(\frac{11}{5} = 2.2\). Check: \(\frac{5.4}{3} = 1.8\) and \(\frac{7.2}{4} = 1.8\).$q$,
  null,
  array['DEMO.LI.SOLVE']);

end
$do$;
