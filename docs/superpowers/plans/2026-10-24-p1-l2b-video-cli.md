# L-2b — video publish CLI (C-2, SEC-01) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

## Context

L-2a (#53, merged) shipped the server side: two-step register (`teacher_create_video_asset` → `teacher_confirm_video_asset`), the quota, and EF delete. Nothing can yet turn an `.mp4` into protected HLS in R2. There is no free cloud transcoding, so packaging runs locally on the operator's machine. **L-2b ships one local tool that packages, checks the quota, uploads, and registers a video.** After it, a real R2 video exists on staging for L-2c's player.

**Spec:** `docs/superpowers/specs/2026-10-24-p1-l2-video-design.md`, Goal 1 + A2/A3.
**Worktree:** `C:/Users/Lenovo/sat-wt-lane3`, branch `feat/P1-l2b-video-cli` (from main `3f982e8`).
**Implementer:** Codex (thread `01a16f15-8d5c-7500-adfb-63d07ea1a9e5`), tests first. Claude runs gates and commits. The PR stays a draft until CI is green.

## Decisions (router's calls)

- **Auth: sign in as a teacher with email + password.** The tool prompts for both in the terminal, with no echo for the password. It uses `@supabase/supabase-js` with the **publishable** key, so `auth.uid()` and `is_teacher()` apply. There is **no service-role key on the operator machine.**
  - Config comes from `--env <path>`, which reads `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY` from a client `env/*.json` file, or from those env vars.
- **R2 credentials:** `R2_ACCOUNT_ID`, `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`, `R2_BUCKET`, read from the process env or a gitignored `.env.video` file (a tiny parser). They are never printed.
- **Object layout** is the same as the EF (`supabase/functions/api/video/r2.ts`): bucket `R2_BUCKET`, key `videos/<asset_id>/<file>`.
- **540p only:** one rendition, still written with a `master.m3u8`, because the EF expects it. Bitrate is about 600 kbps video and 96 kbps AAC mono, about 300 MB/h. There is no IV line: ffmpeg derives the IV from the segment sequence. 6 s segments.
- **Flow (`publish`):**
  1. ffprobe reads the duration.
  2. Package into a temp dir.
  3. Compute the size (ceil MB of all files).
  4. `teacher_video_quota` (fail early with a clear message).
  5. `teacher_create_video_asset`.
  6. Upload every file to `videos/<id>/`.
  7. `teacher_confirm_video_asset(id, key_hex)`.
  8. Wipe the temp dir and the key.
  
  If upload or confirm fails, it releases the reservation with the EF `POST /functions/v1/api/teacher/video-delete` (the user JWT) and exits non-zero, printing the asset id.
- **Other commands:** `quota`, `list --topic <id>` (`teacher_list_videos`), `delete <asset_id>` (EF route).
- The key **never touches disk outside the temp dir**. The spike's `.key.hex` file is gone.
- Commands run as `deno run -A tools/video-pipeline/cli.ts <cmd> …`, plus `tools/video-pipeline/deno.json` tasks (`video:publish` etc.).
- **Tests:** pure modules with injected deps, no network, no ffmpeg in CI. A new CI step `deno test -A tools/` goes in the `functions` job.

## Files

**Create, under `tools/video-pipeline/`:**
- `cli.ts` (args + wiring)
- `publish.ts` (the orchestration, with deps injected: `probe`, `pack`, `api`, `storage`, `fs`)
- `ffmpeg.ts` (`ffmpegArgs` for 540p, moved from `package.ts`)
- `r2_upload.ts` (aws4fetch PUT, content types)
- `config.ts` (`--env` json / `.env.video` / env)
- `deno.json` (tasks)
- `README.md` (install ffmpeg via scoop/winget/brew, setup, the commands, and what to do on failure)
- `*_test.ts` for each module

**Modify:** `tools/video-pipeline/package.ts` (delete it, replaced by the above), `.github/workflows/ci.yml` (functions job: `deno test -A tools/`), `docs/09-content-pipeline.md` (a short "Publishing a video" section).

### Task 0 (Claude): copy this plan to `docs/superpowers/plans/2026-10-24-p1-l2b-video-cli.md` and commit it.

### Task 1 (Codex): the CLI, tests first

- [ ] **Tests:**
  - `ffmpegArgs` has a single 540p map plus the key-info file;
  - the size is a ceiling;
  - quota failure stops before create and upload;
  - `quota_exceeded` from create shows used and cap;
  - upload failure calls delete and exits with code 1;
  - confirm gets the exact key hex;
  - the key/temp dir is removed on success and on failure;
  - config precedence and missing-var messages, and no secret appears in any message;
  - arg validation (uuid topic, title of 1–120 characters, file exists);
  - the `.env.video` parser.
- [ ] **Implement.** Never log keys, tokens, R2 secrets, or presigned URLs.
- [ ] **Claude:** `deno test -A tools/` and `deno check tools/video-pipeline/cli.ts`, review the diff, push, open a draft PR, wait for CI green.

### Task 2 (Claude and the user): staging run

- [ ] Claude makes a 30 s CC0 test clip locally with ffmpeg (`testsrc2` + `sine`, so no download), packages it offline with `--dry-run` (no network), and checks the master and media playlists have `#EXT-X-KEY:METHOD=AES-128,URI="key"` and segments named `*.ts`.
- [ ] **The user runs** `publish` against staging. It needs their R2 keys in a local `.env.video`, and their account temporarily set to teacher (Claude flips the role in the SQL editor and reverts it afterwards). The user types their own password.
- [ ] Claude checks:
  - the DB row is `ready`, `size_mb` is correct, and the `private.video_keys` row exists;
  - `quota` shows the usage;
  - `delete` removes the R2 objects (`list` is empty) and the DB rows.
  
  Then Claude republishes to keep one sample clip for L-2c, and reverts the role.

## Verification

- `deno test -A tools/` and `deno test -A supabase/functions/` green locally and in CI.
- The staging run above: publish → `ready` asset → delete cleans both R2 and DB.
