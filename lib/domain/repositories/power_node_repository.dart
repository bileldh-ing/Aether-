import '../entities/entities.dart';

/// The only contract the UI knows about. Bound to the mock simulator by
/// default; swap the source in `AppConfig` for real BLE + live link.
abstract interface class PowerNodeRepository {
  // Discovery & provisioning (BLE).
  Stream<DiscoveredNode> scan({Duration timeout});
  Future<PairingResult> pair(DiscoveredNode node, {required String ownerName, required String publicKey});
  Stream<CommissionProgress> commission();

  // Live link.
  PowerNode get node;
  Stream<EnergySnapshot> watch();
  Stream<NodeEvent> events();
  Stream<List<MicroInverter>> watchInverters();
  List<double> todayProductionCurve(); // 5-min W samples since midnight
  List<DailyStats> history({int days});

  // Commands (signed with the owner key on a real node).
  Future<void> setMode(EnergyMode mode);
  Future<void> setReserve(int percent);
  Future<void> setAutonomy(bool enabled);
  Future<void> setStormGuard(bool enabled);
  Future<void> rename(String name);
  Future<void> restart();

  // Firmware.
  Future<FirmwareStatus> checkFirmware();
  Stream<FirmwareStatus> installFirmware();
}

/// Debug-only scenario hooks (long-press the avatar).
abstract interface class ScenarioControl {
  void triggerOutage();
  void restoreGrid();
  void forceLowReserve();
  void announceFirmware();
  void toggleNodeOffline();
  void fastForward(Duration d);
}
