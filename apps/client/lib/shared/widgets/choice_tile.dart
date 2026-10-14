import 'package:flutter/material.dart';
import 'package:sat_east_client/core/math_render/math_text.dart';
import 'package:sat_east_client/core/theme/booklet_colors.dart';
import 'package:sat_east_client/core/theme/booklet_tokens.dart';
import 'package:sat_east_client/shared/widgets/feedback_label.dart';
import 'package:sat_east_client/shared/widgets/focus_ring.dart';
import 'package:sat_east_client/shared/widgets/painters/dashed_border.dart';
import 'package:sat_east_client/shared/widgets/painters/strike_through.dart';

/// What a choice tile shows. Feedback states come from the server result
/// (rule 1); the tile never decides correctness.
enum ChoiceTileState {
  idle,
  selected,
  eliminated,
  disabled,

  /// Practice: picked and right.
  correct,

  /// Practice: picked and wrong.
  incorrect,

  /// Review: picked and wrong.
  yourAnswerWrong,

  /// Review: the key, not picked.
  correctAnswer,

  /// Review: picked and right.
  yourAnswerCorrect,

  /// Review: neither picked nor the key.
  reviewOther,
}

/// One MCQ choice (Components.dc.html §2). Whole tile is the target;
/// cross-out is a separate 48 px target.
class ChoiceTile extends StatefulWidget {
  const ChoiceTile({
    required this.letter,
    required this.content,
    required this.state,
    super.key,
    this.onSelect,
    this.onEliminate,
    this.onRestore,
  });

  final String letter;

  /// `MathText` markup.
  final String content;
  final ChoiceTileState state;
  final VoidCallback? onSelect;
  final VoidCallback? onEliminate;
  final VoidCallback? onRestore;

  @override
  State<ChoiceTile> createState() => _ChoiceTileState();
}

class _ChoiceTileState extends State<ChoiceTile> {
  bool _hovered = false;
  bool _focused = false;

  bool get _interactive =>
      widget.onSelect != null &&
      (widget.state == ChoiceTileState.idle ||
          widget.state == ChoiceTileState.selected);

  bool get _chosen => switch (widget.state) {
    ChoiceTileState.selected ||
    ChoiceTileState.correct ||
    ChoiceTileState.incorrect ||
    ChoiceTileState.yourAnswerWrong ||
    ChoiceTileState.yourAnswerCorrect => true,
    ChoiceTileState.idle ||
    ChoiceTileState.eliminated ||
    ChoiceTileState.disabled ||
    ChoiceTileState.correctAnswer ||
    ChoiceTileState.reviewOther => false,
  };

