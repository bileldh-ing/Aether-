import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;

import '../../../domain/entities/entities.dart';
import '../../../domain/metrics.dart';
import '../../../domain/repositories/power_node_repository.dart';
import 'day_curves.dart';

/// Realistic, deterministic simulation of an Aether Power Core (1,024 Wh)
/// with three microinverters. Runs entirely offline.
class MockPowerNodeSource implements PowerNodeRepository, ScenarioControl {
  MockPowerNodeSource({
    DateTime Function()? clock,
    int seed = 901,
    bool autoStart = true,
  })  : _clock = clock ?? DateTime.now,
        _rng = math.Random(seed) {
    _seed();
    if (autoStart) start();
  }

  static const capacityWh = 1024.0;
  static const efficiency = 0.96;
  static const maxChargeW = 1800.0;
  static const maxDischargeW = 2000.0;
  static const firmwareCurrent = 'v4.8.2-Aether';
  static const firmwareNext = 'v4.9.0-Aether';

  final DateTime Function() _clock;
  final math.Random _rng;
  Timer? _timer;
  Duration _offset = Duration.zero;

  // Live state.
  double _storedWh = capacityWh * 0.84; // ≈ 860 Wh (reference)
  double _soh = 100;
  EnergyMode _mode = EnergyMode.selfConsumption;
  int _reserve = 20;
  bool _autonomy = true;
  bool _stormGuard = false;
  bool _gridOnline = true;
  bool _nodeOnline = true;
  bool _updating = false;
  bool _lowReserveAnnounced = false;
  String _firmware = firmwareCurrent;
  String? _firmwareAvailable;
  PowerNode _node = const PowerNode(
    id: 'NEXUS-CORE-901',
    name: 'Garage Core',
    serial: 'AE4-2026-000901',
    firmware: firmwareCurrent,
    capacityWh: capacityWh,
    sohPercent: 100,
    signalPercent: 98,
    state: NodeState.idle,
  );

  // Energy counters (Wh).
  double _monthSolarWh = 0;
  double _monthExportWh = 0;
  double _todaySolarWh = 0;
  double _todayExportWh = 0;
  double _todayImportWh = 0;
  double _todayHomeWh = 0;
  late DateTime _today;
  final List<DailyStats> _history = [];
  final Queue<double> _loadWindow = Queue<double>(); // 15 min @ 1 Hz

  // Last computed flows.
  double _solarW = 0;
  double _loadW = 0;
  double _gridW = 0;
  double _batteryW = 0;

  final _snapshots = StreamController<EnergySnapshot>.broadcast();
  final _events = StreamController<NodeEvent>.broadcast();
  final _inverters = StreamController<List<MicroInverter>>.broadcast();
  EnergySnapshot? _last;

  DateTime get now => _clock().add(_offset);

  // ───────────────────────────── lifecycle

  void start() {
    _timer ??= Timer.periodic(const Duration(seconds: 1), (_) => tick());
  }

  void dispose() {
    _timer?.cancel();
    _snapshots.close();
    _events.close();
    _inverters.close();
  }

  /// One simulated second. Public for tests.
  void tick([double dtSeconds = 1]) {
    _step(dtSeconds);
    _emit();
  }

  // ───────────────────────────── seeding

  void _seed() {
    final t = now;
    _today = DateTime(t.year, t.month, t.day);
    _history
      ..clear()
      ..addAll(_generateHistory(t, 120));

    // Today so far, from the clear-sky model.
    final w = DayCurves.weather(_today);
    final m = DayCurves.minuteOf(t);
    var solar = 0.0;
    var home = 0.0;
    for (var x = 0.0; x < m; x += 5) {
      solar += DayCurves.solarShape(x) * DayCurves.peakW * w * 5 / 60;
      home += DayCurves.homeLoad(x) * 5 / 60;
    }
    _todaySolarWh = solar;
    _todayHomeWh = home;
    // Reference opens on 94.2 % self-consumption (see DECISIONS.md).
    _todayExportWh = solar * 0.058;
    _todayImportWh = home * 0.02;

    // Month to date matches the reference: 200 kWh harvested, 120 kWh exported.
    _monthSolarWh = 200000;
    _monthExportWh = 120000;

    _loadWindow.clear();
    for (var i = 0; i < 60; i++) {
      _loadWindow.add(DayCurves.homeLoad(m));
    }
    _computeFlows(t);
  }

