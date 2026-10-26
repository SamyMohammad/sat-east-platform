import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

class PrototypeSwitcher extends StatefulWidget {
  const PrototypeSwitcher({required this.variant, super.key});

  final String variant;

  @override
  State<PrototypeSwitcher> createState() => _PrototypeSwitcherState();
}

class _PrototypeSwitcherState extends State<PrototypeSwitcher> {
  static const _variants = ['A', 'B', 'C'];

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  bool _onKey(KeyEvent event) {
    final focus = FocusManager.instance.primaryFocus?.context;
    if (focus != null &&
        (focus.widget is EditableText ||
            focus.findAncestorWidgetOfExactType<EditableText>() != null)) {
      return false;
    }
    if (event is! KeyDownEvent) return false;
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _cycle(-1);
      return true;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _cycle(1);
      return true;
    }
    return false;
  }

  void _cycle(int delta) {
    final uri = GoRouterState.of(context).uri;
    context.go(
      uri
          .replace(
            queryParameters: {
              ...uri.queryParameters,
              'variant':
                  _variants[(_variants.indexOf(widget.variant) + delta) % 3],
            },
          )
          .toString(),
    );
  }

  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xFF18181B),
    borderRadius: BorderRadius.circular(40),
    elevation: 8,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Previous design (Left arrow)',
          color: Colors.white,
          onPressed: () => _cycle(-1),
          icon: const Icon(Icons.chevron_left),
        ),
        Flexible(
          child: Text(
            switch (widget.variant) {
              'B' => 'B — shadcn-like',
              'C' => 'C — Digital exam',
              _ => 'A — Material 3',
            },
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.none,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Next design (Right arrow)',
          color: Colors.white,
          onPressed: () => _cycle(1),
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    ),
  );
}
