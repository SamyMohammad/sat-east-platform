import 'dart:async';

import 'package:flutter/material.dart';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:sat_east_client/core/di/injection.dart';
import 'package:sat_east_client/core/theme/app_colors.dart';
import 'package:sat_east_client/core/theme/app_icons.dart';
import 'package:sat_east_client/core/theme/app_tokens.dart';
import 'package:sat_east_client/features/teacher/videos/domain/entities/picked_video.dart';
import 'package:sat_east_client/features/teacher/videos/domain/entities/teacher_video.dart';
import 'package:sat_east_client/features/teacher/videos/domain/entities/video_upload.dart';
import 'package:sat_east_client/features/teacher/videos/presentation/cubit/upload_video_cubit.dart';
import 'package:sat_east_client/features/teacher/videos/presentation/cubit/upload_video_state.dart';
import 'package:sat_east_client/features/teacher/videos/presentation/teacher_videos_copy.dart';
import 'package:sat_east_client/shared/widgets/app_dialog.dart';
import 'package:sat_east_client/shared/widgets/app_progress.dart';

/// The barrier never dismisses: closing is always an explicit button, and a
/// running upload can only be stopped through the confirmation.
Future<void> showUploadVideoDialog(
  BuildContext context, {
  required String topicId,
  required VoidCallback onPublished,
}) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (_) => UploadVideoDialog(topicId: topicId, onPublished: onPublished),
);

class UploadVideoDialog extends StatelessWidget {
  const UploadVideoDialog({
    required this.topicId,
    required this.onPublished,
    super.key,
  });
  final String topicId;

  /// Called once the video is confirmed, so the list and quota reload.
  final VoidCallback onPublished;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) {
      final cubit = getIt<UploadVideoCubit>();
      unawaited(cubit.loadLimits());
      return cubit;
    },
    child: _UploadVideoView(topicId: topicId, onPublished: onPublished),
  );
}

class _UploadVideoView extends StatefulWidget {
  const _UploadVideoView({required this.topicId, required this.onPublished});
  final String topicId;
  final VoidCallback onPublished;
  @override
  State<_UploadVideoView> createState() => _UploadVideoViewState();
}

class _UploadVideoViewState extends State<_UploadVideoView> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  void _start() {
    if (!_form.currentState!.validate()) return;
    unawaited(
      context.read<UploadVideoCubit>().upload(
        topicId: widget.topicId,
        title: _title.text.trim(),
      ),
    );
  }

  Future<void> _confirmStop() async {
    final cubit = context.read<UploadVideoCubit>();
    final stop = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AppDialog(
        title: TeacherVideosCopy.stopTitle,
        content: const Text(TeacherVideosCopy.stopBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(TeacherVideosCopy.keepUploading),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(TeacherVideosCopy.stopUpload),
          ),
        ],
      ),
    );
    if (stop == true) await cubit.cancel();
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocConsumer<UploadVideoCubit, UploadVideoState>(
    listenWhen: (_, current) => current is UploadVideoSuccess,
    listener: (_, _) => widget.onPublished(),
    builder: (context, state) {
      final cubit = context.read<UploadVideoCubit>();
      final running = state is UploadVideoRunning;
      return PopScope(
        canPop: !running,
        child: AppDialog(
          title: TeacherVideosCopy.uploadTitle,
          content: SizedBox(
            width: double.maxFinite,
            child: switch (state) {
              UploadVideoUnsupported() => const Text(
                TeacherVideosCopy.webOnly,
              ),
              UploadVideoRunning() => _Running(state: state),
              UploadVideoSuccess() => const _Notice(
                message: TeacherVideosCopy.uploaded,
                kind: _NoticeKind.success,
              ),
              UploadVideoError(:final error) => _Notice(
                message: TeacherVideosCopy.uploadError(error.code),
                kind: _NoticeKind.error,
              ),
              UploadVideoIdle(:final file, :final limits, :final error) =>
                _Form(
                  form: _form,
                  title: _title,
                  file: file,
                  limits: limits,
                  error: error?.code,
                  onPick: () => unawaited(cubit.pickFile()),
                  onSubmit: _start,
                ),
              UploadVideoPicking(:final file, :final limits) => _Form(
                form: _form,
                title: _title,
                file: file,
                limits: limits,
                onPick: null,
                onSubmit: _start,
              ),
            },
          ),
          actions: switch (state) {
            UploadVideoUnsupported() || UploadVideoSuccess() => [
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  state is UploadVideoSuccess
                      ? TeacherVideosCopy.done
                      : TeacherVideosCopy.close,
                ),
              ),
            ],
            UploadVideoRunning(:final cancelling) => [
              OutlinedButton(
                onPressed: cancelling ? null : () => unawaited(_confirmStop()),
                child: Text(
                  cancelling
                      ? TeacherVideosCopy.stopping
                      : TeacherVideosCopy.stopUpload,
                ),
              ),
            ],
            UploadVideoError() => [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(TeacherVideosCopy.close),
              ),
              FilledButton(
                onPressed: cubit.dismissError,
                child: const Text(TeacherVideosCopy.tryAgain),
              ),
            ],
            UploadVideoIdle(:final file) => [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(TeacherVideosCopy.cancel),
              ),
              FilledButton(
                onPressed: file == null ? null : _start,
                child: const Text(TeacherVideosCopy.startUpload),
              ),
            ],
            UploadVideoPicking() => [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(TeacherVideosCopy.cancel),
              ),
              const FilledButton(
                onPressed: null,
                child: Text(TeacherVideosCopy.startUpload),
              ),
            ],
          },
        ),
      );
    },
  );
}

