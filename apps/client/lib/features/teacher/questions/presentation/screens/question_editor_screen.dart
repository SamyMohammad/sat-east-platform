import 'dart:async';

import 'package:flutter/material.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:sat_east_client/core/di/injection.dart';
import 'package:sat_east_client/core/theme/app_tokens.dart';
import 'package:sat_east_client/features/teacher/questions/presentation/cubit/question_editor_cubit.dart';
import 'package:sat_east_client/features/teacher/questions/presentation/cubit/question_editor_state.dart';
import 'package:sat_east_client/features/teacher/questions/presentation/widgets/editor_preview.dart';
import 'package:sat_east_client/features/teacher/questions/presentation/widgets/editor_reports.dart';
import 'package:sat_east_client/features/teacher/questions/presentation/widgets/editor_save_bar.dart';
import 'package:sat_east_client/shared/widgets/app_banner.dart';
import 'package:sat_east_client/shared/widgets/app_dialog.dart';
import 'package:sat_east_client/shared/widgets/app_skeleton.dart';
import 'package:sat_east_client/shared/widgets/error_retry.dart';

class QuestionEditorScreen extends StatefulWidget {
  const QuestionEditorScreen({this.questionId, super.key});
  final String? questionId;
  @override
  State<QuestionEditorScreen> createState() => QuestionEditorScreenState();
}

class QuestionEditorScreenState extends State<QuestionEditorScreen> {
  late final QuestionEditorCubit _cubit;
  @override
  void initState() {
    super.initState();
    _cubit = getIt<QuestionEditorCubit>();
    unawaited(_cubit.load(widget.questionId));
  }

  @override
  void didUpdateWidget(QuestionEditorScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.questionId != oldWidget.questionId) {
      unawaited(_cubit.load(widget.questionId));
    }
  }

  @override
  void dispose() {
    unawaited(_cubit.close());
    super.dispose();
  }

  Future<bool> confirmLeave() async {
    if (!_cubit.state.isDirty) return true;
    if (_cubit.state.saving) return false;
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AppDialog(
        title: 'Discard changes?',
        content: const Text("Your changes haven't been saved."),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) _cubit.discard();
    return discard ?? false;
  }

  @override
  Widget build(BuildContext context) => BlocProvider.value(
    value: _cubit,
    child: BlocListener<QuestionEditorCubit, QuestionEditorState>(
      listenWhen: (p, n) =>
          p.draft?.id == null && n.draft?.id != null && !n.isDirty,
      listener: (context, state) {
        if (widget.questionId == null) {
          context.go(
            '/teacher/questions/${Uri.encodeComponent(state.draft!.id!)}',
          );
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpace.s4),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  widget.questionId == null ? 'New question' : 'Edit question',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                TextButton(
                  onPressed: () => context.go('/teacher/questions'),
                  child: const Text('Question bank'),
                ),
              ],
            ),
          ),
          const _ConflictBanner(),
          Expanded(
            child: BlocBuilder<QuestionEditorCubit, QuestionEditorState>(
              buildWhen: (p, n) =>
                  p.loading != n.loading ||
                  (p.draft == null) != (n.draft == null),
              builder: (context, state) {
                if (state.loading) {
                  return const Padding(
                    padding: EdgeInsets.all(AppSpace.s4),
                    child: AppSkeleton(),
                  );
                }
                if (state.draft == null) {
                  return ErrorRetry(
                    title: "Couldn't load the question.",
                    message: '',
                    onRetry: () => unawaited(_cubit.load(widget.questionId)),
                  );
                }
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.s4,
                  ),
                  child: MediaQuery.sizeOf(context).width >= 1024
                      ? const Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: SingleChildScrollView(
                                child: EditorWithReports(),
                              ),
                            ),
                            SizedBox(width: AppSpace.s4),
                            Expanded(child: EditorPreview()),
                          ],
                        )
                      : const SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              EditorWithReports(),
                              SizedBox(height: 640, child: EditorPreview()),
                            ],
                          ),
                        ),
                );
              },
            ),
          ),
          const EditorSaveBar(),
        ],
      ),
    ),
  );
}

class _ConflictBanner extends StatelessWidget {
  const _ConflictBanner();
  @override
  Widget build(BuildContext context) =>
      BlocSelector<QuestionEditorCubit, QuestionEditorState, bool>(
        selector: (s) => s.conflict,
        builder: (context, conflict) {
          if (!conflict) return const SizedBox.shrink();
          return AppBanner(
            message:
                'This question changed elsewhere. Reload to see the latest.',
            kind: AppBannerKind.warning,
            actionLabel: 'Reload',
            onAction: () => unawaited(
              context.read<QuestionEditorCubit>().load(
                context.read<QuestionEditorCubit>().state.draft?.id,
              ),
            ),
          );
        },
      );
}
