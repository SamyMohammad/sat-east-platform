import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sat_east_client/core/di/injection.dart';
import 'package:sat_east_client/core/theme/booklet_tokens.dart';
import 'package:sat_east_client/features/teacher/settings/domain/entities/setting_spec.dart';
import 'package:sat_east_client/features/teacher/settings/presentation/cubit/teacher_settings_cubit.dart';
import 'package:sat_east_client/features/teacher/settings/presentation/cubit/teacher_settings_state.dart';
import 'package:sat_east_client/features/teacher/settings/presentation/teacher_settings_copy.dart';
import 'package:sat_east_client/features/teacher/settings/presentation/widgets/settings_group_card.dart';
import 'package:sat_east_client/features/teacher/settings/presentation/widgets/settings_save_bar.dart';

class TeacherSettingsScreen extends StatelessWidget {
  const TeacherSettingsScreen({super.key});
  @override
  Widget build(BuildContext context) => BlocProvider<TeacherSettingsCubit>(
    create: (_) {
      final cubit = getIt<TeacherSettingsCubit>();
      unawaited(cubit.load());
      return cubit;
    },
    child: const TeacherSettingsView(),
  );
}

class TeacherSettingsView extends StatelessWidget {
  const TeacherSettingsView({super.key});
  @override
  Widget build(BuildContext context) =>
      BlocConsumer<TeacherSettingsCubit, TeacherSettingsState>(
        listener: (context, state) {
          if (state is! TeacherSettingsLoaded) return;
          final message = state.lastError != null
              ? teacherSettingsError(state.lastError!.code)
              : state.savedAt != null
              ? 'Settings saved'
              : null;
          final messenger = ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar();
          if (message != null) {
            messenger.showSnackBar(SnackBar(content: Text(message)));
          }
        },
        buildWhen: (previous, next) =>
            !(previous is TeacherSettingsLoaded &&
                next is TeacherSettingsLoaded &&
                listEquals(previous.specs, next.specs)),
        builder: (context, state) => switch (state) {
          TeacherSettingsLoading() => const Center(
            child: CircularProgressIndicator(),
          ),
          TeacherSettingsFailed(:final error) => Center(
            child: Padding(
              padding: const EdgeInsets.all(BookletSpace.s4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(teacherSettingsError(error.code)),
                  TextButton(
                    onPressed: () =>
                        unawaited(context.read<TeacherSettingsCubit>().load()),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
          TeacherSettingsLoaded(specs: []) => const Center(
            child: Text('No settings available.'),
          ),
          TeacherSettingsLoaded(:final specs) => _SettingsBody(specs: specs),
        },
      );
}

class _SettingsBody extends StatelessWidget {
  const _SettingsBody({required this.specs});
  final List<SettingSpec> specs;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.all(BookletSpace.s6),
        child: Text(
          'Settings',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
      ),
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(BookletSpace.s4),
          child: Align(
            alignment: AlignmentDirectional.topStart,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: BookletSize.readingColumn,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: BookletSpace.s4,
                children: [
                  for (final group in specs.map((s) => s.group).toSet())
                    SettingsGroupCard(
                      group: group,
                      specs: specs.where((s) => s.group == group).toList(),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
      const SettingsSaveBar(),
    ],
  );
}
