import 'package:flutter/material.dart';

import 'package:sat_east_client/core/theme/booklet_tokens.dart';
import 'package:sat_east_client/shared/widgets/app_progress.dart';

/// Full-screen placeholder shown while the session state is still unknown.
class AppSplash extends StatelessWidget {
  const AppSplash({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(BookletSpace.s4),
          child: SizedBox(
            width: 240,
            child: AppProgress(label: 'Loading'),
          ),
        ),
      ),
    );
  }
}
