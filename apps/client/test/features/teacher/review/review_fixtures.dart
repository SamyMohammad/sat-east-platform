import 'package:sat_east_client/core/di/injection.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/teacher/review/domain/entities/review.dart';
import 'package:sat_east_client/features/teacher/review/domain/repositories/review_repository.dart';
import 'package:sat_east_client/features/teacher/review/domain/usecases/review_actions.dart';
import 'package:sat_east_client/features/teacher/review/presentation/cubit/review_counts_cubit.dart';
import 'package:sat_east_client/features/teacher/review/presentation/cubit/review_queue_cubit.dart';
import 'package:sat_east_client/features/teacher/review/presentation/cubit/review_reports_cubit.dart';

const Map<String, Object?> queueJson = {
  'total': 2,
  'page': 1,
  'page_size': 1,
  'rows': <Object?>[
    {
      'question_id': 'q1',
      'external_ref': 'REF_1',
      'stem_preview': r'Solve \(x+1=2\).',
      'status': 'published',
      'open_count': 2,
      'oldest_report_at': '2026-10-29T10:00:00Z',
      'reasons': {'answer_key': 1, 'typo': 1},
      'latest_note': '<b>plain note</b>',
    },
  ],
};
final List<QuestionReport> openReports = [
  QuestionReport(
    id: 'r1',
    reason: 'answer_key',
    note: '<b>Plain report</b>',
    createdAt: DateTime.utc(2026, 10, 29),
    fullName: 'Student name',
  ),
];
ReviewPage reviewPage({int page = 1, int total = 2}) => ReviewPage(
  total: total,
  page: page,
  pageSize: 1,
  rows: [
    ReviewRow(
      questionId: page == 1 ? 'q1' : 'q2',
      externalRef: 'REF_$page',
      stemPreview: 'Solve.',
      status: 'published',
      openCount: 2,
      reasons: const {'answer_key': 1, 'typo': 1},
      oldestReportAt: DateTime.utc(2026, 10, 29),
      latestNote: '<b>plain note</b>',
    ),
  ],
);

class FakeReviewRepository implements ReviewRepository {
  final List<(ReviewSection, int)> pages = [];
  final List<(String, String, String?)> resolutions = [];
  final List<String> reportIds = [];
  AppError? listError;
  AppError? resolveError;
  AppError? reportsError;
  AppError? countsError;
  Future<Result<ReviewPage>>? pending;
  Future<Result<ReviewCounts>>? pendingCounts;
  Future<Result<int>>? pendingResolve;
  List<QuestionReport> reportsValue = [];
  ReviewCounts countsValue = const ReviewCounts(reported: 0, needsReview: 0);
  int countCalls = 0;
  @override
  Future<Result<ReviewPage>> list(ReviewSection section, int page) async {
    pages.add((section, page));
    if (pending case final future?) return future;
    return listError == null
        ? Success(reviewPage(page: page))
        : Failure(listError!);
  }

  @override
  Future<Result<List<QuestionReport>>> reports(String id) async {
    reportIds.add(id);
    return reportsError == null
        ? Success(List.of(reportsValue))
        : Failure(reportsError!);
  }

  @override
  Future<Result<int>> resolve(String id, String outcome, String? note) async {
    resolutions.add((id, outcome, note));
    if (resolveError != null) return Failure(resolveError!);
    if (pendingResolve != null) return pendingResolve!;
    reportsValue = [];
    return const Success(2);
  }

  @override
  Future<Result<ReviewCounts>> counts() async {
    countCalls++;
    if (pendingCounts case final future?) return future;
    return countsError == null ? Success(countsValue) : Failure(countsError!);
  }
}

void registerReviewFakes({FakeReviewRepository? repository}) {
  final actions = ReviewActions(repository ?? FakeReviewRepository());
  getIt
    ..registerFactory<ReviewCountsCubit>(() => ReviewCountsCubit(actions))
    ..registerFactory<ReviewReportsCubit>(() => ReviewReportsCubit(actions))
    ..registerFactory<ReviewQueueCubit>(() => ReviewQueueCubit(actions));
}

Future<void> unregisterReviewFakes() async {
  await getIt.unregister<ReviewQueueCubit>();
  await getIt.unregister<ReviewReportsCubit>();
  await getIt.unregister<ReviewCountsCubit>();
}
