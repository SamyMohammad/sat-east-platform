# L-2c — video client (LRN-02, SEC-01, C-2) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. In this repo, tasks go to Codex via `codex-delegate` (tests first, Codex writes them); the router runs the gates and commits.

**Goal:** Students watch a topic's video (protected R2 HLS or YouTube unlisted) inside the app with a moving watermark and server-saved progress, as the first topic step; teachers manage a topic's videos from the course builder.

**Architecture:** A new `features/video` (data → domain → presentation) talks to the existing `api` Edge Function (`POST /api/video-otp`) through a new core `EdgeCaller`, and to `save_video_progress` through `RpcCaller`. Playback goes through a domain `VideoEngine` interface with two web implementations (`dart:js_interop` over a vendored hls.js, and over the YouTube IFrame API) so one Cubit and one set of controls serve both providers. A new `features/teacher/videos` mirrors `features/teacher/notes`.

**Tech Stack:** Flutter web, Cubit, get_it, go_router, `supabase_flutter`, `package:web` + `dart:js_interop`, hls.js 1.7.3 (vendored), YouTube IFrame API. No new pub packages.

**Spec:** `docs/superpowers/specs/2026-10-24-p1-l2-video-design.md` (Goals 3–4, Decisions, Amendments A5–A9). Server contract: `supabase/migrations/20261030100000_l2a_video.sql`, `supabase/functions/api/app.ts`.

## Global Constraints

- **Non-ASCII in Dart source:** write `·` as `·`, `×` as `×`, `—` as `—` inside string literals (the Codex sandbox has mangled non-ASCII into `?` before). Copy below shows the rendered character.
- No CSP exists today (`apps/client/web/` has none); don't add one in this PR.

- CLAUDE.md rules 1–10, A, B. No `dart:html` — `package:web` + `dart:js_interop` only. No code generation.
- No new pub dependency. hls.js is already vendored by the router at `apps/client/web/vendor/hls-1.7.3.min.js` (sha256 `a12e7ee1…423e`); load it lazily by script injection like `core/analytics/posthog_web_loader_web.dart`. Never load scripts from a CDN at runtime, except the YouTube IFrame API (`https://www.youtube.com/iframe_api`), which YouTube requires.
- The client never sends `pct`; it sends watched spans only (`save_video_progress(p_asset_id, p_from_s, p_to_s, p_position_s)`; the server rejects a span longer than `2 * video_progress_interval_s + 5`).
- No magic numbers: the heartbeat interval comes from `settings.video_progress_interval_s` (15); the watermark move period from a new `settings.video_watermark_move_s` (7).
- Speeds exactly `1×`, `1.25×`, `1.5×`. Fullscreen is app-level (the watermark stays on top). `<video>` gets `disablePictureInPicture`, `controlsList="nodownload noremoteplayback"`, no native `controls`, context menu blocked.
- Watermark text: `"<name> · <short_id>"` from the `video-otp` response, white with a dark outline/shadow, alpha ≈ 0.55. R2 only (YouTube has none).
- UI copy is English and lives in `*_copy.dart` files. Error codes map to copy in presentation; never show raw exception text.
- Web is the only target in this PR. On non-web, the engine factory returns an engine whose `attach` fails with `ErrorCodes.unsupported` (add if missing) and the screen shows "Video plays in the web app for now."
- Gates (from `apps/client/`): `dart format --set-exit-if-changed .` · `flutter analyze --fatal-infos` · `flutter test -j 2 --exclude-tags golden`. SQL: `scripts/db-test.ps1` or CI pgTAP.

## Review Focus

1. **Seek forward / backward mid-span** — a jump must close the current span at the old position and start a new one; skipped seconds are never sent (Task 3 tracker tests).
2. **Token expiry or stall mid-video** (key TTL 300 s, playlist TTL 14400 s) — a fatal hls error or no position change for 10 s while playing re-requests `video-otp` and re-attaches at the current position, max 3 times per minute, then shows the error state (Task 5 cubit tests).
3. **Leaving the screen** (back, route pop, cubit close) flushes the open span once; no flush after close; no emit after close (Task 5).
4. **Playback speed 1.5×** — a 15 s wall-clock heartbeat covers 22.5 media seconds; spans are capped at `2 * interval` media seconds and split if longer, so the server never rejects them (Task 3).
5. **Coming back to the topic page after reaching 80 %** — the topic reloads so Notes/Practice unlock without a manual refresh (Task 2 / Task 5).

