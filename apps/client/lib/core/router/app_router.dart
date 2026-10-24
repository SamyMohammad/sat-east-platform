import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:sat_east_client/core/env/env.dart';
import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/router/auth_refresh.dart';
import 'package:sat_east_client/core/router/placeholder_screen.dart';
import 'package:sat_east_client/features/activation/presentation/screens/activate_screen.dart';
import 'package:sat_east_client/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:sat_east_client/features/auth/presentation/cubit/auth_state.dart';
import 'package:sat_east_client/features/auth/presentation/screens/account_screen.dart';
import 'package:sat_east_client/features/auth/presentation/screens/check_inbox_screen.dart';
import 'package:sat_east_client/features/auth/presentation/screens/device_gate_screen.dart';
import 'package:sat_east_client/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:sat_east_client/features/auth/presentation/screens/set_new_password_screen.dart';
import 'package:sat_east_client/features/auth/presentation/screens/sign_in_screen.dart';
import 'package:sat_east_client/features/auth/presentation/screens/sign_up_screen.dart';
import 'package:sat_east_client/features/catalogue/presentation/screens/catalogue_screen.dart';
import 'package:sat_east_client/features/catalogue/presentation/screens/course_page_screen.dart';
import 'package:sat_east_client/features/course_map/presentation/screens/course_map_screen.dart';
import 'package:sat_east_client/features/design_gallery/presentation/gallery_screen.dart';
import 'package:sat_east_client/features/notes/presentation/screens/notes_viewer_screen.dart'
    deferred as notes_viewer;
import 'package:sat_east_client/features/practice/presentation/screens/practice_screen.dart';
import 'package:sat_east_client/features/quiz/domain/entities/quiz.dart';
import 'package:sat_east_client/features/quiz/presentation/quiz_entry.dart';
import 'package:sat_east_client/features/quiz/presentation/screens/quiz_result_screen.dart';
import 'package:sat_east_client/features/quiz/presentation/screens/quiz_screen.dart';
import 'package:sat_east_client/features/teacher/course_builder/presentation/screens/course_builder_screen.dart';
import 'package:sat_east_client/features/teacher/notes/presentation/screens/teacher_notes_screen.dart';
import 'package:sat_east_client/features/teacher/questions/presentation/screens/question_bank_screen.dart';
import 'package:sat_east_client/features/teacher/questions/presentation/screens/question_editor_screen.dart';
import 'package:sat_east_client/features/teacher/questions/presentation/screens/question_import_screen.dart';
import 'package:sat_east_client/features/teacher/review/presentation/screens/review_queue_screen.dart';
import 'package:sat_east_client/features/teacher/settings/presentation/screens/teacher_settings_screen.dart';
import 'package:sat_east_client/features/teacher/shell/teacher_shell.dart';
import 'package:sat_east_client/features/topic/presentation/screens/topic_screen.dart';
import 'package:sat_east_client/shared/widgets/app_shell/app_shell.dart';
import 'package:sat_east_client/shared/widgets/app_shell/app_shell_destination.dart';
import 'package:sat_east_client/shared/widgets/app_splash.dart';

abstract final class AppRoutes {
  static const catalogue = '/catalogue';
  static String coursePage(String slug) =>
      '$catalogue/${Uri.encodeComponent(slug)}';
  static const home = '/';
  static const activate = '/activate';
  static const courses = '/courses';
  static String topic(String id) => '/courses/topics/$id';
  static String notes(String topicId, String assetId) =>
      '/courses/topics/$topicId/notes/$assetId';
  static String practice(String id) => '/courses/topics/$id/practice';
  static String quiz(String id) => '/courses/topics/$id/quiz';
  static String quizResult(String id) => '/courses/topics/$id/quiz/result';
  static const skills = '/skills';
  static const mockExams = '/mock-exams';
  static const profile = '/profile';
  static const gallery = '/gallery';
  static const signIn = '/sign-in';
  static const signUp = '/sign-up';
  static const checkInbox = '/check-inbox';
  static const devices = '/devices';
  static const forgotPassword = '/forgot-password';
  static const teacher = '/teacher';
  static const teacherQuestions = '/teacher/questions';
  static const teacherQuestionImport = '/teacher/questions/import';
  static String teacherNotes(String courseId, String topicId) =>
      '/teacher/courses/$courseId/topics/$topicId/notes';
  static const teacherSettings = '/teacher/settings';
  static const teacherReview = '/teacher/review';
  static const resetPassword = '/reset-password';
}

