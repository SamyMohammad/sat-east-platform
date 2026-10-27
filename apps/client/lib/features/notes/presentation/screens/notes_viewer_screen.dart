import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:sat_east_client/core/di/injection.dart';
import 'package:sat_east_client/core/router/app_router.dart';
import 'package:sat_east_client/core/theme/app_tokens.dart';
import 'package:sat_east_client/features/notes/presentation/cubit/notes_viewer_cubit.dart';
import 'package:sat_east_client/features/notes/presentation/cubit/notes_viewer_state.dart';
import 'package:sat_east_client/features/notes/presentation/notes_copy.dart';
import 'package:sat_east_client/features/notes/presentation/widgets/notes_document.dart';
import 'package:sat_east_client/features/notes/presentation/widgets/notes_page_watermark.dart';
import 'package:sat_east_client/shared/widgets/app_banner.dart';
import 'package:sat_east_client/shared/widgets/app_skeleton.dart';
import 'package:sat_east_client/shared/widgets/error_retry.dart';

class NotesViewerScreen extends StatefulWidget {
  const NotesViewerScreen({
    required this.topicId,
    required this.assetId,
    this.documentBuilder,
    super.key,
  });
  final String topicId;
  final String assetId;
  final NotesDocumentBuilder? documentBuilder;
  @override
  State<NotesViewerScreen> createState() => _NotesViewerScreenState();
}

class _NotesViewerScreenState extends State<NotesViewerScreen> {
  late final NotesViewerCubit _cubit;
  @override
  void initState() {
    super.initState();
    _cubit = getIt<NotesViewerCubit>();
    unawaited(_cubit.load(widget.topicId, widget.assetId));
  }

  @override
  void didUpdateWidget(NotesViewerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.topicId != oldWidget.topicId ||
        widget.assetId != oldWidget.assetId) {
      unawaited(_cubit.load(widget.topicId, widget.assetId));
    }
  }

  @override
  void dispose() {
    unawaited(_cubit.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocProvider.value(
    value: _cubit,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Notes'),
        leading: BackButton(
          onPressed: () => context.go(AppRoutes.topic(widget.topicId)),
        ),
      ),
      body: BlocBuilder<NotesViewerCubit, NotesViewerState>(
        buildWhen: (previous, next) => previous.runtimeType != next.runtimeType,
        builder: (context, state) => switch (state) {
          NotesViewerLoading() => const Padding(
            padding: EdgeInsets.all(AppSpace.s4),
            child: AppSkeleton(),
          ),
          NotesViewerFailed(:final error) => SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpace.s4),
            child: ErrorRetry(
              title: notesErrorCopy(error.code),
              message: '',
              onRetry: () =>
                  unawaited(_cubit.load(widget.topicId, widget.assetId)),
            ),
          ),
          NotesViewerReady() => _ReadyNotes(
            documentBuilder:
                widget.documentBuilder ??
                (context, bytes, overlay) => buildNotesDocument(
                  context,
                  bytes,
                  overlay,
                  sourceName: '${widget.topicId}/${widget.assetId}.pdf',
                ),
          ),
        },
      ),
    ),
  );
}

class _ReadyNotes extends StatelessWidget {
  const _ReadyNotes({required this.documentBuilder});
  final NotesDocumentBuilder documentBuilder;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      BlocSelector<NotesViewerCubit, NotesViewerState, bool>(
        selector: (state) =>
            state is NotesViewerReady && state.markError != null,
        builder: (context, failed) => failed
            ? const Padding(
                padding: EdgeInsets.all(AppSpace.s3),
                child: AppBanner(
                  kind: AppBannerKind.error,
                  message:
                      "Your reading progress couldn't be saved. "
                      'Reopen the notes to try again.',
                ),
              )
            : const SizedBox.shrink(),
      ),
      Expanded(
        child:
            BlocSelector<
              NotesViewerCubit,
              NotesViewerState,
              (Uint8List?, String?)
            >(
              selector: (state) => state is NotesViewerReady
                  ? (state.bytes, state.watermark)
                  : (null, null),
              builder: (context, data) => data.$1 == null
                  ? const SizedBox.shrink()
                  : documentBuilder(
                      context,
                      data.$1!,
                      () => NotesPageWatermark(text: data.$2!),
                    ),
            ),
      ),
    ],
  );
}
