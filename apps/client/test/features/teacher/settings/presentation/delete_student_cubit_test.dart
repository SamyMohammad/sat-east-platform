import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/teacher/settings/presentation/cubit/delete_student_cubit.dart';
import 'package:sat_east_client/features/teacher/settings/presentation/cubit/delete_student_state.dart';

import '../settings_fixtures.dart';

void main() {
  late FakeTeacherSettingsRepository repo;
  late DeleteStudentCubit cubit;
  setUp(() {
    repo = FakeTeacherSettingsRepository();
    cubit = DeleteStudentCubit(repo);
  });
  tearDown(() => cubit.close());

  test('P3: starts idle', () {
    expect(cubit.state, isA<DeleteStudentIdle>());
  });
  test('P3: delete trims the email, emits progress then done', () async {
    final emitted = expectLater(
      cubit.stream,
      emitsInOrder([
        isA<DeleteStudentInProgress>(),
        const DeleteStudentDone('a@b.com'),
      ]),
    );
    await cubit.delete('  a@b.com ');
    await emitted;
    expect(repo.deletes, ['a@b.com']);
  });
  test('P3: blank email fails with invalid_input without a call', () async {
    await cubit.delete('   ');
    expect(repo.deletes, isEmpty);
    expect(
      (cubit.state as DeleteStudentFailed).error.code,
      ErrorCodes.invalidInput,
    );
  });
  test('P3: server failure is exposed', () async {
    repo.deleteResult = const Failure(AppError(ErrorCodes.studentNotFound));
    await cubit.delete('a@b.com');
    expect(
      (cubit.state as DeleteStudentFailed).error.code,
      ErrorCodes.studentNotFound,
    );
  });
  test('P3: a second delete while one is running is ignored', () async {
    final pending = Completer<Result<void>>();
    repo.pendingDelete = pending.future;
    final first = cubit.delete('a@b.com');
    await cubit.delete('a@b.com');
    expect(repo.deletes, hasLength(1));
    pending.complete(const Success(null));
    await first;
    expect(cubit.state, isA<DeleteStudentDone>());
  });
  test('P3: closing mid-request emits nothing and does not throw', () async {
    final pending = Completer<Result<void>>();
    repo.pendingDelete = pending.future;
    final call = cubit.delete('a@b.com');
    await cubit.close();
    pending.complete(const Success(null));
    await call;
    expect(cubit.state, isA<DeleteStudentInProgress>());
  });
  test('P3: reset returns to idle after a result', () async {
    repo.deleteResult = const Failure(AppError(ErrorCodes.forbidden));
    await cubit.delete('a@b.com');
    cubit.reset();
    expect(cubit.state, isA<DeleteStudentIdle>());
  });
  test('P3: confirmationMatches needs the exact email', () {
    expect(
      DeleteStudentCubit.confirmationMatches('a@b.com', ' a@b.com '),
      isTrue,
    );
    expect(
      DeleteStudentCubit.confirmationMatches('a@b.com', 'A@b.com'),
      isFalse,
    );
    expect(DeleteStudentCubit.confirmationMatches('a@b.com', ''), isFalse);
    expect(DeleteStudentCubit.confirmationMatches('', ''), isFalse);
  });
}
