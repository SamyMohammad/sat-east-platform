import 'package:flutter/material.dart';

enum AppShellDestination {
  home('Home', Icons.home_outlined, Icons.home),
  courses('Courses', Icons.menu_book_outlined, Icons.menu_book),
  skills('Skills', Icons.insights_outlined, Icons.insights),
  mockExams('Mock exams', Icons.timer_outlined, Icons.timer),
  profile('Profile', Icons.person_outline, Icons.person);

  const AppShellDestination(this.label, this.icon, this.selectedIcon);

  static const int destinationCount = 5;

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}
