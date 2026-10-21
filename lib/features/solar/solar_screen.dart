import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/design_system/design_system.dart';
import '../../core/utils/format.dart';
import '../../data/sources/mock/day_curves.dart';
import '../../domain/entities/entities.dart';

/// Production curve, refreshed every 5 minutes of wall time.
final productionCurveProvider = StreamProvider<List<double>>((ref) async* {
  final repo = ref.watch(powerNodeRepositoryProvider);
  yield repo.todayProductionCurve();
  yield* Stream.periodic(
      const Duration(minutes: 5), (_) => repo.todayProductionCurve());
});

@immutable
class SolarForecast {
  const SolarForecast(this.kwh, this.windowStart, this.windowEnd);
  final double kwh;
  final String windowStart;
  final String windowEnd;
}

/// Tomorrow's expected harvest and best sun window (shape ≥ 75 % of peak).
final forecastProvider = Provider<SolarForecast>((ref) {
  ref.watch(dayKeyProvider);
  final t = DateTime.now().add(const Duration(days: 1));
  final w = DayCurves.weather(t);
  var kwh = 0.0;
  double? start;
  double? end;
  for (var m = 0.0; m < 1440; m += 5) {
    final s = DayCurves.solarShape(m);
    kwh += s * DayCurves.peakW * w * 5 / 60 / 1000;
    if (s >= 0.75) {
      start ??= m;
      end = m;
    }
  }
  String hm(double m) =>
      '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).round().toString().padLeft(2, '0')}';
  return SolarForecast(kwh, hm(start ?? 600), hm(end ?? 900));
});

