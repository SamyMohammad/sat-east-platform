# 07 — Backend Logic & API Contracts

All RPCs are Postgres functions called with `supabase.rpc(name, params)`; Edge Functions (EF) are
`POST /functions/v1/<name>` with the user's JWT. Errors return `{ "error": { "code", "message" } }`.

## 1. API surface

### 1.1 RPCs (SECURITY DEFINER, validate `auth.uid()` inside)

| Name | Params | Returns | Notes |
|------|--------|---------|-------|
| `get_catalogue` | country? | published courses + topic count, free topic, price in the visitor's currency | S-01; callable by `anon` (PAY-01) |
| `get_course_page` | slug, country? | course + units → published topics (free flag) + `full` price | S-02; callable by `anon`; unknown/unpublished slug → `invalid_input` |
| `get_course_map` | slug? | course + `continue` topic + units → published topics with `status` (`completed`/`open`/`locked`), `sort_label`, `locked_reason`/`after_title`; authenticated only | S-14, LRN-01/03; slug null → caller's latest enrolment; errors `not_authenticated`, `invalid_input`, `not_enrolled`, `access_expired` (no map without active access); step status added with video/notes steps |
| `save_video_progress` | asset_id, from_s, to_s, position_s | pct | merges watched ranges; marks step at ≥ 80% |
| `mark_notes_opened` | asset_id | ok | |
| `get_practice_questions` | topic_id | `attempt_id`, `rep_target`, questions (`id`, `type`, `difficulty`, `stem_md`, `choices[label, body_md]`; no keys, explanations, hints or misconceptions) | PRC-01; creates a `practice` attempt; draws `settings.practice_min` published practice-pool questions, never-seen first then random (fewer if the pool is smaller); errors `not_authenticated`, `invalid_input`, `not_enrolled`, `access_expired`, `topic_locked`, `pool_exhausted`; subtopic/difficulty filters later; per-user quota `settings.rate_start_per_min` per minute; quota exceeded returns `rate_limited` |
| `start_review` | p_topic_id uuid | `attempt_id`, `rep_target`, `questions` (same safe shape as get_practice_questions), `answered` (final question ids) | LRN-04 (L-7); resumes the current review or draws settings.review_per_skill (default 2) published practice questions per missed skill, capped at settings.review_max (default 10), unseen first; fills shortages from the topic practice pool; untagged misses get one review_per_skill batch; errors `not_authenticated`, `invalid_input` (review not required), `not_enrolled`, `access_expired`, `topic_locked`, `pool_exhausted`, `rate_limited`; per-user quota `settings.rate_start_per_min` per minute |
| `check_practice_answer` | attempt_id, question_id, answer, time_ms | `is_correct`, `try`; correct or wrong try 2: `key` (`{choice}` / `{text}` = first accepted form) + `explanation_md`; wrong try 1: `hint_md`, `misconception_md` for the chosen MCQ choice (always null for SPR) | PRC-01/04, LRN-02/04; accepts own in-progress practice or review attempts; submitted reviews allow saved-answer replay only; review answers never increase practice_count; the last final answer (correct or try 2) submits a review; server decides reveal (no `reveal` param); tries stored in `attempt_answers.answer.tries`; an answer equal to the last try is replayed (nothing logged); a third try → `invalid_input`; `practice_count` +1 on try 1 of a question never answered in practice before; spec `2026-10-17-p1-practice-design.md` §1.4; question must belong to the attempt's topic; per-user quota `settings.rate_answer_per_min` per minute; quota exceeded returns `rate_limited` |
| `get_topic` | topic_id | `id`, `title`, `slug`, `sort_label`, `status` (`open`/`completed`), `practice: {count,min}`, `quiz: {state,practice_count,practice_min,best_score_pct,passed,attempt_id?,available_at?,review:{required,attempt_id,answered,total}}` | PRC-03; state priority: in_progress, practice_needed, review_needed, cooldown, available; review_needed includes available_at while cooldown runs; lazy expiry before active-access/lock check |
| `start_quiz` | topic_id | `attempt_id`, `title`, `time_limit_s`, `deadline`, `server_now`, `warn_s`, `questions[{id,type,difficulty,stem_md,choices[{label,body_md}]}]`, `answers[{question_id,answer,marked}]`, `client_seq` | PRC-03; quiz entry point (generic start_attempt is deferred); resumes the same in-progress attempt; draws settings.quiz_size published quiz-pool questions, unseen first; practice_needed/review_needed/cooldown_active gates; review is required after a fail until completed, unless the topic quiz was passed; teacher unlock does not bypass review; no grading content; per-user quota `settings.rate_start_per_min` per minute; quota exceeded returns `rate_limited` |
| `save_answer` | attempt_id uuid, question_id uuid, answer text, time_ms int, marked boolean, eliminated text[], client_seq int | `{ok:true}` or `{ok:true,stale:true}` | PRC-03/04; own in-progress quiz only; null clears answer; >32 characters invalid; total time clamped to 0..3600000; sequence less than or equal to stored ignored; lazy expiry before active-access check; after deadline + settings.save_grace_s returns deadline_passed; no grading until submit; per-user quota `settings.rate_save_per_min` per minute; quota exceeded returns `rate_limited` |
| `submit_attempt` | attempt_id uuid | `{score_raw,score_total,score_pct,pass_mark,passed,next_topic:{id,title} \| null,retake_at}` | PRC-03, LRN-03; quiz only; grades saved MCQ/SPR, unanswered wrong; stores report for idempotent replay; updates best/pass/failure timestamps; topic_states implicitly unlocks next topic; lazy expiry before active-access check; no keys or answer review; mastery later; per-user quota `settings.rate_submit_per_min` per minute; quota exceeded returns `rate_limited` |
| `get_attempt_review` | p_attempt_id uuid | `{summary:{score_raw,score_total,score_pct,pass_mark,passed,keys_visible}, questions:[{id,type,stem_md,choices:[{label,body_md}],my_answer,is_correct,time_ms,skills:[{code,name}],key?,explanation_md?}]}` | PRC-03; own submitted quiz only; questions ordered by frozen position; summary uses the stored report; key (`{choice}` / `{text}` = first accepted SPR form) and explanation_md are absent unless the owner has passed this topic's quiz, including on earlier failed attempts; teacher unlock is not a pass; errors `not_authenticated`, `invalid_input` (null/unknown/non-quiz), `forbidden` (another owner's quiz), `attempt_not_submitted`; executable by `authenticated`, not `anon` |
| `register_device` | fingerprint, platform?, label? | `ok` + device_id, or `limit_reached` + devices + changes_left | called by the `register-device` EF (§8) |
| `remove_device` | device_id | changes_left | `device_limit` when the 30-day allowance is used (§8) |
| `list_my_devices` | p_fingerprint text | `{devices: [{id, label, platform, last_seen_at, created_at, is_current}], changes_left}` | AUTH-04; authenticated only; caller's non-revoked devices ordered by `last_seen_at desc nulls last`, then `created_at desc`; `is_current` matches the supplied fingerprint, which is never returned; allowance uses `device_changes_30d` minus the caller's changes strictly within the last 30 days, clamped to zero (same allowance as `remove_device`); errors `not_authenticated`, `invalid_input` (null/blank fingerprint) |
| `device_status` | fingerprint | `active` / `revoked` / `unknown` | polled every minute (§8) |
| `redeem_activation_code` | p_code text, p_target_test_date date | `{ok:true, course_id, course_slug, course_title, target_test_date, expires_at}` or `{ok:false, error}` | PAY-06/07; authenticated only; trims, uppercases and removes dashes/spaces; published courses only; locks the code and creates one active enrollment atomically; any existing enrollment status blocks reuse of the course; returned errors `code_invalid`, `code_used`, `already_enrolled` retain the quota increment; raised errors `not_authenticated`, `invalid_input`, `rate_limited`; per-user `settings.rate_redeem_per_min` (5) per minute; test date from yesterday through today + `settings.test_date_max_days` (548), inclusive; access window in §7 |
| `teacher_list_devices` / `teacher_revoke_device` / `teacher_reset_devices` | user_id / device_id / user_id | devices / ok / ok | teacher only, audited (AUTH-05) |
| `tag_error_type` | attempt_id, question_id, error_type | ok | |
| `teacher_unlock_topic` | p_student_id uuid, p_topic_id uuid | `{topic_id, unlocked_at, unlocked_by}` | LRN-05 (L-9); teacher only; target must be a student and topic must be published; preserves existing progress and the first unlock timestamp/teacher; audits `topic.unlock` only on the first unlock; errors `not_authenticated`, `forbidden`, `invalid_input`; executable by `authenticated`, not `anon` |
| `teacher_list_courses` | none | `[{id,code,title,slug,is_published}]` ordered by sort | C-1 / ADM-01; teacher only, includes unpublished courses |
| `teacher_get_course_tree` | p_course_id uuid | `{course:{id,title,code},units:[{id,title,sort,in_use,topics:[{id,title,slug,sort,is_published,is_free_preview,subtopic_count,in_use,subtopics:[{id,title,sort,in_use}]}]}]}` | C-1 / ADM-01; teacher only, includes drafts; unknown course: `invalid_input`; each level ordered by sort |
| `teacher_upsert_unit` | p_id uuid, p_course_id uuid, p_title text | `{id}` | C-1 / ADM-01; teacher only; null id appends, otherwise renames within the same parent; trimmed title 1-120 chars |
| `teacher_upsert_topic` | p_id uuid, p_unit_id uuid, p_title text | `{id}` | C-1 / ADM-01; teacher only; null id appends a draft, otherwise renames within the same unit; course derived from unit; trimmed title 1-120 chars; unaccented ASCII slug unique per course with -2/-3 suffixes, unchanged on rename |
| `teacher_upsert_subtopic` | p_id uuid, p_topic_id uuid, p_title text | `{id}` | C-1 / ADM-01; teacher only; null id appends, otherwise renames within the same topic; trimmed title 1-120 chars |
| `teacher_reorder` | p_kind text, p_parent_id uuid, p_ids uuid[] | `{ok:true}` | C-1 / ADM-01; teacher only; kind is unit/topic/subtopic; locks parent; IDs must match all current children exactly (no duplicates or nulls), else `invalid_input`; atomic sort 1..n |
| `teacher_delete_node` | p_kind text, p_id uuid | `{ok:true}` | C-1 / ADM-01; teacher only; `in_use` for any child or FK reference, `invalid_input` for unknown kind/id |
| `teacher_set_topic_flags` | p_id uuid, p_is_published boolean, p_is_free_preview boolean | `{is_published,is_free_preview}` | C-1 / ADM-01; teacher only; null flag preserves its value; unknown id: `invalid_input` |
| `teacher_get_settings` | none | `[{key,group,label,unit,min,max,value}]` in server spec order | C-7 / ADM-06; teacher only; exposes only editable keys and server-owned integer bounds |
| `teacher_import_questions` | `p_items jsonb, p_commit boolean` | `{ok, rows, new, updated, errors, truncated}` | Teacher-only dry run or atomic import, keyed by external_ref; row problems returned, invalid commit rejected. |
| `teacher_list_questions` | p_filter jsonb, p_page int | `{total,page,page_size,rows}` | C-5 / QB-06; teacher only; one-based pages; page size from bank_page_size; literal ILIKE search; no answer fields |
| `teacher_get_question` | p_id uuid | Import-shaped row plus `{id,version,updated_at}`, including private key fields | C-5 / QB-06; teacher only; topic course first; unknown id: invalid_input |
| `teacher_save_question` | p_id uuid, p_row jsonb, p_expected_version int | `{id,version}` or `{ok:false,errors}` | C-5 / QB-06; teacher only; shared import validation, lifecycle guard, locked expected-version check; version_conflict on stale update; safe per-question audit |
| `teacher_list_topics_tree` | none | `[{course_code,topics:[{id,slug,title,subtopics}]}]` | C-5 / QB-06; teacher only; includes unpublished nodes; subtopic slug uses slugify(title) |
| `teacher_update_settings` | p_values jsonb | `{ok:true,updated:[keys]}` | C-7 / ADM-06; teacher only; object patch, numeric integers in the private allow-list ranges; warning must be strictly below proposed quiz duration; locks patch keys and the quiz triple before validation; all-or-nothing; per-key `settings.update` audit with before/after and updated_at; empty object is a no-op; errors `not_authenticated`, `forbidden`, `invalid_input`; authenticated execute only |