---

### Task 1: Core Edge Function transport + video error codes

**Files:**
- Create: `apps/client/lib/core/supabase/edge_caller.dart`
- Modify: `apps/client/lib/core/errors/error_codes.dart`, `apps/client/lib/core/errors/supabase_error_mapper.dart`, `apps/client/lib/core/di/injection.dart`
- Test: `apps/client/test/core/errors/supabase_error_mapper_test.dart` (extend), `apps/client/test/core/supabase/edge_caller_test.dart`

**Interfaces:**
- Produces: `typedef EdgeCaller = Future<Object?> Function(String path, Map<String, Object?> body);` — `path` is relative to the `api` function (e.g. `'video-otp'`, `'teacher/video-delete'`). DI registers it as `(path, body) async => (await client.functions.invoke('api/$path', body: body)).data`.
- Produces: `AppError mapFunctionException(FunctionException e)` — reads `e.details` as `{error: {code, message}}`; known server code → that code; status 401 → `notAuthenticated`; otherwise `internal`.
- Produces: `ErrorCodes.videoNeeded = 'video_needed'`, `ErrorCodes.quotaExceeded = 'quota_exceeded'` (both in the server-code set), `ErrorCodes.unsupported = 'unsupported'` (client-only, if not present).

- [ ] **Step 1: Write failing tests** — `mapFunctionException` cases: details `{error:{code:'video_needed'}}` → `video_needed`; `{error:{code:'topic_locked'}}` → `topic_locked`; unknown code `'boom'` → `internal`; details `null` with status 401 → `not_authenticated`; details a plain string → `internal`. `ErrorCodes.isServerCode('video_needed')` and `('quota_exceeded')` are true.
- [ ] **Step 2: Run** `flutter test test/core/errors` — Expected: FAIL (symbol missing).
- [ ] **Step 3: Implement** the typedef, mapper and codes; register `EdgeCaller` as a lazy singleton next to `RpcCaller` in `injection.dart`.
- [ ] **Step 4: Run** the tests — Expected: PASS. Run gates.
- [ ] **Step 5: Commit** `feat(P1): edge function caller + video error codes (L-2c)`

### Task 2: Topic page — Video step and video gate

**Files:**
- Create: `apps/client/lib/features/topic/domain/entities/topic_video.dart`, `apps/client/lib/features/topic/presentation/widgets/topic_video_step.dart`
- Modify: `features/topic/domain/entities/topic_detail.dart`, `features/topic/data/models/topic_model.dart`, `features/topic/presentation/widgets/topic_content.dart`, `features/topic/presentation/widgets/topic_notes_step.dart`, `features/topic/presentation/topic_copy.dart`, `features/topic/presentation/screens/topic_screen.dart`, `core/router/app_router.dart` (`AppRoutes.video(topicId, assetId)` only; the route itself comes in Task 5)
- Test: `test/features/topic/data/topic_model_test.dart`, `test/features/topic/domain/topic_detail_test.dart`, `test/features/topic/presentation/topic_content_test.dart` (extend existing files where they exist)

**Interfaces:**
- Produces: `enum VideoProvider { r2Hls, youtube }` (`fromWire('r2_hls'|'youtube')`, unknown → parse failure) in `lib/core/video/video_provider.dart` (shared by topic, video and teacher/videos — CLAUDE.md A.2) — create it here; Tasks 3–6 import it from there.
- Produces: `class TopicVideo { String assetId; String title; String? subtopicTitle; int durationS; VideoProvider provider; int pct; int lastPositionS; }`.
- Produces on `TopicDetail`: `List<TopicVideo> videos`, `bool videoDone`, getters `bool get notesLockedByVideo => videos.isNotEmpty && !videoDone;` and `practiceLockedByVideo` (same rule). Existing `practiceLockedByNotes` stays.
- Produces: `AppRoutes.video(String topicId, String assetId)` → `.../topics/$topicId/video/$assetId` (same parent path as `AppRoutes.notes`).

