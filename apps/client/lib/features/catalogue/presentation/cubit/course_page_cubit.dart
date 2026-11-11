import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/catalogue/domain/repositories/catalogue_repository.dart';
import 'package:sat_east_client/features/catalogue/domain/usecases/check_course_preview.dart';
import 'package:sat_east_client/features/catalogue/presentation/cubit/course_page_state.dart';

class CoursePageCubit extends Cubit<CoursePageState> {
  CoursePageCubit(this._repository, this._checkPreview)
    : super(const CoursePageLoading());

  final CatalogueRepository _repository;
  final CheckCoursePreview _checkPreview;
  String? _slug;
  bool _signedIn = false;
  int _loadVersion = 0;

  Future<void> load(String slug, {bool signedIn = false}) async {
    if (isClosed) return;
    final version = ++_loadVersion;
    _slug = slug;
    _signedIn = signedIn;
    emit(const CoursePageLoading());
    final result = await _repository.getCoursePage(slug);
    if (isClosed || version != _loadVersion) return;
    switch (result) {
      case Success(:final value):
        final preview = await _checkPreview(value, signedIn: signedIn);
        if (isClosed || version != _loadVersion) return;
        switch (preview) {
          case Success(value: final canPreview):
            emit(CoursePageLoaded(value, canPreview: canPreview));
          case Failure(:final error):
            emit(CoursePageFailed(error));
        }
      case Failure(:final error):
        emit(CoursePageFailed(error));
    }
  }

  Future<void> retry() async {
    if (_slug case final slug?) await load(slug, signedIn: _signedIn);
  }
}
