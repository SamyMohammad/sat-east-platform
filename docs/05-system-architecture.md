# 05 — System Architecture

## 1. Context

```
                   ┌────────────────────────────────────────────┐
  Students ───────▶│  Flutter client (Web · Android · iOS)       │
  Teacher  ───────▶│  role-based: student area + teacher area    │
                   └───────┬───────────────┬──────────────┬─────┘
                           │ supabase-dart │ video SDK    │ WebView/iframe
                           ▼               ▼              ▼
                ┌──────────────────┐  ┌──────────┐  ┌──────────┐
                │    Supabase      │  │Cloudflare│  │ Desmos   │
                │ Auth · Postgres  │  │ R2 (HLS) │  │ API (JS) │
                │ Storage · Edge Fn│  └──────────┘  └──────────┘
                │ Realtime · Cron  │
                └──┬────┬────┬─────┘
                   │    │    │
        webhooks   │    │    │ HTTPS
   ┌───────────────┘    │    └───────────────┐
   ▼                    ▼                    ▼
┌────────┐       ┌────────────┐        ┌──────────┐
│ Paymob │       │ LLM API    │        │ Email    │
│ payments│      │ (AI tutor) │        │ (Resend) │
└────────┘       └────────────┘        │ FCM push │
                                       └──────────┘
```

Offline / internal: **Content pipeline** (Python scripts + LLM) turns teacher PDFs into reviewed
question JSON → imported via the teacher area. See 09.

## 2. Technology choices (summary — rationale in ADRs)

