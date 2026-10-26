import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:sat_east_client/core/theme/app_hues.dart';
import 'package:sat_east_client/core/theme/app_icons.dart';
import 'package:sat_east_client/core/theme/app_theme.dart';
import 'package:sat_east_client/shared/widgets/icon_tile.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('uses_hue_and_fixed_size_${brightness.name}', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: brightness == Brightness.light
              ? AppTheme.light()
              : AppTheme.dark(),
          home: const Scaffold(
            body: Center(
              child: IconTile(AppIcons.courses, hue: SubjectHue.teal),
            ),
          ),
        ),
      );
      expect(tester.getSize(find.byType(IconTile)), const Size(40, 40));
      final icon = tester.widget<Icon>(find.byIcon(AppIcons.courses));
      expect(icon.color, SubjectHue.teal.color(brightness));
      final box = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(IconTile),
          matching: find.byType(DecoratedBox),
        ),
      );
      final decoration = box.decoration as BoxDecoration;
      expect(decoration.color, SubjectHue.teal.wash(brightness));
      expect(decoration.borderRadius, BorderRadius.circular(10));
    });
  }
}
