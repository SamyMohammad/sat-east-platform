import 'package:equatable/equatable.dart';

final class AppUser extends Equatable {
  const AppUser({required this.id, required this.email});

  final String id;
  final String email;

  @override
  List<Object?> get props => [id, email];
}