- [ ] **Step 1: Write failing tests**
  - model: JSON with `videos: [{asset_id, title, subtopic_title: null, duration_s: 600, provider: 'r2_hls', pct: 40, last_position_s: 120}]`, `video_done: false` parses; missing `videos` → empty list, `video_done` missing → `true`.
  - entity: `notesLockedByVideo` true only when videos non-empty and not done.
  - widget: Video step renders before Notes with title "Video", each row shows title, `10:00` duration and `40%`; done shows the check icon. When `notesLockedByVideo`, note rows are disabled and the step shows `TopicCopy.watchVideoFirst` = `'Watch the video first.'`. Practice card shows `'Watch the video first.'` when `practiceLockedByVideo` (priority over the notes message), else the existing `'Open the notes first.'` — move that literal into `TopicCopy.openNotesFirst`.
  - topic with no videos renders exactly as before (no Video step).
- [ ] **Step 2: Run** `flutter test test/features/topic` — Expected: FAIL.
- [ ] **Step 3: Implement.** In `topic_screen.dart`, tapping a video row does `await context.push(AppRoutes.video(...))` and then reloads the topic (same reload the notes return uses, or add one) — this covers Review Focus 5.
- [ ] **Step 4: Run** tests + gates — Expected: PASS.
- [ ] **Step 5: Commit** `feat(P1): video step + video gate on topic page (L-2c, LRN-02)`

### Task 3: Video data + domain (playback grant, progress tracker, settings)

**Files:**
- Create: `supabase/migrations/20261101100000_l2c_video_settings.sql` (from `supabase/templates/`; inserts `video_watermark_move_s` = `'7'`, `on conflict do nothing`), `supabase/tests/42_l2c_video_settings.test.sql` (signed-in student can read both `video_progress_interval_s` and `video_watermark_move_s` from `settings`; anon cannot).
- Create under `apps/client/lib/features/video/`: `domain/entities/video_playback.dart`, `domain/entities/video_settings.dart`, `domain/entities/watched_span.dart`, `domain/services/progress_tracker.dart`, `domain/repositories/video_repository.dart`, `data/datasources/video_remote_data_source.dart`, `data/repositories/video_repository_impl.dart`
- Modify: `core/di/injection.dart`
- Test: `test/features/video/domain/progress_tracker_test.dart`, `test/features/video/data/video_remote_data_source_test.dart`, `test/features/video/data/video_repository_impl_test.dart`

**Interfaces:**
- Consumes: `EdgeCaller`, `RpcCaller`, `mapFunctionException` (Task 1); `VideoProvider` (Task 2).
- Produces:
  - `sealed class VideoPlayback { int resumeS; }` with `final class HlsPlayback(String hlsUrl, DateTime expiresAt, String watermarkName, String watermarkShortId, int resumeS)` and `final class YoutubePlayback(String youtubeId, int resumeS)`. `watermarkText => '$watermarkName · $watermarkShortId'`.
  - `class VideoSettings { int progressIntervalS; int watermarkMoveS; }`
  - `class WatchedSpan { int fromS; int toS; }`
  - `abstract interface class VideoRepository { Future<Result<VideoPlayback>> requestPlayback(String assetId); Future<Result<({int pct, bool done})>> saveProgress(String assetId, WatchedSpan span, int positionS); Future<Result<VideoSettings>> loadSettings(); }`
  - `class ProgressTracker({required int intervalS})` with `void onPosition(double s)`, `List<WatchedSpan> takeSpans()` (returns closed spans + the open span up to the last position, then restarts the open span at the last position), `bool get hasPending`.
- Data source: `video-otp` via `EdgeCaller('video-otp', {'asset_id': id})`, parsing both response shapes from `app.ts:112` / `:123-125` (`expires_at` is epoch seconds); `save_video_progress` via `RpcCaller` with `p_asset_id, p_from_s, p_to_s, p_position_s`; settings via one `from('settings').select('key,value').inFilter('key', ['video_progress_interval_s','video_watermark_move_s'])` (inject it as a function typedef like the notes `notes_max_mb` read). A missing key is a `Failure(internal)`, not a default.

- [ ] **Step 1: Write failing tests**
  - tracker, interval 15: positions 0→14 by 1 s → `takeSpans()` = `[0–14]`; a jump 30→90 → spans `[…–30]` then new span from 90; a backward jump 50→20 closes at 50; positions advancing 0.5 s per tick to 40 s are split so no span exceeds 30 s (`2 * intervalS`); a span with `toS - fromS < 1` is dropped; `hasPending` false right after `takeSpans()` with no new positions.
  - data source: R2 response → `HlsPlayback` with `expiresAt` from epoch seconds; YouTube response → `YoutubePlayback`; `FunctionException` with `video_needed` → `AppError(video_needed)`; `PostgrestException('forbidden')` on save → `forbidden`; settings with one key missing → `Failure(internal)`.
