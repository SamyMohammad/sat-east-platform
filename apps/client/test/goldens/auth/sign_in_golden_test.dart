@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:sat_east_client/features/auth/presentation/cubit/auth_state.dart';
import 'package:sat_east_client/features/auth/presentation/screens/sign_in_screen.dart';

import '../../features/auth/presentation/screens/auth_screen_harness.dart';
import '../full_viewport_harness.dart';

void main() {
  for (final width in [360.0, 1280.0]) {
    for (final brightness in Brightness.values) {
      final name = 'sign_in_${brightness.name}_${width.toInt()}';
      testWidgets('golden $name', (tester) async {
        final auth = mockCubit(const AuthSignedOut());
        await expectViewportGolden(
          tester,
          name: name,
          width: width,
          height: 800,
          brightness: brightness,
          child: BlocProvider<AuthCubit>.value(
            value: auth,
            child: const SignInScreen(),
          ),
        );
      });
    }
  }
}
