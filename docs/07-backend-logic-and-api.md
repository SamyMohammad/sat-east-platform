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
| `save_video_progress` | p_asset_id uuid, p_from_s int, p_to_s int, p_position_s int | `{pct,done}` | LRN-02; ready video in accessible open/completed topic, allowed device; clamps seconds to 0..duration; rejects reversed spans or raw spans above 2 × settings.video_progress_interval_s + 5; merges ranges, floors covered seconds / duration × 100; done at settings.video_done_pct; no client pct |
| `video_playback_grant` | p_asset_id uuid | `{ok:true,provider:'youtube',youtube_id,resume_s}` or `{ok:true,provider:'r2_hls',asset_id,user_id,watermark:{name,short_id},key_ttl_s,playlist_ttl_s,resume_s}` or `{ok:false,error:'rate_limited'}` | SEC-01; caller-context auth, ready video + has_access_topic, practice_access (open/completed), device, provider checks; unknown/unready/no-access raises forbidden; settings.rate_video_otp_per_min (30) per user, counted without raising; name from profiles.full_name, short_id is first 6 UID hex characters uppercase; EF signs token; no keys returned |
| `teacher_video_quota` | none | `{used_mb,cap_mb}` | C-2; teacher only; all video reservations count, including pending; cap from settings.video_storage_cap_mb (9216) |
| `teacher_video_upload_grant` | p_asset_id uuid | `{r2_prefix,ttl_s}` | C-2 / SEC-01; teacher only; pending kind=video, provider=r2_hls required, otherwise invalid_input; canonical videos/asset_id prefix; TTL from settings.video_upload_url_ttl_s (900); authenticated execute only |
| `service_video_key` | p_asset_id uuid | `{key_hex,r2_prefix}` or null when no row exists | SEC-01; service_role execute only; anon and authenticated denied; api Edge Function calls after verifying a playback token; security definer reads private.video_keys without granting API roles usage on private |
| `teacher_create_video_asset` | p_topic_id uuid, p_subtopic_id uuid, p_title text, p_duration_s int, p_size_mb int | `{ok:true,asset_id}` or `{ok:false,error:'quota_exceeded',used_mb,cap_mb}` | C-2; teacher only; locks cap setting before summing all videos; exactly at cap allowed; reserves ready=false r2_hls asset; trimmed title 1-120, positive duration, nonnegative size, optional subtopic in topic; audited |
| `teacher_confirm_video_asset` | p_asset_id uuid, p_key_hex text | `{ok:true}` | C-2 / SEC-01; teacher only; 32 hex characters decoded into private.video_keys, r2_prefix videos/asset_id; marks ready; same-key retry is a no-op, changed key rejected; audit contains asset metadata only |
| `teacher_add_youtube_video` | p_topic_id uuid, p_subtopic_id uuid, p_title text, p_youtube_id text, p_duration_s int | `{ok:true,asset_id}` | C-2; teacher only; YouTube ID exactly 11 characters from A-Z, a-z, 0-9, underscore or dash; ready=true, size_mb=0; same title/duration/subtopic validation; audited |
| `teacher_update_video` | p_asset_id uuid, p_title text, p_subtopic_id uuid | `{ok:true}` | C-2; teacher only; rename and set/clear subtopic in same topic; audited |
| `teacher_reorder_videos` | p_topic_id uuid, p_ids uuid[] | `{ok:true}` | C-2; teacher only; all video IDs including pending, exactly once; atomic sort 1..n; audited |
| `teacher_list_videos` | p_topic_id uuid | `[{asset_id,title,subtopic_id,subtopic_title,duration_s,size_mb,provider,youtube_id,ready,sort}]` | C-2; teacher only; includes pending, sort/id order; no keys |
| `teacher_video_prefix` | p_asset_id uuid | `{provider,r2_prefix}` | C-2; teacher only; canonical videos/asset_id for r2_hls, null prefix for YouTube; works for pending reservations |
| `teacher_delete_video` | p_asset_id uuid | `{ok:true}` | C-2; teacher only; deletes progress, chapters, private key and asset; audited; EF removes R2 objects first |
| `get_practice_questions` | topic_id | `attempt_id`, `rep_target`, questions (`id`, `type`, `difficulty`, `stem_md`, `choices[label, body_md]`; no keys, explanations, hints or misconceptions) | PRC-01; creates a `practice` attempt; draws `settings.practice_min` published practice-pool questions, never-seen first then random (fewer if the pool is smaller); errors `not_authenticated`, `invalid_input`, `not_enrolled`, `access_expired`, `topic_locked`, `pool_exhausted`; subtopic/difficulty filters later; per-user quota `settings.rate_start_per_min` per minute; quota exceeded returns `rate_limited`; video_needed checked before notes_needed; both gates exempt finished students (practice_count >= settings.practice_min or quiz_passed_at set) |
| `start_review` | p_topic_id uuid | `attempt_id`, `rep_target`, `questions` (same safe shape as get_practice_questions), `answered` (final question ids) | LRN-04 (L-7); resumes the current review or draws settings.review_per_skill (default 2) published practice questions per missed skill, capped at settings.review_max (default 10), unseen first; fills shortages from the topic practice pool; untagged misses get one review_per_skill batch; errors `not_authenticated`, `invalid_input` (review not required), `not_enrolled`, `access_expired`, `topic_locked`, `pool_exhausted`, `rate_limited`; per-user quota `settings.rate_start_per_min` per minute |
| `check_practice_answer` | attempt_id, question_id, answer, time_ms | `is_correct`, `try`; correct or wrong try 2: `key` (`{choice}` / `{text}` = first accepted form) + `explanation_md`; wrong try 1: `hint_md`, `misconception_md` for the chosen MCQ choice (always null for SPR) | PRC-01/04, LRN-02/04; accepts own in-progress practice or review attempts; submitted reviews allow saved-answer replay only; review answers never increase practice_count; the last final answer (correct or try 2) submits a review; server decides reveal (no `reveal` param); tries stored in `attempt_answers.answer.tries`; an answer equal to the last try is replayed (nothing logged); a third try → `invalid_input`; `practice_count` +1 on try 1 of a question never answered in practice before; spec `2026-10-17-p1-practice-design.md` §1.4; question must belong to the attempt's topic; per-user quota `settings.rate_answer_per_min` per minute; quota exceeded returns `rate_limited`; video_needed checked before notes_needed; both gates exempt finished students (practice_count >= settings.practice_min or quiz_passed_at set) |
| `get_topic` | topic_id | `id`, `title`, `slug`, `sort_label`, `status` (`open`/`completed`), `notes: [{asset_id,title,subtopic_title,page_count}]`, `notes_done`, `videos: [{asset_id,title,subtopic_title,duration_s,provider,pct,last_position_s}]`, `video_done`, `practice: {count,min}`, `homework: {state,attempt_id?,score_pct?,total?,answered?}`, `quiz: {state,practice_count,practice_min,best_score_pct,passed,attempt_id?,available_at?,review:{required,attempt_id,answered,total}}` | PRC-03; quiz state priority: in_progress, practice_needed, homework_needed, review_needed, cooldown, available; homework states: locked_by_practice, available, in_progress, submitted, skipped (no published practice pool or prior quiz pass); review_needed includes available_at while cooldown runs; lazy expiry before active-access/lock check; ready notes only, ordered by sort/id; notes_done is true after any first open, when no ready notes exist, or for finished students; videos includes ready assets in sort/id order; video_done requires every ready video at settings.video_done_pct, no ready videos, or finished practice/quiz exemption |
| `start_homework` | p_topic_id uuid | `{attempt_id,title,questions:[{id,type,difficulty,stem_md,choices:[{label,body_md}]}],answers:[{question_id,answer,marked}],client_seq}` | PRC-02/05; one untimed attempt per student/topic, concurrent starts serialized; resumes saved answers and marks; practice_access and video/notes gates, then settings.practice_min; published practice pool, not answered in practice first, then oldest exposure, random ties; capped at settings.homework_size; no grading content; errors not_authenticated, invalid_input, not_enrolled, access_expired, topic_locked, video_needed, notes_needed, practice_needed, attempt_closed (already submitted), pool_exhausted (zero draw) |
| `start_quiz` | topic_id | `attempt_id`, `title`, `time_limit_s`, `deadline`, `server_now`, `warn_s`, `questions[{id,type,difficulty,stem_md,choices[{label,body_md}]}]`, `answers[{question_id,answer,marked}]`, `client_seq` | PRC-03; quiz entry point (generic start_attempt is deferred); resumes the same in-progress attempt; draws settings.quiz_size published quiz-pool questions, unseen first; practice_needed/homework_needed/review_needed/cooldown_active gates; review is required after a fail until completed, unless the topic quiz was passed; teacher unlock does not bypass review; no grading content; per-user quota `settings.rate_start_per_min` per minute; quota exceeded returns `rate_limited` |
| `save_answer` | attempt_id uuid, question_id uuid, answer text, time_ms int, marked boolean, eliminated text[], client_seq int | `{ok:true}` or `{ok:true,stale:true}` | PRC-03/04; own in-progress quiz or homework; homework has no deadline; null clears answer; >32 characters invalid; total time clamped to 0..3600000; sequence less than or equal to stored ignored; quiz-only lazy expiry before active-access check; quiz after deadline + settings.save_grace_s returns deadline_passed; no grading until submit; per-user quota `settings.rate_save_per_min` per minute; quota exceeded returns `rate_limited` |
| `submit_attempt` | attempt_id uuid | `{score_raw,score_total,score_pct,pass_mark,passed,skills:[{code,name,correct,total}],next_topic:{id,title} \| null,retake_at}` | PRC-02/03, LRN-03; accepts quiz and homework; homework returns `{attempt_id,kind:'homework',score_raw,score_total,score_pct}`, persists homework progress and meta.report, single submission with idempotent replay, no pass/fail, cooldown, unlock or practice_count change; quiz grades saved MCQ/SPR, unanswered wrong; quiz report includes per-skill counts (ANL-02); stores report for idempotent replay; updates best/pass/failure timestamps; topic_states implicitly unlocks next topic; lazy expiry before active-access check; no keys or answer review; mastery later; per-user quota `settings.rate_submit_per_min` per minute; quota exceeded returns `rate_limited` |
| `get_my_skills` | p_course_id uuid | `{summary:{solved,total,graded_answers,trend_min_answers}, skills:[{code,name,domain,mastery,attempts,band}], weak:[{code,name,mastery,topic_id,topic_title}], trend:[{week_start,mastery}], topics:[{topic_id,title,unit_title,solved,total,level}]}` | ANL-01 / S-24; aggregates only — no question ids, content, answers or keys; bands per §5; weak = up to 3 lowest `weak` skills, each with the course topic holding most of its practice questions; errors `not_authenticated`, `not_enrolled`, `access_expired`; executable by `authenticated`, not `anon` |
| `get_attempt_review` | p_attempt_id uuid | `{summary:{score_raw,score_total,score_pct,pass_mark,passed,keys_visible,skills:[{code,name,correct,total}]}, questions:[{id,type,stem_md,choices:[{label,body_md}],my_answer,is_correct,time_ms,skills:[{code,name}],key?,explanation_md?}]}` | PRC-02/03; own submitted quiz or homework; homework keys_visible is true after submission, pass_mark/passed are null; questions ordered by frozen position; summary uses the stored report plus live per-skill counts from attempt questions and answers (ANL-02); key (`{choice}` / `{text}` = first accepted SPR form) and explanation_md are absent unless it is submitted homework or the owner has passed this topic's quiz, including on earlier failed quiz attempts; teacher unlock is not a pass; errors `not_authenticated`, `invalid_input` (null/unknown/unsupported kind), `forbidden` (another owner's attempt), `attempt_not_submitted`; executable by `authenticated`, not `anon` |
| `register_device` | fingerprint, platform?, label? | `ok` + device_id, or `limit_reached` + devices + changes_left | called by the `register-device` EF (§8) |
| `remove_device` | device_id | changes_left | `device_limit` when the 30-day allowance is used (§8) |
| `list_my_devices` | p_fingerprint text | `{devices: [{id, label, platform, last_seen_at, created_at, is_current}], changes_left}` | AUTH-04; authenticated only; caller's non-revoked devices ordered by `last_seen_at desc nulls last`, then `created_at desc`; `is_current` matches the supplied fingerprint, which is never returned; allowance uses `device_changes_30d` minus the caller's changes strictly within the last 30 days, clamped to zero (same allowance as `remove_device`); errors `not_authenticated`, `invalid_input` (null/blank fingerprint) |
| `device_status` | fingerprint | `active` / `revoked` / `unknown` | polled every minute (§8) |
| `redeem_activation_code` | p_code text, p_target_test_date date | `{ok:true, course_id, course_slug, course_title, target_test_date, expires_at}` or `{ok:false, error}` | PAY-06/07; authenticated only; trims, uppercases and removes dashes/spaces; published courses only; locks the code and creates one active enrollment atomically; any existing enrollment status blocks reuse of the course; returned errors `code_invalid`, `code_used`, `already_enrolled` retain the quota increment; raised errors `not_authenticated`, `invalid_input`, `rate_limited`; per-user `settings.rate_redeem_per_min` (5) per minute; test date from yesterday through today + `settings.test_date_max_days` (548), inclusive; access window in §7 |
| `teacher_list_devices` / `teacher_revoke_device` / `teacher_reset_devices` | user_id / device_id / user_id | devices / ok / ok | teacher only, audited (AUTH-05) |
| `tag_error_type` | attempt_id, question_id, error_type | ok | |
| `teacher_unlock_topic` | p_student_id uuid, p_topic_id uuid | `{topic_id, unlocked_at, unlocked_by}` | LRN-05 (L-9); teacher only; target must be a student and topic must be published; preserves existing progress and the first unlock timestamp/teacher; audits `topic.unlock` only on the first unlock; errors `not_authenticated`, `forbidden`, `invalid_input`; executable by `authenticated`, not `anon` |
| `mark_notes_opened` | p_asset_id uuid | `{notes_opened_at}` | L-3; ready notes in an accessible open/completed topic only; idempotently preserves the first timestamp and other progress; errors invalid_input, not_enrolled, access_expired, topic_locked |
| `teacher_create_notes_asset` | p_topic_id uuid, p_subtopic_id uuid, p_title text, p_page_count int | `{asset_id,path}` | C-3; teacher only; pending notes asset appended to topic; optional subtopic must belong to topic; trimmed title 1-120 chars, positive page count; canonical path topic_id/asset_id.pdf |
| `teacher_confirm_notes_asset` | p_asset_id uuid | `{ok:true}` | C-3; teacher only; notes object must exist in private notes bucket, else invalid_input; marks ready; repeated confirmation is a no-op |
| `teacher_update_notes_asset` | p_asset_id uuid, p_title text, p_subtopic_id uuid | `{ok:true}` | C-3; teacher only; rename and set/clear subtopic within the same topic |
| `teacher_reorder_notes` | p_topic_id uuid, p_ids uuid[] | `{ok:true}` | C-3; teacher only; IDs must match all notes assets, including pending ones, exactly once; atomic sort 1..n |
| `teacher_delete_notes_asset` | p_asset_id uuid | `{ok:true}` | C-3; teacher only; deletes notes metadata; client removes the Storage object first |
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
| `report_question` | p_question_id uuid, p_reason text, p_note text | `{ok:true,report_id,existing}` or `{ok:false,error:'rate_limited'}` | C-6 / QB-04; authenticated only; published question and has_access_topic required; one open report per student/question; existing reports are returned unchanged; settings.rate_report_per_min per minute, including duplicate and rejected-over-quota calls; invalid input/access raises invalid_input before counting |
| `teacher_list_review_queue` | p_section text, p_page int | `{total,page,page_size,rows:[{question_id,external_ref,stem_preview,status,open_count,oldest_report_at,reasons,latest_note}]}` | C-6 / QB-08 / T-08; teacher only; section reported or needs_review; one-based pages sized by bank_page_size; open count descending, oldest report ascending (nulls last), question id; first-line stem preview; reasons is a reason-to-count object; latest_note is the latest nonempty open-report note |
| `teacher_list_question_reports` | p_question_id uuid | `[{report_id,reason,note,created_at,full_name}]` | C-6 / T-08; teacher only; open reports only, oldest first then report id; full_name is the reporting student's profile name; unknown question raises invalid_input |
| `teacher_resolve_reports` | p_question_id uuid, p_outcome text, p_note text | `{closed:n}` | C-6 / T-08; teacher only; fixed or dismissed; closes all and only the question's open reports, records resolved_at/resolved_by/teacher_note; leaves question status unchanged; one question_reports.resolve audit row with only outcome and closed count |
| `teacher_review_counts` | none | `{reported,needs_review}` | C-6 / QB-08 / T-08; teacher only; reported counts questions with open reports; needs_review counts questions with that status, including those without reports; a question may appear in both tabs |

