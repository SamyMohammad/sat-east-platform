import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:sat_east_client/core/di/injection.dart';
import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/router/app_router.dart';
import 'package:sat_east_client/core/text/text_direction.dart';
import 'package:sat_east_client/core/theme/booklet_tokens.dart';
import 'package:sat_east_client/features/auth/presentation/auth_copy.dart';
import 'package:sat_east_client/features/auth/presentation/cubit/account_cubit.dart';
import 'package:sat_east_client/features/auth/presentation/cubit/account_state.dart';
import 'package:sat_east_client/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:sat_east_client/features/auth/presentation/cubit/auth_state.dart';
import 'package:sat_east_client/features/auth/presentation/widgets/account_courses.dart';
import 'package:sat_east_client/features/auth/presentation/widgets/account_devices.dart';
import 'package:sat_east_client/features/auth/presentation/widgets/account_password_form.dart';
import 'package:sat_east_client/shared/widgets/booklet_banner.dart';
import 'package:sat_east_client/shared/widgets/booklet_skeleton.dart';
import 'package:sat_east_client/shared/widgets/error_retry.dart';
import 'package:sat_east_client/shared/widgets/loading_button.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) {
      final cubit = getIt<AccountCubit>();
      unawaited(cubit.load());
      return cubit;
    },
    child: const AccountView(),
  );
}

class AccountView extends StatelessWidget {
  const AccountView({super.key, this.now});

  final DateTime Function()? now;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: BookletSize.readingColumn),
      child: Column(
        children: [
          Expanded(
            child: BlocBuilder<AccountCubit, AccountState>(
              builder: (context, state) => switch (state) {
                AccountLoading() => const Padding(
                  padding: EdgeInsets.all(BookletSpace.s4),
                  child: BookletSkeleton(),
                ),
                AccountError(:final error) => ErrorRetry(
                  title: 'Could not load your account',
                  message: authErrorCopy(error.code),
                  onRetry: () => unawaited(context.read<AccountCubit>().load()),
                ),
                AccountLoaded() => _loaded(context, state),
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(BookletSpace.s4),
            child: LoadingButton(
              label: 'Sign out',
              expanded: true,
              variant: BookletButtonVariant.secondary,
              onPressed: () => unawaited(context.read<AuthCubit>().signOut()),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _loaded(BuildContext context, AccountLoaded state) =>
      SingleChildScrollView(
        padding: const EdgeInsets.all(BookletSpace.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: BookletSpace.s5,
          children: [
            Text(
              'My account',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            BlocSelector<AuthCubit, AuthState, bool>(
              selector: (state) =>
                  state is AuthSignedIn && state.user.isTeacher,
              builder: (context, isTeacher) => isTeacher
                  ? ListTile(
                      leading: const Icon(Icons.school_outlined),
                      title: const Text('Teacher area'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.go(AppRoutes.teacher),
                    )
                  : const SizedBox.shrink(),
            ),
            Text('Profile', style: Theme.of(context).textTheme.titleLarge),
            Text(
              state.profile.fullName,
              textDirection: detectTextDirection(state.profile.fullName),
            ),
            Text(state.profile.email),
            const Text('Contact your teacher to change your name.'),
            if (state.enrollments.isNotEmpty)
              AccountCourses(enrollments: state.enrollments),
            if (state.error case final error?)
              BookletBanner(
                message: error.code == ErrorCodes.deviceLimit
                    ? 'No changes left this month'
                    : authErrorCopy(error.code),
                kind: BookletBannerKind.error,
              ),
            const AccountPasswordForm(),
            AccountDevices(
              devices: state.devices,
              changesLeft: state.changesLeft,
              busy: state.busy,
              now: (now ?? DateTime.now)(),
            ),
          ],
        ),
      );
}
