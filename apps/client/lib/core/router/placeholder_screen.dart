import 'package:flutter/material.dart';
import 'package:sat_east_client/core/env/env.dart';

/// Temporary home until the first feature lands.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: Text('SAT East · ${Env.flavor.name}')),
    );
  }
}
