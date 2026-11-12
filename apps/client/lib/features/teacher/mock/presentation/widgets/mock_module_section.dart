import 'package:flutter/material.dart';
import 'package:sat_east_client/core/theme/app_colors.dart';
import 'package:sat_east_client/core/theme/app_icons.dart';
import 'package:sat_east_client/core/theme/app_tokens.dart';
import 'package:sat_east_client/features/teacher/mock/domain/entities/mock_entities.dart';
import 'package:sat_east_client/features/teacher/mock/presentation/mock_copy.dart';

/// One module's slots. Stale slots carry a warning icon and text, so the
/// marker never relies on colour alone.
class MockModuleSection extends StatelessWidget {
  const MockModuleSection({
    required this.module,
    required this.stale,
    required this.canSwap,
    required this.swapEnabled,
    required this.selectedId,
    required this.onPreview,
    required this.onSwap,
    super.key,
  });
  final MockModule module;
  final Set<String> stale;
  final bool canSwap;
  final bool swapEnabled;
  final String? selectedId;
  final ValueChanged<String> onPreview;
  final ValueChanged<String> onSwap;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: AppSpace.s2,
    children: [
      Text(
        '${mockModuleTitle(module.name)} · ${module.slots.length} questions',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      for (final slot in module.slots)
        _SlotRow(
          slot: slot,
          isStale: stale.contains(slot.questionId),
          canSwap: canSwap,
          swapEnabled: swapEnabled,
          selected: selectedId == slot.questionId,
          onPreview: () => onPreview(slot.questionId),
          onSwap: () => onSwap(slot.questionId),
        ),
    ],
  );
}

class _SlotRow extends StatelessWidget {
  const _SlotRow({
    required this.slot,
    required this.isStale,
    required this.canSwap,
    required this.swapEnabled,
    required this.selected,
    required this.onPreview,
    required this.onSwap,
  });
  final MockSlot slot;
  final bool isStale;
  final bool canSwap;
  final bool swapEnabled;
  final bool selected;
  final VoidCallback onPreview;
  final VoidCallback onSwap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final stem = mockStemLine(slot.stemMd);
    return Semantics(
      label: mockSlotLabel(slot.slotNo),
      child: Material(
        color: selected ? colors.raised : colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          side: BorderSide(
            color: isStale
                ? colors.warning
                : (selected ? colors.brandLine : colors.line),
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.control),
          onTap: onPreview,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.s3,
              vertical: AppSpace.s2,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: AppSpace.s3,
              children: [
                SizedBox(
                  width: AppSpace.s6,
                  child: Text(
                    '${slot.slotNo}',
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        slot.externalRef ?? mockNoReference,
                        style: theme.textTheme.titleSmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        mockSlotDetail(slot),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.inkSecondary,
                        ),
                      ),
                      if (stem.isNotEmpty)
                        Text(
                          stem,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium,
                        ),
                      if (isStale)
                        Padding(
                          padding: const EdgeInsets.only(top: AppSpace.s1),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            spacing: AppSpace.s1,
                            children: [
                              Icon(
                                AppIcons.masteryWeak,
                                size: AppSpace.s4,
                                color: colors.warning,
                              ),
                              Flexible(
                                child: Text(
                                  mockStaleMarker,
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: colors.warmInk,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                if (canSwap)
                  IconButton(
                    tooltip: mockSwapTooltip,
                    onPressed: swapEnabled ? onSwap : null,
                    icon: const Icon(AppIcons.swap),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
