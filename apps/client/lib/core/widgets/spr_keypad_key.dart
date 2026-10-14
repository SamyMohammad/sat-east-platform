part of 'spr_keypad.dart';

class _KeypadKey extends StatefulWidget {
  const _KeypadKey({
    required this.semanticsLabel,
    required this.onTap,
    this.label,
    this.icon,
    this.operator = false,
  });

  final String semanticsLabel;
  final VoidCallback onTap;
  final String? label;
  final IconData? icon;
  final bool operator;

  @override
  State<_KeypadKey> createState() => _KeypadKeyState();
}

class _KeypadKeyState extends State<_KeypadKey> {
  bool _pressed = false;
  bool _focused = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final foreground = _pressed ? scheme.primary : scheme.onSurface;
    final icon = widget.icon;
    final background = _pressed
        ? scheme.primaryContainer
        : widget.operator
        ? scheme.surfaceContainer
        : scheme.surface;

    return Semantics(
      button: true,
      label: widget.semanticsLabel,
      excludeSemantics: true,
      onTap: widget.onTap,
      child: FocusableActionDetector(
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onTap();
              return null;
            },
          ),
        },
        onShowFocusHighlight: (focused) {
          if (_focused != focused) setState(() => _focused = focused);
        },
        child: FocusRing(
          visible: _focused,
          borderRadius: BookletRadius.sm,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (_) => _setPressed(true),
            onTapUp: (_) => _setPressed(false),
            onTapCancel: () => _setPressed(false),
            onTap: widget.onTap,
            child: Container(
              height: BookletSize.largeControl,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: background,
                border: Border.all(
                  color: _pressed ? scheme.primary : scheme.outlineVariant,
                ),
                borderRadius: const BorderRadius.all(
                  Radius.circular(BookletRadius.sm),
                ),
              ),
              child: icon != null
                  ? Icon(icon, color: foreground)
                  : Text(
                      widget.label!,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: foreground,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
