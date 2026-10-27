# ANL-01 Skills screen and skill mastery — design

Status: draft for owner review · Date: 2026-10-27 · Requirements: ANL-01 (P0), part of ANL-02 (per-skill breakdown on the quiz result) · Screen: S-24 (`docs/04`)

The owner opted out of the question round ("ابدأ"), so every decision below marked **(my call)** is the builder's default and open to change at review.

## Why

Students practise, take quizzes and homework, but get no picture of *what* they are good or weak at. ANL-01 asks for "skill mastery per skill tag (0–100), weak skills list, trend over time". The owner's own framing adds: charts, "X of Y solved", and a level per topic, plus per-skill bars on the quiz result (deferred from the redesign because `QuizReport` carries no per-skill data).

Success: a student opens **Skills** after a week and, in one look, knows their weakest skills and has a one-tap way to practise each.

## Goals

1. Compute skill mastery on the server from every graded answer (practice, homework, quiz), per `docs/07` §5, with every tunable in `settings`.
2. A Skills screen at `/skills` (replaces today's placeholder): overall "X of Y solved", weak skills first with **Practise this**, mastery bars grouped by domain, a weekly trend, and a level per topic.
3. Quiz result shows a per-skill breakdown (correct / total per skill) under the score.

## Non-goals

- Teacher analytics (ANL-05 matrix, ANL-06 class insights), exports (ANL-07), parent report (ANL-08).
- Error-type self-tagging (ANL-03), misconception insight (ANL-04).
- Mastery decay cron (`docs/07` §5 "optional") — later.
- Homework report per-skill breakdown and time-per-question / slow flags (rest of ANL-02) — later; the data model below makes it a small follow-up.
- Mock exams (no mock flow exists yet); the weight is defined so mocks plug in later.

## Anti-goals (would be a failure even if it works)

- Any answer key, explanation or question content reaching the client through the new RPCs (rule 1).
- Mastery computed or adjustable on the client (rule 2).
- Magic numbers in SQL (rule 5).
- Colour-only bands; a chart without labels; a trend line drawn from 2 data points that looks like a conclusion.
- Practice second tries inflating mastery.

## Constraints

CLAUDE.md rules 1–10 and A/B rules apply. New table ships with RLS + pgTAP test (rule 3); every RPC gets `grant execute ... to authenticated` (rule 9); SQL starts from `supabase/templates/` and passes `docs/16` §2. Visuals follow `DESIGN.md` (tokens, icon + word for status, reduced motion, sentence case, English only). No new client package **(my call)**: bars are plain widgets and the trend line is a small `CustomPainter`; a chart library is not justified for one line and a set of bars.

## Data and server

### Mastery engine (my call: implement `docs/07` §5 as written, tunables in settings)

One SQL function `private.apply_mastery(p_user uuid, p_question uuid, p_kind attempt_kind, p_correct boolean, p_time_ms int, p_at timestamptz)`:

- For each skill tagged on the question (`question_skills`): EWMA update of `public.skill_mastery` (`mastery`, `attempts`, `correct`, `avg_time_ms`, `updated_at`).
  - `x = 100` if correct else `0`; `alpha = mastery_alpha × w(kind) × d(difficulty)`; first answer starts from `mastery_start` (50); clamp 0–100.
- Upsert today's value into a new history table (below) for the trend.
- Settings keys (new, `on conflict do nothing`): `mastery_alpha` 0.15, `mastery_weights` `{"practice":0.5,"homework":1.0,"quiz":1.2,"mock":1.5}`, `mastery_difficulty` `{"E":0.8,"M":1.0,"H":1.2}`, `mastery_start` 50, `mastery_weak_below` 50, `mastery_min_attempts` 5, `mastery_trend_min_answers` 10.

Where it is called (each graded answer counts exactly once):

- **Practice:** in `check_practice_answer`, on the **first try only** (the honest signal; the second try and a reveal do not move mastery) **(my call)**.
- **Quiz:** in `finish_quiz`, once per `attempt_answers` row of the attempt (unanswered = incorrect).
- **Homework:** in the homework branch of `submit_attempt`, same.
- Re-grading or duplicate submit must not double-count: the existing submit paths are already idempotent on `status`; the function is only called inside the transition to `submitted`.

**Backfill:** the migration replays existing graded answers in `answered_at` order (practice first tries from `answer.tries[0]`, submitted quiz/homework rows) so current students start with real values. Deterministic, run once.

### Bands (my call: resolve the docs conflict in favour of the design)

`docs/07` says weak = mastery < 60; the design export uses **Weak 0–49 · Building 50–74 · Strong 75–100**, with Strong = the quiz pass mark. Use the design bands: `weak < mastery_weak_below (50)`, `strong ≥ pass_mark (75)`, building in between. A skill with fewer than `mastery_min_attempts` answers is **Not enough answers yet** (no band). Update `docs/07` §5 to match.

### Trend history

New table `public.skill_mastery_daily (user_id, skill_id, day date, mastery numeric, primary key (user_id, skill_id, day))`, RLS: student selects own; writes only through `private.apply_mastery` (security definer). Trend = weekly average of the student's practised skills (last 8 weeks). Shown only when the student has ≥ `mastery_trend_min_answers` graded answers; otherwise "Answer N more questions to see a trend".

### Read RPC `get_my_skills(p_course_id uuid)`

Security definer, `not_enrolled` / `access_expired` per existing access helpers, returns:

```
{
  summary:  { solved, total, graded_answers },          -- X of Y: distinct questions answered correctly ever / published questions in the course
  skills:   [ { code, name, domain, mastery, attempts, band } ],   -- band: weak|building|strong|thin
  weak:     [ { code, name, mastery, topic_id, topic_title } ],    -- up to 3, lowest mastery with ≥ min attempts and band weak; topic = topic holding most of that skill's practice questions (the "Practise this" target)
  trend:    [ { week_start, mastery } ],                -- empty when thin
  topics:   [ { topic_id, title, unit_title, solved, total, level } ]  -- level = band of the mean mastery of the skills tagged on the topic's questions
}
```

No question ids, stems, answers or keys. Error codes from `docs/07` §9 only.

### Quiz report per-skill breakdown

`finish_quiz` adds `skills: [{ code, name, correct, total }]` to `meta.report` (from the attempt's questions and their skills). `get_quiz_report` / the existing report read path returns it unchanged. Reports written before this change have no `skills` key; the client treats that as "no breakdown" and shows nothing (no invented data).

## Client

Feature `lib/features/skills/{data,domain,presentation}` (flutter-feature layout, Cubit, `Result<T>`, data source maps `PostgrestException` → `AppError`).

**Skills screen** at `/skills`, using the shell, 360 and 1280:

1. **Header:** "Skills" H1; course chips if the student has more than one course **(my call)**, otherwise none.
2. **Summary card:** "X of Y questions solved" with a thin progress bar, and "N answers so far".
3. **Weak skills** (first, because that is the action): up to 3 rows — skill name, mastery number, band chip (icon + word), **Practise this** → `/topic/<topic_id>`. Thin data: "Not enough answers to name a weak skill yet."
4. **Trend:** one line, weekly average, labelled axes (week dates, 0–100), last point labelled with its value; thin state copy as above. Draws in once (`AppMotion.enter`), static under reduced motion.
5. **All skills by domain:** domain heading, then a row per skill: name, horizontal bar 0–100 filled with the band colour, number, band word. Bars grow with a 40 ms stagger, collapsed under reduced motion.
6. **Topics:** per topic: title, "X of Y solved", level chip.

States: loading skeleton matching the layout; error with retry; **empty** (no graded answers) with an illustration and "Answer a few practice questions and your skills show up here." plus a button to the course map.

Band colours **(my call)**: weak = `incorrect`, building = `warning`, strong = `correct`, thin = `inkTertiary`; always with the band word.

**Quiz result:** under "N of M correct · Pass mark P%", a "By skill" list: skill name, "c of t", a small bar; staggered grow, collapsed under reduced motion. Hidden when the report has no `skills`.

## Tests

- pgTAP: mastery math (correct/incorrect, weights, difficulty, start value, clamp), practice first-try only, quiz/homework once per submit (idempotent), backfill result on a fixture, `get_my_skills` shape/bands/thin/weak target, access errors, no key fields in output, RLS on `skill_mastery_daily`, grants, settings present.
- Client: data model parsing (incl. missing `skills` in old reports), repository errors, every public Cubit method success + failure, widget tests for each state and band label, goldens light/dark at 360 and 1280 (loaded, thin, empty, error; quiz result with breakdown).

## Left to the builder

Exact SQL structure, index choices (e.g. on `attempt_answers(answered_at)` for the backfill), widget decomposition, copy for error states within `docs/07` §9 mapping, and the trend painter details within the tokens.
