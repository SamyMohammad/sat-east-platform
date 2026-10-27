import 'dart:async';

import 'package:flutter/material.dart';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:sat_east_client/core/theme/app_tokens.dart';
import 'package:sat_east_client/features/teacher/settings/presentation/cubit/teacher_settings_cubit.dart';
import 'package:sat_east_client/features/teacher/settings/presentation/cubit/teacher_settings_state.dart';
import 'package:sat_east_client/features/teacher/shell/teacher_save_surface.dart';
import 'package:sat_east_client/shared/widgets/loading_button.dart';

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
          return TeacherSaveSurface(
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(AppSpace.s4),
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: AppSpace.s2,
                  runSpacing: AppSpace.s2,
                  children: [
                    TextButton(
                      onPressed: state.saving ? null : cubit.discard,
                      child: const Text('Discard'),
                    ),
                    LoadingButton(
                      label: 'Save changes',
                      isLoading: state.saving,
                      onPressed: state.canSave
                          ? () => unawaited(cubit.save())
                          : null,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
}