Teacher-only `teacher_*` RPCs may read/write keys for the teacher only.

Question-report reasons are `answer_key`, `typo`, `math_display`, `other`. Student and teacher notes are optional plain text, trimmed, at most 500 characters; blank notes become null. Direct student inserts are denied; the existing select-own policy remains. Quota errors are returned without raising, retaining the private counter increment, including over-quota calls. Statuses are `open`, `resolved_fixed`, `resolved_dismissed`.

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
| `video-otp` | Planned L-2a EF: POST /api/video-otp {asset_id}; JWT → App Check → caller video_playback_grant; YouTube returns provider/youtube_id/resume_s; R2 returns provider/hls_url/expires_at/watermark {name,short_id}/resume_s. URL uses SUPABASE_URL; token carries iat, playlist TTL settings.video_playlist_ttl_s |
| `v/*` | Planned L-2a EF: GET /api/v/:token/master.m3u8, /:name.m3u8 and /key; signed path token; playlists/segments use playlist TTL, key also enforces settings.video_key_ttl_s since iat; after token verification, service-role-only public.service_video_key returns key_hex/r2_prefix for server-side hex decoding; key and playlists no-store; segment GETs presigned; restricted filenames and CORS |
| `teacher/video-delete` | Planned L-2a EF: POST /api/teacher/video-delete {asset_id}; JWT → caller teacher_video_prefix → R2 list/delete under prefix → caller teacher_delete_video; R2 failure returns internal and preserves DB row for retry; CORS |
| `teacher/video-upload-urls` | POST /api/teacher/video-upload-urls {asset_id,files}; JWT, UUID and 1-2000 unique file names validated before caller teacher_video_upload_grant; names match `^[A-Za-z0-9_-]{1,64}\.(m3u8\|ts)$` and include master.m3u8; returns `{urls:{file:url},expires_in}` with presigned PUT URLs beneath the granted prefix and configured TTL; teacher CORS, no-store; storage secrets remain server-side |
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

