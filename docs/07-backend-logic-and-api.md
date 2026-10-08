# 07 — Backend Logic & API Contracts

All RPCs are Postgres functions called with `supabase.rpc(name, params)`; Edge Functions (EF) are
`POST /functions/v1/<name>` with the user's JWT. Errors return `{ "error": { "code", "message" } }`.

## 1. API surface

### 1.1 RPCs (SECURITY DEFINER, validate `auth.uid()` inside)

| Name | Params | Returns | Notes |
|------|--------|---------|-------|
| `get_catalogue` | country? | published courses + topic count, free topic, price in the visitor's currency | S-01; callable by `anon` (PAY-01) |
| `get_course_page` | slug, country? | course + units → published topics (free flag) + `full` price | S-02; callable by `anon`; unknown/unpublished slug → `invalid_input` |
| `get_course_map` | course_id | units/topics with lock state + step status | single call for the map screen |
| `save_video_progress` | asset_id, from_s, to_s, position_s | pct | merges watched ranges; marks step at ≥ 80% |
| `mark_notes_opened` | asset_id | ok | |
| `get_practice_questions` | topic_id, subtopic_id?, difficulty?, limit | questions (no keys) | practice pool; prefers unseen |
| `check_practice_answer` | question_id, answer, time_ms | is_correct, key, explanation | logs a `practice` attempt answer |
| `start_attempt` | kind, topic_id? / mock_group? | attempt_id, questions (no keys), time_limit_s, deadline, server_now, saved answers + client_seq | idempotent: resumes an in-progress attempt (client continues from max client_seq + 1) |
| `save_answer` | attempt_id, question_id, answer, time_ms, marked, eliminated, client_seq | ok | upsert; ignores older `client_seq`; rejected after deadline + `settings.save_grace_s` (30 s) |
| `submit_attempt` | attempt_id | report | grades, updates progress/mastery/unlocks, returns keys |
| `get_attempt_review` | attempt_id | questions + keys + explanations + my answers | only if submitted |
| `register_device` | fingerprint, platform?, label? | `ok` + device_id, or `limit_reached` + devices + changes_left | called by the `register-device` EF (§8) |
| `remove_device` | device_id | changes_left | `device_limit` when the 30-day allowance is used (§8) |
| `device_status` | fingerprint | `active` / `revoked` / `unknown` | polled every minute (§8) |
| `teacher_list_devices` / `teacher_revoke_device` / `teacher_reset_devices` | user_id / device_id / user_id | devices / ok / ok | teacher only, audited (AUTH-05) |
| `tag_error_type` | attempt_id, question_id, error_type | ok | |
| `teacher_unlock` | user_id, topic_id | ok | teacher only, audited |
| `teacher_matrix` | course_id, filters | rows | completion matrix (ANL-05) |
| `teacher_class_insights` | course_id, topic_id? | stats | ANL-06 |

### 1.2 Edge Functions

Deployed as three functions (16 §8): `api` (Hono router for the routes below), `payment-webhook`, `ai-tutor`.
Sensitive routes (`video-otp`, `pdf-url`, `register-device`, `ai-tutor`) verify a Firebase App Check token (ADR-008).

| Name | Purpose |
|------|---------|
| `register-device` | Validate device fingerprint against limit; insert/revoke; returns `ok` or `limit_reached` + device list |
| `create-checkout` | Compute price (currency, coupon), create `orders(pending)`, create Paymob payment intention, return checkout URL |
| `payment-webhook` | Verify Paymob HMAC; idempotent on `gateway_txn_id`; mark order paid; create/extend enrollment; send receipt |
| `redeem-code` | Activation code → enrollment |
| `video-otp` | Check access; return short-lived signed R2 HLS playlist + key URL and watermark text (name, phone, short id). Upgrade: VdoCipher OTP (ADR-002) |
| `pdf-url` | Check access; return Storage signed URL (TTL 5 min). Client downloads once and opens from memory. Optional per-student stamp (short id, not name) streamed by the EF — see `docs/spikes/2026-10-08-pdf-viewer.md` |
| `assemble-mock` | Build mock forms for a template + set_no (teacher) or pick next unseen form for a student |
| `ai-tutor` | Grounded LLM answer (see §6) |
| `import-questions` | Validate and upsert pipeline JSON (teacher) |
| `send-email` | Templates via Resend |
| `cron-*` | Every minute: `cron-expire-attempts` (auto-submit timed attempts past deadline + grace). Nightly: expire enrollments, inactivity nudges, mastery decay, live reminders |

## 2. Unlock state machine

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
- Access window (Proposed): `expires_at = max(target_test_date + grace_days(14), now() + min_days(60))`.
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
`not_authenticated`, `forbidden`, `invalid_input`, `not_enrolled`, `access_expired`, `topic_locked`,
`attempt_closed`, `deadline_passed`, `device_limit`, `device_revoked`, `cooldown_active`, `pool_exhausted`,
`rate_limited`, `payment_invalid`, `invalid_key` (malformed answer key — content error), `internal` (Edge Functions only — unexpected failure).
