import 'package:flutter/material.dart';

import 'package:flutter_svg/flutter_svg.dart';

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.height = 32, this.semanticLabel});

  final double height;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    Theme.of(context).brightness == Brightness.dark
        ? 'assets/brand/logo-mark-reverse.svg'
        : 'assets/brand/logo-mark.svg',
    height: height,
    excludeFromSemantics: semanticLabel == null,
    semanticsLabel: semanticLabel,
  );
}
