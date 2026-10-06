# 10 — Non-Functional Requirements

| ID | Category | Requirement | Target / how measured |
|----|----------|-------------|-----------------------|
| NFR-01 | Performance | Question load in practice/exam | p95 < 500 ms after first load |
| NFR-02 | Performance | `submit_attempt` incl. grading + analytics | p95 < 1.5 s for 44 questions |
| NFR-03 | Performance | Web first meaningful paint on 4G | < 4 s; teacher area + exam engine deferred-loaded |
| NFR-04 | Reliability | No answer lost on disconnect | Autosave per answer; local queue; resume test |
| NFR-05 | Reliability | Exam timer integrity | Deadline stored server-side; client clock never trusted |
| NFR-06 | Availability | Uptime | 99.5% monthly (managed services) |
| NFR-07 | Security | Answer keys never on client before submit | Automated test inspects network payloads (12) |
| NFR-08 | Security | RLS on every table; no table without a policy | CI check query on `pg_tables` / `pg_policies` |
| NFR-09 | Security | Secrets only server-side | No service-role / gateway / LLM keys in client bundle (CI grep) |
| NFR-10 | Security | Payment webhooks verified + idempotent | HMAC check, unique txn id |
| NFR-11 | Content protection | Encrypted HLS video (DRM upgrade path), watermark, signed PDF URLs (≤ 5 min), secure screen on mobile | See SEC-* |
| NFR-12 | Privacy | Most students are minors | Collect minimum data; privacy policy; parent contact optional; no selling data; delete account on request |
| NFR-13 | Privacy | AI conversations | Stored for quality; disclosed in privacy policy; not used to train third-party models (check provider settings) |
| NFR-14 | Accessibility | Readable math, contrast, font scaling | WCAG AA contrast; LaTeX scales with text size; keyboard navigation in exam on web |
| NFR-15 | Responsiveness | 360 px → 1920 px | All student screens tested at 360, 768, 1280 |
| NFR-16 | Time zones | Students worldwide | Store UTC; show in user's time zone (live sessions, deadlines) |
| NFR-17 | Localisation | UI English; content may contain Arabic | Text widgets support mixed RTL/LTR in notes/AI replies |
| NFR-18 | Observability | Errors and key events | Sentry for crashes; product events: signup, purchase, step_complete, quiz_pass/fail, mock_complete |
| NFR-19 | Backups | DB | Supabase daily backups + PITR on prod; weekly export of question bank to storage |
| NFR-20 | Cost | Monthly infra visible to teacher | Dashboard/notes of Supabase, video, Desmos, LLM, email costs; alert thresholds |
| NFR-21 | Maintainability | Config not code | Pass marks, limits, pools, blueprints in `settings`/DB |
| NFR-22 | Auditability | Teacher actions | `audit_log` for unlocks, grade changes, key edits, enrollment edits |
