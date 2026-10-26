import 'package:flutter/material.dart';

import 'package:sat_east_client/core/theme/app_icons.dart';
import 'package:sat_east_client/shared/widgets/app_banner.dart';
import 'package:sat_east_client/shared/widgets/app_chip.dart';
import 'package:sat_east_client/shared/widgets/app_dialog.dart';
import 'package:sat_east_client/shared/widgets/app_overlays.dart';
import 'package:sat_east_client/shared/widgets/app_progress.dart';
import 'package:sat_east_client/shared/widgets/app_skeleton.dart';
import 'package:sat_east_client/shared/widgets/empty_state.dart';
import 'package:sat_east_client/shared/widgets/error_retry.dart';
import 'package:sat_east_client/shared/widgets/loading_button.dart';

Widget _sheet(List<Widget> children) => Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    for (final child in children)
      Padding(padding: const EdgeInsets.only(bottom: 16), child: child),
  ],
);

Widget controlsSheet() => _sheet([
  const Text('Buttons and feedback'),
  for (final variant in AppButtonVariant.values)
    _sheet([
      Text(variant.name),
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          LoadingButton(label: 'Continue', variant: variant, onPressed: () {}),
          LoadingButton(label: 'Disabled', variant: variant),
          LoadingButton(
            label: 'Loading',
            variant: variant,
            isLoading: true,
            onPressed: () {},
          ),
        ],
      ),
    ]),
  LoadingButton(
    label: 'Retry',
    errorText: 'Not sent. Retry.',
    icon: AppIcons.retry,
    onPressed: () {},
  ),
  Wrap(
    spacing: 12,
    runSpacing: 12,
    children: [
      const AppChip(label: 'E · Easy', kind: AppChipKind.difficulty),
      const AppChip(label: 'Linear equations', icon: AppIcons.topic),
      AppChip(
        label: 'Filter',
        kind: AppChipKind.filter,
        onSelected: (_) {},
      ),
      AppChip(
        label: 'Selected',
        kind: AppChipKind.filter,
        selected: true,
        onSelected: (_) {},
      ),
      const AppChip(label: 'Disabled', kind: AppChipKind.filter),
    ],
  ),
  AppBanner(
    message: 'Desmos is available on every question in this module.',
    actionLabel: 'Got it',
    onAction: () {},
  ),
  AppBanner(
    message:
        '5 minutes left. Answer the rest; a guess scores better than a blank.',
    kind: AppBannerKind.warning,
    actionLabel: 'Review marked',
    onAction: () {},
  ),
  AppBanner(
    message:
        "You're offline. Answers are kept on this device and sync "
        'when you reconnect.',
    kind: AppBannerKind.offline,
    actionLabel: 'Retry',
    onAction: () {},
  ),
]);

Widget statusesSheet() => _sheet([
  const AppProgress(label: 'Topic 4 of 40', value: .1, valueLabel: '10%'),
  const AppProgress(label: 'Saving answers', valueLabel: 'Indeterminate'),
  const AppSkeleton(),
  EmptyState(
    title: 'No mock exams yet',
    message:
        'Mock exams open after your last topic quiz, or 30 days before '
        'your test date. Keep going on your path.',
    actionLabel: 'Continue path',
    onAction: () {},
  ),
  ErrorRetry(
    title: "This topic didn't load",
    message: 'Check your connection and try again. Your progress is saved.',
    onRetry: () {},
    secondaryLabel: 'Go home',
    onSecondary: () {},
  ),
  ErrorRetry(
    title: 'Trying again',
    message: 'Your progress is saved.',
    onRetry: () {},
    isRetrying: true,
  ),
]);

Widget overlaysSheet() => _sheet([
  const Text('Dialog'),
  AppDialog(
    title: 'Leave the quiz?',
    content: const Text(
      "You've answered 6 of 10. Leaving ends this attempt and it counts "
      'toward your score.',
    ),
    actions: [
      LoadingButton(
        label: 'Keep going',
        variant: AppButtonVariant.tertiary,
        onPressed: () {},
      ),
      LoadingButton(
        label: 'Leave quiz',
        variant: AppButtonVariant.destructive,
        onPressed: () {},
      ),
    ],
  ),
  const Text('Snackbar'),
  const _SnackSample(),
]);

class _SnackSample extends StatefulWidget {
  const _SnackSample();

  @override
  State<_SnackSample> createState() => _SnackSampleState();
}

class _SnackSampleState extends State<_SnackSample> {
  final _messenger = GlobalKey<ScaffoldMessengerState>();
  final _scaffold = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showAppSnackBar(
        context: _scaffold.currentContext!,
        message: 'Choice D crossed out.',
        actionLabel: 'Undo',
        onAction: () {},
      );
    });
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 280,
    child: MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true),
      child: ScaffoldMessenger(
        key: _messenger,
        child: Scaffold(
          key: _scaffold,
          body: const Center(child: Text('Question feedback')),
        ),
      ),
    ),
  );
}
