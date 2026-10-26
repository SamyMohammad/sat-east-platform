import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sat_east_client/core/theme/app_icons.dart';
import 'package:sat_east_client/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:sat_east_client/features/auth/presentation/cubit/auth_state.dart';
import 'package:sat_east_client/features/auth/presentation/widgets/auth_card.dart';
import 'package:sat_east_client/shared/widgets/booklet_status_frame.dart';
import 'package:sat_east_client/shared/widgets/loading_button.dart';

class CheckInboxScreen extends StatelessWidget {
  const CheckInboxScreen({super.key});

  @override
  Widget build(BuildContext context) => AuthCard(
    children: [
      BlocSelector<AuthCubit, AuthState, (String, bool)>(
        selector: (state) => (
          state is AuthConfirmationSent ? state.email : '',
          state is AuthResetLinkSent,
        ),
        builder: (context, info) => BookletStatusFrame(
          icon: AppIcons.inbox,
          title: 'Check your inbox',
          message: info.$2
              ? 'If an account exists for that email, we sent a reset link.'
              : 'We sent a confirmation link to ${info.$1}. '
                    'Open it, then sign in.',
          actions: [
            LoadingButton(
              label: 'Back to sign in',
              onPressed: context.read<AuthCubit>().acknowledgeConfirmation,
            ),
          ],
        ),
      ),
    ],
  );
}
