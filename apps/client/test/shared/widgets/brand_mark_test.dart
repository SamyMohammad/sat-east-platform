import 'package:flutter/material.dart';

import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sat_east_client/shared/widgets/brand_mark.dart';

void main() {
  for (final (brightness, asset) in [
    (Brightness.light, 'assets/brand/logo-mark.svg'),
    (Brightness.dark, 'assets/brand/logo-mark-reverse.svg'),
  ]) {
    testWidgets('uses the ${brightness.name} brand asset', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: brightness),
          home: const BrandMark(),
        ),
      );
      await tester.pumpAndSettle();

      final picture = tester.widget<SvgPicture>(find.byType(SvgPicture));
      expect((picture.bytesLoader as SvgAssetLoader).assetName, asset);
      expect(picture.height, 32);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('is decorative by default', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: BrandMark()));
    await tester.pumpAndSettle();

    final picture = tester.widget<SvgPicture>(find.byType(SvgPicture));
    expect(picture.excludeFromSemantics, isTrue);
    expect(picture.semanticsLabel, isNull);
  });

  testWidgets('exposes an optional semantic label', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      const MaterialApp(
        home: BrandMark(semanticLabel: 'Abdelrahman Elmenshawy'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Abdelrahman Elmenshawy'), findsOneWidget);
    final picture = tester.widget<SvgPicture>(find.byType(SvgPicture));
    expect(picture.excludeFromSemantics, isFalse);
    semantics.dispose();
  });

  testWidgets('honors a custom height', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: BrandMark(height: 48)));
    await tester.pumpAndSettle();

    expect(tester.widget<SvgPicture>(find.byType(SvgPicture)).height, 48);
  });
}
