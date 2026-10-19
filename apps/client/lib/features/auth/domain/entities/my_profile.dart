import 'package:equatable/equatable.dart';

final class MyProfile extends Equatable {
  const MyProfile({required this.fullName, required this.email});

  final String fullName;
  final String email;

  @override
  List<Object?> get props => [fullName, email];

  @override
  bool get stringify => false;
}
