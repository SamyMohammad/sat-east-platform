-- P1 demo seed 10: topic 1 "Linear Equations" - 12 practice + 12 quiz questions.
--
-- STAGING AND LOCAL ONLY. NEVER RUN AGAINST PROD. Requires 00_structure.sql
-- (course, topic, subtopic, skills and private.demo_upsert_question).
-- Original SAT-style content; idempotent (each call upserts by fixed id).
--
-- Question ids 00000000-0000-4000-8de0-0000000TPNNN: T = 1 (topic 1),
-- P = 1 practice / 2 quiz, NNN = 001-012.
-- SPR keys: terminating answers list the fraction and decimal forms; repeating
-- answers are keyed as the exact fraction only (docs/08 s6 authoring rule) -
-- the grader's fill rule accepts the 5-character truncated/rounded decimals.

set client_min_messages = warning;

-- ---------------------------------------------------------------------------
-- Practice (hints on every item): 9 MCQ + 3 SPR, difficulty 4 E / 5 M / 3 H
-- ---------------------------------------------------------------------------

-- P1 (E, MCQ)
select private.demo_upsert_question(
  '00000000-0000-4000-8de0-000000011001',
  '00000000-0000-4000-8de0-000000000011', '00000000-0000-4000-8de0-000000000021',
  'practice', 'mcq', 'E',
  $q$If \(3x + 7 = 22\), what is the value of \(x\)?$q$,
  $q$Undo the operations in reverse order: deal with the \(+7\) before the \(3\).$q$,
  jsonb_build_object(
    'A', $q$\(\frac{1}{3}\)$q$,
    'B', $q$\(5\)$q$,
    'C', $q$\(\frac{29}{3}\)$q$,
    'D', $q$\(15\)$q$),
  '{"choice":"B"}',
  $q$Subtract 7 from both sides: \(3x = 15\).

Divide both sides by 3: \(x = 5\).

Check: \(3(5) + 7 = 22\).

الفكرة الأساسية: نطرح 7 من الطرفين أولًا فنحصل على \(3x = 15\)، ثم نقسم الطرفين على 3 فيكون \(x = 5\).$q$,
  jsonb_build_object(
    'A', $q$You divided 22 by 3 before subtracting 7. Subtract 7 from both sides first.$q$,
    'C', $q$You added 7 to 22 instead of subtracting it.$q$),
  array['DEMO.LE.SOLVE']);

-- P2 (E, MCQ)
select private.demo_upsert_question(
  '00000000-0000-4000-8de0-000000011002',
  '00000000-0000-4000-8de0-000000000011', '00000000-0000-4000-8de0-000000000021',
  'practice', 'mcq', 'E',
  $q$What value of \(x\) satisfies \(5 - 2x = 11\)?$q$,
  $q$Subtract 5 from both sides, then watch the sign when you divide by \(-2\).$q$,
  jsonb_build_object(
    'A', $q$\(-8\)$q$,
    'B', $q$\(-3\)$q$,
    'C', $q$\(3\)$q$,
    'D', $q$\(8\)$q$),
  '{"choice":"B"}',
  $q$Subtract 5 from both sides: \(-2x = 6\).

Divide both sides by \(-2\): \(x = -3\).

Check: \(5 - 2(-3) = 5 + 6 = 11\).$q$,
  jsonb_build_object(
    'C', $q$You dropped the negative sign on \(-2x\). Dividing 6 by \(-2\) gives \(-3\).$q$),
  array['DEMO.LE.SOLVE']);

-- P3 (E, MCQ)
select private.demo_upsert_question(
  '00000000-0000-4000-8de0-000000011003',
  '00000000-0000-4000-8de0-000000000011', '00000000-0000-4000-8de0-000000000021',
  'practice', 'mcq', 'E',
  $q$A gym charges a one-time sign-up fee of $40 plus $25 per month. Which equation gives the total cost \(C\), in dollars, of a membership for \(m\) months?$q$,
  $q$Which amount is paid once, and which amount is paid every month?$q$,
  jsonb_build_object(
    'A', $q$\(C = 25(m + 40)\)$q$,
    'B', $q$\(C = 40m + 25\)$q$,
    'C', $q$\(C = 25m + 40\)$q$,
    'D', $q$\(C = 65m\)$q$),
  '{"choice":"C"}',
  $q$The monthly charge is paid \(m\) times: \(25m\).

The sign-up fee is paid once: \(+40\).

So \(C = 25m + 40\). Check with 2 months: \(25(2) + 40 = 90\), which is \(40 + 25 + 25\).$q$,
  jsonb_build_object(
    'B', $q$You swapped the roles: the $40 fee is paid once, and the $25 is multiplied by the number of months.$q$),
  array['DEMO.LE.MODEL']);

