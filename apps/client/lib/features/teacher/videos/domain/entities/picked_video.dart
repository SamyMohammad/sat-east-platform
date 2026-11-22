import 'package:equatable/equatable.dart';

/// A source video chosen by the teacher. The bytes are never read into Dart:
/// [handle] is an opaque platform object (the browser `File`) that only the
/// transcoder of the same platform understands.
class PickedVideo extends Equatable {
  const PickedVideo({
    required this.name,
    required this.sizeBytes,
    required this.handle,
  });

  final String name;
  final int sizeBytes;
  final Object handle;

  @override
  List<Object?> get props => [name, sizeBytes, handle];
}
