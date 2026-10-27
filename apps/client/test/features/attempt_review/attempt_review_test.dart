// Keep the SDK / third-party / project import groups required by AGENTS.md.
// ignore_for_file: directives_ordering

import 'package:flutter/material.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/math_render/math_text.dart';
import 'package:sat_east_client/core/theme/app_icons.dart';
import 'package:sat_east_client/core/theme/app_theme.dart';
import 'package:sat_east_client/features/attempt_review/data/datasources/attempt_review_remote_data_source.dart';
import 'package:sat_east_client/features/attempt_review/data/models/attempt_review_model.dart';
import 'package:sat_east_client/features/attempt_review/data/repositories/attempt_review_repository_impl.dart';
import 'package:sat_east_client/features/attempt_review/presentation/attempt_review_copy.dart';
import 'package:sat_east_client/features/attempt_review/presentation/cubit/attempt_review_cubit.dart';
import 'package:sat_east_client/features/attempt_review/presentation/cubit/attempt_review_state.dart';
import 'package:sat_east_client/features/attempt_review/presentation/screens/attempt_review_screen.dart';
import 'package:sat_east_client/features/homework/presentation/homework_copy.dart';

import '../../core/fakes/fake_rpc.dart';
import 'review_fixture.dart';

void main() {
  testWidgets('review_card_shows_icon_and_word', (tester) async {
    final rpc = FakeRpc()..response = reviewPayload();
    final cubit = AttemptReviewCubit(
      AttemptReviewRepositoryImpl(AttemptReviewRemoteDataSource(rpc.call)),
    );
    addTearDown(cubit.close);
    await cubit.load('hw1');
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: BlocProvider.value(
            value: cubit,
            child: const AttemptReviewView(attemptId: 'hw1'),
          ),
        ),
      ),
    );
    expect(find.text('Incorrect'), findsOneWidget);
    expect(find.byIcon(AppIcons.incorrect), findsOneWidget);
  });
  for (final (pct, expected) in [(8.33, '8%'), (8.5, '9%'), (70.0, '70%')]) {
    test('PRC-02: scores round $pct to a whole percent', () {
      expect(AttemptReviewCopy.score(1, 12, pct), '1 / 12 \u00b7 $expected');
      expect(HomeworkCopy.submitted(pct), 'Submitted \u00b7 $expected');
    });
  }
  test('PRC-02: submitted review parses score, key and explanation', () {
    final review = attemptReviewFromJson(reviewPayload());
    expect(review.scoreRaw, 14);
    expect(review.scorePct, 70);
    expect(review.passMark, isNull);
    expect(review.passed, isNull);
    expect(review.questions.single.key, 'B');
    expect(review.questions.single.explanationMd, r'Because $x=1$.');
  });
  test('PRC-03: hidden keys are discarded even in an unexpected payload', () {
    final review = attemptReviewFromJson(reviewPayload(visible: false));
    expect(review.keysVisible, isFalse);
    expect(review.questions.single.key, isNull);
    expect(review.questions.single.explanationMd, isNull);
  });
  test('PRC-02: cubit calls review RPC and exposes loaded state', () async {
    final rpc = FakeRpc()..response = reviewPayload();
    final cubit = AttemptReviewCubit(
      AttemptReviewRepositoryImpl(AttemptReviewRemoteDataSource(rpc.call)),
    );
    addTearDown(cubit.close);
    final states = <AttemptReviewState>[];
    final sub = cubit.stream.listen(states.add);
    addTearDown(sub.cancel);
    await cubit.load('hw1');
    await Future<void>.delayed(Duration.zero);
    expect(states.last, isA<AttemptReviewLoaded>());
    expect(rpc.calls.single.$1, 'get_attempt_review');
    expect(rpc.calls.single.$2, {'p_attempt_id': 'hw1'});
  });
  test('PRC-03: review errors propagate cleanly', () async {
    final rpc = FakeRpc()
      ..error = const PostgrestException(message: 'attempt_not_submitted');
    final cubit = AttemptReviewCubit(
      AttemptReviewRepositoryImpl(AttemptReviewRemoteDataSource(rpc.call)),
    );
    addTearDown(cubit.close);
    await cubit.load('hw1');
    expect(
      (cubit.state as AttemptReviewFailed).error.code,
      ErrorCodes.attemptNotSubmitted,
    );
    rpc
      ..error = null
      ..response = {'summary': 'invalid'};
    await cubit.load('hw1');
    expect(
      (cubit.state as AttemptReviewFailed).error.code,
      ErrorCodes.internal,
    );
  });
  for (final width in [360.0, 1280.0]) {
    for (final visible in [true, false]) {
      testWidgets('PRC-02: review visibility $visible at $width', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final payload = reviewPayload(visible: visible);
        (payload['summary']! as Map<String, Object?>).addAll({
          'score_raw': 1,
          'score_total': 12,
          'score_pct': 8.33,
        });
        final rpc = FakeRpc()..response = payload;
        final cubit = AttemptReviewCubit(
          AttemptReviewRepositoryImpl(AttemptReviewRemoteDataSource(rpc.call)),
        );
        addTearDown(cubit.close);
        await cubit.load('hw1');
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: BlocProvider.value(
                value: cubit,
                child: const AttemptReviewView(attemptId: 'hw1'),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('1 / 12 \u00b7 8%'), findsOneWidget);
        expect(
          find.text('Correct answer'),
          visible ? findsOneWidget : findsNothing,
        );
        expect(
          find.text('Explanation'),
          visible ? findsOneWidget : findsNothing,
        );
        expect(
          find.text('Incorrect'),
          findsOneWidget,
        );
        for (final (label, value) in [
          ('My answer', 'A'),
          if (visible) ('Correct answer', 'B'),
          if (visible) ('Explanation', r'Because $x=1$.'),
        ]) {
          final labelFinder = find.text(label);
          final text = tester.widget<Text>(labelFinder);
          final context = tester.element(labelFinder);
          expect(
            text.style,
            Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          );
          final row = find.ancestor(
            of: labelFinder,
            matching: find.byType(Row),
          );
          expect(
            find.descendant(
              of: row,
              matching: find.byWidgetPredicate(
                (widget) => widget is MathText && widget.source == value,
              ),
            ),
            findsOneWidget,
          );
        }
        expect(tester.takeException(), isNull);
      });
    }
  }
}
