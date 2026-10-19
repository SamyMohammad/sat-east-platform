import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/catalogue/domain/entities/catalogue_course.dart';
import 'package:sat_east_client/features/catalogue/domain/entities/course_page.dart';

abstract interface class CatalogueRepository {
  Future<Result<List<CatalogueCourse>>> getCatalogue();
  Future<Result<CoursePage>> getCoursePage(String slug);
}