Teacher-only `teacher_*` RPCs may read/write keys for the teacher only.


Course-builder RPCs require authentication (`not_authenticated`) and teacher role (`forbidden`).
Only `authenticated` has execute permission; `anon` has none. Every successful builder write
records actor, action, entity, entity_id and before/after diff in `audit_log`.
| `teacher_matrix` | course_id, filters | rows | completion matrix (ANL-05) |
| `teacher_class_insights` | course_id, topic_id? | stats | ANL-06 |

Quiz RPCs run lazy expiry before checking access. A later raised error (including
`access_expired`, `cooldown_active` or `deadline_passed`) rolls those expiry writes back with
the request. Durable cleanup after a rejected request requires a separate successful transaction.

### 1.2 Edge Functions

Deployed as three functions (16 §8): `api` (Hono router for the routes below), `payment-webhook`, `ai-tutor`.
Sensitive routes (`video-otp`, `pdf-url`, `register-device`, `ai-tutor`) verify a Firebase App Check token (ADR-008).

| Name | Purpose |
|------|---------|
| `register-device` | Validate device fingerprint against limit; insert/revoke; returns `ok` or `limit_reached` + device list |
| `create-checkout` | Compute price (currency, coupon), create `orders(pending)`, create Paymob payment intention, return checkout URL |
| `payment-webhook` | Verify Paymob HMAC; idempotent on `gateway_txn_id`; mark order paid; create/extend enrollment; send receipt |
| `video-otp` | Check access; return short-lived signed R2 HLS playlist + key URL and watermark text (name, phone, short id). Upgrade: VdoCipher OTP (ADR-002) |
| `pdf-url` | Check access; return Storage signed URL (TTL 5 min). Client downloads once and opens from memory. Optional per-student stamp (short id, not name) streamed by the EF — see `docs/spikes/2026-10-08-pdf-viewer.md` |
| `assemble-mock` | Build mock forms for a template + set_no (teacher) or pick next unseen form for a student |
| `ai-tutor` | Grounded LLM answer (see §6) |
| `import-questions` | Validate and upsert pipeline JSON (teacher) |
| `send-email` | Templates via Resend |
| `cron-*` | Every minute: `expire-attempts` → `private.expire_overdue_attempts()` (submit overdue quizzes at their deadline after `save_grace_s`). Daily at 02:00 UTC: `nightly-cleanup` → `private.nightly_cleanup()` (abandon practice inactive for `practice_stale_h`, default 24 hours; purge rate-limit windows older than one day). Planned: expire enrollments, inactivity nudges, mastery decay, live reminders |

