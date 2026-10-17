import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/course_map/data/datasources/course_map_remote_data_source.dart';
import 'package:sat_east_client/features/course_map/domain/entities/course_map.dart';
import 'package:sat_east_client/features/course_map/domain/repositories/course_map_repository.dart';

class CourseMapRepositoryImpl implements CourseMapRepository {
  CourseMapRepositoryImpl(this._remote);

  final CourseMapRemoteDataSource _remote;

  @override
  Future<Result<CourseMap>> getCourseMap({String? slug}) =>
      _remote.getCourseMap(slug: slug);
}
