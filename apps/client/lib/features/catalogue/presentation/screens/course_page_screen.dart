import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:sat_east_client/core/di/injection.dart';
import 'package:sat_east_client/core/env/env.dart';
import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/router/app_router.dart';
import 'package:sat_east_client/core/text/text_direction.dart';
import 'package:sat_east_client/core/theme/booklet_tokens.dart';
import 'package:sat_east_client/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:sat_east_client/features/auth/presentation/cubit/auth_state.dart';
import 'package:sat_east_client/features/catalogue/domain/entities/course_page.dart';
import 'package:sat_east_client/features/catalogue/presentation/catalogue_copy.dart';
import 'package:sat_east_client/features/catalogue/presentation/cubit/course_page_cubit.dart';
import 'package:sat_east_client/features/catalogue/presentation/cubit/course_page_state.dart';
import 'package:sat_east_client/features/catalogue/presentation/price_format.dart';
import 'package:sat_east_client/features/catalogue/presentation/widgets/catalogue_frame.dart';
import 'package:sat_east_client/features/catalogue/presentation/widgets/syllabus_unit.dart';
import 'package:sat_east_client/shared/widgets/app_skeleton.dart';
import 'package:sat_east_client/shared/widgets/empty_state.dart';
import 'package:sat_east_client/shared/widgets/error_retry.dart';

class CoursePageScreen extends StatelessWidget {
  const CoursePageScreen({
    required this.slug,
    super.key,
    this.enablePurchase = Env.enablePurchase,
  });

  final String slug;
  final bool enablePurchase;

  @override
  Widget build(BuildContext context) => BlocProvider(
    key: ValueKey(slug),
    create: (_) {
      final cubit = getIt<CoursePageCubit>();
      unawaited(cubit.load(slug));
      return cubit;
    },
    child: CoursePageView(enablePurchase: enablePurchase),
  );
}

class CoursePageView extends StatelessWidget {
  const CoursePageView({super.key, this.enablePurchase = Env.enablePurchase});

  final bool enablePurchase;

  @override
  Widget build(BuildContext context) => CatalogueFrame(
    fallbackLocation: AppRoutes.catalogue,
    child: BlocBuilder<CoursePageCubit, CoursePageState>(
      builder: (context, state) => switch (state) {
        CoursePageLoading() => const Padding(
          padding: EdgeInsets.all(BookletSpace.s6),
          child: AppSkeleton(),
        ),
        CoursePageFailed(:final error)
            when error.code == ErrorCodes.invalidInput =>
          EmptyState(
            title: CatalogueCopy.notFoundTitle,
            message: CatalogueCopy.notFoundBody,
            actionLabel: CatalogueCopy.browse,
            onAction: () => context.go(AppRoutes.catalogue),
          ),
        CoursePageFailed(:final error) => ErrorRetry(
          title: CatalogueCopy.errorTitle,
          message: CatalogueCopy.errorBody(error.code),
          onRetry: () => unawaited(context.read<CoursePageCubit>().retry()),
        ),
        CoursePageLoaded(:final data) => _CourseContent(
          page: data,
          enablePurchase: enablePurchase,
        ),
      },
    ),
  );
}

class _CourseContent extends StatelessWidget {
  const _CourseContent({required this.page, required this.enablePurchase});

  final CoursePage page;
  final bool enablePurchase;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(BookletSpace.s6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: BookletSpace.s5,
        children: [
          Text(
            page.title,
            style: theme.textTheme.headlineLarge,
            textDirection: detectTextDirection(page.title),
          ),
          if (page.description case final description?)
            Text(
              description,
              style: theme.textTheme.bodyLarge,
              textDirection: detectTextDirection(description),
            ),
          const Divider(),
          Text(CatalogueCopy.contents, style: theme.textTheme.headlineSmall),
          for (final (index, unit) in page.units.indexed)
            SyllabusUnit(unit: unit, number: index + 1),
          const Divider(),
          if (page.price case final price? when enablePurchase)
            Text(formatPrice(price), style: theme.textTheme.titleLarge),
          if (!enablePurchase) const Text(CatalogueCopy.appNote),
          const _ActivationLink(),
        ],
      ),
    );
  }
}

class _ActivationLink extends StatelessWidget {
  const _ActivationLink();

  @override
  Widget build(BuildContext context) {
    final signedIn = context.select<AuthCubit, bool>(
      (cubit) => cubit.state is AuthSignedIn,
    );
    return TextButton(
      onPressed: () => context.go(
        signedIn ? AppRoutes.activate : AppRoutes.signUp,
      ),
      child: const Text(CatalogueCopy.activation),
    );
  }
}
