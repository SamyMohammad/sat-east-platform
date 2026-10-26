import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:sat_east_client/core/di/injection.dart';
import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/router/app_router.dart';
import 'package:sat_east_client/core/theme/app_icons.dart';
import 'package:sat_east_client/core/theme/booklet_tokens.dart';
import 'package:sat_east_client/features/activation/presentation/activation_copy.dart';
import 'package:sat_east_client/features/activation/presentation/cubit/activation_cubit.dart';
import 'package:sat_east_client/features/activation/presentation/cubit/activation_state.dart';
import 'package:sat_east_client/shared/widgets/app_banner.dart';
import 'package:sat_east_client/shared/widgets/loading_button.dart';

class ActivateScreen extends StatelessWidget {
  const ActivateScreen({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => getIt<ActivationCubit>(),
    child: const ActivateView(),
  );
}

class ActivateView extends StatefulWidget {
  const ActivateView({super.key, this.now = DateTime.now});

  final DateTime Function() now;

  @override
  State<ActivateView> createState() => _ActivateViewState();
}

class _ActivateViewState extends State<ActivateView> {
  final _form = GlobalKey<FormState>();
  final _code = TextEditingController();
  final _dateText = TextEditingController();
  DateTime? _date;

  @override
  void dispose() {
    _code.dispose();
    _dateText.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final today = DateUtils.dateOnly(widget.now());
    final last = DateTime(today.year, today.month, today.day + 548);
    final selected = _date;
    final initial = selected == null || selected.isBefore(today)
        ? today
        : selected.isAfter(last)
        ? last
        : selected;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: today,
      lastDate: last,
      currentDate: today,
    );
    if (!mounted || date == null) return;
    _date = date;
    _dateText.text = MaterialLocalizations.of(context).formatMediumDate(date);
  }

  void _submit() {
    final cubit = context.read<ActivationCubit>();
    if (cubit.state is ActivationSubmitting ||
        !(_form.currentState?.validate() ?? false)) {
      return;
    }
    if (_date case final date?) {
      unawaited(cubit.submit(_code.text, date));
    }
  }

  @override
  Widget build(BuildContext context) =>
      BlocListener<ActivationCubit, ActivationState>(
        listener: (context, state) {
          if (state is ActivationDone) context.go(AppRoutes.courses);
        },
        child: Scaffold(
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(BookletSpace.s4),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: BookletSize.authCard,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: BookletSpace.s5,
                    children: [
                      Text(
                        ActivationCopy.title,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      BlocSelector<ActivationCubit, ActivationState, String?>(
                        selector: (state) =>
                            state is ActivationFailed &&
                                state.error.code != ErrorCodes.invalidInput
                            ? state.error.code
                            : null,
                        builder: (context, code) => code == null
                            ? const SizedBox.shrink()
                            : AppBanner(
                                message: ActivationCopy.errorBody(code),
                                kind: AppBannerKind.error,
                              ),
                      ),
                      BlocSelector<
                        ActivationCubit,
                        ActivationState,
                        (bool, String?)
                      >(
                        selector: (state) => (
                          state is ActivationSubmitting,
                          state is ActivationFailed &&
                                  state.error.code == ErrorCodes.invalidInput
                              ? ActivationCopy.invalidDate
                              : null,
                        ),
                        builder: (context, formState) => Form(
                          key: _form,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            spacing: BookletSpace.s5,
                            children: [
                              TextFormField(
                                controller: _code,
                                enabled: !formState.$1,
                                autocorrect: false,
                                enableSuggestions: false,
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(
                                  labelText: ActivationCopy.codeLabel,
                                ),
                                validator: (value) =>
                                    value == null || value.trim().isEmpty
                                    ? ActivationCopy.missingCode
                                    : null,
                              ),
                              TextFormField(
                                controller: _dateText,
                                enabled: !formState.$1,
                                readOnly: true,
                                onTap: _pickDate,
                                decoration: InputDecoration(
                                  labelText: ActivationCopy.dateLabel,
                                  errorText: formState.$2,
                                  suffixIcon: const Icon(
                                    AppIcons.calendar,
                                  ),
                                ),
                                validator: (value) =>
                                    value == null || value.isEmpty
                                    ? ActivationCopy.invalidDate
                                    : null,
                              ),
                              LoadingButton(
                                label: ActivationCopy.activate,
                                expanded: true,
                                isLoading: formState.$1,
                                onPressed: _submit,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}
