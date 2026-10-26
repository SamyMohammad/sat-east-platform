import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:sat_east_client/core/di/injection.dart';
import 'package:sat_east_client/core/env/env.dart';
import 'package:sat_east_client/core/router/app_router.dart';
import 'package:sat_east_client/core/text/text_direction.dart';
import 'package:sat_east_client/core/theme/app_hues.dart';
import 'package:sat_east_client/core/theme/app_icons.dart';
import 'package:sat_east_client/core/theme/app_tokens.dart';
import 'package:sat_east_client/features/catalogue/domain/entities/catalogue_course.dart';
import 'package:sat_east_client/features/catalogue/presentation/catalogue_copy.dart';
import 'package:sat_east_client/features/catalogue/presentation/cubit/catalogue_cubit.dart';
import 'package:sat_east_client/features/catalogue/presentation/cubit/catalogue_state.dart';
import 'package:sat_east_client/features/catalogue/presentation/price_format.dart';
import 'package:sat_east_client/features/catalogue/presentation/widgets/catalogue_frame.dart';
import 'package:sat_east_client/features/catalogue/presentation/widgets/catalogue_greeting.dart';
import 'package:sat_east_client/shared/widgets/app_illustration.dart';
import 'package:sat_east_client/shared/widgets/app_skeleton.dart';
import 'package:sat_east_client/shared/widgets/empty_state.dart';
import 'package:sat_east_client/shared/widgets/error_retry.dart';
import 'package:sat_east_client/shared/widgets/icon_tile.dart';
import 'package:sat_east_client/shared/widgets/loading_button.dart';

class CatalogueScreen extends StatelessWidget {
  const CatalogueScreen({
    super.key,
    this.enablePurchase = Env.enablePurchase,
  });

  final bool enablePurchase;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) {
      final cubit = getIt<CatalogueCubit>();
      unawaited(cubit.load());
      return cubit;
    },
    child: CatalogueView(enablePurchase: enablePurchase),
  );
}

class CatalogueView extends StatelessWidget {
  const CatalogueView({
    super.key,
    this.enablePurchase = Env.enablePurchase,
  });

  final bool enablePurchase;

  @override
  Widget build(BuildContext context) => CatalogueFrame(
    fallbackLocation: AppRoutes.home,
    child: BlocBuilder<CatalogueCubit, CatalogueState>(
      builder: (context, state) => switch (state) {
        CatalogueLoading() => const Padding(
          padding: EdgeInsets.all(AppSpace.s6),
          child: AppSkeleton(),
        ),
        CatalogueFailed(:final error) => ErrorRetry(
          title: CatalogueCopy.errorTitle,
          message: CatalogueCopy.errorBody(error.code),
          onRetry: () => unawaited(context.read<CatalogueCubit>().retry()),
        ),
        CatalogueLoaded(data: final courses) =>
          courses.isEmpty
              ? const EmptyState(
                  illustration: AppIllustrationName.emptyCourses,
                  title: CatalogueCopy.emptyTitle,
                  message: CatalogueCopy.emptyBody,
                )
              : ListView(
                  padding: const EdgeInsets.all(AppSpace.s6),
                  children: [
                    const CatalogueGreeting(),
                    for (final (index, course) in courses.indexed) ...[
                      const SizedBox(height: AppSpace.s6),
                      _CourseCard(
                        course: course,
                        index: index,
                        enablePurchase: enablePurchase,
                      ),
                    ],
                  ],
                ),
      },
    ),
  );
}

class _CourseCard extends StatelessWidget {
  const _CourseCard({
    required this.course,
    required this.index,
    required this.enablePurchase,
  });

  final CatalogueCourse course;
  final int index;
  final bool enablePurchase;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: AppSpace.s2,
            child: ColoredBox(
              key: ValueKey('course-hue-$index'),
              color: SubjectHue.forIndex(index).color(theme.brightness),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpace.s6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: AppSpace.s4,
              children: [
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: IconTile(
                    AppIcons.courses,
                    hue: SubjectHue.forIndex(index),
                  ),
                ),
                Text(
                  course.title,
                  style: theme.textTheme.headlineSmall,
                  textDirection: detectTextDirection(course.title),
                ),
                if (course.description case final description?)
                  Text(
                    description,
                    textDirection: detectTextDirection(description),
                  ),
                Text(
                  CatalogueCopy.topics(course.topicCount),
                  style: theme.textTheme.bodySmall,
                ),
                if (course.price case final price? when enablePurchase)
                  Text(
                    formatPrice(price),
                    style: theme.textTheme.titleLarge,
                  ),
                LoadingButton(
                  label: CatalogueCopy.syllabus,
                  onPressed: () => unawaited(
                    context.push<void>(AppRoutes.coursePage(course.slug)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
