import 'package:flutter/material.dart';

import 'package:sat_east_client/core/theme/app_colors.dart';
import 'package:sat_east_client/core/theme/app_tokens.dart';
import 'package:sat_east_client/features/skills/domain/entities/skills_overview.dart';
import 'package:sat_east_client/features/skills/presentation/skills_copy.dart';
import 'package:sat_east_client/features/skills/presentation/widgets/mastery_band_chip.dart';
import 'package:sat_east_client/shared/widgets/growing_bar.dart';

/// Fallback for the radar with fewer than three domains (a radar with two
/// axes is just a line): one horizontal bar per domain, same labels.
class DomainBars extends StatelessWidget {
  const DomainBars({
    required this.domains,
    required this.onSelectDomain,
    super.key,
  });

  final List<DomainMastery> domains;
  final ValueChanged<String> onSelectDomain;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (index, d) in domains.indexed)
          Semantics(
            button: true,
            excludeSemantics: true,
            label: SkillsCopy.domainLabel(d),
            onTap: () => onSelectDomain(d.domain),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.control),
              onTap: () => onSelectDomain(d.domain),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: AppSize.touchTarget,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpace.s2),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: AppSpace.s2,
                    children: [
                      Text(
                        SkillsCopy.domainLabel(d),
                        style: theme.textTheme.labelLarge,
                        textDirection: TextDirection.ltr,
                      ),
                      GrowingBar(
                        value: (d.mean ?? 0) / 100,
                        color: d.band.color(colors),
                        index: index,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