- [ ] **Step 2: Run** `flutter test test/features/video` — Expected: FAIL.
- [ ] **Step 3: Implement** entities, tracker, data source, repository; register data source + repository as lazy singletons.
- [ ] **Step 4: Run** tests + gates; run pgTAP 42 — Expected: PASS.
- [ ] **Step 5: Commit** `feat(P1): video playback grant, progress tracker, settings (L-2c, SEC-01)`

### Task 4: Web playback engines (hls.js + YouTube)

**Files:**
- Create: `apps/client/lib/features/video/domain/services/video_engine.dart` (interface only), `apps/client/lib/features/video/data/services/video_engine_factory.dart` (conditional import), `.../hls_web_engine.dart`, `.../youtube_web_engine.dart`, `.../video_engine_stub.dart`
- Test: `test/features/video/data/video_engine_stub_test.dart` (the VM stub only; the web engines are checked on staging)

**Interfaces:**
- Produces:
  ```dart
  enum EngineStatus { idle, loading, playing, paused, buffering, ended }
  abstract interface class VideoEngine {
    String get viewType;                 // registered platform view id for HtmlElementView
    Stream<double> get position;         // seconds, ~4 Hz while playing
    Stream<EngineStatus> get status;
    Stream<AppError> get fatalErrors;    // network/key/manifest fatal → AppError(internal)
    double? get durationS;
    Future<Result<void>> attach(VideoPlayback playback); // seeks to resumeS
    void play(); void pause(); void seek(double s); void setRate(double r);
    Future<void> requestFullscreen(); Future<void> exitFullscreen();
    Future<void> dispose();
  }
  VideoEngine createVideoEngine(VideoProvider provider); // factory
  ```
- Hls: inject `vendor/hls-1.7.3.min.js` once; `Hls.isSupported()` else, if `video.canPlayType('application/vnd.apple.mpegurl')` (Safari), set `src` directly; register a `<video>` element via `ui_web.platformViewRegistry` with the attributes from Global Constraints and `playsInline`; map hls `ERROR` events with `fatal: true` to `fatalErrors`. Fullscreen calls `document.documentElement.requestFullscreen()` (never the `<video>` or its parent: the platform view sits outside the Flutter canvas, so fullscreening it would drop the watermark); the screen then expands the player to the viewport and hides the shell chrome — that is the app-level fullscreen.
- YouTube: load the IFrame API once; `YT.Player` with `playerVars {controls: 0, disablekb: 1, modestbranding: 1, rel: 0, playsinline: 1, start: resumeS}`, host `https://www.youtube-nocookie.com`; poll `getCurrentTime()` every 250 ms while playing for `position`.
- Stub (non-web): `attach` → `Failure(AppError(ErrorCodes.unsupported))`.

- [ ] **Step 1: Write failing test** — the stub's `attach` returns `Failure` with `unsupported`; streams are empty and `dispose` completes.
- [ ] **Step 2: Run** — Expected: FAIL.
- [ ] **Step 3: Implement** the interface, stub, factory and the two web engines. `flutter build web --dart-define-from-file=env/dev.example.json` must compile (router runs it).
- [ ] **Step 4: Run** tests + gates + web build — Expected: PASS.
- [ ] **Step 5: Commit** `feat(P1): hls.js and YouTube web engines (L-2c, SEC-01)`

### Task 5: Video player Cubit + screen + route

**Files:**
- Create under `apps/client/lib/features/video/presentation/`: `cubit/video_player_cubit.dart`, `cubit/video_player_state.dart`, `video_copy.dart`, `screens/video_player_screen.dart`, `widgets/video_controls.dart`, `widgets/moving_watermark.dart`
- Modify: `core/router/app_router.dart` (deferred import `deferred as video_player`, route `topics/:topicId/video/:assetId` next to the notes route, `_DeferredVideoPlayer` copying `_DeferredNotesViewer`), `core/di/injection.dart` (`registerFactory<VideoPlayerCubit>`)
- Test: `test/features/video/presentation/video_player_cubit_test.dart`, `test/features/video/presentation/video_controls_test.dart`, `test/features/video/presentation/moving_watermark_test.dart`

