import 'package:sat_east_client/features/auth/domain/entities/device.dart';

class DeviceModel extends Device {
  const DeviceModel({
    required super.id,
    super.platform,
    super.label,
    super.lastSeenAt,
  });

  /// Throws [FormatException] when `id` is missing or fields are mistyped.
  factory DeviceModel.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    if (id is! String) throw const FormatException('device id missing');
    final platform = json['platform'];
    final label = json['label'];
    final seen = json['last_seen_at'];
    if ((platform != null && platform is! String) ||
        (label != null && label is! String) ||
        (seen != null && seen is! String)) {
      throw const FormatException('device field mistyped');
    }
    return DeviceModel(
      id: id,
      platform: platform as String?,
      label: label as String?,
      lastSeenAt: seen == null ? null : DateTime.parse(seen as String),
    );
  }
}