class SolarScreen extends ConsumerWidget {
  const SolarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todayKwh =
        ref.watch(snapshotProvider.select((s) => s.value?.todaySolarKwh ?? 0));
    final solarW = ref.watch(snapshotProvider
        .select((s) => ((s.value?.solarW ?? 0) / 10).round() * 10.0));
    final curve = ref.watch(productionCurveProvider).value ?? const <double>[];
    final inverters =
        ref.watch(invertersProvider).value ?? const <MicroInverter>[];
    final f = ref.watch(forecastProvider);

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
          const TabTitle(
              title: 'Solar',
              subtitle: '3 microinverters · Solar Inverter Bridge'),
          const SizedBox(height: 18),
          SurfaceCard(
            radius: AppRadii.hero,
            padding: const EdgeInsets.fromLTRB(22, 22, 14, 14),
            semanticLabel:
                'Today ${Fmt.kwh(todayKwh)} kilowatt-hours harvested, producing ${solarW.round()} watts now',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const MicroLabel('HARVESTED TODAY'),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    AnimatedNumber(
                      value: todayKwh,
                      style: AppType.display(48,
                          weight: FontWeight.w300, tabular: true),
                      format: (v) => v.toStringAsFixed(1),
                    ),
                    const SizedBox(width: 8),
                    Text('kWh',
                        style:
                            AppType.body(14, color: AppColors.textSecondary)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                          color: AppColors.mintDim,
                          borderRadius: BorderRadius.circular(AppRadii.pill)),
                      child: Row(
                        children: [
                          const Icon(AppIcons.sunFill,
                              size: 13, color: AppColors.amber),
                          const SizedBox(width: 6),
                          Text(Fmt.watts(solarW),
                              style: AppType.mono(12, color: AppColors.mint)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
                const SizedBox(height: 18),
                SizedBox(height: 170, child: _ProductionChart(curve: curve)),
              ],
            ),
          ),
          const SectionHeader('Microinverters'),
          for (final inv in inverters)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _InverterTile(inv: inv),
            ),
          const SectionHeader('Tomorrow'),
          SurfaceCard(
            radius: AppRadii.card,
            child: Row(
              children: [
                const TintedIcon(
                    icon: AppIcons.sunFill,
                    color: AppColors.amber,
                    size: 44,
                    circle: true),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${f.kwh.toStringAsFixed(1)} kWh expected',
                          style: AppType.body(15, weight: FontWeight.w600)),
                      const SizedBox(height: 3),
                      Text(
                        'Best sun ${f.windowStart} – ${f.windowEnd}. Run the dishwasher then.',
                        style:
                            AppType.body(12.5, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductionChart extends StatelessWidget {
  const _ProductionChart({required this.curve});
  final List<double> curve;

  @override
  Widget build(BuildContext context) {
    final spots = [
      for (var i = 0; i < curve.length; i++) FlSpot(i * 5 / 60, curve[i] / 1000)
    ];
    final nowX = spots.isEmpty ? 12.0 : spots.last.x;
    final nowY = spots.isEmpty ? 0.0 : spots.last.y;
    return Semantics(
      label: 'Production today, peaking near 12:30',
      child: LineChart(
        LineChartData(
          minX: 5,
          maxX: 21,
          minY: 0,
          maxY: 4.6,
          clipData: const FlClipData.all(),
          gridData: FlGridData(
            drawVerticalLine: false,
            horizontalInterval: 1,
            getDrawingHorizontalLine: (_) =>
                const FlLine(color: AppColors.track, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          lineTouchData: const LineTouchData(enabled: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: 1,
                getTitlesWidget: (v, m) => Text('${v.toInt()}kW',
                    style: AppType.mono(9,
                        weight: FontWeight.w400,
                        color: AppColors.textTertiary)),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 4,
                reservedSize: 22,
                getTitlesWidget: (v, m) => Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('${v.toInt().toString().padLeft(2, '0')}:00',
                      style: AppType.mono(9,
                          weight: FontWeight.w400,
                          color: AppColors.textTertiary)),
                ),
              ),
            ),
          ),
          extraLinesData: ExtraLinesData(
            verticalLines: [
              VerticalLine(
                  x: nowX,
                  color: AppColors.amber.withValues(alpha: 0.6),
                  strokeWidth: 1,
                  dashArray: [3, 3]),
            ],
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.2,
              color: AppColors.mint,
              barWidth: 2,
              dotData: FlDotData(
                show: true,
                checkToShowDot: (s, _) => s.x == nowX && s.y == nowY,
                getDotPainter: (a, b, c, d) => FlDotCirclePainter(
                    radius: 4,
                    color: AppColors.amber,
                    strokeWidth: 3,
                    strokeColor: AppColors.amber.withValues(alpha: 0.3)),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.mint.withValues(alpha: 0.28),
                    AppColors.mint.withValues(alpha: 0)
                  ],
                ),
              ),
            ),
          ],
        ),
        duration: Duration.zero,
      ),
    );
  }
}

class _InverterTile extends StatelessWidget {
  const _InverterTile({required this.inv});
  final MicroInverter inv;

  @override
  Widget build(BuildContext context) {
    final color = switch (inv.status) {
      InverterStatus.producing => AppColors.mint,
      InverterStatus.idle => AppColors.textSecondary,
      InverterStatus.fault => AppColors.danger,
    };
    return SurfaceCard(
      radius: AppRadii.tile,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      semanticLabel:
          '${inv.label}, ${inv.status.label}, ${inv.watts.round()} watts, ${inv.tempC.round()} degrees',
      child: Row(
        children: [
          TintedIcon(icon: AppIcons.inverter, color: color, size: 38),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(inv.label,
                    style: AppType.body(14, weight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text('${inv.id} · ${inv.tempC.toStringAsFixed(0)} °C panel',
                    style: AppType.body(12, color: AppColors.textSecondary)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              AnimatedNumber(
                value: inv.watts,
                countUp: false,
                style: AppType.mono(14),
                format: (v) => '${v.round()} W',
              ),
              const SizedBox(height: 2),
              Text(inv.status.label,
                  style: AppType.body(11.5,
                      weight: FontWeight.w600, color: color)),
            ],
          ),
        ],
      ),
    );
  }
}