**Interfaces:**
- Consumes: `VideoRepository`, `ProgressTracker`, `VideoEngine` + `createVideoEngine` (inject the factory as `VideoEngine Function(VideoProvider)`), `VideoSettings`.
- Produces:
  - `sealed class VideoPlayerState`: `VideoPlayerLoading`, `VideoPlayerReady({VideoPlayback playback, EngineStatus status, double positionS, double? durationS, double rate, bool fullscreen, bool done, int watermarkMoveS})`, `VideoPlayerError(String code)`.
  - `VideoPlayerCubit(VideoRepository repo, VideoEngine Function(VideoProvider) engineFor, {required Timer Function(Duration, void Function(Timer)) periodic, required DateTime Function() now})` with `load(String assetId, VideoProvider provider)`, `togglePlay()`, `seek(double s)`, `setRate(double r)` (only 1.0/1.25/1.5), `toggleFullscreen()`, `retry()`, `close()`.
  - Heartbeat: every `progressIntervalS` and on pause, `takeSpans()` → `saveProgress` per span (sequential); `done` from the last response. `close()` flushes once, then disposes the engine.
  - Recovery: fatal error, or position unchanged for 10 s while `playing` → `requestPlayback` again and re-`attach` with `resumeS` = current position; more than 3 recoveries within 60 s (use `now`) → `VideoPlayerError(internal)`.
- `VideoCopy`: title fallback `'Video'`, `speed` labels `'1×' '1.25×' '1.5×'`, errors: `video_needed`/`topic_locked` → `'This video isn't open yet.'`, `not_enrolled`/`access_expired` → `'Your access to this course has ended.'`, `device_revoked` → `'This device was signed out. Sign in again.'`, `rate_limited` → `'Too many tries. Wait a minute and retry.'`, `unsupported` → `'Video plays in the web app for now.'`, else `'Couldn't load the video. Try again.'` with a Retry button.
- `MovingWatermark({required String text, required Duration period, required Random random})` — repositions inside its box every `period` with `AnimatedPositioned` (slow, 1.5 s curve); `IgnorePointer`.
- Controls (`VideoControls`): play/pause, a seek slider with `mm:ss / mm:ss`, a speed menu, fullscreen toggle; keyboard Space = play/pause, ←/→ = ∓10 s. Layout per `Learning Path.dc.html` / `Content and Help.dc.html` in `docs/design/claude-design-export/`. Check 360 px and 1280 px.

- [ ] **Step 1: Write failing tests** (fake engine + fake repo + fake periodic timer)
  - `load` success → `Ready` with `resumeS` passed to `attach`; repo failure `video_needed` → `Error('video_needed')`; settings failure → `Error('internal')`.
  - heartbeat tick with pending positions calls `saveProgress` with the tracker spans and sets `done` when the response says so; no call when nothing is pending.
  - `togglePlay` while playing pauses the engine and flushes.
  - fatal error → second `requestPlayback` + `attach(resumeS = current position)`; 4th fatal error inside 60 s → `Error('internal')`.
  - stall: status `playing` and no position change for 10 s → recovery.
  - `close()` flushes pending spans once, disposes the engine; a repo response arriving after close emits nothing.
  - `setRate(2.0)` is ignored.
  - widget: in fullscreen state the watermark is still in the tree.
  - widget: controls show `1×/1.25×/1.5×`; Space toggles play; watermark text renders `"Sara Ali · 3FA2C1"` for R2 and is absent for YouTube; it moves after `period` (pump).
- [ ] **Step 2: Run** `flutter test test/features/video/presentation` — Expected: FAIL.
- [ ] **Step 3: Implement** cubit, state, copy, screen (`HtmlElementView(viewType: engine.viewType)` under a `Stack` with the watermark and controls; app-level fullscreen hides the shell chrome), route and DI.
- [ ] **Step 4: Run** tests + gates + web build — Expected: PASS.
- [ ] **Step 5: Commit** `feat(P1): video player screen with watermark + progress (L-2c, LRN-02, SEC-01)`

### Task 6: Teacher Videos screen

