import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/catalogue/data/datasources/catalogue_remote_data_source.dart';
import 'package:sat_east_client/features/catalogue/data/repositories/catalogue_repository_impl.dart';
import 'package:sat_east_client/features/catalogue/domain/entities/catalogue_course.dart';
import 'package:sat_east_client/features/catalogue/domain/entities/course_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/fakes/fake_rpc.dart';
import '../catalogue_fixtures.dart';

void main() {
  test('PAY-01: repository returns catalogue entities', () async {
    final rpc = FakeRpc()..response = [coursePayload];
    final repo = CatalogueRepositoryImpl(CatalogueRemoteDataSource(rpc.call));
    final result = await repo.getCatalogue();
    expect(
      (result as Success<List<CatalogueCourse>>).value.single.title,
      'SAT Math',
    );
  });
  test('PAY-01: repository returns page for requested slug', () async {
    final rpc = FakeRpc()..response = pagePayload;
    final repo = CatalogueRepositoryImpl(CatalogueRemoteDataSource(rpc.call));
    final result = await repo.getCoursePage('sat-math');
    expect((result as Success<CoursePage>).value.slug, 'sat-math');
    expect(rpc.calls.single.$2['p_slug'], 'sat-math');
  });
  for (final page in [false, true]) {
    test('PAY-01: repository preserves $page failure', () async {
      final rpc = FakeRpc()
        ..error = const PostgrestException(message: 'invalid_input');
      final repo = CatalogueRepositoryImpl(CatalogueRemoteDataSource(rpc.call));
      final result = page
          ? await repo.getCoursePage('missing')
          : await repo.getCatalogue();
      expect(
        (result as Failure).error,
        const AppError('invalid_input', 'invalid_input'),
      );
    });
  }
}
