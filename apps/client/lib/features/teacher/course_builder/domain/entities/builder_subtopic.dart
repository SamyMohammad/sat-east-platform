import 'package:equatable/equatable.dart';

class BuilderSubtopic extends Equatable {
  const BuilderSubtopic({
    required this.id,
    required this.title,
    required this.sort,
    required this.inUse,
  });
  final String id;
  final String title;
  final int sort;
  final bool inUse;
  BuilderSubtopic withSort(int value) =>
      BuilderSubtopic(id: id, title: title, sort: value, inUse: inUse);
  @override
  List<Object?> get props => [id, title, sort, inUse];
}
