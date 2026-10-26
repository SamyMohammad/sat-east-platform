import 'package:flutter/material.dart';

import 'package:flutter_svg/flutter_svg.dart';

import 'package:sat_east_client/core/theme/app_colors.dart';
import 'package:sat_east_client/core/theme/app_tokens.dart';

enum AppIllustrationName {
  welcome('welcome'),
  emptyCourses('empty_courses'),
  inbox('inbox'),
  resetPassword('reset_password'),
  deviceLimit('device_limit'),
  practiceDone('practice_done'),
  quizPassed('quiz_passed'),
  quizRetry('quiz_retry'),
  offline('offline'),
  builderEmpty('builder_empty');

  const AppIllustrationName(this._fileName);

  final String _fileName;

  String get assetPath => 'assets/illustrations/$_fileName.svg';
}

class AppIllustration extends StatelessWidget {
  const AppIllustration(this.name, {this.height, super.key});

  final AppIllustrationName name;
  final double? height;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    name.assetPath,
    height: height ?? AppSize.illustration,
    excludeFromSemantics: true,
    colorMapper: _IllustrationColors(
      context.appColors,
      Theme.of(context).brightness,
    ),
  );
}

@immutable
class _IllustrationColors extends ColorMapper {
  const _IllustrationColors(this.colors, this.brightness);

  final AppColors colors;
  final Brightness brightness;

  @override
  Color substitute(
    String? id,
    String elementName,
    String attributeName,
    Color color,
  ) {
    if (color.toARGB32() == 0xFF6C63FF) return colors.brand;
    if (brightness == Brightness.light) return color;
    // Only known unDraw neutrals change; skin tones and secondary accents stay.
    return switch (color.toARGB32()) {
      0xFF2F2E41 || 0xFF3F3D56 => colors.inkSecondary,
      0xFFCCCCCC || 0xFFCBCBCB || 0xFFD1D3D4 => colors.lineStrong,
      0xFFE6E6E6 || 0xFFE4E4E4 => colors.line,
      0xFFF2F2F2 || 0xFFF0F0F0 => colors.raised,
      0xFFFFFFFF => colors.surface,
      _ => color,
    };
  }

  @override
  bool operator ==(Object other) =>
      other is _IllustrationColors &&
      other.colors == colors &&
      other.brightness == brightness;

  @override
  int get hashCode => Object.hash(colors, brightness);
}
