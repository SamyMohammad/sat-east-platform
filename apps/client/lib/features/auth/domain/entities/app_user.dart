import 'package:equatable/equatable.dart';

final class AppUser extends Equatable {
  const AppUser({required this.id, required this.email});

  final String id;
  final String email;

  // Keep the email out of toString (A.6).
  @override
  bool? get stringify => false;

  @override
  List<Object?> get props => [id, email];
}