## 2. Unlock state machine

`get_course_map` is the read side of this state machine.

```
Topic t for user u:
  LOCKED     → UNLOCKED      when: t is first topic of course
                                   OR previous topic quiz_passed
                                   OR teacher_unlock
                                   OR t.is_free_preview
  Steps inside an UNLOCKED topic (each requires the previous):
    video      done when video_pct ≥ settings.video_done_pct (80)
    notes      done when notes_opened_at not null
    practice   done when practice_count ≥ settings.practice_min (10)
    homework   done when homework_submitted_at not null
    quiz       done when quiz_best_score ≥ settings.pass_mark (75)
  UNLOCKED → COMPLETED when quiz done
```
`compute_unlocks(u, course)` is called at the end of `submit_attempt` and `teacher_unlock`.
Enrollment must be active for any non-free topic; expired → read-only access to nothing (Proposed:
keep analytics visible).

## 3. Question drawing rules

| Kind | Pool | Count | Selection |
|------|------|-------|-----------|
| practice | practice | on demand | filter subtopic/difficulty; unseen first, then oldest-seen |
| homework | practice (excluding questions the user saw in practice) | `settings.homework_size` (20) | blueprint per topic: ~30% E / 50% M / 20% H; covers every subtopic |
| quiz | quiz | 12 + 3 spiral | 25% E / 50% M / 25% H; spiral = 3 from quiz pools of previously passed topics, prefer user's weak skills; never repeat a quiz question the user has seen |
| review (after failed quiz) | practice | 8 | weighted to skills missed in the failed quiz |
| drill (after mock) | practice | 10–15 | weakest skills in the mock |
| mock | mock_reserve | per form | see 08 |

