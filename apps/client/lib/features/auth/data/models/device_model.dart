import 'package:sat_east_client/features/auth/domain/entities/device.dart';

/// Parses `devices` rows into the domain [Device].
abstract final class DeviceModel {
  /// Throws [FormatException] when `id` is missing or fields are mistyped.
  static Device fromJson(Map<String, Object?> json) {
    final id = json['id'];
    if (id is! String) throw const FormatException('device id missing');
    final platform = json['platform'];
    final label = json['label'];
    final seen = json['last_seen_at'];
    final created = json['created_at'];
    final current = json['is_current'];
    if ((platform != null && platform is! String) ||
        (label != null && label is! String) ||
        (seen != null && seen is! String) ||
        (created != null && created is! String) ||
        (current != null && current is! bool)) {
      throw const FormatException('device field mistyped');
    }
    return Device(
      id: id,
      platform: platform as String?,
      label: label as String?,
      lastSeenAt: seen == null ? null : DateTime.parse(seen as String),
      createdAt: created == null ? null : DateTime.parse(created as String),
      isCurrent: current as bool? ?? false,
    );
  }
}
