import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:sat_east_client/core/theme/app_motion.dart';

CustomTransitionPage<void> fadeThroughPage(
  BuildContext context, {
  required LocalKey key,
  required Widget child,
}) => _page(context, key: key, child: child, sharedAxis: false);

CustomTransitionPage<void> sharedAxisPage(
  BuildContext context, {
  required LocalKey key,
  required Widget child,
}) => _page(context, key: key, child: child, sharedAxis: true);

CustomTransitionPage<void> _page(
  BuildContext context, {
  required LocalKey key,
  required Widget child,
  required bool sharedAxis,
}) => CustomTransitionPage<void>(
  key: key,
  transitionDuration: AppMotion.resolve(context, AppMotion.enter),
  reverseTransitionDuration: AppMotion.resolve(context, AppMotion.enter),
  child: child,
  transitionsBuilder: (context, animation, secondaryAnimation, child) {
    if (AppMotion.reduced(context)) return child;
    final incoming = animation.drive(
      CurveTween(
        curve: sharedAxis
            ? AppMotion.emphasized
            : const Interval(0.3, 1, curve: AppMotion.emphasized),
      ),
    );
    final outgoing = secondaryAnimation.drive(
      CurveTween(
        curve: sharedAxis
            ? AppMotion.standard
            : const Interval(0, 0.3, curve: AppMotion.standard),
      ),
    );
    Widget result = FadeTransition(
      opacity: incoming,
      child: FadeTransition(opacity: ReverseAnimation(outgoing), child: child),
    );
    if (sharedAxis) {
      result = SlideTransition(
        position: incoming.drive(
          Tween(begin: const Offset(0.08, 0), end: Offset.zero),
        ),
        child: SlideTransition(
          position: outgoing.drive(
            Tween(begin: Offset.zero, end: const Offset(-0.08, 0)),
          ),
          child: result,
        ),
      );
    }
    return result;
  },
);
