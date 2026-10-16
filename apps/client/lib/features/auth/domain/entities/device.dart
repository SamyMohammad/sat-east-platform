import 'package:equatable/equatable.dart';

class Device extends Equatable {
  const Device({required this.id, this.platform, this.label, this.lastSeenAt});

  final String id;
  final String? platform;
  final String? label;
  final DateTime? lastSeenAt;

  @override
  List<Object?> get props => [id, platform, label, lastSeenAt];
}