Notes (L-3): the private `notes` Storage bucket accepts PDFs only, limited by
`settings.notes_max_mb` (20 MB, applied to the bucket at migration time). Paths are
`<topic_id>/<asset_id>.pdf`; Storage RLS requires active course access, an open/completed
topic and a ready asset, or the teacher role. Pending notes are hidden from students.
Opening any ready notes once completes the notes step; topics without ready notes skip it.
Teacher notes writes are audited as `notes.create`, `notes.confirm`, `notes.update`,
`notes.reorder` and `notes.delete`. All six new RPCs require authentication; the five
teacher RPCs also enforce teacher role. Only `authenticated` can execute them.

Homework (PRC-02): after the practice minimum, one untimed, autosaved set is available.
Submission completes the step regardless of score and is required before the quiz. Skip
homework when the topic has no published practice questions or the student already passed
its quiz. Answers do not increase practice_count. Submit returns scores only; full keys and
explanations are available only through get_attempt_review after submission. Homework has
no retakes, cooldown, deadline or topic unlock.

## 3. Question drawing rules

| Kind | Pool | Count | Selection |
|------|------|-------|-----------|
| practice | practice | on demand | filter subtopic/difficulty; unseen first, then oldest-seen |
| homework | published practice | up to `settings.homework_size` (20), fewer if pool is smaller | not answered in practice first, then oldest exposure (`question_exposure.first_seen_at`, unseen first), random ties; frozen at start_homework; E/M/H blueprint and subtopic coverage deferred |
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
- Implemented in `private.apply_mastery` (one function, so it can be tuned). Every number is a `settings` key: `mastery_alpha`, `mastery_weights` (by attempt kind; `review` uses the practice weight, `mock_module` the mock weight), `mastery_difficulty`, `mastery_start`, `mastery_weak_below`, `mastery_min_attempts`, `mastery_trend_min_answers`.
- Counted once per graded answer: practice/review on the **first try only** (trigger on the `attempt_answers` insert; the second try and a reveal do not move mastery); quiz/homework when the attempt moves to `submitted` (unanswered = incorrect). A one-off backfill replayed earlier answers.
- Bands (ANL-01 Skills screen): **thin** = fewer than `mastery_min_attempts` answers; **weak** < `mastery_weak_below` (50); **strong** ≥ `pass_mark` (75); otherwise **building**.
- Each update also upserts `skill_mastery_daily` for the trend (weekly mean, last 8 weeks; empty below `mastery_trend_min_answers` graded answers or with fewer than 2 weeks).
- Not built yet: "slow" flags (avg_time_ms > 1.5 × skill median) and the optional nightly decay toward 50 for skills untouched > 30 days.

