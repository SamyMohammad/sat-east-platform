# 12 — Testing Strategy

Focus testing where a bug costs trust or money: **grading, unlocking, payments, access control,
exam timing.** UI polish gets lighter coverage.

## 1. Test pyramid

| Layer | Tool | What |
|-------|------|------|
| SQL / RLS | pgTAP (or SQL tests via Supabase CLI) | Every table has RLS; student A cannot read B's rows; `private` schema not reachable via API; no function executable without explicit grant; RPC permission checks |
| Backend logic | pgTAP + Deno tests for Edge Functions | Grading (MCQ, SPR table below), unlock state machine, mastery update, question draw rules, webhook idempotency |
| Dart unit | `flutter_test` | SPR input validation/preview, timers, view models |
| Widget | `flutter_test` + golden tests | QuestionView with LaTeX, exam screen states at 360/768/1280 |
| Integration / E2E | `integration_test` (+ Patrol for native dialogs) on staging | Happy paths below |
| Manual | Checklist per release | DRM playback & watermark on each platform, screenshot blocking, payment in test mode |

## 2. Critical test cases

**Grading (GRD)**
| Input | Key | Expected |
|-------|-----|----------|
| `1/2` | 0.5 | correct |
| `.5` | 1/2 | correct |
| `2/4` | 1/2 | correct |
| `-3/4` / `-.75` | -0.75 | correct |
| `.6666` / `.6667` | 2/3 | correct |
| `.67` / `0.66` | 2/3 | incorrect (doesn't fill field) |
| `3 1/2` | 7/2 | invalid → incorrect |
| `100000` | 100000 | invalid (too long) |
| any of `["2","-5"]` | multi-key | correct |

**Unlock & flow (LRN)**
- Next topic locked until quiz ≥ pass mark; teacher override unlocks; free topic always open.
- Failed quiz → review set required → cooldown enforced → retake draws different questions.

**Security**
- Network payload of `start_attempt` contains no key/explanation fields (automated assertion).
- Expired enrollment → `access_expired` on video-otp, pdf-url, start_attempt.
- Third device → `device_limit`; revoked device rejected within 1 minute.

**Payments**
- Duplicate webhook → one enrollment. Bad HMAC → nothing created. Client-supplied amount ignored.
- Coupon expired/over-used rejected.

**Exam engine**
- Auto-submit at deadline even if the client was offline; resume shows server remaining time.
- Routing threshold boundaries (13/14 correct).
- No question repeats across a student's mocks in the same set.

## 3. E2E happy paths (run on staging before each release)
1. Sign up → free topic → buy (test mode) → enrolled.
2. Full topic loop → quiz pass → next topic unlocked.
3. Homework → teacher sees it in completion matrix.
4. Full mock (shortened test template) → report → drill set.

## 4. CI gates
`flutter analyze` · unit + widget tests · SQL/RLS tests against a local Supabase · secret scan of the
web bundle · build web. Merge to `main` blocked on failure.

## 5. Content QA
Validator in the pipeline (09 §2) + random-sample review; student "report a problem" feeds a
weekly content-bug review.