All counts/mixes in `settings`. The draw is frozen into `attempt_questions` at `start_attempt`.
If a pool is too small to honour "no repeats", fall back to least-recently-seen and log a
`pool_exhausted` warning for the teacher.

## 4. Grading
- MCQ: `answer.choice == key.choice`.
- SPR: normalise → compare to every accepted value (rules in 08 §6).
- Score = correct / total. Practice answers do not affect quiz/homework scores but **do** update mastery.

## 5. Skill mastery (ANL-01)

Exponentially-weighted moving average per (user, skill), updated on every graded answer:

```
w(kind):  practice 0.5 · homework 1.0 · quiz 1.2 · mock 1.5
d(diff):  E 0.8 · M 1.0 · H 1.2
x = 100 if correct else 0
alpha = 0.15 * w * d
mastery_new = mastery_old + alpha * (x - mastery_old)      (start at 50 after first answer)
```
- "Weak skill" = mastery < 60 with ≥ 5 attempts. "Slow" = avg_time_ms > 1.5 × skill median.
- Nightly cron: optional mild decay toward 50 for skills untouched > 30 days (spaced-repetition nudge).
- Formula is a starting heuristic — keep it in one SQL function so it can be tuned.

## 6. AI tutor (ADR-005)

```
Client: ask(question_id, attempt_id?, message)
EF ai-tutor:
  1. Auth; check attempt is submitted (or practice answered); refuse if an active quiz/mock exists
  2. Rate limit: settings.ai_daily_cap (default 20 msgs/day)
  3. Load: stem, choices, key, explanation_md, student's answer, subtopic notes excerpt
  4. System prompt: "You are the teacher's assistant. Explain ONLY using the provided solution.
     If the student's question goes beyond it or you are unsure, say so and offer to escalate.
     Never invent a different final answer. Answer in the student's language (English/Arabic)."
  5. Call LLM, store message + token usage
  6. Return reply; client shows "Still confused? Ask the teacher" → creates escalation
```
Guardrails: refuse non-math/off-course, never reveal keys of unsubmitted items (enforced by step 1),
log everything for teacher review.

