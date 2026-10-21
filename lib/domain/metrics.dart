import 'entities/entities.dart';

/// Pure metric formulas (section 6.2). Unit-tested in test/metrics_test.dart.
abstract final class Metrics {
  static double storedWh(double soc, double capacityWh) => soc * capacityWh;

  /// Solar energy used on-site ÷ solar energy produced, in %.
  static double selfConsumptionPct({required double solarWh, required double exportWh}) {
    if (solarWh <= 0) return 0;
    return ((solarWh - exportWh) / solarWh * 100).clamp(0, 100).toDouble();
  }

  static String healthLabel(double soh) {
    if (soh >= 90) return 'Optimal';
    if (soh >= 80) return 'Good';
    return 'Service soon';
  }

  /// Consecutive independent days counted back from the most recent day.
  static int independenceStreak(List<DailyStats> daysOldestFirst) {
    var streak = 0;
    for (final d in daysOldestFirst.reversed) {
      if (!d.independent) break;
      streak++;
    }
    return streak;
  }

  /// storedWh ÷ rolling average home load (W) → hours.
  static double runtimeHours(double storedWh, List<double> recentLoadW) {
    if (recentLoadW.isEmpty) return 0;
    final avg = recentLoadW.reduce((a, b) => a + b) / recentLoadW.length;
    if (avg <= 1) return 0;
    return storedWh / avg;
  }

  static NodeState deriveState({
    required bool nodeOnline,
    required bool fault,
    required bool updating,
    required bool gridOnline,
    required double soc,
    required int reservePct,
    required double batteryW,
    required double solarW,
  }) {
    if (fault) return NodeState.fault;
    if (updating) return NodeState.updating;
    if (!nodeOnline) return NodeState.offline;
    if (soc * 100 < reservePct) return NodeState.lowReserve;
    if (!gridOnline) return NodeState.island;
    if (batteryW > 50 && solarW > 50) return NodeState.charging;
    if (batteryW < -50) return NodeState.discharging;
    return NodeState.idle;
  }

  static String pillLabel(NodeState s) => switch (s) {
        NodeState.idle => 'GRID ONLINE',
        NodeState.charging => 'CHARGING · SOLAR',
        NodeState.discharging => 'POWERING HOME',
        NodeState.island => 'ISLAND MODE',
        NodeState.lowReserve => 'LOW RESERVE',
        NodeState.pairing => 'PAIRING READY',
        NodeState.updating => 'UPDATING',
        NodeState.offline => 'NODE OFFLINE',
        NodeState.fault => 'ATTENTION NEEDED',
      };
}
