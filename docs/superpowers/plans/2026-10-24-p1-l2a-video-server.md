# L-2a — protected video: server (SEC-01, LRN-02, C-2) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

## Context

Students need protected topic videos at zero hosting cost, using Cloudflare R2's free tier, with encrypted 540p HLS and a 9 GB cap enforced by the app. L-2 ships as 3 PRs. **This plan covers L-2a, the server side only:**
- the DB schema, RPCs and video gate;
- the `api` Edge Function routes that mint playback tokens, serve playlists and the key, and delete R2 objects.

L-2b (the CLI) and L-2c (the client) get their own plans afterwards.

**Spec:** `docs/superpowers/specs/2026-10-24-p1-l2-video-design.md`. The user said "ابدأ", then "go". **Its Amendments A1–A9 override the body.**
**Worktree:** `C:/Users/Lenovo/sat-wt-lane3`, branch `feat/P1-l2-video` (spec commits `22a1cbc`, `39171b4`).
**Implementer:** Codex via `codex-delegate` (new session), tests first. Claude runs the gates and commits. The PR stays a **draft until CI is green**.

## Global constraints

- CLAUDE.md rules 1–10, A, B; `docs/16` §2; SQL from `supabase/templates/`.
- pgTAP: `reset role;` after `clear_authentication`. No `$$` inside function bodies.
- **Reserved:**
  - migration `20261030100000_l2a_video.sql`;
  - pgTAP `40_video.test.sql`;
  - settings `video_storage_cap_mb` 9216, `video_key_ttl_s` 300, `video_playlist_ttl_s` 14400, `video_progress_interval_s` 15, `rate_video_otp_per_min` 30;
  - error code `video_needed`.