-- P4 (E, SPR)
select private.demo_upsert_question(
  '00000000-0000-4000-8de0-000000011004',
  '00000000-0000-4000-8de0-000000000011', '00000000-0000-4000-8de0-000000000021',
  'practice', 'spr', 'E',
  $q$If \(4x - 9 = 5\), what is the value of \(x\)?$q$,
  $q$Add 9 to both sides first. The answer does not have to be a whole number.$q$,
  null,
  '{"accepted":["7/2","3.5"],"tolerance":0}',
  $q$Add 9 to both sides: \(4x = 14\).

Divide both sides by 4: \(x = \frac{14}{4} = \frac{7}{2} = 3.5\).

Check: \(4(3.5) - 9 = 14 - 9 = 5\).$q$,
  null,
  array['DEMO.LE.SOLVE']);

-- P5 (M, MCQ)
select private.demo_upsert_question(
  '00000000-0000-4000-8de0-000000011005',
  '00000000-0000-4000-8de0-000000000011', '00000000-0000-4000-8de0-000000000021',
  'practice', 'mcq', 'M',
  $q$What is the solution to \(3(x - 4) = 2x + 5\)?$q$,
  $q$Distribute the 3 to both terms in the parentheses, then collect the \(x\)-terms on one side.$q$,
  jsonb_build_object(
    'A', $q$\(-7\)$q$,
    'B', $q$\(\frac{17}{5}\)$q$,
    'C', $q$\(9\)$q$,
    'D', $q$\(17\)$q$),
  '{"choice":"D"}',
  $q$Distribute: \(3x - 12 = 2x + 5\).

Subtract \(2x\) from both sides: \(x - 12 = 5\).

Add 12 to both sides: \(x = 17\).

Check: \(3(17 - 4) = 39\) and \(2(17) + 5 = 39\).$q$,
  jsonb_build_object(
    'C', $q$You multiplied only \(x\) by 3. The 3 multiplies the 4 as well: \(3(x - 4) = 3x - 12\).$q$,
    'B', $q$You added \(2x\) to both sides instead of subtracting it.$q$),
  array['DEMO.LE.SOLVE']);

-- P6 (M, MCQ)
select private.demo_upsert_question(
  '00000000-0000-4000-8de0-000000011006',
  '00000000-0000-4000-8de0-000000000011', '00000000-0000-4000-8de0-000000000021',
  'practice', 'mcq', 'M',
  $q$If \(\frac{x}{3} + \frac{x}{6} = 5\), what is the value of \(x\)?$q$,
  $q$Multiply every term on both sides by the common denominator, 6.$q$,
  jsonb_build_object(
    'A', $q$\(\frac{5}{3}\)$q$,
    'B', $q$\(\frac{5}{2}\)$q$,
    'C', $q$\(10\)$q$,
    'D', $q$\(\frac{45}{2}\)$q$),
  '{"choice":"C"}',
  $q$Multiply both sides by 6: \(2x + x = 30\).

Combine like terms: \(3x = 30\), so \(x = 10\).

Check: \(\frac{10}{3} + \frac{10}{6} = \frac{20}{6} + \frac{10}{6} = \frac{30}{6} = 5\).

الخطوة الأساسية: نضرب كل حدود المعادلة في 6 (المقام المشترك) فنحصل على \(2x + x = 30\)، أي \(3x = 30\)، ومنها \(x = 10\).$q$,
  jsonb_build_object(
    'A', $q$You multiplied the left side by 6 but not the right side.$q$,
    'D', $q$You added the denominators. Fractions are added over a common denominator: \(\frac{x}{3} + \frac{x}{6} = \frac{x}{2}\).$q$),
  array['DEMO.LE.SOLVE']);

