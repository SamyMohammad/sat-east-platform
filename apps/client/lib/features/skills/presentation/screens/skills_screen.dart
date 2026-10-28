import 'dart:async';

import 'package:flutter/material.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:sat_east_client/core/di/injection.dart';
import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/core/router/app_router.dart';
import 'package:sat_east_client/core/router/route_refresh_listener.dart';
import 'package:sat_east_client/core/theme/app_tokens.dart';
import 'package:sat_east_client/features/skills/domain/entities/skills_overview.dart';
import 'package:sat_east_client/features/skills/presentation/cubit/skills_cubit.dart';
import 'package:sat_east_client/features/skills/presentation/cubit/skills_state.dart';
import 'package:sat_east_client/features/skills/presentation/skills_copy.dart';
import 'package:sat_east_client/features/skills/presentation/widgets/mastery_trend_chart.dart';
import 'package:sat_east_client/features/skills/presentation/widgets/skill_bar_row.dart';
import 'package:sat_east_client/features/skills/presentation/widgets/skills_summary_card.dart';
import 'package:sat_east_client/features/skills/presentation/widgets/topic_level_row.dart';
import 'package:sat_east_client/features/skills/presentation/widgets/weak_skills_section.dart';
import 'package:sat_east_client/shared/widgets/app_illustration.dart';
import 'package:sat_east_client/shared/widgets/app_skeleton.dart';
import 'package:sat_east_client/shared/widgets/empty_state.dart';
import 'package:sat_east_client/shared/widgets/error_retry.dart';

class SkillsScreen extends StatelessWidget {
  const SkillsScreen({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) {
      final cubit = getIt<SkillsCubit>();
      unawaited(cubit.load());
      return cubit;
    },
    child: const SkillsView(),
  );
}

/// Reads [SkillsCubit] from context (testable with a mock cubit).
class SkillsView extends StatelessWidget {
  const SkillsView({super.key});

  @override
  Widget build(BuildContext context) => RouteRefreshListener(
    location: AppRoutes.skills,
    refreshOnReselect: true,
    onRefresh: () => unawaited(context.read<SkillsCubit>().retry()),
    child: BlocBuilder<SkillsCubit, SkillsState>(
      builder: (context, state) => switch (state) {
        SkillsLoading() => const _Column(
          children: [
            _Header(),
            Card(
              child: Padding(
                padding: EdgeInsets.all(AppSpace.s4),
                child: AppSkeleton(label: 'Loading skills summary'),
              ),
            ),
            AppSkeleton(label: 'Loading weak skills'),
            AppSkeleton(label: 'Loading weekly trend'),
            AppSkeleton(label: 'Loading skills by domain'),
            AppSkeleton(label: 'Loading topic levels'),
          ],
        ),
        SkillsLoaded(:final overview) => _Loaded(overview: overview),
        SkillsEmpty() => const _Empty(),
        SkillsFailed(:final error) => _Failed(error: error),
      },
    ),
  );
}

class _Column extends StatelessWidget {
  const _Column({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: AppSize.readingColumn),
      child: ListView(
        padding: const EdgeInsets.all(AppSpace.s4),
        children: [
          for (final child in children) ...[
            child,
            const SizedBox(height: AppSpace.s6),
          ],
        ],
      ),
    ),
  );
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Text(
      SkillsCopy.title,
      style: Theme.of(context).textTheme.headlineSmall,
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Text(text, style: Theme.of(context).textTheme.titleMedium),
  );
}

class _Loaded extends StatelessWidget {
  const _Loaded({required this.overview});

  final SkillsOverview overview;

  @override
  Widget build(BuildContext context) => _Column(
    children: [
      const _Header(),
      SkillsSummaryCard(summary: overview.summary),
      WeakSkillsSection(weak: overview.weak),
      MasteryTrendSection(trend: overview.trend, summary: overview.summary),
      _SkillsByDomain(skills: overview.skills),
      if (overview.topics.isNotEmpty) _Topics(topics: overview.topics),
    ],
  );
}

class _SkillsByDomain extends StatelessWidget {
  const _SkillsByDomain({required this.skills});

  final List<SkillMastery> skills;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final domains = <String, List<(int, SkillMastery)>>{};
    for (final (index, skill) in skills.indexed) {
      domains.putIfAbsent(skill.domain, () => []).add((index, skill));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpace.s2,
      children: [
        const _SectionTitle(SkillsCopy.skillsTitle),
        if (skills.isEmpty)
          Text(SkillsCopy.noSkills, style: theme.textTheme.bodyMedium),
        for (final MapEntry(:key, :value) in domains.entries) ...[
          Padding(
            padding: const EdgeInsets.only(top: AppSpace.s3),
            child: Semantics(
              header: true,
              child: Text(
                key,
                style: theme.textTheme.titleSmall,
                textDirection: TextDirection.ltr,
              ),
            ),
          ),
          for (final (index, skill) in value)
            SkillBarRow(
              key: ValueKey(skill.code),
              skill: skill,
              index: index,
            ),
        ],
      ],
    );
  }
}

class _Topics extends StatelessWidget {
  const _Topics({required this.topics});

  final List<TopicLevel> topics;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: AppSpace.s1,
    children: [
      const _SectionTitle(SkillsCopy.topicsTitle),
      for (final topic in topics)
        TopicLevelRow(key: ValueKey(topic.topicId), topic: topic),
    ],
  );
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) => _Column(
    children: [
      const _Header(),
      EmptyState(
        illustration: AppIllustrationName.emptyCourses,
        title: SkillsCopy.emptyTitle,
        message: SkillsCopy.emptyBody,
        actionLabel: SkillsCopy.emptyAction,
        onAction: () => context.go(AppRoutes.courses),
      ),
    ],
  );
}

class _Failed extends StatelessWidget {
  const _Failed({required this.error});

  final AppError error;

  @override
  Widget build(BuildContext context) => _Column(
    children: [
      const _Header(),
      switch (error.code) {
        ErrorCodes.notEnrolled => EmptyState(
          title: SkillsCopy.notEnrolledTitle,
          message: SkillsCopy.notEnrolledBody,
          actionLabel: SkillsCopy.activateAction,
          onAction: () => context.go(AppRoutes.activate),
          secondaryActionLabel: SkillsCopy.browseAction,
          onSecondaryAction: () => context.go(AppRoutes.catalogue),
        ),
        ErrorCodes.accessExpired => ErrorRetry(
          title: SkillsCopy.expiredTitle,
          message: SkillsCopy.expiredBody,
          onRetry: () => unawaited(context.read<SkillsCubit>().retry()),
        ),
        final code => ErrorRetry(
          title: SkillsCopy.errorTitle,
          message: SkillsCopy.errorBody(code),
          onRetry: () => unawaited(context.read<SkillsCubit>().retry()),
        ),
      },
    ],
  );
}
