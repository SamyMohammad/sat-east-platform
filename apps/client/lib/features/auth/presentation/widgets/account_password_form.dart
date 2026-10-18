import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sat_east_client/core/theme/booklet_tokens.dart';
import 'package:sat_east_client/features/auth/domain/form_rules.dart';
import 'package:sat_east_client/features/auth/presentation/cubit/account_cubit.dart';
import 'package:sat_east_client/features/auth/presentation/cubit/account_state.dart';
import 'package:sat_east_client/features/auth/presentation/widgets/auth_text_field.dart';
import 'package:sat_east_client/shared/widgets/loading_button.dart';

class AccountPasswordForm extends StatefulWidget {
  const AccountPasswordForm({super.key});

  @override
  State<AccountPasswordForm> createState() => _AccountPasswordFormState();
}

class _AccountPasswordFormState extends State<AccountPasswordForm> {
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
    final cubit = context.read<AccountCubit>();
    final current = cubit.state;
    if (!_valid || current is! AccountLoaded || current.busy) return;
    unawaited(cubit.changePassword(_password.text));
  }

  @override
  Widget build(BuildContext context) =>
      BlocListener<AccountCubit, AccountState>(
        listenWhen: (previous, next) =>
            next is AccountLoaded &&
            next.passwordSaved &&
            (previous is! AccountLoaded || !previous.passwordSaved),
        listener: (_, _) {
          _password.clear();
          _confirm.clear();
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: BookletSpace.s3,
          children: [
            Text('Password', style: Theme.of(context).textTheme.titleLarge),
            AuthTextField(
              label: 'New password',
              controller: _password,
              isPassword: true,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.newPassword],
              onSubmitted: (_) => _confirmFocus.requestFocus(),
            ),
            AuthTextField(
              label: 'Confirm password',
              controller: _confirm,
              focusNode: _confirmFocus,
              isPassword: true,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.newPassword],
              onSubmitted: (_) => _submit(),
            ),
            const Text(
              'Use at least ${FormRules.minPasswordLength} characters, '
              'a letter and a number. Both passwords must match.',
            ),
            BlocSelector<AccountCubit, AccountState, bool>(
              selector: (state) => state is AccountLoaded && state.busy,
              builder: (context, busy) => ListenableBuilder(
                listenable: _form,
                builder: (context, _) => LoadingButton(
                  label: 'Save password',
                  expanded: true,
                  isLoading: busy,
                  onPressed: _valid ? _submit : null,
                ),
              ),
            ),
            BlocSelector<AccountCubit, AccountState, bool>(
              selector: (state) =>
                  state is AccountLoaded && state.passwordSaved,
              builder: (context, saved) => saved
                  ? const Text('Password saved.')
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      );
}