-- P7 (M, MCQ)
select private.demo_upsert_question(
  '00000000-0000-4000-8de0-000000011007',
  '00000000-0000-4000-8de0-000000000011', '00000000-0000-4000-8de0-000000000021',
  'practice', 'mcq', 'M',
  $q$A water tank holds 600 liters. It drains at a constant rate of 15 liters per minute. After how many minutes will the tank hold 150 liters?$q$,
  $q$Write the amount left after \(t\) minutes as \(600 - 15t\) and set it equal to 150.$q$,
  jsonb_build_object(
    'A', $q$\(10\)$q$,
    'B', $q$\(30\)$q$,
    'C', $q$\(40\)$q$,
    'D', $q$\(50\)$q$),
  '{"choice":"B"}',
  $q$The amount left after \(t\) minutes is \(600 - 15t\).

Set it equal to 150: \(600 - 15t = 150\).

Subtract 600: \(-15t = -450\), so \(t = 30\).

Check: \(600 - 15(30) = 600 - 450 = 150\).$q$,
  jsonb_build_object(
    'C', $q$40 minutes is when the tank is completely empty (\(600 \div 15\)), not when 150 liters remain.$q$),
  array['DEMO.LE.MODEL']);

-- P8 (M, SPR)
select private.demo_upsert_question(
  '00000000-0000-4000-8de0-000000011008',
  '00000000-0000-4000-8de0-000000000011', '00000000-0000-4000-8de0-000000000021',
  'practice', 'spr', 'M',
  $q$What value of \(x\) is the solution to \(2(3x + 1) = 4x + 7\)?$q$,
  $q$Distribute the 2, then move the \(x\)-terms to one side and the numbers to the other.$q$,
  null,
  '{"accepted":["5/2","2.5"],"tolerance":0}',
  $q$Distribute: \(6x + 2 = 4x + 7\).

Subtract \(4x\) and subtract 2: \(2x = 5\).

Divide by 2: \(x = \frac{5}{2} = 2.5\).

Check: \(2(3(2.5) + 1) = 2(8.5) = 17\) and \(4(2.5) + 7 = 17\).$q$,
  null,
  array['DEMO.LE.SOLVE']);

-- P9 (M, MCQ)
select private.demo_upsert_question(
  '00000000-0000-4000-8de0-000000011009',
  '00000000-0000-4000-8de0-000000000011', '00000000-0000-4000-8de0-000000000021',
  'practice', 'mcq', 'M',
  $q$An electrician charges a flat fee of $60 plus $40 per hour of work. A customer's bill was $300. For how many hours did the electrician work?$q$,
  $q$Write the bill as \(60 + 40h\) and set it equal to 300.$q$,
  jsonb_build_object(
    'A', $q$\(3\)$q$,
    'B', $q$\(6\)$q$,
    'C', $q$\(7.5\)$q$,
    'D', $q$\(9\)$q$),
  '{"choice":"B"}',
  $q$The bill for \(h\) hours is \(60 + 40h\).

Set it equal to 300: \(60 + 40h = 300\).

Subtract 60: \(40h = 240\), so \(h = 6\).

Check: \(60 + 40(6) = 300\).$q$,
  jsonb_build_object(
    'C', $q$You divided 300 by 40 and ignored the flat fee.$q$,
    'D', $q$You added the $60 fee to 300 instead of subtracting it.$q$),
  array['DEMO.LE.MODEL']);

-- P10 (H, MCQ)
select private.demo_upsert_question(
  '00000000-0000-4000-8de0-000000011010',
  '00000000-0000-4000-8de0-000000000011', '00000000-0000-4000-8de0-000000000021',
  'practice', 'mcq', 'H',
  $q$In the equation \(kx + 6 = 3x + 2\), \(k\) is a constant. For what value of \(k\) does the equation have no solution?$q$,
  $q$A linear equation has no solution when the \(x\)-terms cancel but the constants do not match.$q$,
  jsonb_build_object(
    'A', $q$\(-4\)$q$,
    'B', $q$\(-3\)$q$,
    'C', $q$\(3\)$q$,
    'D', $q$\(4\)$q$),
  '{"choice":"C"}',
  $q$Move the \(x\)-terms to one side: \((k - 3)x = 2 - 6 = -4\).

If \(k - 3 \ne 0\), dividing gives exactly one solution.

If \(k = 3\), the equation becomes \(0 = -4\), which is never true, so there is no solution.

So \(k = 3\).$q$,
  jsonb_build_object(
    'B', $q$Sign error: the \(x\)-coefficients must be equal, so \(k = 3\), not \(-3\).$q$,
    'A', $q$\(-4\) is the difference of the constants, not the value of \(k\). With \(k = -4\) the equation has one solution.$q$),
  array['DEMO.LE.SOLVE']);

