import 'package:equatable/equatable.dart';

class VideoQuota extends Equatable {
  const VideoQuota({required this.usedMb, required this.capMb});
  final int usedMb;
  final int capMb;

  String get label =>
      '${(usedMb / 1024).toStringAsFixed(1)} of '
      '${(capMb / 1024).toStringAsFixed(0)} GB used';
  double get fraction => capMb <= 0 ? 0 : (usedMb / capMb).clamp(0.0, 1.0);

  @override
  List<Object?> get props => [usedMb, capMb];
}
