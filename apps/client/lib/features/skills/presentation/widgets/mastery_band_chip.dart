import 'package:flutter/material.dart';

import 'package:sat_east_client/core/theme/app_colors.dart';
import 'package:sat_east_client/core/theme/app_icons.dart';
import 'package:sat_east_client/core/theme/app_tokens.dart';
import 'package:sat_east_client/features/skills/domain/entities/skills_overview.dart';
import 'package:sat_east_client/features/skills/presentation/skills_copy.dart';

/// Colours and icon of a [MasteryBand]; colour never stands alone, the word
/// and icon always come with it.
extension MasteryBandStyle on MasteryBand {
  Color color(AppColors colors) => switch (this) {
    MasteryBand.weak => colors.incorrect,
    MasteryBand.building => colors.warning,
    MasteryBand.strong => colors.correct,
    MasteryBand.thin => colors.inkTertiary,
  };

  Color wash(AppColors colors) => switch (this) {
    MasteryBand.weak => colors.incorrectWash,
    MasteryBand.building => colors.warningWash,
    MasteryBand.strong => colors.correctWash,
    MasteryBand.thin => colors.surface,
  };

  IconData get icon => switch (this) {
    MasteryBand.weak => AppIcons.masteryWeak,
    MasteryBand.building => AppIcons.masteryBuilding,
    MasteryBand.strong => AppIcons.masteryStrong,
    MasteryBand.thin => AppIcons.masteryThin,
  };
}

/// Compact status pill: band icon plus band word. Smaller than `AppChip`
/// (which is a 48 px touch target) because it sits inside dense rows.
class MasteryBandChip extends StatelessWidget {
  const MasteryBandChip(this.band, {super.key});

  final MasteryBand band;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: band.wash(colors),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: colors.line),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.s2,
          vertical: AppSpace.s1,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: AppSpace.s1,
          children: [
            ExcludeSemantics(
              child: Icon(
                band.icon,
                size: AppSize.iconStatus - 4,
                color: band.color(colors),
              ),
            ),
            Flexible(
              child: Text(
                SkillsCopy.band(band),
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: colors.ink),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
