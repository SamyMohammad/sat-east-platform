import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sat_east_client/core/theme/app_tokens.dart';
import 'package:sat_east_client/features/auth/domain/entities/device.dart';
import 'package:sat_east_client/features/auth/presentation/cubit/account_cubit.dart';
import 'package:sat_east_client/features/auth/presentation/last_used.dart';
import 'package:sat_east_client/shared/widgets/app_chip.dart';
import 'package:sat_east_client/shared/widgets/app_dialog.dart';
import 'package:sat_east_client/shared/widgets/app_overlays.dart';
import 'package:sat_east_client/shared/widgets/loading_button.dart';

class AccountDevices extends StatelessWidget {
  const AccountDevices({
    required this.devices,
    required this.changesLeft,
    required this.busy,
    required this.now,
    super.key,
  });

  final List<Device> devices;
  final int changesLeft;
  final bool busy;
  final DateTime now;

  Future<void> _remove(BuildContext context, Device device) async {
    final cubit = context.read<AccountCubit>();
    final confirmed = await showAppDialog<bool>(
      context: context,
      builder: (dialogContext) => AppDialog(
        title: 'Remove this device?',
        content: const Text('It will be signed out there.'),
        actions: [
          LoadingButton(
            label: 'Cancel',
            variant: AppButtonVariant.tertiary,
            onPressed: () => Navigator.of(dialogContext).pop(false),
          ),
          LoadingButton(
            label: 'Remove',
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
        ],
      ),
    );
    if (context.mounted && (confirmed ?? false)) {
      await cubit.removeDevice(device.id);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: AppSpace.s3,
    children: [
      Text('Devices', style: Theme.of(context).textTheme.titleLarge),
      Text(
        changesLeft == 0
            ? 'No changes left this month'
            : '$changesLeft changes left this month',
      ),
      if (devices.isEmpty) const Text('No devices to show.'),
      for (final device in devices) ...[
        const Divider(),
        Text(
          device.label ?? device.platform ?? 'Unknown device',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (device.platform case final platform?) Text(platform),
        if (device.lastSeenAt case final seen?) Text(lastUsedText(seen, now)),
        if (device.isCurrent)
          const Align(
            alignment: AlignmentDirectional.centerStart,
            child: AppChip(label: 'This device'),
          )
        else
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: LoadingButton(
              key: ValueKey('remove-device-${device.id}'),
              label: 'Remove',
              variant: AppButtonVariant.secondary,
              onPressed: busy || changesLeft <= 0
                  ? null
                  : () => _remove(context, device),
            ),
          ),
      ],
    ],
  );
}
