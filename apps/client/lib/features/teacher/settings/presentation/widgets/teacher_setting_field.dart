import 'package:flutter/material.dart';
import 'package:sat_east_client/features/teacher/settings/domain/entities/setting_spec.dart';

class TeacherSettingField extends StatefulWidget {
  const TeacherSettingField({
    required this.spec,
    required this.value,
    required this.invalid,
    required this.enabled,
    required this.onChanged,
    super.key,
  });
  final SettingSpec spec;
  final int? value;
  final bool invalid;
  final bool enabled;
  final ValueChanged<int?> onChanged;
  @override
  State<TeacherSettingField> createState() => _TeacherSettingFieldState();
}

class _TeacherSettingFieldState extends State<TeacherSettingField> {
  late final TextEditingController _controller;
  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value?.toString() ?? '');
  }

  @override
  void didUpdateWidget(TeacherSettingField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value &&
        int.tryParse(_controller.text) != widget.value) {
      _controller.text = widget.value?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    key: ValueKey('setting-${widget.spec.key}'),
    controller: _controller,
    enabled: widget.enabled,
    keyboardType: const TextInputType.numberWithOptions(signed: true),
    onChanged: (text) => widget.onChanged(int.tryParse(text)),
    decoration: InputDecoration(
      labelText: widget.spec.label,
      suffixText: widget.spec.unit,
      helperText: '${widget.spec.min}\u2013${widget.spec.max}',
      errorMaxLines: 2,
      errorText: widget.invalid
          ? 'Enter a whole number from '
                '${widget.spec.min} to ${widget.spec.max}'
          : null,
    ),
  );
}
