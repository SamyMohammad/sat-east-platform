import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/auth/domain/entities/my_profile.dart';
import 'package:sat_east_client/features/notes/presentation/cubit/notes_viewer_cubit.dart';
import 'package:sat_east_client/features/notes/presentation/cubit/notes_viewer_state.dart';

import '../notes_fixtures.dart';

void main() {
  late FakeNotesRepository repo;
  late MockNotesAuth auth;
  late NotesViewerCubit cubit;
  setUp(() {
    repo = FakeNotesRepository();
    auth = MockNotesAuth();
    when(auth.getMyProfile).thenAnswer(
      (_) async => const Success(
        MyProfile(fullName: 'Sara Ahmed', email: 'sara@example.com'),
      ),
    );
    cubit = NotesViewerCubit(repo, auth, () => DateTime.utc(2026, 10, 27));
  });
  tearDown(() => cubit.close());
  test(
    'SEC-02: ready precedes mark and repeated load marks only once',
    () async {
      final mark = Completer<Result<void>>();
      repo.pendingMark = mark.future;
      final ready = cubit.stream.firstWhere((s) => s is NotesViewerReady);
      final loading = cubit.load('t1', 'a1');
      await ready;
      expect(
        (cubit.state as NotesViewerReady).watermark,
        'Sara Ahmed \u00b7 sara \u00b7 2026-10-27',
      );
      expect(repo.downloads, ['t1/a1.pdf']);
      await cubit.load('t1', 'a1');
      mark.complete(const Success(null));
      await loading;
      expect(repo.marks, ['a1']);
    },
  );
  test(
    'L-3: mark failure keeps bytes usable and reports progress error',
    () async {
      repo.markResult = const Failure(AppError('network'));
      await cubit.load('t1', 'a1');
      final ready = cubit.state as NotesViewerReady;
      expect(ready.bytes, [1, 2, 3]);
      expect(ready.markError?.code, 'network');
      await cubit.load('t1', 'a1');
      expect(repo.marks, ['a1']);
    },
  );
  test('L-3: profile failure stops before download and can retry', () async {
    when(
      auth.getMyProfile,
    ).thenAnswer((_) async => const Failure(AppError('network')));
    await cubit.load('t1', 'a1');
    expect((cubit.state as NotesViewerFailed).error.code, 'network');
    expect(repo.downloads, isEmpty);
    expect(repo.marks, isEmpty);
    when(auth.getMyProfile).thenAnswer(
      (_) async =>
          const Success(MyProfile(fullName: 'Sara', email: 'sara@example.com')),
    );
    await cubit.load('t1', 'a1');
    expect(cubit.state, isA<NotesViewerReady>());
  });
  for (final code in ['topic_locked', 'not_enrolled', 'network']) {
    test('L-3: download $code fails without marking and can retry', () async {
      repo.downloadResult = Failure(AppError(code));
      await cubit.load('t1', 'a1');
      expect((cubit.state as NotesViewerFailed).error.code, code);
      expect(repo.marks, isEmpty);
      repo.downloadResult = Success(Uint8List.fromList([1]));
      await cubit.load('t1', 'a1');
      expect(cubit.state, isA<NotesViewerReady>());
    });
  }
  test('SEC-02: close drops ready bytes', () async {
    await cubit.load('t1', 'a1');
    await cubit.close();
    expect(cubit.state, isA<NotesViewerLoading>());
  });
  test('SEC-02: closed pending download cannot emit bytes or mark', () async {
    final pending = Completer<Result<Uint8List>>();
    repo.pendingDownload = pending.future;
    final started = Completer<void>();
    repo.onDownload = started.complete;
    final loading = cubit.load('t1', 'a1');
    await started.future;
    await cubit.close();
    pending.complete(Success(Uint8List.fromList([1])));
    await loading;
    expect(repo.marks, isEmpty);
    expect(cubit.state, isA<NotesViewerLoading>());
  });
  test('SEC-02: closing while mark is pending cannot restore bytes', () async {
    final pending = Completer<Result<void>>();
    repo.pendingMark = pending.future;
    final ready = cubit.stream.firstWhere((s) => s is NotesViewerReady);
    final loading = cubit.load('t1', 'a1');
    await ready;
    await cubit.close();
    pending.complete(const Failure(AppError('network')));
    await loading;
    expect(cubit.state, isA<NotesViewerLoading>());
  });
  test('L-3: stale download cannot replace another asset or mark it', () async {
    final pending = Completer<Result<Uint8List>>();
    final started = Completer<void>();
    repo
      ..pendingDownload = pending.future
      ..onDownload = started.complete;
    final old = cubit.load('t1', 'a1');
    await started.future;
    repo
      ..pendingDownload = null
      ..onDownload = null;
    await cubit.load('t2', 'a2');
    pending.complete(Success(Uint8List.fromList([99])));
    await old;
    expect((cubit.state as NotesViewerReady).bytes, [1, 2, 3]);
    expect(repo.marks, ['a2']);
  });
}
