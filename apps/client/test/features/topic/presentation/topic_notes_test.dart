import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sat_east_client/core/di/injection.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/core/theme/app_theme.dart';
import 'package:sat_east_client/features/topic/domain/entities/topic_detail.dart';
import 'package:sat_east_client/features/topic/domain/entities/topic_note.dart';
import 'package:sat_east_client/features/topic/domain/repositories/topic_repository.dart';
import 'package:sat_east_client/features/topic/presentation/cubit/topic_cubit.dart';
import 'package:sat_east_client/features/topic/presentation/screens/topic_screen.dart';
import 'package:sat_east_client/shared/widgets/loading_button.dart';

class _Repo extends Mock implements TopicRepository {}

TopicDetail _topic(bool done) => TopicDetail(
  id: 't1',
  title: 'Topic',
  sortLabel: '1',
  status: TopicStatus.open,
  practiceCount: 0,
  practiceMin: 10,
  quiz: const QuizPracticeNeeded(count: 0, min: 10),
  notesDone: done,
  notes: const [
    TopicNote(
      assetId: 'a1',
      title: 'Algebra notes',
      subtopicTitle: 'Linear',
      pageCount: 3,
    ),
  ],
);

void main() {
  for (final width in [360.0, 1280.0]) {
    testWidgets(
      'L-3: notes precede locked practice and return reloads at $width',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 1000);
        addTearDown(tester.view.reset);
        var reads = 0;
        final repo = _Repo();
        when(
          () => repo.getTopic('t1'),
        ).thenAnswer((_) async => Success(_topic(reads++ > 0)));
        getIt.registerFactory<TopicCubit>(() => TopicCubit(repo));
        final router = GoRouter(
          initialLocation: '/courses/topics/t1',
          routes: [
            GoRoute(
              path: '/courses/topics/t1',
              builder: (_, _) =>
                  const Scaffold(body: TopicScreen(topicId: 't1')),
            ),
            GoRoute(
              path: '/courses/topics/t1/notes/a1',
              builder: (context, _) => Scaffold(
                body: TextButton(
                  onPressed: () => context.pop(),
                  child: const Text('Close notes'),
                ),
              ),
            ),
          ],
        );
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
          router.dispose();
          await getIt.unregister<TopicCubit>();
        });
        await tester.pumpWidget(
          MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
        );
        await tester.pumpAndSettle();
        expect(find.text('Open the notes first.'), findsOneWidget);
        LoadingButton practice() => tester.widget<LoadingButton>(
          find.widgetWithText(LoadingButton, 'Practice'),
        );
        expect(practice().onPressed, isNull);
        expect(
          tester.getTopLeft(find.text('Notes')).dy,
          lessThan(tester.getTopLeft(find.text('Practice')).dy),
        );
        await tester.tap(find.text('Algebra notes'));
        await tester.pumpAndSettle();
        expect(find.text('Close notes'), findsOneWidget);
        await tester.tap(find.text('Close notes'));
        await tester.pumpAndSettle();
        expect(reads, 2);
        expect(practice().onPressed, isNotNull);
        expect(find.text('Open the notes first.'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
