import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../core/design_system/design_system.dart';
import '../../domain/entities/entities.dart';

/// Streak calendar: which days were fully independent (≤ 5 % grid import).
class StreakScreen extends ConsumerWidget {
  const StreakScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(historyProvider);
    final streak = ref.watch(streakProvider);
    final byDay = {
      for (final d in history)
        DateTime(d.date.year, d.date.month, d.date.day): d
    };
    final now = history.isEmpty ? DateTime.now() : history.last.date;
    final months = [
      for (var i = 2; i >= 0; i--) DateTime(now.year, now.month - i)
    ];
    final independentCount = history.where((d) => d.independent).length;

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
                const StatusPill(label: 'INDEPENDENCE'),
                const Spacer(),
                const SizedBox(width: 48),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                AnimatedNumber(
                    value: streak.toDouble(),
                    style: AppType.display(64,
                        weight: FontWeight.w300, tabular: true)),
                const SizedBox(width: 10),
                Text('DAYS', style: AppType.micro(size: 12)),
              ],
            ),
            Text('Current streak of total energy independence',
                style: AppType.body(13.5, color: AppColors.textSecondary)),
            const SizedBox(height: 6),
            Text(
              '$independentCount of the last ${history.length} days ran on 5% grid import or less.',
              style: AppType.body(12.5, color: AppColors.textTertiary),
            ),
            const SizedBox(height: 20),
            for (final m in months) ...[
              _Month(month: m, byDay: byDay, today: now),
              const SizedBox(height: AppSpace.cardGap),
            ],
          ],
        ),
      ),
    );
  }
}

class _Month extends StatelessWidget {
  const _Month({required this.month, required this.byDay, required this.today});
  final DateTime month;
  final Map<DateTime, DailyStats> byDay;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month);
    final daysIn = DateTime(month.year, month.month + 1, 0).day;
    final lead = (first.weekday + 6) % 7; // Monday first
    return SurfaceCard(
      radius: AppRadii.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(DateFormat('MMMM yyyy').format(month),
              style: AppType.body(14, weight: FontWeight.w600)),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final d in const ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
                Expanded(
                    child: Center(
                        child: Text(d,
                            style: AppType.body(10.5,
                                color: AppColors.textTertiary)))),
            ],
          ),
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            children: [
              for (var i = 0; i < lead; i++) const SizedBox.shrink(),
              for (var d = 1; d <= daysIn; d++)
                _cell(DateTime(month.year, month.month, d)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _cell(DateTime day) {
    final s = byDay[day];
    final isToday = day == DateTime(today.year, today.month, today.day);
    final Color bg;
    final Color fg;
    if (s == null || day.isAfter(today)) {
      bg = Colors.transparent;
      fg = AppColors.textTertiary;
    } else if (isToday) {
      bg = AppColors.mintDim;
      fg = AppColors.mint;
    } else if (s.independent) {
      bg = AppColors.mint;
      fg = AppColors.ctaText;
    } else {
      bg = AppColors.surfaceHigh;
      fg = AppColors.textSecondary;
    }
    return Semantics(
      label:
          '${DateFormat('d MMMM').format(day)}${s == null ? '' : s.independent ? ', independent' : ', used grid'}',
      child: Container(
        alignment: Alignment.center,
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
        child: Text('${day.day}',
            style: AppType.body(11.5, weight: FontWeight.w600, color: fg)),
      ),
    );
  }
}
