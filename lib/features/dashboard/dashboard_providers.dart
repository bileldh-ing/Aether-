import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';

enum StatPeriod { today, month, year }

extension StatPeriodLabel on StatPeriod {
  String get label => switch (this) {
        StatPeriod.today => 'Today',
        StatPeriod.month => 'This month',
        StatPeriod.year => 'This year',
      };
}

class StatPeriodController extends Notifier<StatPeriod> {
  @override
  StatPeriod build() => StatPeriod.month;
  void set(StatPeriod p) => state = p;
}

final statPeriodProvider = NotifierProvider<StatPeriodController, StatPeriod>(
    StatPeriodController.new);

/// (solar kWh, export kWh) for the chosen period.
final periodTotalsProvider = Provider<(double, double)>((ref) {
  final period = ref.watch(statPeriodProvider);
  final snap = ref.watch(snapshotProvider).value;
  if (snap == null) return (0, 0);
  switch (period) {
    case StatPeriod.today:
      return (snap.todaySolarKwh, snap.todayExportKwh);
    case StatPeriod.month:
      return (snap.monthSolarKwh, snap.monthExportKwh);
    case StatPeriod.year:
      final h = ref.watch(historyProvider);
      final year = snap.at.year;
      final past =
          h.where((d) => d.date.year == year && d.date.month != snap.at.month);
      final solar =
          past.fold<double>(0, (a, d) => a + d.solarKwh) + snap.monthSolarKwh;
      final export =
          past.fold<double>(0, (a, d) => a + d.exportKwh) + snap.monthExportKwh;
      return (solar, export);
  }
});

/// True when the phone has no internet (the local link to the Core can still work).
final offlineInternetProvider = StreamProvider<bool>((ref) async* {
  try {
    final c = Connectivity();
    final first = await c.checkConnectivity();
    yield first.every((r) => r == ConnectivityResult.none);
    yield* c.onConnectivityChanged
        .map((l) => l.every((r) => r == ConnectivityResult.none));
  } catch (_) {
    yield false;
  }
});