class _Form extends StatelessWidget {
  const _Form({
    required this.form,
    required this.title,
    required this.file,
    required this.limits,
    required this.onPick,
    required this.onSubmit,
    this.error,
  });
  final GlobalKey<FormState> form;
  final TextEditingController title;
  final PickedVideo? file;
  final VideoUploadLimits? limits;
  final String? error;
  final VoidCallback? onPick;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final limitText = limits == null
        ? ''
        : TeacherVideosCopy.limits(
            maxSourceMb: limits!.maxSourceMb,
            maxDurationS: limits!.maxDurationS,
          );
    return Form(
      key: form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        spacing: AppSpace.s3,
        children: [
          if (error != null)
            _Notice(
              message: TeacherVideosCopy.uploadError(error!),
              kind: _NoticeKind.error,
            ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: OutlinedButton.icon(
              key: const ValueKey('upload-choose-file'),
              onPressed: onPick,
              icon: const Icon(AppIcons.upload),
              label: Text(
                file == null
                    ? TeacherVideosCopy.chooseFile
                    : TeacherVideosCopy.changeFile,
              ),
            ),
          ),
          Text(
            file == null
                ? TeacherVideosCopy.noFile
                : TeacherVideosCopy.pickedFile(file!.name, file!.sizeBytes),
            key: const ValueKey('upload-file-name'),
            textDirection: TextDirection.ltr,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          TextFormField(
            key: const ValueKey('upload-title'),
            controller: title,
            maxLength: 120,
            textDirection: TextDirection.ltr,
            decoration: const InputDecoration(
              labelText: TeacherVideosCopy.titleLabel,
            ),
            validator: (v) => TeacherVideo.validTitle(v ?? '')
                ? null
                : TeacherVideosCopy.titleRequired,
            onFieldSubmitted: (_) => file == null ? null : onSubmit(),
          ),
          if (limitText.isNotEmpty) Text(limitText),
          const _Notice(
            message: TeacherVideosCopy.keepTabOpen,
            kind: _NoticeKind.warning,
          ),
          const Text(TeacherVideosCopy.conversionNote),
        ],
      ),
    );
  }
}

class _Running extends StatelessWidget {
  const _Running({required this.state});
  final UploadVideoRunning state;

  @override
  Widget build(BuildContext context) {
    final (label, value, valueLabel) = switch (state.progress) {
      PublishChecking() => (TeacherVideosCopy.checking, null, null),
      PublishTranscoding(:final fraction) => (
        TeacherVideosCopy.converting,
        fraction,
        TeacherVideosCopy.percent(fraction),
      ),
      PublishUploading(:final done, :final total) => (
        TeacherVideosCopy.uploading,
        total == 0 ? null : done / total,
        TeacherVideosCopy.files(done, total),
      ),
      PublishFinalizing() => (TeacherVideosCopy.finishing, null, null),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      spacing: AppSpace.s3,
      children: [
        AppProgress(label: label, value: value, valueLabel: valueLabel),
        const _Notice(
          message: TeacherVideosCopy.keepTabOpen,
          kind: _NoticeKind.warning,
        ),
        Text(
          TeacherVideosCopy.conversionNote,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: context.appColors.inkSecondary,
          ),
        ),
      ],
    );
  }
}

enum _NoticeKind { warning, error, success }

/// Like `AppBanner`, minus its `LayoutBuilder`: `AlertDialog` measures its
/// content's intrinsic size, which a `LayoutBuilder` cannot answer.
class _Notice extends StatelessWidget {
  const _Notice({required this.message, required this.kind});
  final String message;
  final _NoticeKind kind;

  @override
  Widget build(BuildContext context) {
    final scheme = context.appColors;
    final (color, background, line, icon) = switch (kind) {
      _NoticeKind.warning => (
        scheme.warning,
        scheme.warningWash,
        scheme.warmLine,
        AppIcons.time,
      ),
      _NoticeKind.error => (
        scheme.incorrect,
        scheme.incorrectWash,
        scheme.incorrectLine,
        AppIcons.error,
      ),
      _NoticeKind.success => (
        scheme.correct,
        scheme.correctWash,
        scheme.correctLine,
        AppIcons.correct,
      ),
    };
    return Container(
      padding: const EdgeInsets.all(AppSpace.s3),
      decoration: BoxDecoration(
        color: background,
        border: Border.all(color: line),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpace.s3,
        children: [
          Icon(icon, size: AppSize.iconSmall, color: color),
          Expanded(
            child: Semantics(
              liveRegion: true,
              child: Text(
                message,
                textDirection: TextDirection.ltr,
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(color: scheme.ink),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