-- P11 (H, MCQ)
select private.demo_upsert_question(
  '00000000-0000-4000-8de0-000000011011',
  '00000000-0000-4000-8de0-000000000011', '00000000-0000-4000-8de0-000000000021',
  'practice', 'mcq', 'H',
  $q$Phone plan A costs $30 per month plus $0.10 per minute of calls. Plan B costs $18 per month plus $0.25 per minute. For how many minutes of calls in a month do the two plans cost the same?$q$,
  $q$Write one cost expression for each plan, set them equal, and solve for the minutes \(m\).$q$,
  jsonb_build_object(
    'A', $q$\(48\)$q$,
    'B', $q$\(80\)$q$,
    'C', $q$\(120\)$q$,
    'D', $q$\(320\)$q$),
  '{"choice":"B"}',
  $q$Plan A: \(30 + 0.10m\). Plan B: \(18 + 0.25m\).

Set them equal: \(30 + 0.10m = 18 + 0.25m\).

Subtract 18 and \(0.10m\): \(12 = 0.15m\).

Divide: \(m = \frac{12}{0.15} = 80\).

Check: Plan A \(30 + 8 = 38\), Plan B \(18 + 20 = 38\).$q$,
  null,
  array['DEMO.LE.MODEL']);

-- P12 (H, SPR)
select private.demo_upsert_question(
  '00000000-0000-4000-8de0-000000011012',
  '00000000-0000-4000-8de0-000000000011', '00000000-0000-4000-8de0-000000000021',
  'practice', 'spr', 'H',
  $q$What value of \(x\) satisfies \(\frac{2x - 1}{3} = \frac{x + 4}{5}\)?$q$,
  $q$Cross-multiply, and keep each numerator in parentheses when you distribute. A fraction answer is fine.$q$,
  null,
  '{"accepted":["17/7"],"tolerance":0}',
  $q$Cross-multiply: \(5(2x - 1) = 3(x + 4)\).

Distribute: \(10x - 5 = 3x + 12\).

Subtract \(3x\) and add 5: \(7x = 17\), so \(x = \frac{17}{7}\).

Check: \(\frac{2 \cdot \frac{17}{7} - 1}{3} = \frac{27/7}{3} = \frac{9}{7}\) and \(\frac{\frac{17}{7} + 4}{5} = \frac{45/7}{5} = \frac{9}{7}\).

As a decimal, \(\frac{17}{7} = 2.4285\ldots\), so 2.428 or 2.429 is also accepted.$q$,
  null,
  array['DEMO.LE.SOLVE']);

-- ---------------------------------------------------------------------------
-- Quiz (no hints): 9 MCQ + 3 SPR, difficulty 4 E / 5 M / 3 H
-- ---------------------------------------------------------------------------

-- Q1 (E, MCQ)
select private.demo_upsert_question(
  '00000000-0000-4000-8de0-000000012001',
  '00000000-0000-4000-8de0-000000000011', '00000000-0000-4000-8de0-000000000021',
  'quiz', 'mcq', 'E',
  $q$If \(7x - 4 = 24\), what is the value of \(x\)?$q$,
  null,
  jsonb_build_object(
    'A', $q$\(\frac{20}{7}\)$q$,
    'B', $q$\(4\)$q$,
    'C', $q$\(\frac{52}{7}\)$q$,
    'D', $q$\(28\)$q$),
  '{"choice":"B"}',
  $q$Add 4 to both sides: \(7x = 28\).

Divide both sides by 7: \(x = 4\).

Check: \(7(4) - 4 = 24\).$q$,
  jsonb_build_object(
    'A', $q$You subtracted 4 from 24 instead of adding it.$q$,
    'D', $q$28 is the value of \(7x\). Divide by 7 to find \(x\).$q$),
  array['DEMO.LE.SOLVE']);

