import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/design_system/design_system.dart';
import '../../core/utils/format.dart';
import '../../domain/entities/entities.dart';
import '../../domain/metrics.dart';
import '../dashboard/dashboard_screen.dart' show stateColor;

/// Live energy flow: Solar → Core → Home ↔ Grid, with the product hero
/// mirroring the LED ring state.
class EnergyFlowScreen extends ConsumerWidget {
  const EnergyFlowScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(snapshotProvider).value;
    final state = s?.state ?? NodeState.idle;
    final accent = stateColor(state);
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
              AppSpace.screenH, 8, AppSpace.screenH, 32),
          children: [
            Row(
              children: [
                IconCircleButton(
                    icon: AppIcons.back,
                    semanticLabel: 'Back',
                    onTap: () => context.pop()),
                const Spacer(),
                StatusPill(label: Metrics.pillLabel(state), color: accent),
                const Spacer(),
                const SizedBox(width: 48),
              ],
            ),
            const SizedBox(height: 20),
            Text('Energy flow',
                style: AppType.display(32, weight: FontWeight.w500)),
            const SizedBox(height: 4),
            Text(
              s == null ? '' : _summary(s),
              style: AppType.body(13.5,
                  color: AppColors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 24),
            if (s != null)
              FlowDiagram(
                solarW: s.solarW,
                homeW: s.homeLoadW,
                gridW: s.gridW,
                batteryW: s.batteryW,
                soc: s.soc,
                gridOnline: s.gridOnline,
                accent: accent,
              ),
            const SizedBox(height: 20),
            SurfaceCard(
              radius: AppRadii.card,
              child: Row(
                children: [
                  ProductHero(width: 58, state: state, reflection: false),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Garage Core · NEXUS-CORE-901',
                            style: AppType.body(13.5, weight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text(
                          s == null
                              ? ''
                              : 'Runtime at current load ≈ ${Fmt.hours(s.estRuntimeH)}',
                          style: AppType.body(12.5,
                              color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 4),
                        Text('The ring on the unit matches this colour.',
                            style: AppType.body(12,
                                color: AppColors.textTertiary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _summary(EnergySnapshot s) {
    if (!s.nodeOnline)
      return 'The Core is offline. Showing the last reading it sent.';
    if (!s.gridOnline)
      return 'Grid is down. Your home is running on solar and stored energy.';
    if (s.gridW < -20)
      return 'Solar covers the house and the surplus is flowing to the grid.';
    if (s.batteryW > 20)
      return 'Solar is powering the house and filling the Core.';
    if (s.batteryW < -20)
      return 'The Core is powering your home from stored energy.';
    return 'Everything is balanced. The Core is standing by.';
  }
}