  List<DailyStats> _generateHistory(DateTime t, int days) {
    final out = <DailyStats>[];
    final r = math.Random(4821);
    for (var i = days; i >= 1; i--) {
      final d = DateTime(t.year, t.month, t.day).subtract(Duration(days: i));
      final w = DayCurves.weather(d);
      final solar = 17.5 * w + r.nextDouble() * 2;
      final home = 11.0 + r.nextDouble() * 3.5;
      final bool independent;
      if (i <= 28) {
        independent = true;
      } else if (i == 29) {
        independent = false;
      } else {
        independent = r.nextDouble() > 0.35;
      }
      final import = independent ? home * (0.01 + r.nextDouble() * 0.03) : home * (0.09 + r.nextDouble() * 0.2);
      final export = solar * (0.45 + r.nextDouble() * 0.2);
      out.add(DailyStats(date: d, solarKwh: solar, homeKwh: home, importKwh: import, exportKwh: export));
    }
    return out;
  }

  // ───────────────────────────── physics

  int get _effectiveReserve {
    if (_stormGuard) return 100;
    if (_mode == EnergyMode.backupPriority) return math.max(_reserve, 80);
    return _reserve;
  }

  double _noise() => 1 + (_rng.nextDouble() * 2 - 1) * 0.02;

  void _computeFlows(DateTime t) {
    final m = DayCurves.minuteOf(t);
    _solarW = _nodeOnline ? DayCurves.solarShape(m) * DayCurves.peakW * DayCurves.weather(t) * _noise() : 0;
    _loadW = DayCurves.homeLoad(m) * _noise();
  }

  void _step(double dt) {
    final before = now;
    _offset += Duration(milliseconds: (dt * 1000).round());
    final t = now;
    if (t.day != before.day) _rollDay(t);
    _computeFlows(t);

    if (!_nodeOnline || _updating) {
      _batteryW = 0;
      _gridW = _gridOnline ? _loadW - _solarW : 0;
      return;
    }

    final h = dt / 3600;
    final surplus = _solarW - _loadW;
    var charge = 0.0;
    var discharge = 0.0;
    var grid = 0.0;

    if (surplus >= 0) {
      final roomW = (capacityWh - _storedWh) / (efficiency * h);
      final wantsCharge = _mode != EnergyMode.gridExport || _storedWh / capacityWh < 0.5;
      charge = wantsCharge ? math.min(surplus, math.min(maxChargeW, roomW)) : 0;
      final rest = surplus - charge;
      grid = _gridOnline ? -rest : 0; // curtailed when islanded
    } else {
      final deficit = -surplus;
      if (!_gridOnline) {
        final availW = _storedWh * efficiency / h;
        discharge = math.min(deficit, math.min(maxDischargeW, availW));
      } else {
        final floorPct = _autonomy ? _effectiveReserve : math.max(_effectiveReserve, 50);
        final hour = t.hour;
        final touBlocked = _mode == EnergyMode.timeOfUse && (hour < 17 || hour >= 22);
        final availW = math.max(0.0, (_storedWh - floorPct / 100 * capacityWh) * efficiency / h);
        discharge = touBlocked ? 0 : math.min(deficit, math.min(maxDischargeW, availW));
        grid = deficit - discharge;
      }
    }

    _storedWh = (_storedWh + charge * efficiency * h - discharge / efficiency * h).clamp(0, capacityWh);
    _batteryW = charge - discharge;
    _gridW = grid;

    _todaySolarWh += _solarW * h;
    _monthSolarWh += _solarW * h;
    _todayHomeWh += _loadW * h;
    if (grid < 0) {
      _todayExportWh += -grid * h;
      _monthExportWh += -grid * h;
    } else {
      _todayImportWh += grid * h;
    }

    _loadWindow.add(_loadW);
    while (_loadWindow.length > 900) {
      _loadWindow.removeFirst();
    }

    final socPct = _storedWh / capacityWh * 100;
    if (socPct < _reserve && !_lowReserveAnnounced) {
      _lowReserveAnnounced = true;
      _events.add(const NodeEvent(NodeEventType.lowReserve));
    } else if (socPct > _reserve + 5) {
      _lowReserveAnnounced = false;
    }
  }

  void _rollDay(DateTime t) {
    _history.add(DailyStats(
      date: _today,
      solarKwh: _todaySolarWh / 1000,
      homeKwh: _todayHomeWh / 1000,
      importKwh: _todayImportWh / 1000,
      exportKwh: _todayExportWh / 1000,
    ));
    if (t.month != _today.month) {
      _monthSolarWh = 0;
      _monthExportWh = 0;
    }
    _today = DateTime(t.year, t.month, t.day);
    _todaySolarWh = 0;
    _todayExportWh = 0;
    _todayImportWh = 0;
    _todayHomeWh = 0;
  }