## 7. Payments (ADR-003)
- **Currency (PAY-04):** `private.currency_for(country)` maps through `settings.currency_by_country`
  (`{"EG":"EGP","default":"USD"}`). The country is `profiles.country` for a signed-in user, else
  the client's hint (locale/timezone), else `default`. The hint changes only what is displayed;
  `create-checkout` recomputes with the same helper. A course without a price in that currency
  shows its `default`-currency price; with neither, `price` is null ("Coming soon").
- Prices stored as minor units. `create-checkout` recomputes the amount server-side (never trusts client).
- Webhook: verify HMAC → `insert ... on conflict (gateway_txn_id) do nothing` → if new and success:
  create enrollment (or extend for renewal: `expires_at = greatest(expires_at, new_target + grace)`, `mock_set_no += 1`).
- **Activation codes (PAY-06):** call `redeem_activation_code` directly as an RPC; no Edge
  Function or third-party secret is needed. Business failures are returned as `{ok:false,error}`
  so wrong guesses count toward the quota; the sixth attempt in one minute raises `rate_limited`.
  An existing enrollment in any status returns `already_enrolled` and leaves the code unused.
  Code generation is SQL-editor only: [activation-code setup](setup/activation-codes.md).
- **Access window (PAY-07):** activation uses `greatest((target_test_date +
  settings.access_grace_days + 1)::timestamp at time zone 'UTC', now() +
  make_interval(days => settings.access_min_days))`. Defaults are 14 grace days and a 60-day
  minimum: access lasts through the end of the grace day, with expiration at the following
  midnight UTC, or the minimum window if later. The server computes and stores the window.
  Test date is read-only for students after activation; teacher changes and paid renewals follow later.