/// [refresh] is owned (and disposed) by the caller; when omitted with [auth],
/// a stream-backed one is created and never disposed (tests only).
/// Auth screens read the [AuthCubit] from a `BlocProvider` above the app.
/// With [auth] set, the router redirects by session state; without it (tests)
/// there is no guard.
GoRouter createRouter({
  String? initialLocation,
  bool? includeGallery,
  AuthCubit? auth,
  Listenable? refresh,
}) {
  assert(refresh == null || auth != null, 'refresh requires auth');
  final galleryEnabled = !Env.isProd && (includeGallery ?? true);
  final newEditorKey = GlobalKey<QuestionEditorScreenState>();
  final editorKey = GlobalKey<QuestionEditorScreenState>();
  Future<bool> confirmEditorExit(
    GlobalKey<QuestionEditorScreenState> key,
  ) async {
    if (auth != null) {
      final session = auth.state;
      if (session is! AuthSignedIn || !session.user.isTeacher) return true;
    }
    return await key.currentState?.confirmLeave() ?? true;
  }

  return GoRouter(
    initialLocation: initialLocation,
    refreshListenable:
        refresh ?? (auth == null ? null : GoRouterRefreshStream(auth.stream)),
    redirect: auth == null
        ? null
        : (context, state) =>
              _authRedirect(auth.state, state.uri.path, galleryEnabled),
    routes: [
      GoRoute(
        path: AppRoutes.catalogue,
        builder: (context, state) => const CatalogueScreen(),
      ),
      GoRoute(
        path: '${AppRoutes.catalogue}/:slug',
        builder: (context, state) =>
            CoursePageScreen(slug: state.pathParameters['slug']!),
      ),
      GoRoute(
        path: AppRoutes.teacher,
        builder: (context, state) =>
            const TeacherShell(child: CourseBuilderScreen()),
      ),
      GoRoute(
        path: '${AppRoutes.teacher}/courses/:courseId',
        builder: (context, state) => TeacherShell(
          child: CourseBuilderScreen(
            courseId: state.pathParameters['courseId'],
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.teacherReview,
        builder: (_, _) => const TeacherShell(child: ReviewQueueScreen()),
      ),
      GoRoute(
        path: AppRoutes.teacherSettings,
        builder: (context, state) => const TeacherShell(
          child: TeacherSettingsScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.teacherQuestionImport,
        builder: (context, state) =>
            const TeacherShell(child: QuestionImportScreen()),
      ),
      GoRoute(
        path: AppRoutes.teacherQuestions,
        builder: (context, state) =>
            const TeacherShell(child: QuestionBankScreen()),
      ),
      GoRoute(
        path: '${AppRoutes.teacherQuestions}/new',
        builder: (context, state) =>
            TeacherShell(child: QuestionEditorScreen(key: newEditorKey)),
        onExit: (context, state) => confirmEditorExit(newEditorKey),
      ),
      GoRoute(
        path: '${AppRoutes.teacherQuestions}/:id',
        builder: (context, state) => TeacherShell(
          child: QuestionEditorScreen(
            key: editorKey,
            questionId: state.pathParameters['id'],
          ),
        ),
        onExit: (context, state) => confirmEditorExit(editorKey),
      ),
      GoRoute(
        path: '${AppRoutes.teacher}/courses/:courseId/topics/:topicId/notes',
        builder: (context, state) => TeacherShell(
          child: TeacherNotesScreen(
            courseId: state.pathParameters['courseId']!,
            topicId: state.pathParameters['topicId']!,
          ),
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) {
          final appShell = AppShell(
            selectedIndex: shell.currentIndex,
            onDestinationSelected: (index) => shell.goBranch(
              index,
              initialLocation:
                  index == shell.currentIndex &&
                  AppShellDestination.values[index] ==
                      AppShellDestination.courses,
            ),
            child: shell,
          );
          if (auth == null) return appShell;
          // AuthBusy is only emitted at boot/sign-in/sign-up, never while on
          // shell paths; emitting it while signed in would unmount the shell
          // and reset the branch stacks.
          return BlocSelector<AuthCubit, AuthState, bool>(
            bloc: auth,
            selector: (s) => s is AuthUnknown || s is AuthBusy,
            builder: (_, busy) => busy ? const AppSplash() : appShell,
          );
        },
        branches: [
          for (final destination in AppShellDestination.values)
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: _pathFor(destination),
                  builder: (context, state) => switch (destination) {
                    AppShellDestination.courses => const CourseMapScreen(),
                    AppShellDestination.home => const PlaceholderScreen(),
                    AppShellDestination.profile => const AccountScreen(),
                    _ => PlaceholderScreen(title: destination.label),
                  },
                  routes: [
                    if (destination == AppShellDestination.courses) ...[
                      GoRoute(
                        path: 'topics/:topicId',
                        builder: (context, state) => TopicScreen(
                          topicId: state.pathParameters['topicId']!,
                          title: switch (state.extra) {
                            final String t => t,
                            _ => null,
                          },
                        ),
                      ),
                      GoRoute(
                        path: 'topics/:topicId/notes/:assetId',
                        builder: (context, state) => _DeferredNotesViewer(
                          topicId: state.pathParameters['topicId']!,
                          assetId: state.pathParameters['assetId']!,
                        ),
                      ),
                      GoRoute(
                        path: 'topics/:topicId/practice',
                        builder: (context, state) => PracticeScreen(
                          topicId: state.pathParameters['topicId']!,
                          title: switch (state.extra) {
                            final String t => t,
                            _ => null,
                          },
                        ),
                      ),
                      GoRoute(
                        path: 'topics/:topicId/quiz',
                        redirect: (context, state) =>
                            state.extra == QuizEntry.startOrResume
                            ? null
                            : AppRoutes.topic(state.pathParameters['topicId']!),
                        builder: (context, state) => QuizScreen(
                          topicId: state.pathParameters['topicId']!,
                        ),
                      ),
                      GoRoute(
                        path: 'topics/:topicId/quiz/result',
                        redirect: (context, state) => state.extra is QuizReport
                            ? null
                            : AppRoutes.topic(state.pathParameters['topicId']!),
                        builder: (context, state) => QuizResultScreen(
                          topicId: state.pathParameters['topicId']!,
                          // The redirect above requires a report.
                          report: state.extra! as QuizReport,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
        ],
      ),
      GoRoute(
        path: AppRoutes.activate,
        builder: (context, state) => const ActivateScreen(),
      ),
      GoRoute(
        path: AppRoutes.signIn,
        builder: (context, state) => const SignInScreen(),
      ),
      GoRoute(
        path: AppRoutes.signUp,
        builder: (context, state) => const SignUpScreen(),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.resetPassword,
        builder: (context, state) => const SetNewPasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.checkInbox,
        builder: (context, state) => const CheckInboxScreen(),
      ),
      GoRoute(
        path: AppRoutes.devices,
        builder: (context, state) => const DeviceGateScreen(),
      ),
      if (galleryEnabled)
        GoRoute(
          path: AppRoutes.gallery,
          builder: (context, state) =>
              GalleryScreen(entryId: state.uri.queryParameters['entry']),
        ),
    ],
  );
}

const _signedOutPaths = <String>{
  AppRoutes.signIn,
  AppRoutes.signUp,
  AppRoutes.forgotPassword,
  AppRoutes.resetPassword,
};

/// Returns the location to move to, or null to stay. Never loops: every
/// target is a fixed point of the same function for that state.
String? _authRedirect(AuthState state, String path, bool galleryEnabled) {
  if (state is AuthRecovery) {
    return path == AppRoutes.resetPassword ? null : AppRoutes.resetPassword;
  }
  if (state is AuthSignedOut && state.error?.code == ErrorCodes.linkExpired) {
    return path == AppRoutes.forgotPassword ? null : AppRoutes.forgotPassword;
  }
  if (state is AuthSignedIn &&
      !state.user.isTeacher &&
      (path == AppRoutes.teacher || path.startsWith('${AppRoutes.teacher}/'))) {
    return AppRoutes.home;
  }
  if (galleryEnabled && path == AppRoutes.gallery) return null;
  if ((state is AuthSignedOut || state is AuthSignedIn) && _isPublic(path)) {
    return null;
  }
  return switch (state) {
    AuthUnknown() || AuthBusy() => null,
    AuthRecovery() => null,
    AuthSignedOut() => _signedOutPaths.contains(path) ? null : AppRoutes.signIn,
    AuthConfirmationSent() || AuthResetLinkSent() =>
      path == AppRoutes.checkInbox ? null : AppRoutes.checkInbox,
    AuthDeviceGate() => path == AppRoutes.devices ? null : AppRoutes.devices,
    AuthSignedIn() =>
      _signedOutPaths.contains(path) ||
              path == AppRoutes.checkInbox ||
              path == AppRoutes.devices
          ? AppRoutes.home
          : null,
  };
}

String galleryLocation(String id) =>
    Uri(path: AppRoutes.gallery, queryParameters: {'entry': id}).toString();

String _pathFor(AppShellDestination destination) => switch (destination) {
  AppShellDestination.home => AppRoutes.home,
  AppShellDestination.courses => AppRoutes.courses,
  AppShellDestination.skills => AppRoutes.skills,
  AppShellDestination.mockExams => AppRoutes.mockExams,
  AppShellDestination.profile => AppRoutes.profile,
};

bool _isPublic(String path) =>
    path == AppRoutes.catalogue || path.startsWith('${AppRoutes.catalogue}/');

class _DeferredNotesViewer extends StatefulWidget {
  const _DeferredNotesViewer({required this.topicId, required this.assetId});
  final String topicId;
  final String assetId;
  @override
  State<_DeferredNotesViewer> createState() => _DeferredNotesViewerState();
}

class _DeferredNotesViewerState extends State<_DeferredNotesViewer> {
  late Future<void> _loaded;
  @override
  void initState() {
    super.initState();
    _loaded = notes_viewer.loadLibrary();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: _loaded,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Couldn't load the notes viewer."),
              TextButton(
                onPressed: () => setState(() {
                  _loaded = notes_viewer.loadLibrary();
                }),
                child: const Text('Retry'),
              ),
            ],
          ),
        );
      }
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      return notes_viewer.NotesViewerScreen(
        topicId: widget.topicId,
        assetId: widget.assetId,
      );
    },
  );
}
