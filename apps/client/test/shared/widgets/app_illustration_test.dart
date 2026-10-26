import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sat_east_client/core/theme/app_colors.dart';
import 'package:sat_east_client/core/theme/app_theme.dart';
import 'package:sat_east_client/shared/widgets/app_illustration.dart';

const _names = {
  'welcome',
  'empty_courses',
  'inbox',
  'reset_password',
  'device_limit',
  'practice_done',
  'quiz_passed',
  'quiz_retry',
  'offline',
  'builder_empty',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every_name_maps_to_planned_asset', () {
    expect(AppIllustrationName.values.map((name) => name.assetPath).toSet(), {
      for (final name in _names) 'assets/illustrations/$name.svg',
    });
  });
  for (final brightness in Brightness.values) {
    testWidgets('recolours_accent_and_preserves_skin_${brightness.name}', (
      tester,
    ) async {
      late SvgPicture picture;
      await tester.pumpWidget(
        MaterialApp(
          theme: brightness == Brightness.light
              ? AppTheme.light()
              : AppTheme.dark(),
          home: Builder(
            builder: (context) {
              picture =
                  const AppIllustration(
                        AppIllustrationName.welcome,
                      ).build(context)
                      as SvgPicture;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      final loader = picture.bytesLoader as SvgAssetLoader;
      final mapper = loader.colorMapper!;
      final colors = brightness == Brightness.light
          ? AppColors.light
          : AppColors.dark;
      expect(
        mapper.substitute(null, 'path', 'fill', const Color(0xFF6C63FF)),
        colors.brand,
      );
      expect(
        mapper.substitute(null, 'path', 'fill', const Color(0xFFFFB8B8)),
        const Color(0xFFFFB8B8),
      );
      expect(
        mapper.substitute(null, 'path', 'fill', const Color(0xFFF2F2F2)),
        brightness == Brightness.light
            ? const Color(0xFFF2F2F2)
            : colors.raised,
      );
      expect(picture.height, 200);
      expect(loader.assetName, 'assets/illustrations/welcome.svg');
    });
  }
  test(
    'every_name_has_an_asset',
    () async {
      for (final name in AppIllustrationName.values) {
        expect(await rootBundle.loadString(name.assetPath), contains('<svg'));
      }
    },
  );

  testWidgets(
    'renders_in_dark_without_exception',
    (tester) async {
      for (final name in AppIllustrationName.values) {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.dark(),
            home: Scaffold(body: AppIllustration(name, height: 180)),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(SvgPicture), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    },
  );
}
