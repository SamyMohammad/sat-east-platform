import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:sat_east_client/core/errors/result.dart';

sealed class NotesViewerState extends Equatable {
  const NotesViewerState();
  @override
  bool get stringify => false;
  @override
  List<Object?> get props => [];
}

final class NotesViewerLoading extends NotesViewerState {
  const NotesViewerLoading();
}

final class NotesViewerFailed extends NotesViewerState {
  const NotesViewerFailed(this.error);
  final AppError error;
  @override
  List<Object?> get props => [error];
}

final class NotesViewerReady extends NotesViewerState {
  const NotesViewerReady({
    required this.bytes,
    required this.watermark,
    this.markError,
  });
  final Uint8List bytes;
  final String watermark;
  final AppError? markError;
  @override
  List<Object?> get props => [bytes, watermark, markError];
}
