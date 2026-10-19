import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/catalogue/domain/repositories/catalogue_repository.dart';
import 'package:sat_east_client/features/catalogue/presentation/cubit/course_page_state.dart';

class CoursePageCubit extends Cubit<CoursePageState> {
  CoursePageCubit(this._repository) : super(const CoursePageLoading());

  final CatalogueRepository _repository;
  String? _slug;

  Future<void> load(String slug) async {
    if (isClosed) return;
    _slug = slug;
    emit(const CoursePageLoading());
    final result = await _repository.getCoursePage(slug);
    if (isClosed) return;
    switch (result) {
      case Success(:final value):
        emit(CoursePageLoaded(value));
      case Failure(:final error):
        emit(CoursePageFailed(error));
    }
  }

  Future<void> retry() async {
    if (_slug case final slug?) await load(slug);
  }
}
