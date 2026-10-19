import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/core/errors/supabase_error_mapper.dart';
import 'package:sat_east_client/core/supabase/rpc_caller.dart';
import 'package:sat_east_client/features/catalogue/data/models/catalogue_course_model.dart';
import 'package:sat_east_client/features/catalogue/data/models/catalogue_json.dart';
import 'package:sat_east_client/features/catalogue/data/models/course_page_model.dart';
import 'package:sat_east_client/features/catalogue/domain/entities/catalogue_course.dart';
import 'package:sat_east_client/features/catalogue/domain/entities/course_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CatalogueRemoteDataSource {
  CatalogueRemoteDataSource(this._rpc);

  final RpcCaller _rpc;

  Future<Result<List<CatalogueCourse>>> getCatalogue() => _fetch(
    'get_catalogue',
    {'p_country': null},
    (raw) => jsonList(raw, catalogueCourseFromJson),
  );

  Future<Result<CoursePage>> getCoursePage(String slug) => _fetch(
    'get_course_page',
    {'p_slug': slug, 'p_country': null},
    (raw) => coursePageFromJson(jsonObject(raw)),
  );

  Future<Result<T>> _fetch<T>(
    String function,
    Map<String, Object?> params,
    T Function(Object?) parse,
  ) async {
    try {
      return Success(parse(await _rpc(function, params)));
    } on PostgrestException catch (e) {
      return Failure(mapPostgrestException(e));
    } on Object catch (e) {
      return Failure(mapUnknownError(e));
    }
  }
}
