import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/design_system/design_system.dart';
import '../../core/utils/format.dart';
import '../../domain/entities/entities.dart';

void showAlertsSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (c) => const AlertsSheet(),
  );
}

class AlertsSheet extends ConsumerStatefulWidget {
  const AlertsSheet({super.key});
  @override
  ConsumerState<AlertsSheet> createState() => _AlertsSheetState();
}

class _AlertsSheetState extends ConsumerState<AlertsSheet> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(alertsProvider.notifier).markRead());
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(alertsProvider.select((s) => s.items));
    final now = DateTime.now();
    final today = items.where((a) => now.difference(a.at).inHours < 24 && a.at.day == now.day).toList();
    final earlier = items.where((a) => !today.contains(a)).toList();

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.78),
      child: SheetFrame(
        title: 'Alerts',
        child: items.isEmpty
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text(
                    'All quiet. You’ll hear from us when the grid or your Core needs you.',
                    textAlign: TextAlign.center,
                    style: AppType.body(13.5, color: AppColors.textSecondary),
                  ),
                ),
              )
            : ListView(
                shrinkWrap: true,
                children: [
                  if (today.isNotEmpty) ...[
                    const SectionHeader('Today'),
                    for (final a in today) _AlertRow(alert: a, now: now),
                  ],
                  if (earlier.isNotEmpty) ...[
                    const SectionHeader('Earlier'),
                    for (final a in earlier) _AlertRow(alert: a, now: now),
                  ],
                ],
              ),
      ),
    );
  }
}

class _AlertRow extends ConsumerWidget {
  const _AlertRow({required this.alert, required this.now});
  final AppAlert alert;
  final DateTime now;

  (IconData, Color) get _style => switch (alert.type) {
        AlertType.outage => (AppIcons.warning, AppColors.amber),
        AlertType.restored => (AppIcons.plug, AppColors.mint),
        AlertType.lowReserve => (AppIcons.battery, AppColors.amber),
        AlertType.firmware => (AppIcons.download, AppColors.mint),
        AlertType.overTemp => (AppIcons.thermometer, AppColors.danger),
        AlertType.stormGuard => (AppIcons.storm, AppColors.amber),
        AlertType.member => (AppIcons.userPlus, AppColors.mint),
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (icon, color) = _style;
    return Dismissible(
      key: ValueKey(alert.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => ref.read(alertsProvider.notifier).dismiss(alert.id),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(AppIcons.trash, color: AppColors.textSecondary, size: 20),
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: SurfaceCard(
          radius: AppRadii.tile,
          color: AppColors.surfaceHigh,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          semanticLabel: '${alert.title}. ${alert.detail}. ${Fmt.relative(alert.at, now)}',
          child: Row(
            children: [
              TintedIcon(icon: icon, color: color, size: 36),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(alert.title, style: AppType.body(14, weight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(
                      alert.detail,
                      style: AppType.body(12, color: AppColors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(Fmt.relative(alert.at, now), style: AppType.body(11, color: AppColors.textTertiary)),
            ],
          ),
        ),
      ),
    );
  }
}
