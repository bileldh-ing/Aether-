import 'package:aether_grid/data/sources/mock/day_curves.dart';
import 'package:aether_grid/data/sources/mock/mock_power_node_source.dart';
import 'package:aether_grid/domain/entities/entities.dart';
import 'package:flutter_test/flutter_test.dart';

MockPowerNodeSource _sim(DateTime at) =>
    MockPowerNodeSource(clock: () => at, autoStart: false);

/// Advances one simulated second and returns the snapshot it produced.
Future<EnergySnapshot> _latest(MockPowerNodeSource s) {
  s.tick();
  return s.watch().first;
}

void main() {
  group('DayCurves', () {
    test('no sun before sunrise or after sunset, full shape at peak', () {
      expect(DayCurves.solarShape(6 * 60), 0);
      expect(DayCurves.solarShape(20 * 60), 0);
      expect(
          DayCurves.solarShape(DayCurves.peakMin.toDouble()), closeTo(1, 1e-9));
    });
    test('home load has an evening peak above the night base', () {
      expect(DayCurves.homeLoad(19 * 60 + 40),
          greaterThan(DayCurves.homeLoad(3 * 60) * 3));
    });
    test('weather is deterministic per day', () {
      final d = DateTime(2026, 10, 21);
      expect(DayCurves.weather(d), DayCurves.weather(d));
      expect(DayCurves.weather(d), inInclusiveRange(0.72, 1.0));
    });
  });

  group('MockPowerNodeSource', () {
    late MockPowerNodeSource sim;
    tearDown(() => sim.dispose());

    test('boots with the reference node identity', () {
      sim = _sim(DateTime(2026, 10, 21, 12, 30));
      expect(sim.node.id, 'NEXUS-CORE-901');
      expect(sim.node.capacityWh, 1024);
      expect(sim.node.firmware, 'v4.8.2-Aether');
    });

    test('stored energy stays within 0..capacity and matches soc', () async {
      sim = _sim(DateTime(2026, 10, 21, 12, 30));
      final s = await _latest(sim);
      expect(s.storedWh, inInclusiveRange(0, 1024));
      expect(s.storedWh, closeTo(s.soc * 1024, 0.5));
    });

    test('midday sun produces solar power, night produces none', () async {
      sim = _sim(DateTime(2026, 10, 21, 12, 30));
      expect((await _latest(sim)).solarW, greaterThan(1500));
      sim.dispose();
      sim = _sim(DateTime(2026, 10, 21, 2));
      expect((await _latest(sim)).solarW, 0);
    });

    test('outage → island mode with runtime estimate, restore → grid back',
        () async {
      sim = _sim(DateTime(2026, 10, 21, 21));
      final events = <NodeEvent>[];
      final sub = sim.events().listen(events.add);

      sim.triggerOutage();
      final island = await _latest(sim);
      expect(island.gridOnline, isFalse);
      expect(island.state, NodeState.island);
      expect(island.gridW.abs(), lessThan(1));

      sim.restoreGrid();
      final back = await _latest(sim);
      expect(back.gridOnline, isTrue);
      expect(back.state, isNot(NodeState.island));

      await Future<void>.delayed(Duration.zero);
      expect(events.map((e) => e.type),
          [NodeEventType.outage, NodeEventType.restored]);
      expect(events.first.runtimeH, greaterThan(0));
      await sub.cancel();
    });

    test('outage is idempotent', () async {
      sim = _sim(DateTime(2026, 10, 21, 21));
      final events = <NodeEvent>[];
      final sub = sim.events().listen(events.add);
      sim
        ..triggerOutage()
        ..triggerOutage();
      await Future<void>.delayed(Duration.zero);
      expect(events.where((e) => e.type == NodeEventType.outage), hasLength(1));
      await sub.cancel();
    });

    test('low reserve scenario drops below the reserve threshold', () async {
      sim = _sim(DateTime(2026, 10, 21, 21));
      sim.forceLowReserve();
      final s = await _latest(sim);
      expect(s.soc * 100, lessThan(s.reservePct));
      expect(s.state, NodeState.lowReserve);
    });

    test('offline node keeps last-known data and reports offline', () async {
      sim = _sim(DateTime(2026, 10, 21, 12));
      final before = await _latest(sim);
      sim.toggleNodeOffline();
      final off = await _latest(sim);
      expect(off.nodeOnline, isFalse);
      expect(off.state, NodeState.offline);
      expect(off.storedWh, before.storedWh);
    });

    test('fast-forward advances the simulated clock', () {
      sim = _sim(DateTime(2026, 10, 21, 6));
      final t0 = sim.now;
      sim.fastForward(const Duration(hours: 6));
      expect(sim.now.difference(t0), const Duration(hours: 6));
    });

    test('history ends with today and respects the requested length', () {
      sim = _sim(DateTime(2026, 10, 21, 12));
      final h = sim.history(days: 30);
      expect(h, hasLength(30));
      expect(h.last.date.day, 21);
    });

    test('commissioning walks every step and finishes at 100 %', () async {
      sim = _sim(DateTime(2026, 10, 21, 12));
      final steps = await sim.commission().toList();
      expect(steps.last.step, CommissionStep.done);
      expect(steps.last.progress, 1);
      for (var i = 1; i < steps.length; i++) {
        expect(steps[i].progress, greaterThanOrEqualTo(steps[i - 1].progress));
      }
    });
  });
}
