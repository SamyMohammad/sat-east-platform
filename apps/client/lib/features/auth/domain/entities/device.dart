import 'package:equatable/equatable.dart';

final class Device extends Equatable {
  const Device({required this.id, this.platform, this.label, this.lastSeenAt});

  final String id;
  final String? platform;
  final String? label;
  final DateTime? lastSeenAt;

  @override
  List<Object?> get props => [id, platform, label, lastSeenAt];
}
