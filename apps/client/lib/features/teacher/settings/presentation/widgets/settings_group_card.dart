import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sat_east_client/core/theme/booklet_tokens.dart';
import 'package:sat_east_client/features/teacher/settings/domain/entities/setting_spec.dart';
import 'package:sat_east_client/features/teacher/settings/presentation/cubit/teacher_settings_cubit.dart';
import 'package:sat_east_client/features/teacher/settings/presentation/cubit/teacher_settings_state.dart';
import 'package:sat_east_client/features/teacher/settings/presentation/widgets/teacher_setting_field.dart';

class SettingsGroupCard extends StatelessWidget {
  const SettingsGroupCard({
    required this.group,
    required this.specs,
    super.key,
  });
  final String group;
  final List<SettingSpec> specs;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(BookletSpace.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: BookletSpace.s4,
        children: [
          Text(group, style: Theme.of(context).textTheme.titleMedium),
          for (final spec in specs)
            _SettingEditor(key: ValueKey(spec.key), spec: spec),
        ],
      ),
    ),
  );
}

typedef _FieldSelection = ({int? value, bool invalid, bool enabled});

class _SettingEditor extends StatelessWidget {
  const _SettingEditor({required this.spec, super.key});
  final SettingSpec spec;
  @override
  Widget build(BuildContext context) =>
      BlocSelector<TeacherSettingsCubit, TeacherSettingsState, _FieldSelection>(
        selector: (state) {
          if (state is! TeacherSettingsLoaded) {
            return (value: spec.value, invalid: false, enabled: false);
          }
          final current =
              state.specs.where((s) => s.key == spec.key).firstOrNull ?? spec;
          return (
            value: state.edits.containsKey(spec.key)
                ? state.edits[spec.key]
                : current.value,
            invalid: state.invalidKeys.contains(spec.key),
            enabled: !state.saving,
          );
        },
        builder: (context, selection) => TeacherSettingField(
          spec: spec,
          value: selection.value,
          invalid: selection.invalid,
          enabled: selection.enabled,
          onChanged: (value) =>
              context.read<TeacherSettingsCubit>().edit(spec.key, value),
        ),
      );
}