-- Q2 (E, MCQ)
select private.demo_upsert_question(
  '00000000-0000-4000-8de0-000000012002',
  '00000000-0000-4000-8de0-000000000011', '00000000-0000-4000-8de0-000000000021',
  'quiz', 'mcq', 'E',
  $q$What value of \(x\) satisfies \(\frac{x}{4} + 3 = 8\)?$q$,
  null,
  jsonb_build_object(
    'A', $q$\(5\)$q$,
    'B', $q$\(20\)$q$,
    'C', $q$\(29\)$q$,
    'D', $q$\(44\)$q$),
  '{"choice":"B"}',
  $q$Subtract 3 from both sides: \(\frac{x}{4} = 5\).

Multiply both sides by 4: \(x = 20\).

Check: \(\frac{20}{4} + 3 = 5 + 3 = 8\).$q$,
  jsonb_build_object(
    'C', $q$You multiplied 8 by 4 before subtracting 3, so the 3 was never multiplied. Subtract 3 first.$q$),
  array['DEMO.LE.SOLVE']);

-- Q3 (E, MCQ)
select private.demo_upsert_question(
  '00000000-0000-4000-8de0-000000012003',
  '00000000-0000-4000-8de0-000000000011', '00000000-0000-4000-8de0-000000000021',
  'quiz', 'mcq', 'E',
  $q$Maya has $120 in savings and adds $15 each week. Which equation can be solved to find \(w\), the number of weeks until she has $300 in savings?$q$,
  null,
  jsonb_build_object(
    'A', $q$\(120 - 15w = 300\)$q$,
    'B', $q$\(15 + 120w = 300\)$q$,
    'C', $q$\(15w = 300\)$q$,
    'D', $q$\(120 + 15w = 300\)$q$),
  '{"choice":"D"}',
  $q$She starts with 120 dollars, and after \(w\) weeks she has added \(15w\) dollars.

Her savings are \(120 + 15w\), so the equation is \(120 + 15w = 300\).

(Solving it gives \(15w = 180\), so \(w = 12\) weeks.)$q$,
  null,
  array['DEMO.LE.MODEL']);

-- Q4 (E, SPR)
select private.demo_upsert_question(
  '00000000-0000-4000-8de0-000000012004',
  '00000000-0000-4000-8de0-000000000011', '00000000-0000-4000-8de0-000000000021',
  'quiz', 'spr', 'E',
  $q$If \(6x + 5 = 9\), what is the value of \(x\)?$q$,
  null,
  null,
  '{"accepted":["2/3"],"tolerance":0}',
  $q$Subtract 5 from both sides: \(6x = 4\).

Divide both sides by 6: \(x = \frac{4}{6} = \frac{2}{3}\).

Check: \(6 \cdot \frac{2}{3} + 5 = 4 + 5 = 9\).

As a decimal, \(\frac{2}{3} = 0.666\ldots\); enter it filling all five characters, such as .6666, .6667, 0.666 or 0.667.$q$,
  null,
  array['DEMO.LE.SOLVE']);

-- Q5 (M, MCQ)
select private.demo_upsert_question(
  '00000000-0000-4000-8de0-000000012005',
  '00000000-0000-4000-8de0-000000000011', '00000000-0000-4000-8de0-000000000021',
  'quiz', 'mcq', 'M',
  $q$What is the solution to \(4(2x - 3) = 5x + 9\)?$q$,
  null,
  jsonb_build_object(
    'A', $q$\(-1\)$q$,
    'B', $q$\(\frac{21}{13}\)$q$,
    'C', $q$\(4\)$q$,
    'D', $q$\(7\)$q$),
  '{"choice":"D"}',
  $q$Distribute: \(8x - 12 = 5x + 9\).

Subtract \(5x\): \(3x - 12 = 9\).

Add 12: \(3x = 21\), so \(x = 7\).

Check: \(4(14 - 3) = 44\) and \(5(7) + 9 = 44\).

الخطوة الأساسية: نوزّع العدد 4 على الحدّين داخل القوسين، فيصبح الطرف الأيسر \(8x - 12\)، ثم نجمع الحدود المتشابهة لنحصل على \(3x = 21\)، أي \(x = 7\).$q$,
  jsonb_build_object(
    'C', $q$You multiplied only \(2x\) by 4. The 4 multiplies the \(-3\) as well, giving \(-12\).$q$,
    'A', $q$You subtracted 12 instead of adding it when moving it to the right side.$q$),
  array['DEMO.LE.SOLVE']);

