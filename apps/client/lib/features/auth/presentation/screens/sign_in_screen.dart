import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sat_east_client/core/captcha/captcha.dart';
import 'package:sat_east_client/core/di/injection.dart';
import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/router/app_router.dart';
import 'package:sat_east_client/features/auth/presentation/auth_copy.dart';
import 'package:sat_east_client/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:sat_east_client/features/auth/presentation/cubit/auth_state.dart';
import 'package:sat_east_client/features/auth/presentation/widgets/auth_card.dart';
import 'package:sat_east_client/features/auth/presentation/widgets/auth_footer_link.dart';
import 'package:sat_east_client/features/auth/presentation/widgets/auth_text_field.dart';
import 'package:sat_east_client/features/auth/presentation/widgets/captcha_slot.dart';
import 'package:sat_east_client/shared/widgets/app_banner.dart';
import 'package:sat_east_client/shared/widgets/loading_button.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _passwordFocus = FocusNode();
  final _captcha = CaptchaController();
  final Captcha _provider = getIt<Captcha>();

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
    _email.dispose();
    _password.dispose();
    _passwordFocus.dispose();
    _captcha.dispose();
    super.dispose();
  }

  bool get _canSubmit => !_provider.enabled || _captcha.hasToken;

  void _submit() {
    final cubit = context.read<AuthCubit>();
    if (cubit.state is AuthBusy || !_canSubmit) return;
    unawaited(_signIn(cubit));
  }

  Future<void> _signIn(AuthCubit cubit) async {
    await cubit.signIn(
      _email.text.trim(),
      _password.text,
      captchaToken: _captcha.token,
    );
    // Tokens are single-use, whatever the outcome.
    if (mounted) _captcha.reset();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AuthCard(
      showWelcomeIllustration: true,
      children: [
        Text('Sign in', style: theme.textTheme.headlineSmall),
        Text(
          'Your path is where you left it.',
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
          label: 'Email',
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.email],
          onSubmitted: (_) => _passwordFocus.requestFocus(),
        ),
        AuthTextField(
          label: 'Password',
          controller: _password,
          focusNode: _passwordFocus,
          isPassword: true,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.password],
          onSubmitted: (_) => _submit(),
        ),
        if (_provider.enabled)
          CaptchaSlot(captcha: _provider, controller: _captcha),
        BlocSelector<AuthCubit, AuthState, bool>(
          selector: (state) => state is AuthBusy,
          builder: (context, busy) => ListenableBuilder(
            listenable: _captcha,
            builder: (context, _) => LoadingButton(
              label: 'Sign in',
              isLoading: busy,
              expanded: true,
              onPressed: _canSubmit ? _submit : null,
            ),
          ),
        ),
        const AuthFooterLink(
          prompt: '',
          linkLabel: 'Forgot password?',
          path: AppRoutes.forgotPassword,
        ),
        const AuthFooterLink(
          prompt: 'New here?',
          linkLabel: 'Create an account',
          path: AppRoutes.signUp,
        ),
        const AuthFooterLink(
          prompt: '',
          linkLabel: 'Browse courses',
          path: AppRoutes.catalogue,
        ),
      ],
    );
  }

  static String? _bannerMessage(AuthState state) {
    if (state is! AuthSignedOut) return null;
    // Sign-up-only codes belong to the sign-up screen.
    if (state.error case final error?
        when error.code != ErrorCodes.emailTaken &&
            error.code != ErrorCodes.weakPassword) {
      return authErrorCopy(error.code);
    }
    if (state.reason case final reason?) return signOutReasonCopy(reason);
    return null;
  }
}
