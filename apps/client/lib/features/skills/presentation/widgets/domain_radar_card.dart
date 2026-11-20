import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:sat_east_client/core/theme/app_colors.dart';
import 'package:sat_east_client/core/theme/app_icons.dart';
import 'package:sat_east_client/core/theme/app_motion.dart';
import 'package:sat_east_client/core/theme/app_tokens.dart';
import 'package:sat_east_client/features/skills/domain/entities/skills_overview.dart';
import 'package:sat_east_client/features/skills/presentation/skills_copy.dart';
import 'package:sat_east_client/features/skills/presentation/skills_layout.dart';
import 'package:sat_east_client/features/skills/presentation/widgets/chart_dash.dart';
import 'package:sat_east_client/features/skills/presentation/widgets/domain_bars.dart';
import 'package:sat_east_client/features/skills/presentation/widgets/mastery_band_chip.dart';

/// Hero of the Skills screen: mastery of every SAT domain at a glance.
/// Three or more domains draw a radar; fewer fall back to [DomainBars];
/// none hides the card. The number and the band word always appear in text
/// (axis labels, or a legend on narrow screens), so colour never stands alone.
class DomainRadarCard extends StatelessWidget {
  const DomainRadarCard({
    required this.domains,
    required this.strongAt,
    required this.onSelectDomain,
    required this.onFocusDomain,
    super.key,
  });

  final List<DomainMastery> domains;

  /// Mastery at which a domain counts as strong; no ring when null.
  final int? strongAt;

  /// Called with the domain name when an axis label, legend row or bar is
  /// tapped.
  final ValueChanged<String> onSelectDomain;

  /// Called with the domain name when "Focus next" is tapped.
  final ValueChanged<String> onFocusDomain;

  /// Fewest domains that still make a meaningful polygon.
  static const int minRadarDomains = 3;