-- Q6 (M, MCQ)
select private.demo_upsert_question(
  '00000000-0000-4000-8de0-000000012006',
  '00000000-0000-4000-8de0-000000000011', '00000000-0000-4000-8de0-000000000021',
  'quiz', 'mcq', 'M',
  $q$If \(0.4x + 1.2 = 0.1x + 3\), what is the value of \(x\)?$q$,
  null,
  jsonb_build_object(
    'A', $q$\(0.6\)$q$,
    'B', $q$\(3.6\)$q$,
    'C', $q$\(6\)$q$,
    'D', $q$\(14\)$q$),
  '{"choice":"C"}',
  $q$Subtract \(0.1x\) from both sides: \(0.3x + 1.2 = 3\).

Subtract 1.2: \(0.3x = 1.8\).

Divide by 0.3: \(x = 6\). (Multiplying everything by 10 first gives \(3x = 18\), the same result.)

Check: \(0.4(6) + 1.2 = 3.6\) and \(0.1(6) + 3 = 3.6\).$q$,
  null,
  array['DEMO.LE.SOLVE']);

-- Q7 (M, MCQ)
select private.demo_upsert_question(
  '00000000-0000-4000-8de0-000000012007',
  '00000000-0000-4000-8de0-000000000011', '00000000-0000-4000-8de0-000000000021',
  'quiz', 'mcq', 'M',
  $q$A taxi ride costs $3.50 to start plus $2 for each mile driven. A ride cost $21.50 in total. How many miles long was the ride?$q$,
  null,
  jsonb_build_object(
    'A', $q$\(9\)$q$,
    'B', $q$\(10.75\)$q$,
    'C', $q$\(12.5\)$q$,
    'D', $q$\(18\)$q$),
  '{"choice":"A"}',
  $q$The cost for \(d\) miles is \(3.50 + 2d\).

Set it equal to 21.50: \(3.50 + 2d = 21.50\).

Subtract 3.50: \(2d = 18\), so \(d = 9\).

Check: \(3.50 + 2(9) = 21.50\).$q$,
  jsonb_build_object(
    'D', $q$18 dollars is the mileage charge \(2d\). Divide by 2 to get the miles.$q$),
  array['DEMO.LE.MODEL']);

-- Q8 (M, SPR)
select private.demo_upsert_question(
  '00000000-0000-4000-8de0-000000012008',
  '00000000-0000-4000-8de0-000000000011', '00000000-0000-4000-8de0-000000000021',
  'quiz', 'spr', 'M',
  $q$A rectangle has a perimeter of 47 centimeters and a length of 15 centimeters. What is its width, in centimeters?$q$,
  null,
  null,
  '{"accepted":["17/2","8.5"],"tolerance":0}',
  $q$The perimeter is \(2(\text{length} + \text{width})\): \(2(15 + w) = 47\).

Divide by 2: \(15 + w = 23.5\).

Subtract 15: \(w = 8.5\).

Check: \(2(15 + 8.5) = 2(23.5) = 47\).$q$,
  null,
  array['DEMO.LE.MODEL']);

-- Q9 (M, MCQ)
select private.demo_upsert_question(
  '00000000-0000-4000-8de0-000000012009',
  '00000000-0000-4000-8de0-000000000011', '00000000-0000-4000-8de0-000000000021',
  'quiz', 'mcq', 'M',
  $q$If \(3x + 2 = 14\), what is the value of \(6x - 1\)?$q$,
  null,
  jsonb_build_object(
    'A', $q$\(4\)$q$,
    'B', $q$\(11\)$q$,
    'C', $q$\(23\)$q$,
    'D', $q$\(27\)$q$),
  '{"choice":"C"}',
  $q$Subtract 2: \(3x = 12\).

Double both sides: \(6x = 24\).

Subtract 1: \(6x - 1 = 23\).

(Or solve \(x = 4\) and substitute: \(6(4) - 1 = 23\).)$q$,
  jsonb_build_object(
    'A', $q$4 is the value of \(x\), not of \(6x - 1\).$q$,
    'D', $q$You doubled 14 and subtracted 1. Doubling \(3x + 2 = 14\) gives \(6x + 4 = 28\), so \(6x - 1 = 28 - 5\).$q$),
  array['DEMO.LE.SOLVE']);

