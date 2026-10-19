import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/teacher/course_builder/domain/entities/course_tree.dart';
import 'package:sat_east_client/features/teacher/course_builder/domain/entities/node_kind.dart';
import 'package:sat_east_client/features/teacher/course_builder/presentation/cubit/course_builder_cubit.dart';
import 'package:sat_east_client/features/teacher/course_builder/presentation/cubit/course_builder_state.dart';

import '../builder_fixtures.dart';

void main() {
  late FakeBuilderRepository repo;
  late CourseBuilderCubit cubit;
  setUp(() {
    repo = FakeBuilderRepository();
    cubit = CourseBuilderCubit(repo);
  });
  tearDown(() => cubit.close());

  test('C-1: loads courses and first tree', () async {
    await cubit.load(null);
    final state = cubit.state as CourseBuilderLoaded;
    expect(state.tree, builderTree);
    expect(state.courses, builderCourses);
    expect(repo.calls.map((call) => [call.$1, call.$2]), [
      ['list', <String, Object?>{}],
      [
        'tree',
        {'courseId': 'c1'},
      ],
    ]);
  });
  test('C-1: explicit course is loaded', () async {
    await cubit.load('c2');
    expect(repo.calls.last.$1, 'tree');
    expect(repo.calls.last.$2, equals({'courseId': 'c2'}));
  });
  test('C-1: empty catalogue has an explicit empty state', () async {
    repo.courses = const Success([]);
    await cubit.load(null);
    expect((cubit.state as CourseBuilderLoaded).tree, isNull);
    expect(repo.calls.length, 1);
  });
  for (final target in ['courses', 'tree']) {
    test('C-1: load maps $target failure', () async {
      if (target == 'courses') {
        repo.courses = const Failure(AppError(ErrorCodes.forbidden));
      } else {
        repo.tree = const Failure(AppError(ErrorCodes.forbidden));
      }
      await cubit.load('c1');
      expect(
        (cubit.state as CourseBuilderFailed).error.code,
        ErrorCodes.forbidden,
      );
    });
  }
  final actions = <String, Future<void> Function(CourseBuilderCubit)>{
    'add unit': (c) => c.addUnit('New unit'),
    'add topic': (c) => c.addTopic('u1', 'New topic'),
    'add subtopic': (c) => c.addSubtopic('t1', 'New subtopic'),
    'rename unit': (c) => c.rename(NodeKind.unit, 'u1', 'New title'),
    'rename topic': (c) => c.rename(NodeKind.topic, 't1', 'New title'),
    'rename subtopic': (c) => c.rename(NodeKind.subtopic, 's1', 'New title'),
    'delete': (c) => c.delete(NodeKind.topic, 't2'),
    'flags': (c) => c.setFlags('t1', isFreePreview: true),
    'reorder': (c) => c.reorder(NodeKind.topic, 'u1', ['t2', 't1']),
  };
  for (final action in actions.entries) {
    test('C-1: ${action.key} reloads after success', () async {
      await cubit.load('c1');
      repo.calls.clear();
      await action.value(cubit);
      expect(repo.calls.length, 2);
      expect(repo.calls.last.$1, 'tree');
      expect(repo.calls.last.$2, equals({'courseId': 'c1'}));
      final loaded = cubit.state as CourseBuilderLoaded;
      expect(loaded.busyId, isNull);
      expect(loaded.lastError, isNull);
      expect(loaded.tree, builderTree);
    });
    test('C-1: ${action.key} preserves tree on failure', () async {
      await cubit.load('c1');
      repo
        ..write = const Failure(AppError(ErrorCodes.inUse))
        ..mutation = const Failure(AppError(ErrorCodes.inUse))
        ..flags = const Failure(AppError(ErrorCodes.inUse));
      repo.calls.clear();
      await action.value(cubit);
      final loaded = cubit.state as CourseBuilderLoaded;
      expect(loaded.tree, builderTree);
      expect(loaded.lastError?.code, ErrorCodes.inUse);
      expect(loaded.busyId, isNull);
      expect(repo.calls.length, 1);
    });
  }
  test('C-1: rename resolves correct parent at each level', () async {
    await cubit.load('c1');
    for (final (kind, id, parent) in [
      (NodeKind.unit, 'u1', 'c1'),
      (NodeKind.topic, 't1', 'u1'),
      (NodeKind.subtopic, 's1', 't1'),
    ]) {
      await cubit.rename(kind, id, 'Title');
      expect(repo.calls[repo.calls.length - 2].$2, {
        'id': id,
        'parent': parent,
        'title': 'Title',
      });
    }
  });
  test('C-1: reorder is optimistic and rolls back', () async {
    await cubit.load('c1');
    final pending = Completer<Result<void>>();
    repo.pending = pending.future;
    final future = cubit.reorder(NodeKind.topic, 'u1', ['t2', 't1']);
    final optimistic = cubit.state as CourseBuilderLoaded;
    expect(optimistic.tree!.units.first.topics.map((t) => t.id), ['t2', 't1']);
    expect(optimistic.tree!.units.first.topics.map((t) => t.sort), [1, 2]);
    expect(optimistic.busyId, 'u1');
    pending.complete(const Failure(AppError(ErrorCodes.network)));
    await future;
    expect((cubit.state as CourseBuilderLoaded).tree, builderTree);
  });
  test('C-1: all levels reorder without mutating the old tree', () {
    for (final (kind, parent, ids) in [
      (NodeKind.unit, 'c1', ['u2', 'u1']),
      (NodeKind.topic, 'u1', ['t2', 't1']),
      (NodeKind.subtopic, 't1', ['s2', 's1']),
    ]) {
      final next = builderTree.reordered(kind, parent, ids);
      expect(next!.childIds(kind, parent), ids);
    }
    expect(builderTree.units.first.id, 'u1');
    expect(builderTree.units.first.topics.first.id, 't1');
  });
  test('C-1: malformed reorder is rejected before sending', () async {
    await cubit.load('c1');
    repo.calls.clear();
    await cubit.reorder(NodeKind.topic, 'u1', ['t1', 't1']);
    expect(repo.calls, isEmpty);
    expect(
      (cubit.state as CourseBuilderLoaded).lastError?.code,
      ErrorCodes.invalidInput,
    );
  });
  for (final (kind, parent, valid) in [
    (NodeKind.unit, 'c1', ['u1', 'u2']),
    (NodeKind.topic, 'u1', ['t1', 't2']),
    (NodeKind.subtopic, 't1', ['s1', 's2']),
  ]) {
    test('C-1: $kind rejects missing, extra and foreign reorder IDs', () {
      for (final ids in [
        valid.take(1).toList(),
        [...valid, 'extra'],
        [valid.first, 'foreign'],
        [valid.first, valid.first],
      ]) {
        expect(builderTree.reordered(kind, parent, ids), isNull);
      }
      expect(builderTree.reordered(kind, 'unknown', valid), isNull);
    });
  }
  test('C-1: unknown rename target produces an input failure', () async {
    await cubit.load('c1');
    repo.calls.clear();
    await cubit.rename(NodeKind.topic, 'unknown', 'Title');
    expect(repo.calls, isEmpty);
    expect(
      (cubit.state as CourseBuilderLoaded).lastError?.code,
      ErrorCodes.invalidInput,
    );
  });
  test('C-1: closing during a write does not emit or refresh', () async {
    await cubit.load('c1');
    repo.calls.clear();
    final pending = Completer<Result<void>>();
    repo.pending = pending.future;
    final future = cubit.reorder(NodeKind.topic, 'u1', ['t2', 't1']);
    await cubit.close();
    pending.complete(const Success(null));
    await expectLater(future, completes);
    expect(repo.calls.map((call) => call.$1), ['reorder']);
  });
  test('C-1: mutation reload failure stays visible', () async {
    await cubit.load('c1');
    repo.tree = const Failure(AppError(ErrorCodes.network));
    await cubit.addUnit('New');
    expect(
      (cubit.state as CourseBuilderLoaded).lastError?.code,
      ErrorCodes.network,
    );
  });
  test('C-1: overlapping writes are ignored', () async {
    await cubit.load('c1');
    final pending = Completer<Result<void>>();
    repo.pending = pending.future;
    final future = cubit.reorder(NodeKind.unit, 'c1', ['u2', 'u1']);
    await cubit.addUnit('Ignored');
    expect(repo.calls.where((c) => c.$1 == 'unit'), isEmpty);
    pending.complete(const Success(null));
    await future;
  });
  test('C-1: late load does not overwrite the next course', () async {
    final pending = Completer<Result<CourseTree>>();
    repo.pendingTree = pending.future;
    final started = Completer<void>();
    repo.onTree = started.complete;
    final first = cubit.load('c1');
    await started.future;
    repo
      ..onTree = null
      ..pendingTree = null;
    await cubit.load('c2');
    final latest = cubit.state;
    pending.complete(const Failure(AppError(ErrorCodes.network)));
    await first;
    expect(cubit.state, same(latest));
  });
  test('C-1: closing while loading does not emit', () async {
    final pending = Completer<Result<CourseTree>>();
    repo.pendingTree = pending.future;
    final started = Completer<void>();
    repo.onTree = started.complete;
    final future = cubit.load('c1');
    await started.future;
    repo.onTree = null;
    await cubit.close();
    pending.complete(Success(builderTree));
    await expectLater(future, completes);
  });
}
