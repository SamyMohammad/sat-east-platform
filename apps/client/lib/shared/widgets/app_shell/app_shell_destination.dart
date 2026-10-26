import 'package:flutter/material.dart';

import 'package:sat_east_client/core/theme/app_icons.dart';

enum AppShellDestination {
  home('Home', AppIcons.home, AppIcons.home),
  courses('Courses', AppIcons.courses, AppIcons.courses),
  skills('Skills', AppIcons.skills, AppIcons.skills),
  mockExams('Mock exams', AppIcons.mockExams, AppIcons.mockExams),
  profile('Profile', AppIcons.profile, AppIcons.profile);

  const AppShellDestination(this.label, this.icon, this.selectedIcon);

  static const int destinationCount = 5;

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}
