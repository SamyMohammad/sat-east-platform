import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:sat_east_client/core/di/injection.dart';
import 'package:sat_east_client/core/router/app_router.dart';
import 'package:sat_east_client/core/theme/booklet_tokens.dart';
import 'package:sat_east_client/features/topic/presentation/cubit/topic_cubit.dart';
import 'package:sat_east_client/features/topic/presentation/cubit/topic_state.dart';
import 'package:sat_east_client/features/topic/presentation/widgets/topic_content.dart';
import 'package:sat_east_client/features/topic/presentation/widgets/topic_failure.dart';
import 'package:sat_east_client/shared/widgets/booklet_skeleton.dart';

class TopicScreen extends StatelessWidget {
  const TopicScreen({required this.topicId, super.key, this.title});

  final String topicId;
  final String? title;

  @override
  Widget build(BuildContext context) => BlocProvider(
    key: ValueKey(topicId),
    create: (_) {
      final cubit = getIt<TopicCubit>();
      unawaited(cubit.load(topicId));
      return cubit;
    },
    child: TopicView(topicId: topicId, title: title),
  );
}

class TopicView extends StatefulWidget {
  const TopicView({required this.topicId, super.key, this.title});

  final String topicId;
  final String? title;

  @override
  State<TopicView> createState() => _TopicViewState();
}

class _TopicViewState extends State<TopicView> {
  GoRouter? _router;
  bool _visible = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final router = GoRouter.of(context);
    if (identical(router, _router)) return;
    _router?.routerDelegate.removeListener(_routeChanged);
    _router = router;
    _visible = _isVisible;
    router.routerDelegate.addListener(_routeChanged);
  }

  // Leaf matches include pushed pages whose URL is not reported by
  // routeInformationProvider. A `go` return also notifies the delegate.
  bool get _isVisible =>
      _router?.routerDelegate.currentConfiguration.last.matchedLocation ==
      AppRoutes.topic(widget.topicId);

  void _routeChanged() {
    final visible = _isVisible;
    if (visible && !_visible) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _visible) {
          unawaited(context.read<TopicCubit>().load(widget.topicId));
        }
      });
    }
    _visible = visible;
  }

  @override
  void dispose() {
    _router?.routerDelegate.removeListener(_routeChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: BookletSize.readingColumn),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(BookletSpace.s4),
          child: BlocBuilder<TopicCubit, TopicState>(
            builder: (context, state) => switch (state) {
              TopicLoading() => const BookletSkeleton(),
              TopicFailed(:final error) => TopicFailure(
                topicId: widget.topicId,
                error: error,
              ),
              TopicLoaded(:final topic) => TopicContent(
                topic: topic,
                title: widget.title,
                onPractice: () => unawaited(
                  context.push<void>(
                    AppRoutes.practice(widget.topicId),
                    extra: widget.title,
                  ),
                ),
                onQuiz: () => unawaited(
                  context.push<void>(AppRoutes.quiz(widget.topicId)),
                ),
              ),
            },
          ),
        ),
      ),
    ),
  );
}