- **Reuse:**
  - `private.setting_int`, `private.hit_rate_limit` (return-don't-raise pattern, as in `redeem_activation_code`);
  - `public.has_access_topic`, `private.practice_access` (topic open), `private.device_allowed()`, `public.is_teacher()`;
  - `audit_log` insert pattern, the notes create/confirm pattern (`20261027100000_l3_notes.sql` lines 99–215);
  - `private.notes_satisfied` (`20261028100000_notes_gate_exempt.sql`), `appCheckGate` (`supabase/functions/_shared/app_check.ts`).
- **Port from the spike** (`spikes/video-hls/server/`): `token.ts`, plus `iat`; `playlist.ts`; `R2Storage` from `storage.ts`, plus `list` and `delete`. Move them into `supabase/functions/api/video/`. `aws4fetch@1.0.20` is the only new dependency; the spike already justified it.
- Don't touch the spike folder or `tools/video-pipeline`. Never log tokens, keys or presigned URLs.

## Review focus

1. **Keys.**
   - `private.get_video_key(asset_id)` (security definer) is executable by `service_role` only. pgTAP checks that `authenticated` and `anon` can't run it.
   - The key route runs only with a valid `p` token, checks `now - iat ≤ video_key_ttl_s`, and responds with `no-store`.
   - Teacher audit rows never contain `key_hex`.
2. **Quota.** `teacher_create_video_asset` locks the cap (`select … for update` on `settings` where `key='video_storage_cap_mb'`). It sums `size_mb` over **all** video rows, ready or not, and returns `{ok:false,error:'quota_exceeded', used_mb, cap_mb}` past the cap. pgTAP: exactly at the cap is ok, one MB over is refused.
3. **Grant.** `video_playback_grant(asset_id)` runs as the caller and checks, in order:
   - auth;
   - the asset exists, is a ready `video`, and `has_access_topic`;
   - the topic isn't locked (`practice_access`);
   - `device_allowed()`;
   - the provider.
   
   For `youtube` it returns `{provider:'youtube', youtube_id}` and no token. Unknown or unready assets give `forbidden`, so asset existence isn't revealed.
4. **Progress.** `save_video_progress(asset_id, from_s, to_s, position_s)` clamps to `[0, duration_s]` and rejects `to < from` or a span over 2× `video_progress_interval_s` + 5 (`invalid_input`). It merges into `watched_ranges` with `range_agg`/multirange and computes `pct = covered / duration_s`. It returns `{pct, done}`. The client never sends `pct`.
5. **Gate.** `private.video_satisfied(uid, topic)` is true when:
   - the topic has no ready video, or
   - every ready video has `pct ≥ video_done_pct`, or
   - the student finished it (`practice_count ≥ practice_min` or `quiz_passed_at`).
   
   `private.require_notes_opened` is redefined: video first (`video_needed`), then notes. `get_topic` (copied from `20261028100000`) adds `videos[]` (`asset_id, title, subtopic_title, duration_s, provider, pct, last_position_s`) and `video_done`.
6. **EF.**
   - `config.toml` `[functions.api] verify_jwt=false`; `/register-device` still verifies itself.
   - CORS on `/video-otp`, `/v/*`, `/teacher/video-delete`.
   - URLs built from `SUPABASE_URL`.
   - Segment lines are rewritten to presigned R2 GETs (TTL = `video_playlist_ttl_s`).
   - Path params are regex-limited, so no traversal.

---

### Task 0: Land the plan (Claude)
- [ ] Copy this plan to `docs/superpowers/plans/2026-10-24-p1-l2a-video-server.md` and commit it.

### Task 1: DB (Codex)

**Create:** the migration and `supabase/tests/40_video.test.sql`.

The migration:
- **Columns:** alters `topic_assets` to add `provider text check (provider in ('r2_hls','youtube'))` and `size_mb int check (size_mb >= 0)`, with column grants to `authenticated` for `provider`, `size_mb`, `duration_s`.
- **RLS:** recreates the student policy so `kind='video'` also requires `ready`.
- **Settings:** the 5 settings above.
- **Helpers:** `private.get_video_key` (returns `key`, `r2_prefix`) and `private.video_satisfied`; redefines `private.require_notes_opened` and `get_topic`.
- **Teacher RPCs:**
  - `teacher_video_quota()`
  - `teacher_create_video_asset(topic_id, subtopic_id, title, duration_s, size_mb)`
  - `teacher_confirm_video_asset(asset_id, key_hex)`: 32 hex characters, otherwise `invalid_input`; `r2_prefix = 'videos/'||id`
  - `teacher_add_youtube_video(topic_id, subtopic_id, title, youtube_id, duration_s)`: `youtube_id` must match `^[A-Za-z0-9_-]{11}$`; `ready=true`, `size_mb=0`
  - `teacher_update_video(asset_id, title, subtopic_id)`
  - `teacher_reorder_videos(topic_id, ids)`
  - `teacher_list_videos(topic_id)`
  - `teacher_video_prefix(asset_id)`
  - `teacher_delete_video(asset_id)`: deletes `video_progress`, `video_chapters`, `private.video_keys` and the asset
- **Student RPCs:** `video_playback_grant`, `save_video_progress`.
- **Grants:** an explicit `grant execute … to authenticated` for each public RPC; revoke from `public`/`anon`.

`docs/07` changes: the RPC rows, the `video-otp` / `v/*` / `teacher/video-delete` rows, and `video_needed` in §9.

- [ ] **Step 1: pgTAP first**, covering Review focus 1–5 (DB parts):
  - cap at, under and over;
  - an unready reservation counts;
  - key RPC privileges;
  - grant refusals: no enrolment, locked topic, unready, device revoked; YouTube returns its id;
  - progress merge across overlapping and disjoint ranges, and the clamp;
  - `video_needed` from `get_practice_questions` before 80% and none after;
  - the finished-student exemption;
  - a topic with no video is unaffected (the existing notes tests stay green);
  - teacher RPCs are `forbidden` for students;
  - no `key_hex` in `audit_log`.
- [ ] **Step 2: Implement.**
- [ ] **Step 3 (Claude):** `scripts/db-reset.ps1` plus `scripts/db-test.ps1` if Docker works locally, otherwise push and let CI `db` run. Open a draft PR.

### Task 2: EF routes (Codex, after Task 1)

**Create:**
- `supabase/functions/api/video/{token.ts,playlist.ts,r2.ts}`, ported from the spike with `iat`, plus `list`/`delete` in R2;
- `supabase/functions/api/video_test.ts`.

**Modify:**
- `app.ts`:
  - `Deps` gains `video: { secret, supabaseUrl, storage: VideoStorage, serviceKey: (assetId) => Promise<{key, prefix} | null>, now }`;
  - add the routes;
  - extend `ERROR_CODES` with `video_needed` and `quota_exceeded` (only if returned).
- `index.ts`: the service-role client for `get_video_key`, and env `VIDEO_TOKEN_SECRET`, `R2_*`, `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`.
- `supabase/config.toml`.

**Routes:**
- `POST /api/video-otp {asset_id}` runs, in order:
  1. auth;
  2. the App Check gate (`'video-otp'`);
  3. `caller.rpc('video_playback_grant')`.
  
  For `r2_hls` it signs a `p` token `{a, u, iat, e = iat + playlist_ttl}` and returns `{provider, hls_url, expires_at, watermark:{name, short_id}, resume_s}`. For `youtube` it returns `{provider:'youtube', youtube_id, resume_s}`.
- `GET /api/v/:token/master.m3u8` and `/:name.m3u8` (regex `[A-Za-z0-9_-]+`): the master as-is, media playlists with the segments rewritten.
- `GET /api/v/:token/key`: needs `now - iat ≤ key_ttl`, then the service-role key, served as `application/octet-stream` with `no-store`.
- `POST /api/teacher/video-delete {asset_id}`, run in order:
  1. auth;
  2. `caller.rpc('teacher_video_prefix')` (forbidden for non-teachers);
  3. R2 list and delete under the prefix;
  4. `caller.rpc('teacher_delete_video')`.
  
  If R2 fails, return `internal` and leave the row so a retry works.

- [ ] **Step 1: Deno tests first**, with fake deps and no network:
  - tampered, expired, wrong-kind token → 403;
  - a key past `key_ttl` but inside `playlist_ttl` → 403, while the playlist still returns 200;
  - `no-store` on the key and the playlists;
  - a bad file name → 404/400;
  - a segment line that isn't `*.ts` → 500 without leaking it;
  - OTP refusals map the RPC errors; App Check rejection; YouTube shape;
  - `hls_url` uses `SUPABASE_URL`;
  - CORS preflight;
  - delete: a non-teacher is forbidden, the R2 failure path leaves the RPC uncalled, and on success R2 is called before the RPC;
  - the existing `/register-device` tests still pass.
- [ ] **Step 2: Implement.**
- [ ] **Step 3 (Claude):** `deno test` locally (functions gate), push, CI `functions` green.

### Task 3: Secrets, R2 CORS, PR (Claude and the user)

- [ ] Claude generates `VIDEO_TOKEN_SECRET` locally (`openssl rand -base64 32`). It goes straight to the user, who pastes it into the Supabase staging secrets. It is never written to a file or committed.
- [ ] The user adds a CORS rule on the R2 bucket `videos`: GET/HEAD from the staging Pages origin and `http://localhost:*`. Claude gives the exact JSON.
- [ ] Gates: `scripts/db-test.ps1` (or CI), `deno test supabase/functions`, `deno lint`/`fmt` for the touched files. Check the diff against Review focus 1–6. Add the L-2a row to STATUS. Commit by path, push, keep the PR a draft until CI is green, then say "ready to merge".
- [ ] **Staging check after merge** (no player yet):
  1. In the SQL editor, as a teacher, `teacher_add_youtube_video` on the demo topic. As a student, `get_topic` shows the video and `get_practice_questions` raises `video_needed`.
  2. `save_video_progress` up to 80%, then practice works.
  3. `curl` `/api/video-otp` with a student JWT for a YouTube asset returns `youtube_id`. (R2 playback is checked in L-2b, once the CLI has uploaded a clip.)
  4. Clean up and set the role back to student.

## Verification

- pgTAP 40 plus all existing tests green in CI `db`; Deno tests green in CI `functions`.
- `api-private-check.ps1` still passes: `private` isn't reachable.
- The staging steps above.
