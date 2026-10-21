import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../../core/design_system/design_system.dart';
import '../../core/haptics/haptics.dart';
import '../../core/utils/motion.dart';
import '../../domain/entities/entities.dart';

enum InsightsRange { day, week, month, year }

enum InsightsFocus { all, solar, export }

class InsightsFocusController extends Notifier<InsightsFocus> {
  @override
  InsightsFocus build() => InsightsFocus.all;
  void set(InsightsFocus f) => state = f;
}

final insightsFocusProvider =
    NotifierProvider<InsightsFocusController, InsightsFocus>(
        InsightsFocusController.new);

class InsightsRangeController extends Notifier<InsightsRange> {
  @override
  InsightsRange build() => InsightsRange.week;
  void set(InsightsRange r) => state = r;
}

final insightsRangeProvider =
    NotifierProvider<InsightsRangeController, InsightsRange>(
        InsightsRangeController.new);

@immutable
class Bucket {
  const Bucket(this.label, this.solar, this.home, this.import, this.export);
  final String label;
  final double solar, home, import, export;
}

/// Aggregates daily history into chart buckets for the selected range.
/// Day = last 7 days · Week = last 8 weeks · Month = last 4 months · Year = by month, year to date.
List<Bucket> bucketize(List<DailyStats> days, InsightsRange range) {
  if (days.isEmpty) return const [];
  Bucket sum(String label, Iterable<DailyStats> ds) => Bucket(
        label,
        ds.fold(0, (a, d) => a + d.solarKwh),
        ds.fold(0, (a, d) => a + d.homeKwh),
        ds.fold(0, (a, d) => a + d.importKwh),
        ds.fold(0, (a, d) => a + d.exportKwh),
      );
  switch (range) {
    case InsightsRange.day:
      final last = days.sublist(days.length > 7 ? days.length - 7 : 0);
      return [
        for (final d in last)
          sum(DateFormat('E').format(d.date).substring(0, 2), [d])
      ];
    case InsightsRange.week:
      final out = <Bucket>[];
      for (var w = 7; w >= 0; w--) {
        final end = days.length - w * 7;
        final start = end - 7;
        if (start < 0) continue;
        out.add(sum(w == 0 ? 'Now' : '-${w}w', days.sublist(start, end)));
      }
      return out;
    case InsightsRange.month:
    case InsightsRange.year:
      final byMonth = <String, List<DailyStats>>{};
      for (final d in days) {
        byMonth
            .putIfAbsent(DateFormat('yyyy-MM').format(d.date), () => [])
            .add(d);
      }
      final keys = byMonth.keys.toList()..sort();
      final year = days.last.date.year;
      final pick = range == InsightsRange.month
          ? keys.sublist(keys.length > 4 ? keys.length - 4 : 0)
          : keys.where((k) => k.startsWith('$year')).toList();
      return [
        for (final k in pick)
          sum(DateFormat('MMM').format(DateTime.parse('$k-01')), byMonth[k]!)
      ];
  }
}

