import 'package:flutter/widgets.dart';

abstract final class AppMotion {
  static const Duration press = Duration(milliseconds: 120);
  static const Duration state = Duration(milliseconds: 200);
  static const Duration enter = Duration(milliseconds: 320);
  static const Duration signature = Duration(milliseconds: 500);
  static const Duration stagger = Duration(milliseconds: 40);

  static const Curve emphasized = Cubic(0.05, 0.7, 0.1, 1);
  static const Curve standard = Cubic(0.2, 0, 0, 1);

  static bool reduced(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context);

  static Duration resolve(BuildContext context, Duration duration) =>
      reduced(context) ? Duration.zero : duration;
}
