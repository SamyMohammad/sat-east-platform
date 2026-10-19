import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/catalogue/data/models/catalogue_course_model.dart';
import 'package:sat_east_client/features/catalogue/domain/entities/catalogue_course.dart';
import 'package:sat_east_client/features/catalogue/presentation/cubit/catalogue_cubit.dart';
import 'package:sat_east_client/features/catalogue/presentation/cubit/catalogue_state.dart';

import '../catalogue_fixtures.dart';

void main() {
  late FakeCatalogueRepository repository;
  final data = [catalogueCourseFromJson(coursePayload)];
  setUp(() {
    repository = FakeCatalogueRepository()..catalogue = Success(data);
  });
  blocTest<CatalogueCubit, CatalogueState>(
    'PAY-01: retry recovers from a failed request',
    build: () => CatalogueCubit(repository),
    act: (cubit) async {
      repository.catalogue = const Failure(AppError('network'));
      await cubit.load();
      repository.catalogue = Success(data);
      await cubit.retry();
    },
    expect: () => [
      const CatalogueLoading(),
      const CatalogueFailed(AppError('network')),
      const CatalogueLoading(),
      CatalogueLoaded(data),
    ],
  );
  for (final retry in [false, true]) {
    for (final failure in [false, true]) {
      blocTest<CatalogueCubit, CatalogueState>(
        'PAY-01: $retry retry / $failure failure emits load outcome',
        build: () {
          if (failure) {
            repository.catalogue = const Failure(AppError('network'));
          }
          return CatalogueCubit(repository);
        },
        act: (cubit) async {
          await cubit.load();
          if (retry) await cubit.retry();
        },
        expect: () => [
          const CatalogueLoading(),
          if (failure)
            const CatalogueFailed(AppError('network'))
          else
            CatalogueLoaded(data),
          if (retry) ...[
            const CatalogueLoading(),
            if (failure)
              const CatalogueFailed(AppError('network'))
            else
              CatalogueLoaded(data),
          ],
        ],
        verify: (_) => expect(repository.catalogueCalls, retry ? 2 : 1),
      );
    }
  }
  for (final outcome in <Result<List<CatalogueCourse>>>[
    Success(data),
    const Failure(AppError('network')),
  ]) {
    test('PAY-01: closed Catalogue ignores pending $outcome', () async {
      final pending = Completer<Result<List<CatalogueCourse>>>();
      repository.pendingCatalogue = pending.future;
      final cubit = CatalogueCubit(repository);
      final request = cubit.load();
      await cubit.close();
      pending.complete(outcome);
      await request;
      expect(cubit.state, const CatalogueLoading());
    });
  }
  test('PAY-01: Catalogue methods after close never call repository', () async {
    final cubit = CatalogueCubit(repository);
    await cubit.close();
    await cubit.load();
    await cubit.retry();
    expect(repository.catalogueCalls, 0);
  });
}
