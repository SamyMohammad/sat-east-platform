# Video publishing CLI

Packages one 540p AES-128 HLS rendition locally, reserves storage, uploads to R2 and confirms
the video through the teacher RPCs. Requires Deno 2 and ffmpeg/ffprobe on PATH.

Install ffmpeg with `scoop install ffmpeg`, `winget install --id Gyan.FFmpeg -e` on Windows,
or `brew install ffmpeg` on macOS. Verify `ffmpeg -version` and `ffprobe -version`.

## Configuration

Run from the repository root. Use `--env apps/client/env/staging.json` to read
`SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY`, or set those process environment variables.
An explicit JSON file takes precedence for both Supabase values. Use the publishable key;
the CLI uses a teacher's email/password session and never needs a service-role key.

For live publishing, set these process environment variables or put them in `.env.video`
in the current working directory (already covered by the repository's `.env.*` ignore rule):

```dotenv
R2_ACCOUNT_ID=<account id>
R2_ACCESS_KEY_ID=<access key id>
R2_SECRET_ACCESS_KEY=<secret access key>
R2_BUCKET=videos
```

Process R2 values override the file. The small parser accepts blank lines, `#` comments,
optional `export`, single/double quotes and unquoted trailing comments after whitespace.
It does not expand variables or execute shell expressions. Never commit this file.
Quota, list and delete need only Supabase configuration; deletion uses the server's R2 credentials.

## Commands

Replace the UUIDs with real topic/subtopic/asset IDs:

```sh
deno run -A tools/video-pipeline/cli.ts publish --topic <uuid> --title "Linear equations" --env apps/client/env/staging.json lesson.mp4
deno run -A tools/video-pipeline/cli.ts publish --topic <uuid> --subtopic <uuid> --title "Lesson" --env apps/client/env/staging.json lesson.mp4
deno run -A tools/video-pipeline/cli.ts quota --env apps/client/env/staging.json
deno run -A tools/video-pipeline/cli.ts list --topic <uuid> --env apps/client/env/staging.json
deno run -A tools/video-pipeline/cli.ts delete <asset_uuid> --env apps/client/env/staging.json
```

The CLI prompts for teacher email and a password without echo. When raw terminal input is
unavailable, it warns before falling back to `prompt()`, which may display the password.
Sessions remain in memory. No password, token or encryption key is written to configuration.

From `tools/video-pipeline/`, equivalent tasks are `deno task video:publish ...`,
`deno task video:quota ...`, `deno task video:list ...`, and `deno task video:delete ...`.
Task arguments and `.env.video`/`--env` paths resolve from that directory.

## Offline packaging

```sh
deno run -A tools/video-pipeline/cli.ts publish --topic <uuid> --title "Offline preview" --dry-run --out out/video-preview lesson.mp4
```

Dry-run does not read credentials, sign in or call a network service. Install/cache the pinned
Deno imports once before going offline. `--out` must be empty; it is supported only with
`--dry-run`. Without it, the encrypted output is retained in a temporary directory whose path
is printed. The key and key-info file live in a separate temporary directory and are deleted;
dry-run output cannot subsequently be decrypted or uploaded as a playable asset. Run live
publish from the source file when ready.

Output contains `master.m3u8`, `540p.m3u8` and `540p_*.ts` segments. Video is approximately
600 kbps, with 96 kbps mono AAC when audio exists, and six-second segments. The key URI is
`key`; ffmpeg derives the IV from the segment sequence. No key hex file is produced.

## Results and recovery

Live publish prints asset ID, title, duration (ceiling seconds), total HLS size (ceiling MiB,
labelled MB to match the DB), and refreshed quota used/cap. All files upload beneath
`videos/<asset_id>/` in `R2_BUCKET`. Both pending and ready video rows consume quota.

An upload or confirmation failure triggers the teacher delete EF, removing R2 objects before
releasing the DB reservation. The error prints the asset ID. If rollback fails, retry `delete`
with that ID once connectivity is restored. R2 deletion is idempotent. If the reservation call
times out before an ID is received, use `list --topic ...` to identify the pending row before
retrying; do not blindly create duplicate reservations. A quota-refresh failure after confirmation
leaves the published video intact and prints its ID; use `quota` to check usage.

Normal publishing removes its temporary output and key directory in `finally`, including on
errors. Dry-run retains only encrypted output. A forced OS/process termination can interrupt
cleanup; remove abandoned `video-publish-*` temporary directories before retrying. Do not share
them. Plain English errors include only recognized error codes, never raw server error text.

Exit codes: `0` success, `1` runtime failure, `2` invalid usage.

## Verification

```sh
deno test -A tools/
deno check tools/video-pipeline/cli.ts
```

Tests inject filesystem, API, process and storage dependencies; no real network or ffmpeg is
needed. Dependencies are pinned to `@supabase/supabase-js@2.118.0`, `aws4fetch@1.0.20`,
`@std/path@1.1.4` (and `@std/assert@1.0.19` for tests).
