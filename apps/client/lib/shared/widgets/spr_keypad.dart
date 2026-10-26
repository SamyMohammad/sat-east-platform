import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:sat_east_client/core/grading/spr_editing.dart';
import 'package:sat_east_client/core/theme/app_icons.dart';
import 'package:sat_east_client/core/theme/booklet_tokens.dart';
import 'package:sat_east_client/shared/widgets/focus_ring.dart';

part 'spr_keypad_key.dart';

/// Docked SPR keypad for phones (Components.dc.html §3.1). Emits keys only;
/// the parent applies them with `applySprKey`.
class SprKeypad extends StatelessWidget {
  const SprKeypad({required this.onKey, required this.onHide, super.key});

  final ValueChanged<SprKey> onKey;
  final VoidCallback onHide;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Widget digit(int n) => _KeypadKey(
      label: '$n',
      semanticsLabel: '$n',
      onTap: () => onKey(SprKey.digit(n)),
    );

    Widget row(List<(Widget, int)> keys) => LayoutBuilder(
      builder: (context, constraints) {
        final column = (constraints.maxWidth - 3 * BookletSpace.s2) / 4;
        return Row(
          spacing: BookletSpace.s2,
          children: [
            for (final (key, span) in keys)
              SizedBox(
                width: column * span + BookletSpace.s2 * (span - 1),
                child: key,
              ),
          ],
        );
      },
    );

    return Directionality(
      textDirection: TextDirection.ltr,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainer,
          border: Border(top: BorderSide(color: scheme.outlineVariant)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              BookletSpace.s2,
              BookletSpace.s2,
              BookletSpace.s2,
              BookletSpace.s4,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: BookletSpace.s2,
              children: [
                row([
                  (digit(1), 1),
                  (digit(2), 1),
                  (digit(3), 1),
                  (
                    _KeypadKey(
                      icon: AppIcons.backspace,
                      semanticsLabel: 'Delete',
                      operator: true,
                      onTap: () => onKey(SprKey.backspace),
                    ),
                    1,
                  ),
                ]),
                row([
                  (digit(4), 1),
                  (digit(5), 1),
                  (digit(6), 1),
                  (
                    _KeypadKey(
                      label: '/',
                      semanticsLabel: 'Fraction bar',
                      operator: true,
                      onTap: () => onKey(SprKey.slash),
                    ),
                    1,
                  ),
                ]),
                row([
                  (digit(7), 1),
                  (digit(8), 1),
                  (digit(9), 1),
                  (
                    _KeypadKey(
                      label: '−',
                      semanticsLabel: 'Minus sign',
                      operator: true,
                      onTap: () => onKey(SprKey.minus),
                    ),
                    1,
                  ),
                ]),
                row([
                  (
                    _KeypadKey(
                      label: '.',
                      semanticsLabel: 'Decimal point',
                      operator: true,
                      onTap: () => onKey(SprKey.dot),
                    ),
                    1,
                  ),
                  (digit(0), 2),
                  (
                    _KeypadKey(
                      icon: AppIcons.hideKeyboard,
                      semanticsLabel: 'Hide keypad',
                      operator: true,
                      onTap: onHide,
                    ),
                    1,
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
