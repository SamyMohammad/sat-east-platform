@Tags(['golden'])
library;

import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:sat_east_client/core/theme/app_theme.dart';
import 'package:sat_east_client/core/widgets/app_shell/app_shell.dart';
import 'package:sat_east_client/core/widgets/app_shell/focus_mode_scaffold.dart';

void main() {
  for (final width in [360.0, 768.0, 1280.0]) {
    for (final brightness in Brightness.values) {
      final name = 'shell_${brightness.name}_${width.toInt()}';
      testWidgets('F-4: golden $name', (tester) async {
        await _expectShellGolden(
          tester,
          name: name,
          width: width,
          brightness: brightness,
        );
      });
    }

    final scaledName = 'shell_light_${width.toInt()}_text2x';
    testWidgets('F-4: golden $scaledName', (tester) async {
      await _expectShellGolden(
        tester,
        name: scaledName,
        width: width,
        textScale: 2,
      );
    });

    final focusName = 'focus_shell_light_${width.toInt()}';
    testWidgets('F-4: golden $focusName', (tester) async {
      await _expectShellGolden(
        tester,
        name: focusName,
        width: width,
        focusMode: true,
      );
    });
  }

  testWidgets('F-4: golden focus_shell_dark_1280', (tester) async {
    await _expectShellGolden(
      tester,
      name: 'focus_shell_dark_1280',
      width: 1280,
      brightness: Brightness.dark,
      focusMode: true,
    );
  });
}

Future<void> _expectShellGolden(
  WidgetTester tester, {
  required String name,
  required double width,
  Brightness brightness = Brightness.light,
  double textScale = 1,
  bool focusMode = false,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, width == 768 ? 1024 : 800);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  const boundaryKey = Key('full-shell-golden');
  await tester.pumpWidget(
    MaterialApp(
      theme: brightness == Brightness.light
          ? AppTheme.light()
          : AppTheme.dark(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
        ),
        child: child!,
      ),
      home: RepaintBoundary(
        key: boundaryKey,
        child: focusMode
            ? FocusModeScaffold(
                appBar: AppBar(title: const Text('Practice')),
                bottomBar: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: FilledButton(
                      onPressed: () {},
                      child: const Text('Check answer'),
                    ),
                  ),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(24),
                  child: _FocusSample(),
                ),
              )
            : AppShell(
                selectedIndex: 1,
                onDestinationSelected: (_) {},
                onNotifications: () {},
                child: const _CoursesSample(),
              ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
  await expectLater(
    find.byKey(boundaryKey),
    matchesGoldenFile('../baselines/$name.png'),
  );
}

class _CoursesSample extends StatelessWidget {
  const _CoursesSample();

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Your courses', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        const Text('Build confidence, one topic at a time.'),
        const SizedBox(height: 24),
        const _CourseCard(
          title: 'SAT Math',
          description: 'Explore algebra, problem solving, and geometry.',
        ),
        const SizedBox(height: 16),
        const _CourseCard(
          title: 'EST Math',
          description: 'Study the concepts and practise at your own pace.',
        ),
      ],
    ),
  );
}

class _CourseCard extends StatelessWidget {
  const _CourseCard({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(description),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () {},
              child: const Text('Explore course'),
            ),
          ],
        ),
      ),
    ),
  );
}

class _FocusSample extends StatelessWidget {
  const _FocusSample();

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Linear equations', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 24),
        const Text('Find the value of x when 2x + 4 = 12.'),
        const SizedBox(height: 24),
        const TextField(
          decoration: InputDecoration(labelText: 'Your answer'),
        ),
      ],
    ),
  );
}
