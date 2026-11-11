# R4a — Persistent answer outbox (quiz + homework)

## Context

Roadmap R4 (docs/STATUS.md). `docs/16` §3 and `docs/05` §… promise an outbox: answers queued locally in `hive_ce`, surviving a reload. The code has only an in-memory queue (`apps/client/lib/core/attempts/answer_save_queue.dart`). Today, if a student is offline or a save is failing/retrying and they reload the tab (or the app is killed), every answer not yet acknowledged by the server is lost.

What already works and is reused: the server resumes an in-progress attempt and returns saved answers plus `client_seq` (`start_quiz` / `start_homework`, `20261017200100_prc03_quiz.sql:245-257`); `save_answer` is idempotent and ignores older `client_seq`; `AnswerSaveQueue` already retries with backoff and seeds `clientSeq` from the session. So the only missing piece is: persist each not-yet-acked answer snapshot, and on resume re-apply and re-send it.

Outcome: an answer is never lost on reload/kill while the attempt is still open (quiz: until deadline + `save_grace_s`; homework: always). No server change.

## Design

### 1. Domain-pure contract — `apps/client/lib/core/attempts/pending_answers.dart`
```dart
final class PendingAnswer {            // one unacked snapshot of one question
  const PendingAnswer({required this.answer, required this.marked,
    required this.timeMs, required this.rev, required this.savedAt});
  final String? answer; final bool marked; final int timeMs;
  final int rev; final DateTime savedAt;
}
abstract interface class PendingAnswers {
  int put(String attemptId, String questionId, {String? answer, required bool marked, required int timeMs}); // returns new rev
  int? revOf(String attemptId, String questionId);
  void ack(String attemptId, String questionId, int rev);   // removes only if stored rev == rev
  Map<String, PendingAnswer> forAttempt(String attemptId);
  void clearAttempt(String attemptId);
  void pruneOlderThan(DateTime cutoff);
}
```
No Flutter/Hive imports (rule B3). Hand-written `toJson`/`fromJson` on `PendingAnswer` (rule B2).

### 2. Hive implementation — `apps/client/lib/core/attempts/data/hive_pending_answers.dart`
- Wraps `Box<String>`; key `"<attemptId>:<questionId>"`, value = JSON of `PendingAnswer`. `rev` = stored rev + 1 (start at 1). Corrupt entries are deleted and skipped (no silent catch: report via existing `ErrorReporter` if one is available in core/observability, else just delete).
- Synchronous API (Hive box writes are buffered; no await needed in cubits).
- `apps/client/lib/main.dart`: open box `pending_answers` next to `device`/`settings`, with the same delete-and-reopen fallback as `settings` (`main.dart:69-72`). Call `pruneOlderThan(now - 7 days)` once at startup.
- `apps/client/lib/core/di/injection.dart`: register `PendingAnswers` lazy singleton from the opened box (same way `deviceBox` is passed in); inject into `QuizCubit` and `HomeworkCubit` factories.

### 3. Cubit wiring (same pattern in `features/quiz/presentation/cubit/quiz_cubit.dart` and `features/homework/presentation/cubit/homework_cubit.dart`)
- **On every local change** (`_answer`, `toggleMark`, homework equivalents): after emitting, `put(attemptId, id, answer, marked, timeMs)` then `_saves.enqueue(id)` as today.
- **In `_save(id, seq)`**: read `rev = revOf(attemptId, id)` before calling the repository; on `Success`, `ack(attemptId, id, rev)` (a newer edit made during the flight has a higher rev and survives).
- **On session start / resume** (`_startSession`): `local = forAttempt(session.attemptId)`; overlay each local snapshot onto the server answers/marked in the first emitted state, then `enqueue` each of those ids. Local wins because it is, by definition, unacknowledged (documented trade-off: an answer changed later on a *second* device can be overwritten by a stale unacked one from the first device; device limit is 2 and this needs both devices on the same attempt).
- **Clear**: on submit `Success` and on `deadline_passed` → `clearAttempt(attemptId)`. Starting a *different* attempt id leaves other entries alone (pruned by age).
- No UI change. Existing save-error banner keeps working (`saveError` state).

### 4. Tests first (implementer writes them; deterministic, no real timers — inject clock as cubits already do)
- `test/core/attempts/hive_pending_answers_test.dart` (Hive in a temp dir via `Hive.init(tempDir)`): put/rev increments, ack with stale rev keeps entry, ack with current rev removes, forAttempt isolates attempts, clearAttempt, prune by age, corrupt JSON entry skipped+deleted.
- `test/core/attempts/pending_answers_test.dart`: `PendingAnswer` JSON round-trip.
- Quiz cubit (`test/features/quiz/...`, existing fakes + an in-memory `PendingAnswers` fake):
  1. answer → entry stored; repository save success → entry removed.
  2. save fails (offline) → entry stays; new cubit (simulated reload) with same attempt → state shows the local answer and it is re-saved.
  3. edit during in-flight save → stale ack does not remove the newer entry.
  4. submit success → attempt cleared; `deadline_passed` → cleared.
- Same 4 for homework cubit.
- Existing quiz/homework/answer_save_queue tests stay green unchanged.

### 5. Docs
- `docs/16-supabase-playbook.md` §3: say it is implemented as `PendingAnswers` + `AnswerSaveQueue` in `lib/core/attempts/` (not `core/sync/AttemptSyncService`), the 7-day prune, and the second-device trade-off. Remove "every 10 s"/connectivity wording if not true (queue retries on ticks with backoff).
- `docs/STATUS.md` (router, after merge).

## Out of scope
Offline banner with countdown (§3 mentions it) — separate UI story. Practice (needs a connection by design). Mock exams (don't exist yet).

## Execution
- Branch `feat/r4a-answer-outbox` off `main`, worktree `../sat-r4a`.
- `implementer` (claude-sonnet-5-5), tests first, no commit. `/flutter-feature` conventions; context7 / `read_package_uris` for the `hive_ce` API instead of guessing.
- Router review: diff, then gates myself.

## Verification
- From `apps/client/`: `dart format --set-exit-if-changed .`, `flutter analyze --fatal-infos`, `flutter test --exclude-tags golden -j 2`.
- CI green on the PR.
- Manual on staging after merge: start a quiz, go offline in DevTools, answer 2 questions, reload, go online → the 2 answers are shown and saved (check `attempt_answers` via Supabase MCP `execute_sql` on staging).