class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(insightsRangeProvider);
    final focus = ref.watch(insightsFocusProvider);
    final history = ref.watch(historyProvider);
    final settings = ref.watch(settingsProvider);
    final buckets = bucketize(history, range);
    final total = buckets.fold<Bucket>(
      const Bucket('', 0, 0, 0, 0),
      (a, b) => Bucket('', a.solar + b.solar, a.home + b.home,
          a.import + b.import, a.export + b.export),
    );
    final selfSufficiency = total.home <= 0
        ? 0.0
        : ((total.home - total.import) / total.home * 100).clamp(0, 100);
    final saved = (total.home - total.import).clamp(0, double.infinity) * 0.28 +
        total.export * 0.08;
    final co2 = total.solar * 0.42;

    return SafeArea(
      bottom: false,
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          AppSpace.screenH,
          18,
          AppSpace.screenH,
          AppSpace.navClearance + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          Row(
            children: [
              const Expanded(
                  child: TabTitle(
                      title: 'Insights',
                      subtitle: 'Where your energy came from and went')),
              IconCircleButton(
                icon: AppIcons.export,
                semanticLabel: 'Export report as CSV',
                onTap: () => _export(ref, buckets, range),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _Segmented(
            value: range,
            onChanged: (r) {
              Haptics.nav();
              ref.read(insightsRangeProvider.notifier).set(r);
            },
          ),
          const SizedBox(height: 12),
          SurfaceCard(
            radius: AppRadii.hero,
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Legend(
                    focus: focus,
                    onFocus: (f) =>
                        ref.read(insightsFocusProvider.notifier).set(f)),
                const SizedBox(height: 18),
                SizedBox(
                    height: 190, child: _Bars(buckets: buckets, focus: focus)),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.cardGap),
          Row(
            children: [
              Expanded(
                  child: _Kpi(
                      icon: AppIcons.home,
                      label: 'Self-sufficiency',
                      value: '${selfSufficiency.toStringAsFixed(0)}%')),
              const SizedBox(width: 10),
              Expanded(
                child: _Kpi(
                  icon: AppIcons.coins,
                  label: 'Money saved',
                  value:
                      '${settings.currencySymbol}${saved.toStringAsFixed(0)}',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                  child: _Kpi(
                      icon: AppIcons.leaf,
                      label: 'CO₂ avoided',
                      value: '${co2.toStringAsFixed(0)} kg')),
            ],
          ),
          const SectionHeader('Energy Independence'),
          _HeatStrip(days: history, onTap: () => context.push(Routes.streak)),
        ],
      ),
    );
  }

  void _export(WidgetRef ref, List<Bucket> buckets, InsightsRange range) {
    final b =
        StringBuffer('period,solar_kwh,home_kwh,grid_import_kwh,export_kwh\n');
    for (final x in buckets) {
      b.writeln(
          '${x.label},${x.solar.toStringAsFixed(2)},${x.home.toStringAsFixed(2)},'
          '${x.import.toStringAsFixed(2)},${x.export.toStringAsFixed(2)}');
    }
    Clipboard.setData(ClipboardData(text: b.toString()));
    ref.read(toastProvider.notifier).show(
        'CSV report copied · ${range.name} view',
        tone: ToastTone.success);
  }
}

class _Segmented extends StatelessWidget {
  const _Segmented({required this.value, required this.onChanged});
  final InsightsRange value;
  final ValueChanged<InsightsRange> onChanged;

