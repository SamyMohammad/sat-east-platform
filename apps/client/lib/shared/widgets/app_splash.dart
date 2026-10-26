import 'package:flutter/material.dart';
import 'package:sat_east_client/core/theme/app_tokens.dart';
import 'package:sat_east_client/shared/widgets/app_progress.dart';
import 'package:sat_east_client/shared/widgets/app_shell/shell_header.dart';

/// Full-screen placeholder shown while the session state is still unknown.
class AppSplash extends StatelessWidget {
  const AppSplash({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpace.s4),
          child: SizedBox(
            width: AppSize.authCard,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ShellWordmark(),
                AppProgress(label: 'Loading'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
