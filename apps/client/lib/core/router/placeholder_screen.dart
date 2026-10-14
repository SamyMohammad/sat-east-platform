import 'package:flutter/material.dart';

import 'package:sat_east_client/core/theme/booklet_tokens.dart';
import 'package:sat_east_client/shared/widgets/empty_state.dart';

/// Temporary destination content until each feature lands.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({super.key, this.title});

  final String? title;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: BookletSize.readingColumn,
          ),
          child: EmptyState(
            title: title ?? 'SAT East',
            message: 'This page will be available soon.',
          ),
        ),
      ),
    );
  }
}