| Concern | Choice | ADR |
|---------|--------|-----|
| Client | Flutter 3.x, single codebase: web (CanvasKit), Android, iOS | ADR-001 |
| State mgmt | Riverpod (or BLoC — developer's choice, be consistent) | — |
| Architecture | Clean Architecture, feature-first folders | — |
| Backend | Supabase: Postgres 15+, Auth, Storage, Edge Functions (Deno/TS), pg_cron, Realtime | ADR-001 |
| Video | MVP: AES-128 encrypted HLS on Cloudflare R2 + Flutter watermark overlay; upgrade: VdoCipher DRM behind `VideoSource` | ADR-002 |
| Payments | Paymob (cards incl. international, wallets) + activation codes | ADR-003 |
| Calculator | Desmos API, commercial plan, loaded in WebView/iframe | ADR-004 |
| AI tutor | LLM via Edge Function, grounded on stored solutions | ADR-005 |
| Math rendering | LaTeX via `flutter_math_fork` (inline + block) | — |
| PDF viewing | `pdfrx` (or equivalent) with watermark overlay, signed URLs | — |
| Email | Resend (or Postmark) | — |
| Push | Firebase Cloud Messaging | — |
| Errors / analytics | Sentry · PostHog; Firebase only for FCM + App Check | ADR-008 |
| Web hosting | Cloudflare Pages (static Flutter web build) | ADR-009 |
| Distribution | Web first; Android + iOS per ADR-006 | ADR-006 |

## 3. Client architecture

```
lib/
  core/            # theme, router, env, errors, network, math_render, secure_screen
  features/
    auth/          # data · domain · presentation
    catalog/
    checkout/
    course_map/
    topic/         # stepper, unlock state
    video/
    notes/
    practice/
    assessment/    # shared player for homework/quiz (mode param)
    exam/          # Bluebook simulator (mock) — isolated, heavy
    analytics/
    ai_tutor/
    live/
    teacher/       # all admin screens, behind role guard
  shared/widgets/
```

- **Router:** `go_router` with role guards; teacher routes code-split/deferred on web.
- **Question rendering:** one `QuestionView` widget (stem Markdown+LaTeX, images, MCQ/SPR input) reused by practice, homework, quiz, mock.
- **Offline tolerance:** Outbox pattern — answers queued locally (`hive_ce`) with `client_seq` and flushed by `AttemptSyncService`; server is the source of truth (16 §3).
- **Secure screen:** platform channel — Android `FLAG_SECURE`; iOS: detect `UIScreen.capturedDidChange` / screenshot notification → blur + log.

## 4. Backend architecture (Supabase)

**Rule of thumb**
- Plain reads/writes of a user's own rows → direct PostgREST with **RLS**.
- Anything involving answer keys, money, unlocking, scoring, or third-party secrets → **Edge Function** or `SECURITY DEFINER` Postgres function. Clients never read answer keys.
- Secrets and internal helpers live in the non-exposed **`private` schema** (`private.question_keys`, `private.rate_limits`, analytics materialized views, RPC-internal helpers). RLS policy helpers (`is_teacher()`, `has_access()`) stay in `public` because policies run as the caller. New functions are not executable until explicitly granted (16 §1).

| Component | Responsibility |
|-----------|----------------|
| Postgres + RLS | All data; policies per role (06 §4) |
| RPC functions (SQL) | `start_attempt`, `save_answer`, `submit_attempt`, `compute_unlocks`, analytics aggregation |
| Edge Functions | Three "fat" functions (16 §8): `api` (Hono router: checkout, redeem-code, video-otp, pdf-url, register-device, import-questions, assemble-mock, send-email/push helpers) · `payment-webhook` · `ai-tutor` (streaming) |
| Storage buckets | `notes` (private), `question-images` (public-read via CDN, unguessable paths), `book` (private) |
| pg_cron | nightly analytics rollups, inactivity nudges, access expiry, cleanup |
| Realtime | teacher dashboard live updates (optional) |

## 5. Key sequence diagrams

### 5.1 Purchase
```
Client            create-checkout(EF)       Paymob            payment-webhook(EF)      DB
  │──start(course,coupon)──▶│                  │                     │                  │
  │                         │──order+intention▶│                     │                  │
  │◀──payment URL/token─────│                  │                     │                  │
  │────────────────pay──────────────────────▶ │                     │                  │
  │                         │                  │──signed callback──▶ │──verify HMAC────▶│
  │                         │                  │                     │  upsert order    │
  │                         │                  │                     │  create enrolment│
  │◀──────────────── realtime / poll "enrolled" ───────────────────────────────────────│
```

### 5.2 Video playback
```
Client ──(topic_video_id)──▶ video-otp(EF): check enrolment & access window
                              → signed R2 playlist URL + key URL (TTL ≤ 5 min)
       ◀── playbackInfo ──
Client plays encrypted HLS with watermark overlay; progress → save_video_progress RPC every 15 s
(upgrade path: video-otp returns a VdoCipher OTP instead — same client interface)
```

### 5.3 Assessment (homework/quiz/mock)
```
start_attempt(kind, topic) → server draws questions (no keys) → attempt_id + questions
save_answer(attempt_id, q, answer, time_ms)  (autosave, idempotent)
submit_attempt(attempt_id) → grade server-side → write results → update mastery
   → compute_unlocks → return report (now includes keys + explanations)
```

## 6. Environments

| Env | Supabase project | Web URL | Payments | Video |
|-----|------------------|---------|----------|-------|
| dev | local (`supabase start`, Docker) | localhost | Paymob test mode | R2 dev bucket |
| staging | `sat-staging` (free tier, separate Supabase account, keep-alive cron) | Cloudflare Pages URL | Paymob test mode | R2 staging bucket |
| prod | `sat-prod` (Pro + PITR) | custom domain | live | live |

Secrets only in Supabase Edge Function secrets / CI secrets — never in the Flutter bundle
(except Supabase anon key and public Desmos/analytics keys, which are designed to be public).

## 7. Capacity estimate (year 1)

- Students: assume ≤ 2,000 total, ≤ 300 concurrent at peak (pre-exam weekends).
- Answers: 2,000 students × ~3,000 answers = ~6M `attempt_answers` rows/year → fine for Postgres with indexes; partition by month only if > 50M.
- Video: dominant cost; billed by bandwidth on the host.
- Supabase Pro tier is sufficient for year 1.

## 8. What to revisit as it grows
- Analytics aggregation moving from on-submit triggers to a queue if submit latency > 500 ms.
- Multi-teacher (tenant_id) if the business expands — keep `course.owner_id` from day one.
- Self-hosted Desmos (Enterprise) if Desmos-hosted latency is an issue.
