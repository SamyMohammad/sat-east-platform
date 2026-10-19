import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/catalogue/data/datasources/catalogue_remote_data_source.dart';
import 'package:sat_east_client/features/catalogue/domain/entities/catalogue_course.dart';
import 'package:sat_east_client/features/catalogue/domain/entities/course_page.dart';
import 'package:sat_east_client/features/catalogue/domain/repositories/catalogue_repository.dart';

class CatalogueRepositoryImpl implements CatalogueRepository {
  CatalogueRepositoryImpl(this._remote);

  final CatalogueRemoteDataSource _remote;

  @override
  Future<Result<List<CatalogueCourse>>> getCatalogue() =>
      _remote.getCatalogue();

  @override
  Future<Result<CoursePage>> getCoursePage(String slug) =>
      _remote.getCoursePage(slug);
}
