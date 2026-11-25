import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/di/injection.dart';
import 'package:sat_east_client/core/links/external_link_launcher.dart';
import 'package:sat_east_client/core/theme/app_theme.dart';
import 'package:sat_east_client/features/auth/presentation/widgets/legal_agreement_line.dart';
import 'package:sat_east_client/shared/widgets/loading_button.dart';

Finder _link(String label) => find.byWidgetPredicate(
  (w) => w is LoadingButton && w.label == label,
  description: 'link "$label"',
);

void main() {
  late List<Uri> opened;

  setUp(() {
    opened = <Uri>[];
    getIt.registerSingleton<ExternalLinkLauncher>((url) async {
      opened.add(url);
      return true;
    });
  });
  tearDown(getIt.reset);

  Future<void> pump(WidgetTester tester, {double width = 360}) async {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(body: LegalAgreementLine()),
      ),
    );
  }

  for (final width in [360.0, 1280.0]) {
    group('P3: LegalAgreementLine at ${width.toInt()}px', () {
      testWidgets('P3: shows the agreement sentence with both links', (
        tester,
      ) async {
        await pump(tester, width: width);

        expect(
          find.text('By creating an account you agree to the'),
          findsOneWidget,
        );
        expect(_link('Terms'), findsOneWidget);
        expect(find.text('and the'), findsOneWidget);
        expect(_link('Privacy Policy'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    });
  }

  testWidgets('P3: tapping Terms opens the landing terms page', (tester) async {
    await pump(tester);

    await tester.tap(_link('Terms'));
    await tester.pump();

    expect(opened, hasLength(1));
    expect(opened.single.path, '/terms');
    expect(opened.single.scheme, 'https');
  });

  testWidgets('P3: tapping Privacy Policy opens the landing privacy page', (
    tester,
  ) async {
    await pump(tester);

    await tester.tap(_link('Privacy Policy'));
    await tester.pump();

    expect(opened, hasLength(1));
    expect(opened.single.path, '/privacy');
  });

  testWidgets('P3: a link that cannot be opened shows a message', (
    tester,
  ) async {
    await getIt.reset();
    getIt.registerSingleton<ExternalLinkLauncher>((_) async => false);
    await pump(tester);

    await tester.tap(_link('Terms'));
    await tester.pump();

    expect(find.text('Could not open the link. Try again.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
