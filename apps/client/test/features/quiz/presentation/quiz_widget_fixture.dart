part of 'quiz_view_test.dart';

class _MockCubit extends MockCubit<QuizState> implements QuizCubit {}

const _passed = QuizReport(
  scoreRaw: 9,
  scoreTotal: 12,
  scorePct: 75,
  passMark: 70,
  passed: true,
  nextTopic: (id: 't2', title: 'Systems'),
  retakeAt: null,
);

QuizRunning _running() => QuizRunning(
  session: QuizSession(
    attemptId: 'a1',
    title: 'Linear equations',
    timeLimit: const Duration(minutes: 20),
    deadline: DateTime.utc(2026, 10, 17, 12, 20),
    serverNow: DateTime.utc(2026, 10, 17, 12),
    warnAt: const Duration(seconds: 90),
    clientSeq: 3,
    answers: const {},
    questions: const [
      QuizQuestion(
        id: 'q1',
        kind: QuizKind.mcq,
        difficulty: 'M',
        stemMd: 'Solve the equation.',
        choices: [QuizChoice('A', 'One'), QuizChoice('B', 'Two')],
      ),
      QuizQuestion(
        id: 'q2',
        kind: QuizKind.spr,
        difficulty: 'H',
        stemMd: 'Enter the fraction.',
        choices: [],
      ),
    ],
  ),
  remaining: const Duration(minutes: 10),
  answers: const {'q1': 'B'},
  marked: const {'q1'},
);

_MockCubit _cubit(QuizState state, {Stream<QuizState>? stream}) {
  final cubit = _MockCubit();
  whenListen(
    cubit,
    stream ?? const Stream<QuizState>.empty(),
    initialState: state,
  );
  when(() => cubit.start(any())).thenAnswer((_) async {});
  when(cubit.submit).thenAnswer((_) async {});
  when(cubit.close).thenAnswer((_) async {});
  return cubit;
}

Future<GoRouter> _pump(
  WidgetTester tester,
  _MockCubit cubit, {
  double width = 360,
  bool screen = false,
  QuizReport? report,
  bool fromTopic = false,
}) async {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: fromTopic ? '/courses/topics/t1' : '/quiz',
    routes: [
      GoRoute(
        path: '/quiz',
        builder: (_, _) => Scaffold(
          body: report != null
              ? QuizResultScreen(topicId: 't1', report: report)
              : screen
              ? const QuizScreen(topicId: 't1')
              : BlocProvider<QuizCubit>.value(
                  value: cubit,
                  child: const QuizView(topicId: 't1'),
                ),
        ),
      ),
      GoRoute(
        path: '/courses/topics/t1',
        builder: (_, _) => const Scaffold(body: Text('Topic destination')),
      ),
      GoRoute(
        path: '/courses/topics/t2',
        builder: (_, _) => const Scaffold(body: Text('Next topic destination')),
      ),
      GoRoute(
        path: '/courses',
        builder: (_, _) => const Scaffold(body: Text('Course destination')),
      ),
      GoRoute(
        path: '/courses/topics/t1/quiz/result',
        builder: (_, _) => const Scaffold(body: Text('Result destination')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  if (fromTopic) {
    unawaited(router.push<void>('/quiz'));
    await tester.pumpAndSettle();
  }
  return router;
}

QuestionView _question(WidgetTester tester) =>
    tester.widget<QuestionView>(find.byType(QuestionView));
