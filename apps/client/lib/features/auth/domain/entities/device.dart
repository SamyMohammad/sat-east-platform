import 'package:equatable/equatable.dart';

final class Device extends Equatable {
  const Device({
    required this.id,
    this.platform,
    this.label,
    this.lastSeenAt,
    this.createdAt,
    this.isCurrent = false,
  });

  final String id;
  final String? platform;
  final String? label;
  final DateTime? lastSeenAt;
  final DateTime? createdAt;
  final bool isCurrent;

  @override
  List<Object?> get props => [
    id,
    platform,
    label,
    lastSeenAt,
    createdAt,
    isCurrent,
  ];
}
