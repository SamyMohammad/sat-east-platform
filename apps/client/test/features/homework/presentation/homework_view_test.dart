import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/theme/app_theme.dart';
import 'package:sat_east_client/features/homework/data/datasources/homework_remote_data_source.dart';
import 'package:sat_east_client/features/homework/data/repositories/homework_repository_impl.dart';
import 'package:sat_east_client/features/homework/presentation/cubit/homework_cubit.dart';
import 'package:sat_east_client/features/homework/presentation/screens/homework_screen.dart';
import 'package:sat_east_client/shared/widgets/question_view/question_view.dart';
import 'package:sat_east_client/shared/widgets/question_view/question_view_mode.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/fakes/fake_rpc.dart';
import '../homework_fixture.dart';

void main() {
  for (final width in [360.0, 1280.0]) {
    testWidgets('PRC-05: untimed homework and restored answers at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final rpc = FakeRpc()..response = homeworkPayload();
      final cubit = HomeworkCubit(
        HomeworkRepositoryImpl(HomeworkRemoteDataSource(rpc.call)),
        () => DateTime.utc(2026),
        (_) => const Stream<void>.empty(),
      );
      addTearDown(cubit.close);
      await cubit.start('t1');
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: BlocProvider.value(
              value: cubit,
              child: const HomeworkView(topicId: 't1'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final view = tester.widget<QuestionView>(find.byType(QuestionView));
      expect(view.mode, isA<HomeworkMode>());
      expect(view.answer.selected, 'B');
      expect(view.answer.marked, isTrue);
      expect((view.mode as HomeworkMode).saveStatus, SaveStatus.saved);
      cubit.goTo(1);
      await tester.pumpAndSettle();
      expect(
        tester.widget<QuestionView>(find.byType(QuestionView)).question.id,
        'q2',
      );
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('PRC-02: failed homework start shows actionable copy', (
    tester,
  ) async {
    final rpc = FakeRpc()
      ..error = const PostgrestException(message: 'practice_needed');
    final cubit = HomeworkCubit(
      HomeworkRepositoryImpl(HomeworkRemoteDataSource(rpc.call)),
      () => DateTime.utc(2026),
      (_) => const Stream<void>.empty(),
    );
    addTearDown(cubit.close);
    await cubit.start('t1');
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: BlocProvider.value(
            value: cubit,
            child: const HomeworkView(topicId: 't1'),
          ),
        ),
      ),
    );
    expect(find.text('Complete the practice first.'), findsOneWidget);
  });
}
