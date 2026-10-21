import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/services/notification_service.dart';
import '../core/services/security_service.dart';
import '../core/utils/format.dart';
import '../data/sources/mock/mock_power_node_source.dart';
import '../domain/entities/entities.dart';
import '../domain/metrics.dart';
import '../domain/repositories/power_node_repository.dart';
import 'brand.dart';
import 'config.dart';

// ───────────────────────────── infrastructure (overridden in main / tests)

final appConfigProvider = Provider<AppConfig>((ref) => const AppConfig());

final sharedPrefsProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('Override sharedPrefsProvider in main()'),
);

final secureStoreProvider =
    Provider<SecureStore>((ref) => const PlatformSecureStore());

final securityServiceProvider = Provider<SecurityService>(
  (ref) => SecurityService(ref.watch(secureStoreProvider)),
);

final notificationServiceProvider = Provider<NotificationService>((ref) {
  final s = NotificationService(
      enabled: ref.watch(appConfigProvider).enableNotifications);
  unawaited(s.init());
  return s;
});

final powerNodeRepositoryProvider = Provider<PowerNodeRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  if (!config.useMockDevice) {
    // Real node: compose BleProvisioningSource + LiveLinkSource here.
    throw UnimplementedError(
        'Live repository: see README › Swapping in real hardware.');
  }
  final mock = MockPowerNodeSource();
  ref.onDispose(mock.dispose);
  return mock;
});

/// Debug scenario hooks (null on real hardware).
final scenarioProvider = Provider<ScenarioControl?>((ref) {
  final repo = ref.watch(powerNodeRepositoryProvider);
  return repo is ScenarioControl ? repo as ScenarioControl : null;
});

// ───────────────────────────── live data

final snapshotProvider = StreamProvider<EnergySnapshot>(
  (ref) => ref.watch(powerNodeRepositoryProvider).watch(),
);

final invertersProvider = StreamProvider<List<MicroInverter>>(
  (ref) => ref.watch(powerNodeRepositoryProvider).watchInverters(),
);

/// Changes once per simulated day; used to recompute history-derived values.
final dayKeyProvider = Provider<int>((ref) {
  final at = ref.watch(snapshotProvider.select((s) => s.value?.at));
  final t = at ?? DateTime.now();
  return t.year * 10000 + t.month * 100 + t.day;
});

final historyProvider = Provider<List<DailyStats>>((ref) {
  ref.watch(dayKeyProvider);
  return ref.watch(powerNodeRepositoryProvider).history(days: 120);
});

/// Completed days only (today is still in progress).
final streakProvider = Provider<int>((ref) {
  final h = ref.watch(historyProvider);
  return Metrics.independenceStreak(h.isEmpty ? h : h.sublist(0, h.length - 1));
});

// ───────────────────────────── toasts

@immutable
class Toast {
  const Toast(this.message, {this.tone = ToastTone.neutral});
  final String message;
  final ToastTone tone;
}

enum ToastTone { neutral, success, warning }

class ToastController extends Notifier<Toast?> {
  Timer? _t;
  @override
  Toast? build() {
    ref.onDispose(() => _t?.cancel());
    return null;
  }

  void show(String message, {ToastTone tone = ToastTone.neutral}) {
    state = Toast(message, tone: tone);
    _t?.cancel();
    _t = Timer(const Duration(milliseconds: 2600), () => state = null);
  }
}

final toastProvider =
    NotifierProvider<ToastController, Toast?>(ToastController.new);

// ───────────────────────────── settings

@immutable
class AppSettings {
  const AppSettings({
    this.paired = false,
    this.mode = EnergyMode.selfConsumption,
    this.reserve = 20,
    this.stormGuard = false,
    this.autonomy = true,
    this.biometricLock = false,
    this.localAuthOnly = true,
    this.currency = 'EUR',
    this.notifyOutage = true,
    this.notifyLowReserve = true,
    this.notifyFirmware = true,
    this.members = const [
      Member(id: 'm1', name: AppBrand.ownerName, role: Role.admin, you: true),
      Member(id: 'm2', name: 'Lucía Ferrer', role: Role.member),
      Member(id: 'm3', name: 'Ana & José Ferrer', role: Role.viewer),
    ],
  });

  final bool paired;
  final EnergyMode mode;
  final int reserve;
  final bool stormGuard;
  final bool autonomy;
  final bool biometricLock;
  final bool localAuthOnly;
  final String currency;
  final bool notifyOutage;
  final bool notifyLowReserve;
  final bool notifyFirmware;
  final List<Member> members;

  String get currencySymbol => switch (currency) {
        'USD' => r'$',
        'TND' => 'DT ',
        'GBP' => '£',
        _ => '€'
      };

