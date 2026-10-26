import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/router/app_router.dart';
import 'package:sat_east_client/core/theme/app_icons.dart';
import 'package:sat_east_client/core/theme/booklet_tokens.dart';
import 'package:sat_east_client/features/auth/domain/form_rules.dart';
import 'package:sat_east_client/features/auth/presentation/auth_copy.dart';
import 'package:sat_east_client/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:sat_east_client/features/auth/presentation/cubit/auth_state.dart';
import 'package:sat_east_client/features/auth/presentation/widgets/auth_card.dart';
import 'package:sat_east_client/features/auth/presentation/widgets/auth_footer_link.dart';
import 'package:sat_east_client/features/auth/presentation/widgets/auth_text_field.dart';
import 'package:sat_east_client/shared/widgets/app_banner.dart';
import 'package:sat_east_client/shared/widgets/loading_button.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  late final Listenable _form = Listenable.merge([_name, _email, _password]);

  @override
  void initState() {
    super.initState();
    // Drop an error left over from the other auth screen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AuthCubit>().clearError();
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  bool get _valid =>
      _name.text.trim().isNotEmpty &&
      FormRules.looksLikeEmail(_email.text) &&
      FormRules.passwordRules(_password.text).allMet;

  void _submit() {
    final cubit = context.read<AuthCubit>();
    if (!_valid || cubit.state is AuthBusy) return;
    unawaited(
      cubit.signUp(_email.text.trim(), _password.text, _name.text.trim()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AuthCard(
      footer: Column(
        spacing: BookletSpace.s3,
        children: [
          BlocSelector<AuthCubit, AuthState, bool>(
            selector: (state) => state is AuthBusy,
            builder: (context, busy) => ListenableBuilder(
              listenable: _form,
              builder: (context, _) => LoadingButton(
                label: 'Create account',
                isLoading: busy,
                expanded: true,
                onPressed: _valid ? _submit : null,
              ),
            ),
          ),
          const AuthFooterLink(
            prompt: 'Already have an account?',
            linkLabel: 'Sign in',
            path: AppRoutes.signIn,
          ),
        ],
      ),
      children: [
        Text('Create your account', style: theme.textTheme.headlineSmall),
        Text(
          'Use the email you check most. Receipts and reset links go there.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        BlocSelector<AuthCubit, AuthState, String?>(
          selector: _bannerMessage,
          builder: (context, message) => message == null
              ? const SizedBox.shrink()
              : AppBanner(message: message, kind: AppBannerKind.error),
        ),
        AuthTextField(
          label: 'Full name',
          controller: _name,
          keyboardType: TextInputType.name,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.name],
          onSubmitted: (_) => _emailFocus.requestFocus(),
        ),
        BlocSelector<AuthCubit, AuthState, bool>(
          selector: (state) => _errorCode(state) == ErrorCodes.emailTaken,
          builder: (context, taken) => AuthTextField(
            label: 'Email',
            controller: _email,
            focusNode: _emailFocus,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            onSubmitted: (_) => _passwordFocus.requestFocus(),
            error: taken ? const _EmailTakenError() : null,
          ),
        ),
        BlocSelector<AuthCubit, AuthState, bool>(
          selector: (state) => _errorCode(state) == ErrorCodes.weakPassword,
          builder: (context, weak) => AuthTextField(
            label: 'Password',
            controller: _password,
            focusNode: _passwordFocus,
            isPassword: true,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.newPassword],
            onSubmitted: (_) => _submit(),
            error: weak ? const Text('Choose a stronger password.') : null,
          ),
        ),
        ListenableBuilder(
          listenable: _password,
          builder: (context, _) =>
              _PasswordRules(FormRules.passwordRules(_password.text)),
        ),
        Text(
          'By creating an account you agree to the Terms and Privacy policy.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  static String? _errorCode(AuthState state) =>
      state is AuthSignedOut ? state.error?.code : null;

  /// Field-level errors show inline; everything else uses the banner.
  static String? _bannerMessage(AuthState state) {
    final code = _errorCode(state);
    if (code == null ||
        code == ErrorCodes.emailTaken ||
        code == ErrorCodes.weakPassword ||
        // Sign-in-only codes belong to the sign-in screen.
        code == ErrorCodes.invalidCredentials ||
        code == ErrorCodes.emailNotConfirmed) {
      return null;
    }
    return authErrorCopy(code);
  }
}

class _EmailTakenError extends StatelessWidget {
  const _EmailTakenError();

  @override
  Widget build(BuildContext context) => Wrap(
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: BookletSpace.s2,
    children: [
      const Text('This email already has an account.'),
      LoadingButton(
        label: 'Sign in instead',
        variant: AppButtonVariant.tertiary,
        onPressed: () => context.go(AppRoutes.signIn),
      ),
    ],
  );
}

class _PasswordRules extends StatelessWidget {
  const _PasswordRules(this.rules);

  final PasswordRules rules;

  @override
  Widget build(BuildContext context) {
    const base = 'At least ${FormRules.minPasswordLength} characters';
    final length = rules.hasMinLength ? base : '$base · ${rules.length} so far';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: BookletSpace.s1,
      children: [
        _Rule(label: length, met: rules.hasMinLength),
        _Rule(label: 'A number', met: rules.hasNumber),
        _Rule(label: 'A letter', met: rules.hasLetter),
      ],
    );
  }
}

class _Rule extends StatelessWidget {
  const _Rule({required this.label, required this.met});

  final String label;
  final bool met;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = met
        ? theme.colorScheme.onSurface
        : theme.colorScheme.onSurfaceVariant;
    return Semantics(
      label: '$label, ${met ? 'met' : 'not met'}',
      excludeSemantics: true,
      child: Row(
        spacing: BookletSpace.s2,
        children: [
          Icon(
            met ? AppIcons.correct : AppIcons.unselected,
            size: BookletSize.iconStatus,
            color: color,
          ),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