  @override
  Widget build(BuildContext context) {
    final look = _ChoiceLook.of(
      context,
      widget.state,
      hovered: _hovered && _interactive,
    );
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    const radius = BorderRadius.all(Radius.circular(BookletRadius.sm));
    final eliminated = widget.state == ChoiceTileState.eliminated;
    final trailing = _trailing(look);
    final trailingIsButton = trailing != null && look.status == null;

    final body = StrikeThrough(
      struck: eliminated,
      color: scheme.onSurfaceVariant,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: BookletSpace.s3,
        children: [
          Padding(
            padding: const EdgeInsets.only(
              top: (BookletSize.touchTarget - BookletSize.choiceBadge) / 2,
            ),
            child: _Badge(letter: widget.letter, look: look),
          ),
          Expanded(
            child: Opacity(
              opacity: eliminated ? BookletOpacity.eliminated : 1,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: BookletSpace.s3),
                child: MathText(
                  widget.content,
                  style: textTheme.bodyMedium?.copyWith(color: look.text),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    Widget tile = Container(
      constraints: const BoxConstraints(minHeight: BookletSize.largeControl),
      padding: EdgeInsetsDirectional.only(
        start: BookletSpace.s3 + BookletStroke.thin,
        top: BookletSpace.s1 + BookletStroke.thin,
        bottom: BookletSpace.s1 + BookletStroke.thin,
        end: trailingIsButton
            ? BookletStroke.thin
            : BookletSpace.s3 + BookletStroke.thin,
      ),
      decoration: BoxDecoration(color: look.background, borderRadius: radius),
      foregroundDecoration: look.dashed
          ? null
          : BoxDecoration(
              borderRadius: radius,
              border: Border.all(color: look.border, width: look.borderWidth),
            ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final fontSize = textTheme.bodyMedium!.fontSize!;
          final enlarged =
              MediaQuery.textScalerOf(context).scale(fontSize) > fontSize;
          if (trailing != null &&
              enlarged &&
              constraints.maxWidth < BookletSize.readingColumn) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                body,
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: trailing,
                ),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: BookletSpace.s3,
            children: [
              Expanded(child: body),
              ?trailing,
            ],
          );
        },
      ),
    );
    if (look.dashed) {
      tile = CustomPaint(
        foregroundPainter: DashedBorderPainter(
          color: look.border,
          radius: BookletRadius.sm,
        ),
        child: tile,
      );
    }

    return Semantics(
      container: true,
      inMutuallyExclusiveGroup: true,
      checked: _chosen,
      enabled: _interactive,
      label: 'Choice ${widget.letter}',
      child: FocusableActionDetector(
        enabled: _interactive,
        mouseCursor: _interactive
            ? SystemMouseCursors.click
            : MouseCursor.defer,
        onShowHoverHighlight: (v) => setState(() => _hovered = v),
        onShowFocusHighlight: (v) => setState(() => _focused = v),
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onSelect?.call();
              return null;
            },
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _interactive ? widget.onSelect : null,
          child: FocusRing(
            visible: _focused && _interactive,
            borderRadius: BookletRadius.sm,
            child: tile,
          ),
        ),
      ),
    );
  }

  Widget? _trailing(_ChoiceLook look) {
    final status = look.status;
    if (status != null) {
      return ConstrainedBox(
        constraints: const BoxConstraints(minHeight: BookletSize.touchTarget),
        child: Align(
          widthFactor: 1,
          child: FeedbackLabel(
            icon: status.icon,
            label: status.label,
            color: status.color,
          ),
        ),
      );
    }
    if (widget.state == ChoiceTileState.eliminated &&
        widget.onRestore != null) {
      return TextButton.icon(
        onPressed: widget.onRestore,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: BookletSpace.s3),
        ),
        icon: const Icon(Icons.undo_rounded, size: BookletSize.iconSmall),
        label: Text(
          'Undo',
          semanticsLabel: 'Restore choice ${widget.letter}',
        ),
      );
    }
    if (_interactive && widget.onEliminate != null) {
      return IconButton(
        onPressed: widget.onEliminate,
        tooltip: 'Cross out choice ${widget.letter}',
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        icon: const Icon(
          Icons.strikethrough_s_rounded,
          size: BookletSize.iconSmall,
        ),
      );
    }
    return null;
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.letter, required this.look});

  final String letter;
  final _ChoiceLook look;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(
        minWidth: BookletSize.choiceBadge,
        minHeight: BookletSize.choiceBadge,
      ),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: look.badgeFill,
        border: Border.all(
          color: look.badgeBorder,
          width: look.badgeBorderWidth,
        ),
        borderRadius: const BorderRadius.all(
          Radius.circular(BookletRadius.xs),
        ),
      ),
      child: Text(
        letter,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: look.badgeText,
          fontWeight: look.badgeWeight,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

typedef _Status = ({IconData icon, String label, Color color});

final class _ChoiceLook {
  const _ChoiceLook({
    required this.background,
    required this.border,
    required this.borderWidth,
    required this.badgeBorder,
    required this.badgeBorderWidth,
    required this.badgeText,
    required this.text,
    this.badgeFill,
    this.badgeWeight = FontWeight.w600,
    this.dashed = false,
    this.status,
  });

  /// 1 px rule, outlined badge.
  factory _ChoiceLook.plain({
    required Color background,
    required Color border,
    required Color badgeBorder,
    required Color text,
    bool dashed = false,
  }) => _ChoiceLook(
    background: background,
    border: border,
    borderWidth: BookletStroke.thin,
    badgeBorder: badgeBorder,
    badgeBorderWidth: BookletStroke.badge,
    badgeText: text,
    text: text,
    dashed: dashed,
  );

  /// 2 px accent edge, solid accent badge.
  factory _ChoiceLook.filled({
    required Color accent,
    required Color container,
    required Color onAccent,
    required Color text,
    _Status? status,
  }) => _ChoiceLook(
    background: container,
    border: accent,
    borderWidth: BookletStroke.strong,
    badgeFill: accent,
    badgeBorder: accent,
    badgeBorderWidth: BookletStroke.badge,
    badgeText: onAccent,
    text: text,
    status: status,
  );

  factory _ChoiceLook.of(
    BuildContext context,
    ChoiceTileState state, {
    required bool hovered,
  }) {
    final s = Theme.of(context).colorScheme;
    final b = context.booklet;
    return switch (state) {
      ChoiceTileState.idle => _ChoiceLook.plain(
        background: hovered ? s.surfaceContainer : s.surface,
        border: hovered ? b.inkDisabled : s.outlineVariant,
        badgeBorder: s.outline,
        text: s.onSurface,
      ),
      ChoiceTileState.selected => _ChoiceLook.filled(
        accent: s.primary,
        container: s.primaryContainer,
        onAccent: s.onPrimary,
        text: s.onSurface,
      ),
      ChoiceTileState.eliminated => _ChoiceLook.plain(
        background: s.surface,
        border: s.outlineVariant,
        badgeBorder: b.inkDisabled,
        text: b.inkDisabled,
        dashed: true,
      ),
      ChoiceTileState.disabled => _ChoiceLook.plain(
        background: s.surface,
        border: s.outlineVariant,
        badgeBorder: b.inkDisabled,
        text: b.inkDisabled,
      ),
      ChoiceTileState.reviewOther => _ChoiceLook.plain(
        background: s.surface,
        border: s.outlineVariant,
        badgeBorder: b.inkDisabled,
        text: s.onSurfaceVariant,
      ),
      ChoiceTileState.correct => _ChoiceLook.filled(
        accent: b.greenTick,
        container: b.greenTickContainer,
        onAccent: s.surface,
        text: s.onSurface,
        status: (
          icon: Icons.check_circle_rounded,
          label: 'Correct',
          color: b.greenTick,
        ),
      ),
      ChoiceTileState.yourAnswerCorrect => _ChoiceLook.filled(
        accent: b.greenTick,
        container: b.greenTickContainer,
        onAccent: s.surface,
        text: s.onSurface,
        status: (
          icon: Icons.check_circle_rounded,
          label: 'Your answer · Correct',
          color: b.greenTick,
        ),
      ),
      ChoiceTileState.incorrect => _ChoiceLook.filled(
        accent: s.error,
        container: s.errorContainer,
        onAccent: s.surface,
        text: s.onSurface,
        status: (
          icon: Icons.cancel_rounded,
          label: 'Incorrect',
          color: s.error,
        ),
      ),
      ChoiceTileState.yourAnswerWrong => _ChoiceLook.filled(
        accent: s.error,
        container: s.errorContainer,
        onAccent: s.surface,
        text: s.onSurface,
        status: (
          icon: Icons.cancel_rounded,
          label: 'Your answer',
          color: s.error,
        ),
      ),
      ChoiceTileState.correctAnswer => _ChoiceLook(
        background: s.surface,
        border: b.greenTick,
        borderWidth: BookletStroke.strong,
        badgeBorder: b.greenTick,
        badgeBorderWidth: BookletStroke.strong,
        badgeText: b.greenTick,
        badgeWeight: FontWeight.w700,
        text: s.onSurface,
        status: (
          icon: Icons.check_circle_outline_rounded,
          label: 'Correct answer',
          color: b.greenTick,
        ),
      ),
    };
  }

  final Color background;
  final Color border;
  final double borderWidth;
  final Color? badgeFill;
  final Color badgeBorder;
  final double badgeBorderWidth;
  final Color badgeText;
  final FontWeight badgeWeight;
  final Color text;
  final bool dashed;
  final _Status? status;
}
