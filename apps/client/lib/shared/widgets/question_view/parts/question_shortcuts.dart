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

  bool _hasChoice(int index) => index < labels.length;

  /// True while the primary focus is inside a text field. The actions are
  /// disabled then, so the key bubbles to the default text-editing shortcuts
  /// (typing, caret movement) instead of being swallowed here.
  static bool _isTyping() {
    final context = FocusManager.instance.primaryFocus?.context;
    if (context == null) return false;
    return context.widget is EditableText ||
        context.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: _bindings,
      child: Actions(
        actions: <Type, Action<Intent>>{
          _SelectChoiceIntent: _GatedAction<_SelectChoiceIntent>(
            enabled: (i) =>
                !_isTyping() &&
                onSelect != null &&
                choicesInteractive &&
                _hasChoice(i.index),
            run: (i) => onSelect!(labels[i.index]),
          ),
          _EliminateChoiceIntent: _GatedAction<_EliminateChoiceIntent>(
            enabled: (i) =>
                !_isTyping() &&
                onEliminate != null &&
                choicesInteractive &&
                _hasChoice(i.index),
            run: (i) => onEliminate!(labels[i.index]),
          ),
          _MarkIntent: _GatedAction<_MarkIntent>(
            enabled: (_) => !_isTyping() && onMark != null,
            run: (_) => onMark!(),
          ),
          _PrevIntent: _GatedAction<_PrevIntent>(
            enabled: (_) => !_isTyping() && onPrev != null,
            run: (_) => onPrev!(),
          ),
          _NextIntent: _GatedAction<_NextIntent>(
            enabled: (_) => !_isTyping() && onNext != null,
            run: (_) => onNext!(),
          ),
        },
        child: Focus(autofocus: true, child: child),
      ),
    );
  }
}
