import 'package:aether_grid/domain/entities/entities.dart';
import 'package:aether_grid/domain/metrics.dart';
import 'package:flutter_test/flutter_test.dart';

DailyStats _day(int i, {required double home, required double import}) =>
    DailyStats(
      date: DateTime(2026, 10, 1).add(Duration(days: i)),
      solarKwh: 14,
      homeKwh: home,
      importKwh: import,
      exportKwh: 2,
    );

void main() {
  group('Metrics.storedWh', () {
    test('84 % of 1,024 Wh is ≈ 860 Wh (reference screen)', () {
      expect(Metrics.storedWh(0.84, 1024), closeTo(860.16, 0.001));
    });
    test('empty and full', () {
      expect(Metrics.storedWh(0, 1024), 0);
      expect(Metrics.storedWh(1, 1024), 1024);
    });
  });

  group('Metrics.selfConsumptionPct', () {
    test('no production yields 0 %', () {
      expect(Metrics.selfConsumptionPct(solarWh: 0, exportWh: 0), 0);
    });
    test('25 % exported means 75 % self-consumed', () {
      expect(Metrics.selfConsumptionPct(solarWh: 4000, exportWh: 1000), 75);
    });
    test('clamped to 0..100', () {
      expect(Metrics.selfConsumptionPct(solarWh: 1000, exportWh: 1500), 0);
      expect(Metrics.selfConsumptionPct(solarWh: 1000, exportWh: -10), 100);
    });
  });

  group('Metrics.healthLabel', () {
    test('thresholds', () {
      expect(Metrics.healthLabel(100), 'Optimal');
      expect(Metrics.healthLabel(90), 'Optimal');
      expect(Metrics.healthLabel(89.9), 'Good');
      expect(Metrics.healthLabel(80), 'Good');
      expect(Metrics.healthLabel(79.9), 'Service soon');
    });
  });

  group('Metrics.independenceStreak', () {
    test(
        'counts back from the most recent day and stops at first dependent day',
        () {
      final days = [
        _day(0, home: 10, import: 0),
        _day(1, home: 10, import: 4), // dependent
        _day(2, home: 10, import: 0.2),
        _day(3, home: 10, import: 0.5), // exactly 5 % → independent
        _day(4, home: 10, import: 0),
      ];
      expect(Metrics.independenceStreak(days), 3);
    });
    test('empty history and a dependent last day both give 0', () {
      expect(Metrics.independenceStreak(const []), 0);
      expect(
          Metrics.independenceStreak(
              [_day(0, home: 10, import: 0), _day(1, home: 10, import: 3)]),
          0);
    });
  });

  group('Metrics.runtimeHours', () {
    test('stored energy divided by average load', () {
      expect(Metrics.runtimeHours(860, [400, 460, 430]), closeTo(2.0, 0.001));
    });
    test('guards against empty or near-zero load', () {
      expect(Metrics.runtimeHours(860, const []), 0);
      expect(Metrics.runtimeHours(860, [0, 0.5]), 0);
    });
  });

  group('Metrics.deriveState', () {
    NodeState derive({
      bool nodeOnline = true,
      bool fault = false,
      bool updating = false,
      bool gridOnline = true,
      double soc = 0.84,
      int reserve = 20,
      double batteryW = 0,
      double solarW = 0,
    }) =>
        Metrics.deriveState(
          nodeOnline: nodeOnline,
          fault: fault,
          updating: updating,
          gridOnline: gridOnline,
          soc: soc,
          reservePct: reserve,
          batteryW: batteryW,
          solarW: solarW,
        );

    test('priority: fault > updating > offline > low reserve > island', () {
      expect(derive(fault: true, updating: true, nodeOnline: false),
          NodeState.fault);
      expect(derive(updating: true, nodeOnline: false), NodeState.updating);
      expect(derive(nodeOnline: false, soc: 0.05), NodeState.offline);
      expect(derive(soc: 0.10, gridOnline: false), NodeState.lowReserve);
      expect(derive(gridOnline: false), NodeState.island);
    });
    test('charging, discharging and idle', () {
      expect(derive(batteryW: 900, solarW: 2400), NodeState.charging);
      expect(derive(batteryW: -600), NodeState.discharging);
      expect(derive(batteryW: 20, solarW: 2400), NodeState.idle);
    });
    test('every state has a pill label', () {
      for (final s in NodeState.values) {
        expect(Metrics.pillLabel(s), isNotEmpty);
      }
    });
  });

  group('DailyStats', () {
    test('self-sufficiency and independence', () {
      final d = DailyStats(
          date: DateTime(2026, 10, 20),
          solarKwh: 12,
          homeKwh: 10,
          importKwh: 1,
          exportKwh: 3);
      expect(d.selfConsumptionPct, closeTo(75, 0.001));
      expect(d.selfSufficiencyPct, closeTo(90, 0.001));
      expect(d.independent, isFalse);
    });
  });
}