  AppSettings copyWith({
    bool? paired,
    EnergyMode? mode,
    int? reserve,
    bool? stormGuard,
    bool? autonomy,
    bool? biometricLock,
    bool? localAuthOnly,
    String? currency,
    bool? notifyOutage,
    bool? notifyLowReserve,
    bool? notifyFirmware,
    List<Member>? members,
  }) =>
      AppSettings(
        paired: paired ?? this.paired,
        mode: mode ?? this.mode,
        reserve: reserve ?? this.reserve,
        stormGuard: stormGuard ?? this.stormGuard,
        autonomy: autonomy ?? this.autonomy,
        biometricLock: biometricLock ?? this.biometricLock,
        localAuthOnly: localAuthOnly ?? this.localAuthOnly,
        currency: currency ?? this.currency,
        notifyOutage: notifyOutage ?? this.notifyOutage,
        notifyLowReserve: notifyLowReserve ?? this.notifyLowReserve,
        notifyFirmware: notifyFirmware ?? this.notifyFirmware,
        members: members ?? this.members,
      );
}

class SettingsController extends Notifier<AppSettings> {
  SharedPreferences get _p => ref.read(sharedPrefsProvider);
  PowerNodeRepository get _repo => ref.read(powerNodeRepositoryProvider);

  @override
  AppSettings build() {
    final p = ref.watch(sharedPrefsProvider);
    final s = AppSettings(
      paired: p.getBool('paired') ?? false,
      mode: EnergyMode.values[
          (p.getInt('mode') ?? 0).clamp(0, EnergyMode.values.length - 1)],
      reserve: p.getInt('reserve') ?? 20,
      stormGuard: p.getBool('stormGuard') ?? false,
      autonomy: p.getBool('autonomy') ?? true,
      biometricLock: p.getBool('biometricLock') ?? false,
      currency: p.getString('currency') ?? 'EUR',
    );
    // Push persisted settings to the node.
    final repo = ref.read(powerNodeRepositoryProvider);
    unawaited(repo.setMode(s.mode));
    unawaited(repo.setReserve(s.reserve));
    unawaited(repo.setAutonomy(s.autonomy));
    return s;
  }

  Future<void> setPaired(bool v) async {
    state = state.copyWith(paired: v);
    await _p.setBool('paired', v);
  }

  Future<void> setMode(EnergyMode m) async {
    state = state.copyWith(mode: m);
    await _repo.setMode(m);
    await _p.setInt('mode', m.index);
    ref.read(toastProvider.notifier).show('${m.label} mode on');
  }

  Future<void> setReserve(int v, {bool announce = true}) async {
    state = state.copyWith(reserve: v);
    await _repo.setReserve(v);
    await _p.setInt('reserve', v);
    if (announce) ref.read(toastProvider.notifier).show(Copy.reserveSet(v));
  }

  Future<void> setStormGuard(bool v) async {
    state = state.copyWith(stormGuard: v);
    await _repo.setStormGuard(v);
    await _p.setBool('stormGuard', v);
  }

  Future<void> setAutonomy(bool v) async {
    state = state.copyWith(autonomy: v);
    await _repo.setAutonomy(v);
    await _p.setBool('autonomy', v);
    ref
        .read(toastProvider.notifier)
        .show(v ? Copy.autonomyActive : Copy.autonomyPaused);
  }

  Future<void> setBiometric(bool v) async {
    state = state.copyWith(biometricLock: v);
    await _p.setBool('biometricLock', v);
  }

  Future<void> setCurrency(String c) async {
    state = state.copyWith(currency: c);
    await _p.setString('currency', c);
  }

  void setNotify({bool? outage, bool? lowReserve, bool? firmware}) {
    state = state.copyWith(
        notifyOutage: outage,
        notifyLowReserve: lowReserve,
        notifyFirmware: firmware);
  }

  void setLocalAuthOnly(bool v) => state = state.copyWith(localAuthOnly: v);

  void invite(String name, Role role) {
    state = state.copyWith(members: [
      ...state.members,
      Member(id: 'm${state.members.length + 1}', name: name, role: role),
    ]);
  }

  void setRole(String id, Role role) {
    state = state.copyWith(members: [
      for (final m in state.members)
        m.id == id && !m.you ? Member(id: m.id, name: m.name, role: role) : m,
    ]);
  }

  Future<void> reset() async {
    await _p.clear();
    state = const AppSettings();
  }
}

final settingsProvider =
    NotifierProvider<SettingsController, AppSettings>(SettingsController.new);

// ───────────────────────────── alerts (events → alerts, push, toasts)

