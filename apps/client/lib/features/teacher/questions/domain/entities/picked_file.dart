import 'package:equatable/equatable.dart';

class PickedFile extends Equatable {
  const PickedFile({required this.name, required this.text});
  final String name;
  final String text;
  @override
  List<Object?> get props => [name, text];
}
