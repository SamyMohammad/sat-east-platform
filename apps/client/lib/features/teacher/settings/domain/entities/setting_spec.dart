import 'package:equatable/equatable.dart';

class SettingSpec extends Equatable {
  const SettingSpec({
    required this.key,
    required this.group,
    required this.label,
    required this.unit,
    required this.min,
    required this.max,
    required this.value,
  });
  final String key;
  final String group;
  final String label;
  final String unit;
  final int min;
  final int max;
  final int value;

  bool accepts(int? input) => input != null && input >= min && input <= max;
  @override
  List<Object?> get props => [key, group, label, unit, min, max, value];
}