  @override
  Widget build(BuildContext context) {
    if (domains.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final strongest = domains.strongest;
    final weakest = domains.weakest;
    final unstarted = domains.nextToStart;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpace.s3,
          children: [
            Semantics(
              header: true,
              child: Text(
                SkillsCopy.radarTitle,
                style: theme.textTheme.titleMedium,
              ),
            ),
            if (domains.length < minRadarDomains)
              DomainBars(domains: domains, onSelectDomain: onSelectDomain)
            else
              _Radar(
                domains: domains,
                strongAt: strongAt,
                onSelectDomain: onSelectDomain,
              ),
            if (strongest != null)
              Wrap(
                spacing: AppSpace.s2,
                runSpacing: AppSpace.s2,
                children: [
                  _ActionPill(
                    key: const ValueKey('radar-chip-strongest'),
                    icon: AppIcons.moveUp,
                    label: SkillsCopy.strongest(strongest.domain),
                    onTap: () => onSelectDomain(strongest.domain),
                  ),
                  if (weakest != null)
                    _ActionPill(
                      key: const ValueKey('radar-chip-focus'),
                      icon: AppIcons.moveDown,
                      label: SkillsCopy.focusNext(weakest.domain),
                      onTap: () => onFocusDomain(weakest.domain),
                    )
                  else if (unstarted != null)
                    _ActionPill(
                      key: const ValueKey('radar-chip-focus'),
                      icon: AppIcons.play,
                      label: SkillsCopy.startNext(unstarted.domain),
                      onTap: () => onSelectDomain(unstarted.domain),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Icon-plus-word pill that wraps its label instead of overflowing at large
/// text sizes (a Material chip would not).
class _ActionPill extends StatelessWidget {
  const _ActionPill({
    required this.icon,
    required this.label,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Semantics(
      button: true,
      excludeSemantics: true,
      label: label,
      onTap: onTap,
      child: Material(
        color: colors.raised,
        shape: StadiumBorder(side: BorderSide(color: colors.line)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AppSize.touchTarget),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.s4,
                vertical: AppSpace.s2,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: AppSpace.s2,
                children: [
                  Icon(icon, size: AppSize.iconSmall, color: colors.ink),
                  Flexible(
                    child: Text(
                      label,
                      style: Theme.of(
                        context,
                      ).textTheme.labelLarge?.copyWith(color: colors.ink),
                      textDirection: TextDirection.ltr,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Raw geometry of the radar, in logical pixels.
abstract final class _RadarGeometry {
  /// Gap between the outer ring and a wide-layout axis label.
  static const double gap = 6;

  /// Largest ring radius in the wide layout.
  static const double maxRadius = 120;

  /// Largest ring radius in the narrow (legend) layout.
  static const double maxRadiusNarrow = 140;

  /// Smallest ring radius, whatever the width.
  static const double minRadius = 36;

  /// Room around the narrow radar for the number beside each dot.
  static const double valueMargin = 28;

  /// Gap between a vertex dot and its number.
  static const double valueGap = 2;

  /// Widest wide-layout axis label before it wraps.
  static const double labelWidth = 128;

  /// Rings, as fractions of the outer radius (25/50/75/100).
  static const List<double> rings = [.25, .5, .75, 1];

  /// Radius of a vertex dot.
  static const double dot = 4.5;
}

class _Radar extends StatefulWidget {
  const _Radar({
    required this.domains,
    required this.strongAt,
    required this.onSelectDomain,
  });

  final List<DomainMastery> domains;
  final int? strongAt;
  final ValueChanged<String> onSelectDomain;

  @override
  State<_Radar> createState() => _RadarState();
}

class _RadarState extends State<_Radar> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _progress;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: AppMotion.enter);
    _progress = _controller.drive(CurveTween(curve: AppMotion.emphasized));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final duration = AppMotion.resolve(context, AppMotion.enter);
    if (duration == Duration.zero) {
      _controller.value = 1;
    } else if (!_controller.isAnimating && _controller.value == 0) {
      _controller.duration = duration;
      unawaited(_controller.forward());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final domains = widget.domains;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return width < SkillsLayout.narrowWidth
            ? _buildNarrow(context, width, domains)
            : _buildWide(context, width, domains);
      },
    );
  }

  Widget _plot(
    BuildContext context, {
    required double radius,
    required bool withValues,
  }) {
    final colors = context.appColors;
    final domains = widget.domains;
    final valueStyle = Theme.of(
      context,
    ).textTheme.labelMedium?.copyWith(color: colors.ink);
    return Semantics(
      container: true,
      image: true,
      label: SkillsCopy.radarSemantics(domains),
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _progress,
          builder: (context, _) => CustomPaint(
            painter: _RadarPainter(
              domains: domains,
              strongAt: widget.strongAt,
              radius: radius,
              progress: _progress.value,
              ringColor: colors.line,
              targetColor: colors.inkSecondary,
              fillColor: colors.brandWash,
              strokeColor: colors.brandLine,
              surface: colors.raised,
              dotColors: [for (final d in domains) d.band.color(colors)],
              valueStyle: withValues ? valueStyle : null,
              textScaler: MediaQuery.textScalerOf(context),
            ),
          ),
        ),
      ),
    );
  }

  /// Full-width radar with the number beside each dot, then a legend: one
  /// tappable row per domain with its full name, number and band word.
  Widget _buildNarrow(
    BuildContext context,
    double width,
    List<DomainMastery> domains,
  ) {
    final colors = context.appColors;
    final radius = math.max(
      _RadarGeometry.minRadius,
      math.min(
        width / 2 - _RadarGeometry.valueMargin,
        _RadarGeometry.maxRadiusNarrow,
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpace.s2,
      children: [
        SizedBox(
          key: const ValueKey('radar-plot'),
          width: width,
          height: 2 * (radius + _RadarGeometry.valueMargin),
          child: _plot(context, radius: radius, withValues: true),
        ),
        for (final d in domains)
          _LegendRow(
            key: ValueKey('radar-legend-${d.domain}'),
            domain: d,
            dotColor: d.band.color(colors),
            onTap: () => widget.onSelectDomain(d.domain),
          ),
      ],
    );
  }

  /// Radar with a label (name, number, band word) beside each axis end.
  Widget _buildWide(
    BuildContext context,
    double width,
    List<DomainMastery> domains,
  ) {
    final textScaler = MediaQuery.textScalerOf(context);
    final radius = math.max(
      _RadarGeometry.minRadius,
      math.min(
        width / 2 - _RadarGeometry.labelWidth - _RadarGeometry.gap,
        _RadarGeometry.maxRadius,
      ),
    );
    // Room above and below the ring for a label of up to three lines.
    final band = math.max(AppSize.touchTarget, textScaler.scale(16) * 3);
    return SizedBox(
      key: const ValueKey('radar-plot'),
      height: 2 * (radius + _RadarGeometry.gap + band),
      child: CustomMultiChildLayout(
        delegate: _RadarLayout(
          count: domains.length,
          radius: radius,
          labelWidth: _RadarGeometry.labelWidth,
          gap: _RadarGeometry.gap,
        ),
        children: [
          LayoutId(
            id: _RadarLayout.plot,
            child: _plot(context, radius: radius, withValues: false),
          ),
          for (final (i, d) in domains.indexed)
            LayoutId(
              id: i,
              child: _AxisLabel(
                domain: d,
                align: _alignFor(i, domains.length),
                onTap: () => widget.onSelectDomain(d.domain),
              ),
            ),
        ],
      ),
    );
  }

  TextAlign _alignFor(int i, int n) {
    final c = math.cos(_RadarLayout.angle(i, n));
    return c > _RadarLayout.sideCos
        ? TextAlign.left
        : c < -_RadarLayout.sideCos
        ? TextAlign.right
        : TextAlign.center;
  }
}

/// Legend row: band dot, full domain name (wraps), then number and band word
/// at the end. Never truncates either part.
class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.domain,
    required this.dotColor,
    required this.onTap,
    super.key,
  });

  final DomainMastery domain;
  final Color dotColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    // At large text sizes name and value no longer fit side by side.
    final stacked = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    final name = Text(
      domain.domain,
      style: theme.textTheme.labelLarge?.copyWith(color: colors.ink),
      textDirection: TextDirection.ltr,
    );
    final value = Text(
      SkillsCopy.domainValue(domain),
      textAlign: TextAlign.end,
      style: theme.textTheme.labelLarge?.copyWith(color: colors.inkSecondary),
      textDirection: TextDirection.ltr,
    );
    return Semantics(
      button: true,
      excludeSemantics: true,
      label: SkillsCopy.domainLabel(domain),
      onTap: onTap,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.control),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSize.touchTarget),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.s1,
              vertical: AppSpace.s1,
            ),
            child: Row(
              spacing: AppSpace.s2,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: domain.mean == null ? colors.raised : dotColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: dotColor, width: AppStroke.badge),
                  ),
                  child: const SizedBox.square(dimension: AppSpace.s3),
                ),
                Expanded(
                  child: stacked
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [name, value],
                        )
                      : Row(
                          spacing: AppSpace.s2,
                          children: [
                            Expanded(child: name),
                            value,
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AxisLabel extends StatelessWidget {
  const _AxisLabel({
    required this.domain,
    required this.align,
    required this.onTap,
  });

  final DomainMastery domain;
  final TextAlign align;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final label = SkillsCopy.domainLabel(domain);
    return Semantics(
      button: true,
      excludeSemantics: true,
      label: label,
      onTap: onTap,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.control),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSize.touchTarget),
          child: Center(
            widthFactor: 1,
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.s1),
              child: Text(
                label,
                textAlign: align,
                textDirection: TextDirection.ltr,
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(color: colors.ink),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Places the plot over the whole box and each axis label just outside its
/// axis end: beside it on the left/right, above or below it at the poles.
class _RadarLayout extends MultiChildLayoutDelegate {
  _RadarLayout({
    required this.count,
    required this.radius,
    required this.labelWidth,
    required this.gap,
  });

  static const String plot = 'plot';

  /// |cos| above this puts the label beside the axis end, not above/below.
  static const double sideCos = 0.3;

  final int count;
  final double radius;
  final double labelWidth;
  final double gap;

  /// Axis angle, first axis at the top, clockwise.
  static double angle(int i, int n) => -math.pi / 2 + 2 * math.pi * i / n;

  @override
  void performLayout(Size size) {
    layoutChild(plot, BoxConstraints.tight(size));
    positionChild(plot, Offset.zero);
    final centre = size.center(Offset.zero);
    for (var i = 0; i < count; i++) {
      final s = layoutChild(i, BoxConstraints(maxWidth: labelWidth));
      final a = angle(i, count);
      final c = math.cos(a);
      final sn = math.sin(a);
      final anchor = centre + Offset(c, sn) * (radius + gap);
      final dx = c > sideCos
          ? anchor.dx
          : c < -sideCos
          ? anchor.dx - s.width
          : anchor.dx - s.width / 2;
      final dy = c.abs() > sideCos
          ? anchor.dy - s.height / 2 + sn * s.height / 2
          : (sn < 0 ? anchor.dy - s.height : anchor.dy);
      positionChild(i, Offset(dx, dy));
    }
  }

  @override
  bool shouldRelayout(_RadarLayout old) =>
      old.count != count ||
      old.radius != radius ||
      old.labelWidth != labelWidth ||
      old.gap != gap;
}

class _RadarPainter extends CustomPainter {
  const _RadarPainter({
    required this.domains,
    required this.strongAt,
    required this.radius,
    required this.progress,
    required this.ringColor,
    required this.targetColor,
    required this.fillColor,
    required this.strokeColor,
    required this.surface,
    required this.dotColors,
    required this.valueStyle,
    required this.textScaler,
  });

  final List<DomainMastery> domains;
  final int? strongAt;
  final double radius;
  final double progress;
  final Color ringColor;
  final Color targetColor;
  final Color fillColor;
  final Color strokeColor;
  final Color surface;
  final List<Color> dotColors;

  /// When set, the rounded mean is drawn beside each practised vertex.
  final TextStyle? valueStyle;
  final TextScaler textScaler;

  Path _polygon(Offset centre, double Function(int) radiusAt) {
    final n = domains.length;
    final path = Path();
    for (var i = 0; i < n; i++) {
      final a = _RadarLayout.angle(i, n);
      final p = centre + Offset(math.cos(a), math.sin(a)) * radiusAt(i);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }

  double _valueRadius(int i) {
    final mean = domains[i].mean;
    return radius * ((mean ?? 0).clamp(0, 100) / 100) * progress;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (domains.length < DomainRadarCard.minRadarDomains) return;
    final centre = size.center(Offset.zero);
    final n = domains.length;
    final line = Paint()
      ..color = ringColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = AppStroke.thin;
    for (final f in _RadarGeometry.rings) {
      canvas.drawPath(_polygon(centre, (_) => radius * f), line);
    }
    for (var i = 0; i < n; i++) {
      final a = _RadarLayout.angle(i, n);
      canvas.drawLine(
        centre,
        centre + Offset(math.cos(a), math.sin(a)) * radius,
        line,
      );
    }
    final target = validStrongAt(strongAt?.toDouble());
    if (target != null) {
      drawDashedPath(
        canvas,
        _polygon(centre, (_) => radius * target / 100),
        Paint()
          ..color = targetColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = AppStroke.thin,
      );
    }

    final shape = _polygon(centre, _valueRadius);
    canvas
      ..drawPath(shape, Paint()..color = fillColor)
      ..drawPath(
        shape,
        Paint()
          ..color = strokeColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = AppStroke.strong
          ..strokeJoin = StrokeJoin.round,
      );
    for (var i = 0; i < n; i++) {
      final a = _RadarLayout.angle(i, n);
      final dir = Offset(math.cos(a), math.sin(a));
      final p = centre + dir * _valueRadius(i);
      final hollow = domains[i].mean == null;
      canvas
        ..drawCircle(
          p,
          _RadarGeometry.dot,
          Paint()..color = hollow ? surface : dotColors[i],
        )
        ..drawCircle(
          p,
          _RadarGeometry.dot,
          Paint()
            ..color = hollow ? dotColors[i] : surface
            ..style = PaintingStyle.stroke
            ..strokeWidth = AppStroke.badge,
        );
      final mean = domains[i].mean;
      final style = valueStyle;
      if (style != null && mean != null) {
        final text = TextPainter(
          text: TextSpan(text: '${mean.round()}', style: style),
          textDirection: TextDirection.ltr,
          textScaler: textScaler,
        )..layout();
        final middle =
            p +
            dir * (_RadarGeometry.dot + _RadarGeometry.valueGap) +
            Offset(dir.dx * text.width / 2, dir.dy * text.height / 2);
        final topLeft = Offset(
          (middle.dx - text.width / 2)
              .clamp(
                0,
                math.max(0, size.width - text.width),
              )
              .toDouble(),
          (middle.dy - text.height / 2)
              .clamp(
                0,
                math.max(0, size.height - text.height),
              )
              .toDouble(),
        );
        text.paint(canvas, topLeft);
      }
    }
  }

  @override
  bool shouldRepaint(_RadarPainter old) =>
      !listEquals(old.domains, domains) ||
      old.strongAt != strongAt ||
      old.radius != radius ||
      old.progress != progress ||
      old.ringColor != ringColor ||
      old.targetColor != targetColor ||
      old.fillColor != fillColor ||
      old.strokeColor != strokeColor ||
      old.surface != surface ||
      !listEquals(old.dotColors, dotColors) ||
      old.valueStyle != valueStyle ||
      old.textScaler != textScaler;
}