  @override
  Widget build(BuildContext context) {
    const labels = ['Day', 'Week', 'Month', 'Year'];
    return Container(
      height: 46,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: AppColors.border),
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          final w = box.maxWidth / 4;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: context.motion(AppMotion.medium),
                curve: AppMotion.curve,
                left: value.index * w,
                top: 0,
                bottom: 0,
                width: w,
                child: Container(
                  decoration: BoxDecoration(
                      color: AppColors.ctaWhite,
                      borderRadius: BorderRadius.circular(AppRadii.pill)),
                ),
              ),
              Row(
                children: [
                  for (var i = 0; i < 4; i++)
                    Expanded(
                      child: Semantics(
                        button: true,
                        selected: value.index == i,
                        label: labels[i],
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => onChanged(InsightsRange.values[i]),
                          child: Center(
                            child: Text(
                              labels[i],
                              style: AppType.body(
                                13,
                                weight: FontWeight.w600,
                                color: value.index == i
                                    ? AppColors.ctaText
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

const _cSolarUsed = AppColors.amber;
const _cExport = AppColors.mint;
const _cHomeLocal = Color(0xFFB9C0C8);
const _cImport = Color(0xFF5E6268);

class _Legend extends StatelessWidget {
  const _Legend({required this.focus, required this.onFocus});
  final InsightsFocus focus;
  final ValueChanged<InsightsFocus> onFocus;

  @override
  Widget build(BuildContext context) {
    Widget item(Color c, String label, InsightsFocus? f) => GestureDetector(
          onTap: f == null
              ? null
              : () => onFocus(focus == f ? InsightsFocus.all : f),
          child: Padding(
            padding: const EdgeInsets.only(right: 14, bottom: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                        color: c, borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 6),
                Text(label,
                    style: AppType.body(11.5, color: AppColors.textSecondary)),
              ],
            ),
          ),
        );
    return Wrap(
      children: [
        item(_cSolarUsed, 'Solar', InsightsFocus.solar),
        item(_cExport, 'Export', InsightsFocus.export),
        item(_cHomeLocal, 'Home use', null),
        item(_cImport, 'Grid import', null),
      ],
    );
  }
}

class _Bars extends StatelessWidget {
  const _Bars({required this.buckets, required this.focus});
  final List<Bucket> buckets;
  final InsightsFocus focus;

  @override
  Widget build(BuildContext context) {
    final maxY = buckets.fold<double>(
            1, (a, b) => [a, b.solar, b.home].reduce((x, y) => x > y ? x : y)) *
        1.15;
    final dimHome = focus != InsightsFocus.all;
    final dimSolarUsed = focus == InsightsFocus.export;
    final rodW = buckets.length > 6 ? 9.0 : 13.0;
    return Semantics(
      label: 'Solar, export, home use and grid import per period',
      child: BarChart(
        BarChartData(
          maxY: maxY,
          alignment: BarChartAlignment.spaceAround,
          barTouchData: const BarTouchData(enabled: false),
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) =>
                const FlLine(color: AppColors.track, strokeWidth: 1),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 34,
                getTitlesWidget: (v, m) => v == m.max
                    ? const SizedBox.shrink()
                    : Text(v.toStringAsFixed(0),
                        style: AppType.mono(9,
                            weight: FontWeight.w400,
                            color: AppColors.textTertiary)),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                getTitlesWidget: (v, m) {
                  final i = v.toInt();
                  if (i < 0 || i >= buckets.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(buckets[i].label,
                        style: AppType.body(10, color: AppColors.textTertiary)),
                  );
                },
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < buckets.length; i++)
              BarChartGroupData(
                x: i,
                barsSpace: 3,
                barRods: [
                  BarChartRodData(
                    toY: buckets[i].solar,
                    width: rodW,
                    borderRadius: BorderRadius.circular(3),
                    rodStackItems: [
                      BarChartRodStackItem(
                        0,
                        buckets[i].solar - buckets[i].export,
                        _cSolarUsed.withValues(alpha: dimSolarUsed ? 0.25 : 1),
                      ),
                      BarChartRodStackItem(buckets[i].solar - buckets[i].export,
                          buckets[i].solar, _cExport),
                    ],
                  ),
                  BarChartRodData(
                    toY: buckets[i].home,
                    width: rodW,
                    borderRadius: BorderRadius.circular(3),
                    rodStackItems: [
                      BarChartRodStackItem(
                        0,
                        buckets[i].home - buckets[i].import,
                        _cHomeLocal.withValues(alpha: dimHome ? 0.2 : 0.85),
                      ),
                      BarChartRodStackItem(
                        buckets[i].home - buckets[i].import,
                        buckets[i].home,
                        _cImport.withValues(alpha: dimHome ? 0.3 : 1),
                      ),
                    ],
                  ),
                ],
              ),
          ],
        ),
        duration: context.motion(AppMotion.slow),
      ),
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => SurfaceCard(
        radius: AppRadii.tile,
        padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
        semanticLabel: '$label $value',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: AppColors.mint),
            const SizedBox(height: 14),
            FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(value,
                    style: AppType.display(20,
                        weight: FontWeight.w500, tabular: true))),
            const SizedBox(height: 2),
            Text(label,
                style: AppType.body(11, color: AppColors.textSecondary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      );
}

/// Last 8 weeks as a heat strip; mint = fully independent day.
class _HeatStrip extends StatelessWidget {
  const _HeatStrip({required this.days, required this.onTap});
  final List<DailyStats> days;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final last = days.sublist(days.length > 56 ? days.length - 56 : 0);
    return SurfaceCard(
      radius: AppRadii.card,
      onTap: onTap,
      semanticLabel:
          'Independence history, last 8 weeks. Opens streak calendar.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, box) {
              const cols = 14;
              final cell = (box.maxWidth - (cols - 1) * 4) / cols;
              return Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  for (var i = 0; i < last.length; i++)
                    Container(
                      width: cell,
                      height: cell,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: i == last.length - 1
                            ? AppColors.mint.withValues(alpha: 0.35)
                            : last[i].independent
                                ? AppColors.mint
                                : AppColors.surfaceHigh,
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          Text(
            'Mint days ran on ≤ 5% grid import. Today is still in progress.',
            style: AppType.body(12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
