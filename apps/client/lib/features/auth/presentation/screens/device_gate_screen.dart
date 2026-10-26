import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sat_east_client/core/theme/app_tokens.dart';
import 'package:sat_east_client/features/auth/domain/entities/device.dart';
import 'package:sat_east_client/features/auth/presentation/auth_copy.dart';
import 'package:sat_east_client/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:sat_east_client/features/auth/presentation/cubit/auth_state.dart';
import 'package:sat_east_client/features/auth/presentation/last_used.dart';
import 'package:sat_east_client/features/auth/presentation/widgets/auth_card.dart';
import 'package:sat_east_client/shared/widgets/app_banner.dart';
import 'package:sat_east_client/shared/widgets/app_dialog.dart';
import 'package:sat_east_client/shared/widgets/app_illustration.dart';
import 'package:sat_east_client/shared/widgets/app_overlays.dart';
import 'package:sat_east_client/shared/widgets/loading_button.dart';

/// Device-limit gate (S-11): choose a device to remove, or sign out.
class DeviceGateScreen extends StatefulWidget {
  const DeviceGateScreen({super.key, this.now});

  /// Injected clock for the relative "Last used" text.
  final DateTime Function()? now;

  @override
  State<DeviceGateScreen> createState() => _DeviceGateScreenState();
}

class _DeviceGateScreenState extends State<DeviceGateScreen> {
  String? _selectedId;

  Future<void> _confirmRemove(Device device) async {
    final cubit = context.read<AuthCubit>();
    final name = _nameOf(device);
    final confirmed = await showAppDialog<bool>(
      context: context,
      builder: (dialogContext) => AppDialog(
        title: 'Remove $name?',
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
    if (confirmed ?? false) await cubit.removeDevice(device.id);
  }

  @override
  Widget build(BuildContext context) => BlocBuilder<AuthCubit, AuthState>(
    buildWhen: (_, next) => next is AuthDeviceGate,
    builder: (context, state) {
      final signOut = Align(
        alignment: AlignmentDirectional.centerEnd,
        child: LoadingButton(
          label: 'Sign out',
          variant: AppButtonVariant.tertiary,
          onPressed: state is AuthDeviceGate && state.removing
              ? null
              : context.read<AuthCubit>().signOut,
        ),
      );
      if (state is! AuthDeviceGate) {
        return AuthCard(
          illustration: AppIllustrationName.deviceLimit,
          children: [signOut],
        );
      }
      return _gate(context, state, signOut);
    },
  );

  Widget _gate(BuildContext context, AuthDeviceGate gate, Widget signOut) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final n = gate.devices.length;
    final exhausted = gate.changesLeft == 0;
    final selected = gate.devices.where((d) => d.id == _selectedId).firstOrNull;
    final now = (widget.now ?? DateTime.now)();
    final changes = gate.changesLeft == 1 ? 'change' : 'changes';
    return AuthCard(
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpace.s3,
        children: [
          LoadingButton(
            label: selected == null
                ? 'Remove and continue'
                : 'Remove ${_nameOf(selected)} and continue',
            isLoading: gate.removing,
            expanded: true,
            onPressed: exhausted || selected == null
                ? null
                : () => _confirmRemove(selected),
          ),
          LoadingButton(
            label: 'Sign out instead',
            variant: AppButtonVariant.secondary,
            expanded: true,
            onPressed: gate.removing ? null : context.read<AuthCubit>().signOut,
          ),
        ],
      ),
      children: [
        signOut,
        Text(
          exhausted
              ? 'No changes left this month.'
              : "You're already using $n devices",
          style: theme.textTheme.headlineSmall,
        ),
        if (gate.error case final error?)
          AppBanner(
            message: authErrorCopy(error.code),
            kind: AppBannerKind.error,
          ),
        RadioGroup<String>(
          groupValue: _selectedId,
          onChanged: (id) {
            if (!gate.removing) setState(() => _selectedId = id);
          },
          child: Column(
            children: [
              for (final device in gate.devices)
                RadioListTile<String>(
                  value: device.id,
                  enabled: !gate.removing,
                  contentPadding: EdgeInsets.zero,
                  title: Text(_nameOf(device)),
                  subtitle: device.lastSeenAt == null
                      ? null
                      : Text(lastUsedText(device.lastSeenAt!, now)),
                ),
            ],
          ),
        ),
        Text(
          exhausted
              ? 'Keep using one of your current devices, '
                    'or contact your teacher.'
              : 'You can use $n devices. '
                    'To continue on this device, remove one of them.',
          style: muted,
        ),
        if (!exhausted)
          Text(
            'Removing a device signs it out and uses 1 change. '
            'You have ${gate.changesLeft} $changes left this month.',
            style: muted,
          ),
        const AppIllustration(AppIllustrationName.deviceLimit),
      ],
    );
  }

  static String _nameOf(Device device) =>
      device.label ?? device.platform ?? 'Unknown device';
}
