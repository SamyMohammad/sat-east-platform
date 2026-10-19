import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/catalogue/domain/entities/catalogue_course.dart';
import 'package:sat_east_client/features/catalogue/domain/entities/course_page.dart';
import 'package:sat_east_client/features/catalogue/domain/repositories/catalogue_repository.dart';

const coursePayload = <String, Object?>{
  'id': 'c1',
  'code': 'SAT',
  'slug': 'sat-math',
  'title': 'SAT Math',
  'description': 'Build your math skills.',
  'topic_count': 3,
  'free_topic_slug': 'linear',
  'price': {'currency': 'EGP', 'amount_minor': 240000},
};
const pagePayload = <String, Object?>{
  'id': 'c1',
  'code': 'SAT',
  'slug': 'sat-math',
  'title': 'SAT Math',
  'description': 'Build your math skills.',
  'price': {'currency': 'EGP', 'amount_minor': 240000},
  'units': [
    {
      'title': 'Algebra',
      'topics': [
        {
          'slug': 'linear',
          'title': 'Linear equations',
          'is_free_preview': true,
          'subtopic_count': 4,
        },
        {
          'slug': 'systems',
          'title': 'Systems',
          'is_free_preview': false,
          'subtopic_count': 2,
        },
      ],
    },
    {
      'title': 'Advanced math',
      'topics': [
        {
          'slug': 'quadratics',
          'title': 'Quadratics',
          'is_free_preview': false,
          'subtopic_count': 3,
        },
      ],
    },
  ],
};

class FakeCatalogueRepository implements CatalogueRepository {
  Result<List<CatalogueCourse>> catalogue = const Success([]);
  late Result<CoursePage> page;
  Future<Result<List<CatalogueCourse>>>? pendingCatalogue;
  Future<Result<CoursePage>>? pendingPage;
  int catalogueCalls = 0;
  final slugs = <String>[];

  @override
  Future<Result<List<CatalogueCourse>>> getCatalogue() async {
    catalogueCalls++;
    return pendingCatalogue ?? catalogue;
  }

  @override
  Future<Result<CoursePage>> getCoursePage(String slug) async {
    slugs.add(slug);
    return pendingPage ?? page;
  }
}