  // ───────────────────────────── output

  EnergySnapshot _snapshot() {
    final soc = _storedWh / capacityWh;
    final state = Metrics.deriveState(
      nodeOnline: _nodeOnline,
      fault: false,
      updating: _updating,
      gridOnline: _gridOnline,
      soc: soc,
      reservePct: _reserve,
      batteryW: _batteryW,
      solarW: _solarW,
    );
    _node = _node.copyWith(state: state, firmware: _firmware, sohPercent: _soh);
    return EnergySnapshot(
      at: now,
      storedWh: _storedWh,
      soc: soc,
      solarW: _solarW,
      homeLoadW: _loadW,
      gridW: _gridW,
      batteryW: _batteryW,
      gridOnline: _gridOnline,
      mode: _mode,
      estRuntimeH: Metrics.runtimeHours(_storedWh, _loadWindow.toList()),
      state: state,
      nodeOnline: _nodeOnline,
      selfConsumptionPct: Metrics.selfConsumptionPct(solarWh: _todaySolarWh, exportWh: _todayExportWh),
      monthSolarKwh: _monthSolarWh / 1000,
      monthExportKwh: _monthExportWh / 1000,
      todaySolarKwh: _todaySolarWh / 1000,
      todayExportKwh: _todayExportWh / 1000,
      autonomy: _autonomy,
      reservePct: _reserve,
      sohPercent: _soh,
    );
  }

  void _emit() {
    if (_snapshots.isClosed) return;
    // When the node is offline the app keeps the last-known data.
    if (_nodeOnline || _last == null) {
      _last = _snapshot();
    } else {
      final l = _last!;
      _last = EnergySnapshot(
        at: l.at,
        storedWh: l.storedWh,
        soc: l.soc,
        solarW: l.solarW,
        homeLoadW: l.homeLoadW,
        gridW: l.gridW,
        batteryW: l.batteryW,
        gridOnline: l.gridOnline,
        mode: l.mode,
        estRuntimeH: l.estRuntimeH,
        state: NodeState.offline,
        nodeOnline: false,
        selfConsumptionPct: l.selfConsumptionPct,
        monthSolarKwh: l.monthSolarKwh,
        monthExportKwh: l.monthExportKwh,
        todaySolarKwh: l.todaySolarKwh,
        todayExportKwh: l.todayExportKwh,
        autonomy: l.autonomy,
        reservePct: l.reservePct,
        sohPercent: l.sohPercent,
      );
    }
    _snapshots.add(_last!);
    _inverters.add(_inverterList());
  }

  List<MicroInverter> _inverterList() {
    const shares = [0.38, 0.34, 0.28];
    const labels = ['Roof A', 'Roof B', 'Roof C'];
    return List.generate(3, (i) {
      final w = _solarW * shares[i];
      return MicroInverter(
        id: 'MI-${i + 1}',
        label: labels[i],
        watts: w,
        tempC: 17 + w / 1600 * 32,
        status: !_nodeOnline ? InverterStatus.idle : (w > 5 ? InverterStatus.producing : InverterStatus.idle),
      );
    });
  }

  // ───────────────────────────── PowerNodeRepository

  @override
  PowerNode get node => _node;

  @override
  Stream<EnergySnapshot> watch() async* {
    yield _last ?? (_last = _snapshot());
    yield* _snapshots.stream;
  }

  @override
  Stream<NodeEvent> events() => _events.stream;

  @override
  Stream<List<MicroInverter>> watchInverters() async* {
    yield _inverterList();
    yield* _inverters.stream;
  }

  @override
  List<double> todayProductionCurve() {
    final t = now;
    final w = DayCurves.weather(t);
    final m = DayCurves.minuteOf(t);
    final r = math.Random(t.day);
    return [
      for (var x = 0.0; x <= m; x += 5)
        DayCurves.solarShape(x) * DayCurves.peakW * w * (1 + (r.nextDouble() * 2 - 1) * 0.03),
    ];
  }

  @override
  List<DailyStats> history({int days = 120}) {
    final today = DailyStats(
      date: _today,
      solarKwh: _todaySolarWh / 1000,
      homeKwh: _todayHomeWh / 1000,
      importKwh: _todayImportWh / 1000,
      exportKwh: _todayExportWh / 1000,
    );
    final all = [..._history, today];
    return all.length <= days ? all : all.sublist(all.length - days);
  }