**Files:**
- Create under `apps/client/lib/features/teacher/videos/` the mirror of `features/teacher/notes/`: `data/datasources/teacher_videos_remote_data_source.dart`, `data/repositories/teacher_videos_repository_impl.dart`, `domain/entities/teacher_video.dart`, `domain/entities/video_quota.dart`, `domain/repositories/teacher_videos_repository.dart`, `domain/youtube_id.dart`, `presentation/cubit/teacher_videos_cubit.dart`, `presentation/cubit/teacher_videos_state.dart`, `presentation/teacher_videos_copy.dart`, `presentation/screens/teacher_videos_screen.dart`, `presentation/widgets/teacher_video_card.dart`, `presentation/widgets/add_youtube_dialog.dart`
- Modify: `features/teacher/course_builder/presentation/widgets/builder_node_row.dart` (menu item `'videos'` → `'Videos…'` after `'Notes…'`, callback `onVideos`), `.../builder_tree.dart` (wire `onVideos`), `core/router/app_router.dart` (`/teacher/courses/:courseId/topics/:topicId/videos`, `AppRoutes.teacherVideos(courseId, topicId)`), `core/di/injection.dart`
- Test: `test/features/teacher/videos/...` (data source, `youtube_id` parser, cubit, screen)

**Interfaces:**
- Consumes: `RpcCaller` (`teacher_list_videos`, `teacher_video_quota`, `teacher_add_youtube_video`, `teacher_update_video`, `teacher_reorder_videos`), `EdgeCaller('teacher/video-delete', {'asset_id'})`, `VideoProvider`.
- Produces: `TeacherVideo {assetId, title, subtopicId?, subtopicTitle?, durationS, sizeMb?, provider, youtubeId?, ready, sort}`; `VideoQuota {usedMb, capMb}` with `String label` = `'${(usedMb/1024).toStringAsFixed(1)} of ${(capMb/1024).toStringAsFixed(0)} GB used'`; `String? parseYoutubeId(String input)` (accepts a bare 11-char id, `youtu.be/<id>`, `youtube.com/watch?v=<id>`, `/embed/<id>`, `/shorts/<id>`; otherwise `null`).
- Cubit methods: `load(topicId)`, `addYoutube({title, input, durationS})`, `rename(assetId, title)` (keeps `subtopicId`), `moveUp/moveDown(assetId)` → `teacher_reorder_videos` with every id (pending ones included), `delete(assetId)`. Each action reloads list + quota.
- Screen: storage meter at the top (`LinearProgressIndicator` + `quota.label`); the note `'Upload protected videos with the video tool.'`; card shows title, `mm:ss`, size (`— ` for YouTube), provider chip `Protected`/`YouTube`; `ready == false` shows `'Upload not finished'` and only Delete; delete confirms with `'Delete this video? Students lose their progress on it.'`; the add dialog validates the YouTube link (`'Paste a YouTube link or video id.'`) and duration `mm:ss` (> 0).

- [ ] **Step 1: Write failing tests** — `parseYoutubeId` table (5 valid forms → `'dQw4w9WgXcQ'`, `'abc'` → null, a link with `&t=30s` → id); `quota.label` for `3277/9216` → `'3.2 of 9 GB used'`; data source maps each RPC + the EF delete; cubit `moveDown` sends the full id list in the new order; delete failure keeps the list and emits the error code; screen shows the pending card with only Delete, and the builder menu shows `'Videos…'` for topics.
- [ ] **Step 2: Run** `flutter test test/features/teacher/videos test/features/teacher/course_builder` — Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** tests + gates — Expected: PASS.
- [ ] **Step 5: Commit** `feat(P1): teacher Videos screen (L-2c, C-2)`

### Task 7 (router): STATUS, PR, staging check

- [ ] Update `docs/STATUS.md` (rows for #52–#55 done; L-2c in review) and `docs/07` only if a contract changed (it should not).
- [ ] Draft PR `feat(P1): video client (L-2c, LRN-02, SEC-01, C-2)`; mark ready when CI is green.
- [ ] Staging check after merge: publish the 30 s sample clip with the CLI to a demo topic; as a student, Notes/Practice show "Watch the video first."; play, watermark moves, speed, fullscreen keeps the watermark, seek forward does not jump pct; reach 80 % → back on the topic page Notes unlock; teacher screen shows the meter, adds a YouTube video, reorders, deletes (R2 files gone). Delete the test assets after.
