import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../../../domain/entities/entities.dart';

/// Real BLE discovery + provisioning. Not used by default (see AppConfig).
///
/// GATT layout expected on the Core (to be confirmed with firmware team):
/// * Service  `AE7E0001-…`  Aether provisioning
/// * Char     `AE7E0002-…`  owner public key (write, 32 bytes Ed25519)
/// * Char     `AE7E0003-…`  Wi-Fi credentials (write, encrypted with session key)
/// * Char     `AE7E0004-…`  commission status (notify, 1 byte step + 1 byte %)
class BleProvisioningSource {
  static final provisioningService =
      Guid('ae7e0001-0000-1000-8000-00805f9b34fb');

  Stream<DiscoveredNode> scan(
      {Duration timeout = const Duration(seconds: 8)}) async* {
    if (await FlutterBluePlus.adapterState.first != BluetoothAdapterState.on) {
      throw const BleUnavailable();
    }
    await FlutterBluePlus.startScan(
        withServices: [provisioningService], timeout: timeout);
    await for (final results in FlutterBluePlus.scanResults) {
      for (final r in results) {
        final name = r.advertisementData.advName;
        if (!name.startsWith('NEXUS-CORE-')) continue;
        yield DiscoveredNode(
            id: name,
            mesh: '5.8 GHz Mesh',
            signalPercent: rssiToPercent(r.rssi));
      }
    }
  }

  /// Maps RSSI (dBm) to 0–100 %: −40 dBm or better is 100 %, −95 dBm is 0 %.
  static int rssiToPercent(int rssi) =>
      (((rssi + 95) / 55) * 100).clamp(0, 100).round();

  Future<void> stop() => FlutterBluePlus.stopScan();
}

class BleUnavailable implements Exception {
  const BleUnavailable();
  @override
  String toString() =>
      'Bluetooth is off. Turn it on in Control Center or Quick Settings, then try again.';
}