- Reconciliation cron: orders `pending` > 1h → query gateway status.
- Webhook matches the order by the **signed** gateway order id + amount + currency (never by
  `merchant_order_id`). A declined attempt keeps the order `pending` (the gateway allows a retry).
  Spike findings: `docs/spikes/2026-10-08-paymob.md`.

## 8. Device limit (AUTH-04, AUTH-05)
- The app makes a random install id (16–128 chars `[A-Za-z0-9_-]`) on first launch and keeps it in
  secure storage. On web it goes in localStorage + IndexedDB, which is a weaker guarantee we accept.
  Every request sends it as `x-device-id`.
- After login, the client calls `register-device` (EF: App Check → RPC `register_device`). Outcomes:
  - **known, active device** → `ok`, and `last_seen_at` is updated;
  - **known but revoked, or new** → `ok` while there are fewer than `settings.device_limit` active
    devices, otherwise `limit_reached`. A revoked device that comes back is re-activated, so it uses a
    slot like any new device;
  - **`limit_reached`** returns the active devices plus `changes_left`, and the client shows S-11.
  Teachers have no limit.
- `remove_device(device_id)` (S-11) revokes one of the caller's own active devices. Each removal is
  one change. Once there have been `settings.device_changes_30d` changes in the last 30 days it
  raises `device_limit`, and the client shows "contact your teacher".
- **Revoked sessions:**
  - The client calls `device_status(fingerprint)` (`active | revoked | unknown`) on app resume and
    every minute, and signs out on `revoked`.
  - `has_access` is false when `x-device-id` names a revoked or unknown device for the caller.
  - A **missing** header is allowed while `settings.device_header_required` is false. That is the
    default until the client sends the header (A-1). Then the setting flips to true.
- **Teacher (AUTH-05):**
  - `teacher_list_devices(user_id)` lists all devices plus the changes used;
  - `teacher_revoke_device(device_id)` revokes one device;
  - `teacher_reset_devices(user_id)` revokes every device and clears the change counter.
  Each action is written to `audit_log`.
- Registration and removal lock the caller's `profiles` row, so parallel calls cannot overshoot the limit.

## 9. Error codes
`version_conflict` (question changed since loading; reload before saving),
`in_use` (course-builder deletion blocked by children or FK references),
`not_authenticated`, `forbidden`, `invalid_input`, `not_enrolled`, `access_expired`, `topic_locked`,
`practice_needed` (practice_count below settings.practice_min), `review_needed` (finish the review set before a quiz retake), `attempt_not_submitted` (quiz review requires a submitted attempt), `attempt_closed`, `deadline_passed`, `device_limit`, `device_revoked`, `cooldown_active`, `pool_exhausted`,
`rate_limited`, `payment_invalid`, `code_invalid` (unknown code or unpublished course),
`code_used` (already redeemed), `already_enrolled` (any existing enrollment for the course),
`invalid_key` (malformed answer key — content error), `internal` (Edge Functions only — unexpected failure).

`redeem_activation_code` returns `code_invalid`, `code_used` and `already_enrolled` inside
`{ok:false,error}`; these are successful SQL transactions that retain the rate-limit increment.
Its authentication, input-validation and rate-limit errors are raised with the code as the message.

Client-only codes (GoTrue / transport; never returned by an RPC or Edge Function):
`invalid_credentials`, `email_not_confirmed`, `email_taken`, `weak_password`, `network`. `rate_limited` is reused for GoTrue rate limits.