  @override
  Stream<DiscoveredNode> scan({Duration timeout = const Duration(seconds: 8)}) async* {
    await Future<void>.delayed(const Duration(milliseconds: 1600));
    final end = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(end)) {
      yield DiscoveredNode(id: _node.id, mesh: '5.8 GHz Mesh', signalPercent: 96 + _rng.nextInt(3));
      await Future<void>.delayed(const Duration(seconds: 1));
    }
  }

  @override
  Future<PairingResult> pair(DiscoveredNode node, {required String ownerName, required String publicKey}) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    return PairingResult(
      node: node,
      ownerName: ownerName,
      microinverters: 3,
      keyFingerprint: publicKey.length > 16 ? publicKey.substring(0, 16) : publicKey,
    );
  }

  @override
  Stream<CommissionProgress> commission() async* {
    const steps = [
      CommissionStep.registeringKey,
      CommissionStep.securingLink,
      CommissionStep.syncingBridge,
      CommissionStep.checkingFirmware,
    ];
    for (var i = 0; i < steps.length; i++) {
      for (var k = 0; k <= 10; k++) {
        yield CommissionProgress(steps[i], (i + k / 10) / steps.length);
        await Future<void>.delayed(const Duration(milliseconds: 85));
      }
    }
    yield const CommissionProgress(CommissionStep.done, 1);
  }

  @override
  Future<void> setMode(EnergyMode mode) async => _mode = mode;

  @override
  Future<void> setReserve(int percent) async => _reserve = percent.clamp(10, 100);

  @override
  Future<void> setAutonomy(bool enabled) async => _autonomy = enabled;

  @override
  Future<void> setStormGuard(bool enabled) async {
    _stormGuard = enabled;
    if (enabled) _events.add(const NodeEvent(NodeEventType.stormGuard));
  }

  @override
  Future<void> rename(String name) async => _node = _node.copyWith(name: name);

  @override
  Future<void> restart() async {
    _nodeOnline = false;
    _events.add(const NodeEvent(NodeEventType.offline));
    await Future<void>.delayed(const Duration(seconds: 3));
    _nodeOnline = true;
    _events.add(const NodeEvent(NodeEventType.online));
  }

  @override
  Future<FirmwareStatus> checkFirmware() async {
    await Future<void>.delayed(const Duration(milliseconds: 900));
    return FirmwareStatus(current: _firmware, available: _firmwareAvailable);
  }

  @override
  Stream<FirmwareStatus> installFirmware() async* {
    final target = _firmwareAvailable;
    if (target == null) {
      yield FirmwareStatus(current: _firmware, phase: FirmwarePhase.done, progress: 1);
      return;
    }
    _updating = true;
    for (var i = 0; i <= 20; i++) {
      yield FirmwareStatus(current: _firmware, available: target, phase: FirmwarePhase.downloading, progress: i / 20 * 0.6);
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }
    for (var i = 0; i <= 10; i++) {
      yield FirmwareStatus(current: _firmware, available: target, phase: FirmwarePhase.installing, progress: 0.6 + i / 10 * 0.3);
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    yield FirmwareStatus(current: _firmware, available: target, phase: FirmwarePhase.restarting, progress: 0.95);
    await Future<void>.delayed(const Duration(seconds: 2));
    _firmware = target;
    _firmwareAvailable = null;
    _updating = false;
    yield FirmwareStatus(current: _firmware, phase: FirmwarePhase.done, progress: 1);
  }

  // ───────────────────────────── ScenarioControl

  @override
  void triggerOutage() {
    if (!_gridOnline) return;
    _gridOnline = false;
    _events.add(NodeEvent(NodeEventType.outage, runtimeH: Metrics.runtimeHours(_storedWh, _loadWindow.toList())));
    _emit();
  }

  @override
  void restoreGrid() {
    if (_gridOnline) return;
    _gridOnline = true;
    _events.add(const NodeEvent(NodeEventType.restored));
    _emit();
  }

  @override
  void forceLowReserve() {
    _storedWh = capacityWh * (_reserve - 4).clamp(2, 100) / 100;
    _lowReserveAnnounced = true;
    _events.add(const NodeEvent(NodeEventType.lowReserve));
    _emit();
  }

  @override
  void announceFirmware() {
    _firmwareAvailable = firmwareNext;
    _events.add(const NodeEvent(NodeEventType.firmwareAvailable));
  }

  @override
  void toggleNodeOffline() {
    _nodeOnline = !_nodeOnline;
    _events.add(NodeEvent(_nodeOnline ? NodeEventType.online : NodeEventType.offline));
    _emit();
  }

  @override
  void fastForward(Duration d) {
    var left = d.inSeconds;
    while (left > 0) {
      final s = math.min(60, left);
      _step(s.toDouble());
      left -= s;
    }
    _emit();
  }
}
