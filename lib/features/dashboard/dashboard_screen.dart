import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/brand.dart';
import '../../app/providers.dart';
import '../../app/router.dart';
import '../../core/design_system/design_system.dart';
import '../../core/haptics/haptics.dart';
import '../../core/utils/format.dart';
import '../../core/utils/motion.dart';
import '../../domain/entities/entities.dart';
import '../../domain/metrics.dart';
import '../alerts/alerts_sheet.dart';
import '../insights/insights_screen.dart';
import '../pairing/pairing_screen.dart' show coreDiscHeroTag;
import '../shell/home_shell.dart';
import 'dashboard_providers.dart';
import 'debug_sheet.dart';

Color stateColor(NodeState s) => switch (s) {
      NodeState.island || NodeState.lowReserve => AppColors.amber,
      NodeState.fault => AppColors.danger,
      NodeState.offline => AppColors.textTertiary,
      NodeState.updating => Colors.white,
      _ => AppColors.mint,
    };

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online =
        ref.watch(snapshotProvider.select((s) => s.value?.nodeOnline ?? true));
    final lastAt = ref.watch(snapshotProvider.select((s) => s.value?.at));
    final noInternet = ref.watch(offlineInternetProvider).value ?? false;
    return SafeArea(
      bottom: false,
      child: LayoutBuilder(
        builder: (context, box) {
          final compact = box.maxHeight < 700;
          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              const SliverToBoxAdapter(child: _TopBar()),
              if (!online || noInternet)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Center(
                      child: _Chip(
                        icon: online ? AppIcons.wifiOff : AppIcons.clock,
                        text: online
                            ? 'Local only · live data from your Core'
                            : 'Last seen ${lastAt == null ? '—' : Fmt.clock(lastAt)} · check the Core is powered and on Wi-Fi',
                      ),
                    ),
                  ),
                ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  AppSpace.screenH,
                  compact ? 12 : 18,
                  AppSpace.screenH,
                  AppSpace.navClearance + MediaQuery.paddingOf(context).bottom,
                ),
                sliver: SliverToBoxAdapter(
                  child: AnimatedOpacity(
                    duration: context.motion(AppMotion.medium),
                    opacity: online ? 1 : 0.45,
                    child: Column(
                      children: [
                        _HeroCard(compact: compact),
                        const SizedBox(height: AppSpace.cardGap),
                        _StatRow(compact: compact),
                        const SizedBox(height: AppSpace.cardGap),
                        const _IndependenceCard(),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Flexible(
              child: Text(text,
                  style: AppType.body(11.5, color: AppColors.textSecondary),
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      );
}

class _TopBar extends ConsumerWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(
        snapshotProvider.select((s) => s.value?.state ?? NodeState.idle));
    final unread = ref.watch(alertsProvider.select((s) => s.unread));
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpace.screenH - 2, 10, AppSpace.screenH - 2, 0),
      child: Row(
        children: [
          IconCircleButton(
            icon: AppIcons.bell,
            badge: unread,
            semanticLabel: unread ? 'Alerts, unread' : 'Alerts',
            onTap: () => showAlertsSheet(context),
          ),
          const Spacer(),
          StatusPill(
            label: state == NodeState.idle ||
                    state == NodeState.charging ||
                    state == NodeState.discharging
                ? (state == NodeState.idle
                    ? Copy.gridOnline
                    : Metrics.pillLabel(state))
                : Metrics.pillLabel(state),
            color: stateColor(state),
            breathe: state != NodeState.offline,
          ),
          const Spacer(),
          Semantics(
            button: true,
            label:
                'Account, ${AppBrand.ownerName}. Long-press for demo scenarios.',
            child: GestureDetector(
              onTap: () => ref.read(homeTabProvider.notifier).select(3),
              onLongPress: () {
                Haptics.toggle();
                showDebugSheet(context);
              },
              child: SizedBox(
                width: 48,
                height: 48,
                child: Center(
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: const BoxDecoration(
                        color: AppColors.avatarTeal, shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: Text(AppBrand.ownerInitial,
                        style: AppType.display(19, weight: FontWeight.w500)),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroCard extends ConsumerWidget {
  const _HeroCard({required this.compact});
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stored =
        ref.watch(snapshotProvider.select((s) => s.value?.storedWh ?? 0));
    final soc = ref.watch(snapshotProvider.select((s) => s.value?.soc ?? 0));
    final selfCons = ref.watch(
        snapshotProvider.select((s) => s.value?.selfConsumptionPct ?? 0));
    final soh =
        ref.watch(snapshotProvider.select((s) => s.value?.sohPercent ?? 100));
    final state = ref.watch(
        snapshotProvider.select((s) => s.value?.state ?? NodeState.idle));
    final runtime = ref.watch(snapshotProvider
        .select((s) => ((s.value?.estRuntimeH ?? 0) * 6).round() / 6));
    final island = state == NodeState.island ||
        (state == NodeState.lowReserve &&
            !(ref.read(snapshotProvider).value?.gridOnline ?? true));
    final accent = stateColor(state);

    return SurfaceCard(
      radius: AppRadii.hero,
      padding:
          EdgeInsets.fromLTRB(22, compact ? 18 : 26, 22, compact ? 16 : 20),
      onTap: () => context.push(Routes.flow),
      semanticLabel:
          'Stored energy ${stored.round()} watt-hours, ${(soc * 100).round()} percent. Opens energy flow.',
      child: LayoutBuilder(
        builder: (context, box) {
          final d = math.min(box.maxWidth * 0.66, compact ? 190.0 : 222.0);
          return Column(
            children: [
              Hero(
                tag: coreDiscHeroTag,
                child: Material(
                  type: MaterialType.transparency,
                  child: EnergyGauge(
                    fraction: soc,
                    diameter: d,
                    color: accent,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(Copy.storedEnergy,
                            style: AppType.micro(
                                size: 10, color: AppColors.textSecondary)),
                        const SizedBox(height: 4),
                        AnimatedNumber(
                          value: stored,
                          style: AppType.display(d * 0.25,
                              weight: FontWeight.w400,
                              height: 1.05,
                              tabular: true),
                          format: (v) => Fmt.wh(v),
                        ),
                        const SizedBox(height: 2),
                        AnimatedSwitcher(
                          duration: context.motion(AppMotion.medium),
                          child: Text(
                            island
                                ? '≈ ${Fmt.hours(runtime)} runtime'
                                : Copy.whActive,
                            key: ValueKey(island),
                            style: AppType.body(12.5,
                                weight: FontWeight.w500, color: accent),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(height: compact ? 26 : 34),
              Container(height: 1, color: AppColors.divider),
              const SizedBox(height: 16),
              IntrinsicHeight(
                child: Row(
                  children: [
                    Expanded(
                      child: _Metric(
                          label: Copy.selfConsumption,
                          value: Fmt.pct(selfCons),
                          color: AppColors.textPrimary),
                    ),
                    Container(width: 1, color: AppColors.divider),
                    Expanded(
                      child: _Metric(
                        label: Copy.batteryHealth,
                        value: '${soh.round()}% ${Metrics.healthLabel(soh)}',
                        color: soh >= 90 ? AppColors.mint : AppColors.amber,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric(
      {required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Semantics(
        label: '$label $value',
        excludeSemantics: true,
        child: Column(
          children: [
            Text(label,
                style: AppType.micro(
                    size: 9.5, color: AppColors.textSecondary, spacing: 1)),
            const SizedBox(height: 6),
            Text(value, style: AppType.mono(14.5, color: color)),
          ],
        ),
      );
}

class _StatRow extends ConsumerWidget {
  const _StatRow({required this.compact});
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (solar, export) = ref.watch(periodTotalsProvider);
    final period = ref.watch(statPeriodProvider);
    void open(InsightsFocus f) {
      ref.read(insightsFocusProvider.notifier).set(f);
      ref.read(homeTabProvider.notifier).select(2);
    }

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: AppIcons.sun,
            iconColor: AppColors.amber,
            value: solar,
            label: Copy.solarHarvest,
            period: period,
            compact: compact,
            onTap: () => open(InsightsFocus.solar),
          ),
        ),
        const SizedBox(width: AppSpace.cardGap),
        Expanded(
          child: _StatCard(
            icon: AppIcons.bolt,
            iconColor: AppColors.mint,
            value: export,
            label: Copy.exportedToGrid,
            period: period,
            compact: compact,
            onTap: () => open(InsightsFocus.export),
          ),
        ),
      ],
    );
  }
}

class _StatCard extends ConsumerWidget {
  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
    required this.period,
    required this.compact,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final double value;
  final String label;
  final StatPeriod period;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SurfaceCard(
      radius: AppRadii.card,
      padding: EdgeInsets.fromLTRB(18, 16, 14, compact ? 14 : 18),
      onTap: onTap,
      semanticLabel: '$label ${Fmt.kwh(value)} kilowatt-hours, ${period.label}',
      child: SizedBox(
        height: compact ? 100 : 112,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DarkIconCircle(icon: icon, color: iconColor, size: 38),
                const Spacer(),
                GestureDetector(
                  onTap: () => _pickPeriod(context, ref),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Text(period.label,
                        style: AppType.body(10,
                            weight: FontWeight.w600,
                            color: AppColors.textTertiary)),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                AnimatedNumber(
                  value: value,
                  style: AppType.display(28,
                      weight: FontWeight.w500, tabular: true),
                  format: Fmt.kwh,
                ),
                const SizedBox(width: 6),
                Text('kWh',
                    style: AppType.body(12,
                        weight: FontWeight.w500,
                        color: AppColors.textSecondary)),
              ],
            ),
            const SizedBox(height: 4),
            Text(label,
                style: AppType.body(12,
                    weight: FontWeight.w500, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }

  void _pickPeriod(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      builder: (c) => SheetFrame(
        title: 'Show totals for',
        child: Column(
          children: [
            for (final p in StatPeriod.values)
              _OptionRow(
                label: p.label,
                selected: ref.read(statPeriodProvider) == p,
                onTap: () {
                  Haptics.toggle();
                  ref.read(statPeriodProvider.notifier).set(p);
                  Navigator.pop(c);
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow(
      {required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: SurfaceCard(
          radius: AppRadii.tile,
          color: AppColors.surfaceHigh,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          onTap: onTap,
          child: Row(
            children: [
              Expanded(
                  child: Text(label,
                      style: AppType.body(14, weight: FontWeight.w600))),
              if (selected)
                const Icon(AppIcons.check, color: AppColors.mint, size: 20),
            ],
          ),
        ),
      );
}

class _IndependenceCard extends ConsumerWidget {
  const _IndependenceCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streak = ref.watch(streakProvider);
    final autonomy = ref.watch(settingsProvider.select((s) => s.autonomy));
    return SurfaceCard(
      radius: AppRadii.card,
      padding: const EdgeInsets.fromLTRB(18, 18, 16, 18),
      onTap: () => context.push(Routes.streak),
      semanticLabel:
          '$streak days of total energy independence. Opens streak calendar.',
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    AnimatedNumber(
                      value: streak.toDouble(),
                      style: AppType.display(24,
                          weight: FontWeight.w500, tabular: true),
                    ),
                    const SizedBox(width: 6),
                    Text(Copy.days,
                        style: AppType.micro(
                            size: 10, color: AppColors.textSecondary)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(Copy.totalIndependence,
                    style: AppType.body(12,
                        weight: FontWeight.w500,
                        color: AppColors.textSecondary)),
              ],
            ),
          ),
          _AutonomyPill(
            active: autonomy,
            onTap: () {
              Haptics.toggle();
              ref.read(settingsProvider.notifier).setAutonomy(!autonomy);
            },
          ),
        ],
      ),
    );
  }
}

class _AutonomyPill extends StatelessWidget {
  const _AutonomyPill({required this.active, required this.onTap});
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      toggled: active,
      label: 'Autonomy Mode, ${active ? 'active' : 'paused'}',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: context.motion(AppMotion.fast),
          curve: AppMotion.curve,
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            color: active ? AppColors.mint : AppColors.surfaceHigh,
            borderRadius: BorderRadius.circular(AppRadii.pill),
            border: Border.all(
                color: active ? Colors.transparent : AppColors.glassBorder),
            boxShadow: active
                ? [
                    BoxShadow(
                        color: AppColors.mint.withValues(alpha: 0.25),
                        blurRadius: 16)
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                active ? AppIcons.check : AppIcons.pause,
                size: 18,
                color: active ? AppColors.ctaText : AppColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                active ? Copy.active : Copy.paused,
                style: AppType.body(13.5,
                    weight: FontWeight.w700,
                    color:
                        active ? AppColors.ctaText : AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