@immutable
class AlertsState {
  const AlertsState({required this.items, this.unread = false});
  final List<AppAlert> items;
  final bool unread;
}

class AlertsController extends Notifier<AlertsState> {
  int _seq = 0;

  @override
  AlertsState build() {
    final repo = ref.watch(powerNodeRepositoryProvider);
    final sub = repo.events().listen(_onEvent);
    ref.onDispose(sub.cancel);
    final now = DateTime.now();
    return AlertsState(items: [
      AppAlert(
        id: 'seed-1',
        type: AlertType.restored,
        title: 'Grid restored',
        detail: 'Back on the grid after 2 h 14 min in island mode.',
        at: now.subtract(const Duration(hours: 27)),
      ),
      AppAlert(
        id: 'seed-2',
        type: AlertType.member,
        title: 'New member joined',
        detail: 'Lucía Ferrer joined as Member.',
        at: now.subtract(const Duration(days: 3)),
      ),
    ]);
  }

  void _add(AlertType type, String title, String detail) {
    state = AlertsState(
      items: [
        AppAlert(
            id: 'a${_seq++}',
            type: type,
            title: title,
            detail: detail,
            at: DateTime.now()),
        ...state.items,
      ],
      unread: true,
    );
  }

  void _onEvent(NodeEvent e) {
    final settings = ref.read(settingsProvider);
    final push = ref.read(notificationServiceProvider);
    final toast = ref.read(toastProvider.notifier);
    switch (e.type) {
      case NodeEventType.outage:
        final rt = Fmt.hours(e.runtimeH ?? 0);
        _add(AlertType.outage, 'Grid outage',
            'Running on stored energy · about $rt left.');
        toast.show('Island mode · about $rt of backup',
            tone: ToastTone.warning);
        if (settings.notifyOutage)
          unawaited(push.show('Grid outage detected', Copy.outageBody(rt)));
      case NodeEventType.restored:
        _add(AlertType.restored, 'Grid restored',
            'Your Core is back on the grid and recharging.');
        toast.show(Copy.gridRestored, tone: ToastTone.success);
      case NodeEventType.lowReserve:
        _add(AlertType.lowReserve, 'Low reserve',
            'Stored energy fell below your ${settings.reserve}% backup reserve.');
        toast.show('Low reserve · below ${settings.reserve}%',
            tone: ToastTone.warning);
        if (settings.notifyLowReserve) {
          unawaited(push.show('Low reserve',
              'Your Power Core is below the ${settings.reserve}% backup reserve.'));
        }
      case NodeEventType.firmwareAvailable:
        _add(AlertType.firmware, 'Firmware available',
            '${MockPowerNodeSource.firmwareNext} is ready to install.');
        if (settings.notifyFirmware) {
          unawaited(push.show('Update available',
              'Firmware ${MockPowerNodeSource.firmwareNext} is ready for your Power Core.'));
        }
      case NodeEventType.stormGuard:
        _add(AlertType.stormGuard, 'Storm Guard active',
            'Reserve raised to 100% ahead of bad weather.');
      case NodeEventType.offline:
        toast.show('Power Core offline · showing last-known data',
            tone: ToastTone.warning);
      case NodeEventType.online:
        toast.show('Power Core back online', tone: ToastTone.success);
    }
  }

  void markRead() => state = AlertsState(items: state.items);

  void dismiss(String id) => state = AlertsState(
      items: state.items.where((a) => a.id != id).toList(),
      unread: state.unread);
}

final alertsProvider =
    NotifierProvider<AlertsController, AlertsState>(AlertsController.new);

// ───────────────────────────── firmware

class FirmwareController extends Notifier<FirmwareStatus> {
  StreamSubscription<FirmwareStatus>? _sub;

  @override
  FirmwareStatus build() {
    ref.onDispose(() => _sub?.cancel());
    return FirmwareStatus(
        current: ref.read(powerNodeRepositoryProvider).node.firmware);
  }

  Future<void> check() async {
    final s = await ref.read(powerNodeRepositoryProvider).checkFirmware();
    state = s;
    if (s.available == null)
      ref
          .read(toastProvider.notifier)
          .show('Firmware ${s.current} is up to date');
  }

  void install() {
    _sub?.cancel();
    _sub = ref.read(powerNodeRepositoryProvider).installFirmware().listen((s) {
      state = s;
      if (s.phase == FirmwarePhase.done) {
        ref
            .read(toastProvider.notifier)
            .show(Copy.updateInstalled, tone: ToastTone.success);
      }
    });
  }
}

final firmwareProvider = NotifierProvider<FirmwareController, FirmwareStatus>(
    FirmwareController.new);