-- Q10 (H, MCQ)
select private.demo_upsert_question(
  '00000000-0000-4000-8de0-000000012010',
  '00000000-0000-4000-8de0-000000000011', '00000000-0000-4000-8de0-000000000021',
  'quiz', 'mcq', 'H',
  $q$In the equation \(a(x + 2) = 4x + 8\), \(a\) is a constant. The equation has infinitely many solutions. What is the value of \(a\)?$q$,
  null,
  jsonb_build_object(
    'A', $q$\(-4\)$q$,
    'B', $q$\(2\)$q$,
    'C', $q$\(4\)$q$,
    'D', $q$\(8\)$q$),
  '{"choice":"C"}',
  $q$Distribute: \(ax + 2a = 4x + 8\).

Infinitely many solutions means both sides are the same expression, so the \(x\)-coefficients and the constants must match: \(a = 4\) and \(2a = 8\).

Both give \(a = 4\). Check: \(4(x + 2) = 4x + 8\) for every \(x\).$q$,
  jsonb_build_object(
    'D', $q$8 matches the constant \(2a\), not \(a\). With \(a = 8\), \(8x + 16 = 4x + 8\) has one solution.$q$),
  array['DEMO.LE.SOLVE']);

-- Q11 (H, MCQ)
select private.demo_upsert_question(
  '00000000-0000-4000-8de0-000000012011',
  '00000000-0000-4000-8de0-000000000011', '00000000-0000-4000-8de0-000000000021',
  'quiz', 'mcq', 'H',
  $q$Candle A is 30 centimeters tall and burns down 2 centimeters per hour. Candle B is 22 centimeters tall and burns down 1.2 centimeters per hour. Both are lit at the same time. After how many hours will the two candles be the same height?$q$,
  null,
  jsonb_build_object(
    'A', $q$\(2.5\)$q$,
    'B', $q$\(4\)$q$,
    'C', $q$\(10\)$q$,
    'D', $q$\(65\)$q$),
  '{"choice":"C"}',
  $q$Height of candle A after \(t\) hours: \(30 - 2t\). Candle B: \(22 - 1.2t\).

Set them equal: \(30 - 2t = 22 - 1.2t\).

Add \(2t\) and subtract 22: \(8 = 0.8t\), so \(t = 10\).

Check: \(30 - 20 = 10\) and \(22 - 12 = 10\); both candles are 10 cm tall.$q$,
  jsonb_build_object(
    'A', $q$You added the burn rates (\(8 \div 3.2\)). The gap of 8 cm closes at the difference of the rates, 0.8 cm per hour.$q$),
  array['DEMO.LE.MODEL']);

-- Q12 (H, SPR)
select private.demo_upsert_question(
  '00000000-0000-4000-8de0-000000012012',
  '00000000-0000-4000-8de0-000000000011', '00000000-0000-4000-8de0-000000000021',
  'quiz', 'spr', 'H',
  $q$What value of \(x\) is the solution to \(\frac{3}{4}(x - 2) = \frac{1}{3}x + \frac{1}{2}\)?$q$,
  null,
  null,
  '{"accepted":["24/5","4.8"],"tolerance":0}',
  $q$Multiply every term by 12 to clear the fractions: \(9(x - 2) = 4x + 6\).

Distribute: \(9x - 18 = 4x + 6\).

Subtract \(4x\) and add 18: \(5x = 24\), so \(x = \frac{24}{5} = 4.8\).

Check: \(\frac{3}{4}(2.8) = 2.1\) and \(\frac{1}{3}(4.8) + 0.5 = 1.6 + 0.5 = 2.1\).$q$,
  null,
  array['DEMO.LE.SOLVE']);