## 6. AI tutor (ADR-005)

```
Client: ask(question_id, attempt_id?, message)
EF ai-tutor:
  1. Auth; check attempt is submitted (or practice answered); refuse if an active quiz/mock exists
  2. Rate limit: settings.ai_daily_cap (default 20 msgs/day)
  3. Load: stem, choices, key, explanation_md, student's answer, subtopic notes excerpt
  4. System prompt: "You are the teacher's assistant. Explain ONLY using the provided solution.
     If the student's question goes beyond it or you are unsure, say so and offer to escalate.
     Never invent a different final answer. Answer in English only; the product targets international schools."
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
`video_needed` (a ready video is below settings.video_done_pct; exempt when practice_count >= settings.practice_min or quiz_passed_at is set; checked before notes_needed),
`notes_needed` (ready notes exist but notes_opened_at is null; exempt when practice_count >= settings.practice_min or quiz_passed_at is set, which also makes get_topic.notes_done true),
`practice_needed` (practice_count below settings.practice_min), `homework_needed` (submit homework before starting the quiz; exempt when no published practice questions or quiz already passed), `review_needed` (finish the review set before a quiz retake), `attempt_not_submitted` (quiz/homework review requires a submitted attempt), `attempt_closed`, `deadline_passed`, `device_limit`, `device_revoked`, `cooldown_active`, `pool_exhausted`,
`quota_exceeded` (video reservation exceeds settings.video_storage_cap_mb; returned with used_mb and cap_mb, never raised),
`rate_limited`, `payment_invalid`, `code_invalid` (unknown code or unpublished course),
`code_used` (already redeemed), `already_enrolled` (any existing enrollment for the course),
`invalid_key` (malformed answer key — content error), `internal` (Edge Functions only — unexpected failure).

`redeem_activation_code` returns `code_invalid`, `code_used` and `already_enrolled` inside
`{ok:false,error}`; these are successful SQL transactions that retain the rate-limit increment.
Its authentication, input-validation and rate-limit errors are raised with the code as the message.

Client-only codes (GoTrue / transport; never returned by an RPC or Edge Function):
`invalid_credentials`, `email_not_confirmed`, `email_taken`, `weak_password`, `network`. `rate_limited` is reused for GoTrue rate limits.
