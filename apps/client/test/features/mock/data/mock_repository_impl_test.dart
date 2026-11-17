import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/auth/domain/entities/my_enrollment.dart';
import 'package:sat_east_client/features/mock/data/datasources/mock_remote_data_source.dart';
import 'package:sat_east_client/features/mock/data/repositories/mock_repository_impl.dart';
import 'package:sat_east_client/features/mock/domain/entities/mock_entities.dart';

import '../../../core/fakes/fake_rpc.dart';
import 'mock_fixtures.dart';

MyEnrollment _enrollment(String id, String code, {bool expired = false}) =>
    MyEnrollment(
      courseId: id,
      courseTitle: code,
      courseCode: code,
      targetTestDate: null,
      expiresAt: DateTime.utc(2027),
      isExpired: expired,
    );

MockRepositoryImpl _repo(
  Result<List<MyEnrollment>> enrollments, {
  FakeRpc? rpc,
}) => MockRepositoryImpl(
  MockRemoteDataSource(
    (rpc ?? FakeRpc()).call,
    readResult: (_) async => resultRowJson(),
  ),
  listEnrollments: () async => enrollments,
);

String? _course(Result<String?> r) => (r as Success<String?>).value;

void main() {
  group('satCourseId', () {
    test('MCK-01: picks the SAT course among several enrolments', () async {
      final repo = _repo(
        Success([_enrollment('est', 'EST'), _enrollment('sat', 'SAT')]),
      );
      expect(_course(await repo.satCourseId()), 'sat');
    });

    test('MCK-01: an expired SAT enrolment is not used', () async {
      final repo = _repo(
        Success([
          _enrollment('sat', 'SAT', expired: true),
          _enrollment('est', 'EST'),
        ]),
      );
      expect(_course(await repo.satCourseId()), isNull);
    });

    test('MCK-01: an active SAT row beats an expired one', () async {
      final repo = _repo(
        Success([
          _enrollment('old', 'SAT', expired: true),
          _enrollment('new', 'SAT'),
        ]),
      );
      expect(_course(await repo.satCourseId()), 'new');
    });

    test(
      'MCK-01: no SAT enrolment is Success(null), never the latest',
      () async {
        final repo = _repo(Success([_enrollment('est', 'EST')]));
        expect(_course(await repo.satCourseId()), isNull);
        expect(_course(await _repo(const Success([])).satCourseId()), isNull);
      },
    );

    test('MCK-01: an enrolment failure is passed through', () async {
      final repo = _repo(const Failure(AppError(ErrorCodes.network)));
      final result = await repo.satCourseId();
      expect((result as Failure<String?>).error.code, ErrorCodes.network);
    });
  });

  test('MCK-01: the repository delegates to the data source', () async {
    final rpc = FakeRpc()..response = hubJson();
    final repo = _repo(const Success([]), rpc: rpc);
    final hub = (await repo.hub(courseId) as Success<MockHub>).value;
    expect(rpc.calls.single.$1, 'get_mock_hub');
    expect(hub.activeGroup, groupId);
    final result = (await repo.result(resultId) as Success<MockResult>).value;
    expect(result.rawM2, 15);
  });
}
