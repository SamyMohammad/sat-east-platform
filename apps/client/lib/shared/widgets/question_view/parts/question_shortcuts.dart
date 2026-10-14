import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

final class _SelectChoiceIntent extends Intent {
  const _SelectChoiceIntent(this.index);
  final int index;
}

final class _EliminateChoiceIntent extends Intent {
  const _EliminateChoiceIntent(this.index);
  final int index;
}

final class _MarkIntent extends Intent {
  const _MarkIntent();
}

final class _PrevIntent extends Intent {
  const _PrevIntent();
}

final class _NextIntent extends Intent {
  const _NextIntent();
}

/// An [Action] that is enabled only when [enabled] says so, so a disabled
/// shortcut lets the key event keep bubbling.
final class _GatedAction<T extends Intent> extends Action<T> {
  _GatedAction({required this.enabled, required this.run});

  final bool Function(T intent) enabled;
  final void Function(T intent) run;

  @override
  bool isEnabled(T intent) => enabled(intent);

  @override
  Object? invoke(T intent) {
    run(intent);
    return null;
  }
}

/// Keyboard shortcuts for `QuestionView`: A-D select, Shift+A-D cross out,
/// M marks, left / right arrows go back / forward. Owns an autofocus node so
/// keys work without clicking into the view. Each callback arrives already
/// gated by the caller; a null callback disables its key.
class QuestionShortcuts extends StatelessWidget {
  const QuestionShortcuts({
    required this.child,
    required this.labels,
    required this.choicesInteractive,
    super.key,
    this.onSelect,
    this.onEliminate,
    this.onMark,
    this.onPrev,
    this.onNext,
  });

  final Widget child;
  final List<String> labels;
  final bool choicesInteractive;
  final ValueChanged<String>? onSelect;
  final ValueChanged<String>? onEliminate;
  final VoidCallback? onMark;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  /// Letter keys bound to choices A-D, in order.
  static const List<LogicalKeyboardKey> _choiceKeys = [
    LogicalKeyboardKey.keyA,
    LogicalKeyboardKey.keyB,
    LogicalKeyboardKey.keyC,
    LogicalKeyboardKey.keyD,
  ];

  static final Map<ShortcutActivator, Intent> _bindings = {
    for (var i = 0; i < _choiceKeys.length; i++) ...{
      SingleActivator(_choiceKeys[i]): _SelectChoiceIntent(i),
      SingleActivator(_choiceKeys[i], shift: true): _EliminateChoiceIntent(i),
    },
    const SingleActivator(LogicalKeyboardKey.keyM): const _MarkIntent(),
    const SingleActivator(LogicalKeyboardKey.arrowLeft): const _PrevIntent(),
    const SingleActivator(LogicalKeyboardKey.arrowRight): const _NextIntent(),
  };

  /// Shortcuts for an editable field: every key bound above maps to a no-op
  /// that stops propagation, so typed letters, arrows and M never reach the
  /// bindings of an ancestor [QuestionShortcuts].
  static final Map<ShortcutActivator, Intent> typingBlockers = {
    for (final activator in _bindings.keys)
      activator: const DoNothingAndStopPropagationTextIntent(),
  };

  bool _hasChoice(int index) => index < labels.length;

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: _bindings,
      child: Actions(
        actions: <Type, Action<Intent>>{
          _SelectChoiceIntent: _GatedAction<_SelectChoiceIntent>(
            enabled: (i) =>
                onSelect != null && choicesInteractive && _hasChoice(i.index),
            run: (i) => onSelect!(labels[i.index]),
          ),
          _EliminateChoiceIntent: _GatedAction<_EliminateChoiceIntent>(
            enabled: (i) =>
                onEliminate != null &&
                choicesInteractive &&
                _hasChoice(i.index),
            run: (i) => onEliminate!(labels[i.index]),
          ),
          _MarkIntent: _GatedAction<_MarkIntent>(
            enabled: (_) => onMark != null,
            run: (_) => onMark!(),
          ),
          _PrevIntent: _GatedAction<_PrevIntent>(
            enabled: (_) => onPrev != null,
            run: (_) => onPrev!(),
          ),
          _NextIntent: _GatedAction<_NextIntent>(
            enabled: (_) => onNext != null,
            run: (_) => onNext!(),
          ),
        },
        child: Focus(autofocus: true, child: child),
      ),
    );
  }
}
