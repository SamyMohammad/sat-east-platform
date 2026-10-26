import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sat_east_client/core/router/app_router.dart';
import 'package:sat_east_client/features/auth/domain/form_rules.dart';
import 'package:sat_east_client/features/auth/presentation/auth_copy.dart';
import 'package:sat_east_client/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:sat_east_client/features/auth/presentation/cubit/auth_state.dart';
import 'package:sat_east_client/features/auth/presentation/widgets/auth_card.dart';
import 'package:sat_east_client/features/auth/presentation/widgets/auth_footer_link.dart';
import 'package:sat_east_client/features/auth/presentation/widgets/auth_text_field.dart';
import 'package:sat_east_client/shared/widgets/app_banner.dart';
import 'package:sat_east_client/shared/widgets/loading_button.dart';

class SetNewPasswordScreen extends StatefulWidget {
  const SetNewPasswordScreen({super.key});

  @override
  State<SetNewPasswordScreen> createState() => _SetNewPasswordScreenState();
}

class _SetNewPasswordScreenState extends State<SetNewPasswordScreen> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _confirmFocus = FocusNode();
  late final _form = Listenable.merge([_password, _confirm]);

  bool get _valid =>
      FormRules.passwordRules(_password.text).allMet &&
      _password.text == _confirm.text;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  void _submit() {
    final cubit = context.read<AuthCubit>();
    if (!_valid || cubit.state is! AuthRecovery) return;
    if ((cubit.state as AuthRecovery).saving) return;
    unawaited(cubit.setNewPassword(_password.text));
  }

  @override
  Widget build(BuildContext context) =>
      BlocSelector<AuthCubit, AuthState, bool>(
        selector: (state) => state is AuthRecovery,
        builder: (context, recovering) => recovering
            ? _recoveryForm(context)
            : const AuthCard(
                children: [
                  Text('Request a reset link to choose a new password.'),
                  AuthFooterLink(
                    prompt: '',
                    linkLabel: 'Forgot password?',
                    path: AppRoutes.forgotPassword,
                  ),
                ],
              ),
      );

  Widget _recoveryForm(BuildContext context) => AuthCard(
    footer: BlocSelector<AuthCubit, AuthState, bool>(
      selector: (state) => state is AuthRecovery && state.saving,
      builder: (context, saving) => ListenableBuilder(
        listenable: _form,
        builder: (context, _) => LoadingButton(
          label: 'Save password',
          expanded: true,
          isLoading: saving,
          onPressed: _valid ? _submit : null,
        ),
      ),
    ),
    children: [
      Text(
        'Choose a new password',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      BlocSelector<AuthCubit, AuthState, String?>(
        selector: (state) => state is AuthRecovery ? state.error?.code : null,
        builder: (context, code) => code == null
            ? const SizedBox.shrink()
            : AppBanner(
                message: authErrorCopy(code),
                kind: AppBannerKind.error,
              ),
      ),
      AuthTextField(
        label: 'New password',
        controller: _password,
        isPassword: true,
        autofillHints: const [AutofillHints.newPassword],
        textInputAction: TextInputAction.next,
        onSubmitted: (_) => _confirmFocus.requestFocus(),
      ),
      AuthTextField(
        label: 'Confirm password',
        controller: _confirm,
        focusNode: _confirmFocus,
        isPassword: true,
        autofillHints: const [AutofillHints.newPassword],
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
      ),
      const Text(
        'Use at least ${FormRules.minPasswordLength} characters, '
        'a letter and a number. Both passwords must match.',
      ),
    ],
  );
}
