part of 'spr_input.dart';

class _Preview extends StatelessWidget {
  const _Preview({required this.tex});

  final String tex;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final labelSize = text.bodySmall!.fontSize!;
    final scale = MediaQuery.textScalerOf(context).scale(labelSize) / labelSize;
    return SizedBox(
      width: BookletSize.sprPreviewWidth * scale,
      child: Container(
        padding: const EdgeInsetsDirectional.only(start: BookletSpace.s4),
        decoration: BoxDecoration(
          border: BorderDirectional(
            start: BorderSide(color: scheme.outlineVariant),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Answer preview',
              style: text.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: scheme.onSurfaceVariant,
              ),
            ),
            MathText(
              '\\($tex\\)',
              style: text.titleLarge?.copyWith(fontWeight: FontWeight.w400),
            ),
          ],
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      liveRegion: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: BookletSpace.s1,
        children: [
          Icon(
            AppIcons.info,
            size: BookletSize.iconStatus,
            color: context.booklet.info,
          ),
          Flexible(
            child: MathText(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewBox extends StatelessWidget {
  const _ReviewBox({
    required this.value,
    required this.correct,
    required this.style,
  });

  final String value;
  final bool correct;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final booklet = context.booklet;
    final accent = correct ? booklet.greenTick : scheme.error;
    const radius = BorderRadius.all(Radius.circular(BookletRadius.sm));
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: BookletSpace.s4,
        vertical: BookletSpace.s2,
      ),
      decoration: BoxDecoration(
        color: correct ? booklet.greenTickContainer : scheme.errorContainer,
        borderRadius: radius,
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: accent, width: BookletStroke.strong),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: BookletSpace.s2,
        runSpacing: BookletSpace.s1,
        children: [
          Text(
            value,
            style: style,
          ),
          FeedbackLabel(
            icon: correct ? AppIcons.correct : AppIcons.incorrect,
            label: correct ? 'Correct' : 'Incorrect',
            color: accent,
          ),
        ],
      ),
    );
  }
}

class _CorrectAnswer extends StatelessWidget {
  const _CorrectAnswer({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(
      context,
    ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w400);
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: BookletSpace.s1,
      children: [
        Icon(
          AppIcons.correct,
          size: BookletSize.iconStatus,
          color: context.booklet.greenTick,
        ),
        Flexible(
          child: Text.rich(
            TextSpan(
              text: 'Correct answer: ',
              children: [
                TextSpan(
                  text: value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            style: style,
          ),
        ),
      ],
    );
  }
}
