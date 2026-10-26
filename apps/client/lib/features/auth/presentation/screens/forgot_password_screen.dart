import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:sat_east_client/core/router/app_router.dart';
import 'package:sat_east_client/features/auth/domain/form_rules.dart';
import 'package:sat_east_client/features/auth/presentation/auth_copy.dart';
import 'package:sat_east_client/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:sat_east_client/features/auth/presentation/cubit/auth_state.dart';
import 'package:sat_east_client/features/auth/presentation/widgets/auth_card.dart';
import 'package:sat_east_client/features/auth/presentation/widgets/auth_text_field.dart';
import 'package:sat_east_client/shared/widgets/app_banner.dart';
import 'package:sat_east_client/shared/widgets/loading_button.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _email = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  void _submit() {
    final cubit = context.read<AuthCubit>();
    if (!FormRules.looksLikeEmail(_email.text) || cubit.state is AuthBusy) {
      return;
    }
    unawaited(cubit.requestPasswordReset(_email.text.trim()));
  }

  @override
  Widget build(BuildContext context) => AuthCard(
    footer: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        BlocSelector<AuthCubit, AuthState, bool>(
          selector: (state) => state is AuthBusy,
          builder: (context, busy) => ListenableBuilder(
            listenable: _email,
            builder: (context, _) => LoadingButton(
              label: 'Send reset link',
              expanded: true,
              isLoading: busy,
              onPressed: FormRules.looksLikeEmail(_email.text) ? _submit : null,
            ),
          ),
        ),
        LoadingButton(
          label: 'Back to sign in',
          variant: AppButtonVariant.tertiary,
          onPressed: () {
            context.read<AuthCubit>().clearError();
            context.go(AppRoutes.signIn);
          },
        ),
      ],
    ),
    children: [
      Text(
        'Reset your password',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      BlocSelector<AuthCubit, AuthState, String?>(
        selector: (state) => state is AuthSignedOut ? state.error?.code : null,
        builder: (context, code) => code == null
            ? const SizedBox.shrink()
            : AppBanner(
                message: authErrorCopy(code),
                kind: AppBannerKind.error,
              ),
      ),
      AuthTextField(
        label: 'Email',
        controller: _email,
        keyboardType: TextInputType.emailAddress,
        textInputAction: TextInputAction.done,
        autofillHints: const [AutofillHints.email],
        onSubmitted: (_) => _submit(),
      ),
    ],
  );
}
