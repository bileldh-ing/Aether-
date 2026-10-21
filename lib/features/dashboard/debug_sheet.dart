import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../../core/design_system/design_system.dart';

/// Hidden scenario menu (long-press the avatar). Makes the whole story
/// demo-able in two minutes.
void showDebugSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (c) => const _DebugSheet(),
  );
}

class _DebugSheet extends ConsumerWidget {
  const _DebugSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(scenarioProvider);
    void run(void Function() f) {
      f();
      Navigator.pop(context);
    }

    if (s == null) {
      return const SheetFrame(
          title: 'Scenarios',
          child: Text('Scenarios are only available on the simulator.'));
    }
    final items = <(IconData, Color, String, String, VoidCallback)>[
      (
        AppIcons.warning,
        AppColors.amber,
        'Trigger grid outage',
        'Island mode, amber ring, push alert',
        () => run(s.triggerOutage)
      ),
      (
        AppIcons.plug,
        AppColors.mint,
        'Restore grid',
        'Back to mint, “Grid restored” toast',
        () => run(s.restoreGrid)
      ),
      (
        AppIcons.battery,
        AppColors.amber,
        'Low reserve',
        'Drop below the backup reserve',
        () => run(s.forceLowReserve)
      ),
      (
        AppIcons.download,
        AppColors.mint,
        'Firmware available',
        'Announce v4.9.0-Aether',
        () => run(s.announceFirmware)
      ),
      (
        AppIcons.wifiOff,
        AppColors.textSecondary,
        'Node offline',
        'Toggle the local link',
        () => run(s.toggleNodeOffline)
      ),
      (
        AppIcons.clock,
        AppColors.mint,
        'Fast-forward 6 h',
        'Run the day curve ahead',
        () => run(() => s.fastForward(const Duration(hours: 6)))
      ),
      (
        AppIcons.flask,
        AppColors.textSecondary,
        'Component gallery',
        'Design-system widgets',
        () {
          Navigator.pop(context);
          context.push(Routes.gallery);
        }
      ),
      (
        AppIcons.restart,
        AppColors.danger,
        'Reset demo',
        'Clear pairing and start over',
        () async {
          Navigator.pop(context);
          await ref.read(settingsProvider.notifier).reset();
          if (context.mounted) context.go(Routes.onboarding);
        }
      ),
    ];

    return SheetFrame(
      title: 'Demo scenarios',
      child: ListView(
        shrinkWrap: true,
        children: [
          for (final (icon, color, title, sub, onTap) in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SurfaceCard(
                radius: AppRadii.tile,
                color: AppColors.surfaceHigh,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                onTap: onTap,
                child: Row(
                  children: [
                    TintedIcon(icon: icon, color: color, size: 36),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title,
                              style: AppType.body(14, weight: FontWeight.w600)),
                          Text(sub,
                              style: AppType.body(12,
                                  color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
