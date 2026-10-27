part of 'loading_button.dart';

class _ButtonSurface extends StatefulWidget {
  const _ButtonSurface({
    required this.enabled,
    required this.primary,
    required this.builder,
  });

  final bool enabled;
  final bool primary;
  final Widget Function(WidgetStatesController) builder;

  @override
  State<_ButtonSurface> createState() => _ButtonSurfaceState();
}

class _ButtonSurfaceState extends State<_ButtonSurface> {
  late final WidgetStatesController _states;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _states = WidgetStatesController()..addListener(_onStates);
  }

  void _onStates() {
    final pressed = _states.value.contains(WidgetState.pressed);
    if (!widget.enabled) {
      _pressed = false;
    } else if (_pressed != pressed) {
      setState(() => _pressed = pressed);
    }
  }

  @override
  void didUpdateWidget(_ButtonSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled) _pressed = false;
  }

  @override
  void dispose() {
    _states
      ..removeListener(_onStates)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scale = widget.enabled && _pressed ? .98 : 1.0;
    final child = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.control),
        boxShadow: widget.enabled && widget.primary
            ? [
                BoxShadow(
                  color: context.appColors.shadow,
                  offset: const Offset(0, 1),
                ),
                BoxShadow(
                  color: context.appColors.brand.withValues(alpha: .25),
                  offset: const Offset(0, 2),
                  blurRadius: 6,
                ),
              ]
            : null,
      ),
      child: widget.builder(_states),
    );
    return AppMotion.reduced(context)
        ? Transform.scale(scale: scale, child: child)
        : AnimatedScale(
            scale: scale,
            duration: AppMotion.resolve(context, AppMotion.press),
            curve: AppMotion.standard,
            child: child,
          );
  }
}
