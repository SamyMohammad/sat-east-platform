import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sat_east_client/core/theme/booklet_tokens.dart';
import 'package:sat_east_client/features/teacher/settings/presentation/cubit/teacher_settings_cubit.dart';
import 'package:sat_east_client/features/teacher/settings/presentation/cubit/teacher_settings_state.dart';

class SettingsSaveBar extends StatelessWidget {
  const SettingsSaveBar({super.key});
  @override
  Widget build(BuildContext context) =>
      BlocBuilder<TeacherSettingsCubit, TeacherSettingsState>(
        builder: (context, state) {
          if (state is! TeacherSettingsLoaded || !state.isDirty) {
            return const SizedBox.shrink();
          }
          final cubit = context.read<TeacherSettingsCubit>();
          return SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(BookletSpace.s4),
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: BookletSpace.s2,
                runSpacing: BookletSpace.s2,
                children: [
                  TextButton(
                    onPressed: state.saving ? null : cubit.discard,
                    child: const Text('Discard'),
                  ),
                  FilledButton(
                    onPressed: state.canSave
                        ? () => unawaited(cubit.save())
                        : null,
                    child: const Text('Save changes'),
                  ),
                ],
              ),
            ),
          );
        },
      );
}
