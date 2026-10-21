import 'package:flutter/foundation.dart';

/// Device state, mirrored 1:1 by the physical LED ring and the in-app glow.
enum NodeState {
  idle,
  charging,
  discharging,
  island,
  lowReserve,
  pairing,
  updating,
  offline,
  fault,
}

enum EnergyMode { selfConsumption, backupPriority, gridExport, timeOfUse }

extension EnergyModeLabel on EnergyMode {
  String get label => switch (this) {
        EnergyMode.selfConsumption => 'Self-Consumption',
        EnergyMode.backupPriority => 'Backup Priority',
        EnergyMode.gridExport => 'Grid Export',
        EnergyMode.timeOfUse => 'Time-of-Use',
      };

  String get detail => switch (this) {
        EnergyMode.selfConsumption => 'Use your own solar first, store the rest.',
        EnergyMode.backupPriority => 'Keep the Core full and ready for outages.',
        EnergyMode.gridExport => 'Sell surplus to the grid as soon as it is produced.',
        EnergyMode.timeOfUse => 'Charge off-peak, power the home at peak tariffs.',
      };
}

enum Role { admin, member, viewer }

extension RoleLabel on Role {
  String get label => switch (this) {
        Role.admin => 'Admin',
        Role.member => 'Member',
        Role.viewer => 'Viewer',
      };
  bool get canControl => this != Role.viewer;
}

@immutable
class PowerNode {
  const PowerNode({
    required this.id,
    required this.name,
    required this.serial,
    required this.firmware,
    required this.capacityWh,
    required this.sohPercent,
    required this.signalPercent,
    required this.state,
  });

  final String id;
  final String name;
  final String serial;
  final String firmware;
  final double capacityWh;
  final double sohPercent;
  final int signalPercent;
  final NodeState state;

  PowerNode copyWith({
    String? name,
    String? firmware,
    double? sohPercent,
    int? signalPercent,
    NodeState? state,
  }) =>
      PowerNode(
        id: id,
        name: name ?? this.name,
        serial: serial,
        firmware: firmware ?? this.firmware,
        capacityWh: capacityWh,
        sohPercent: sohPercent ?? this.sohPercent,
        signalPercent: signalPercent ?? this.signalPercent,
        state: state ?? this.state,
      );
}

/// One live telemetry sample (1 Hz).
@immutable
class EnergySnapshot {
  const EnergySnapshot({
    required this.at,
    required this.storedWh,
    required this.soc,
    required this.solarW,
    required this.homeLoadW,
    required this.gridW,
    required this.batteryW,
    required this.gridOnline,
    required this.mode,
    required this.estRuntimeH,
    required this.state,
    required this.nodeOnline,
    required this.selfConsumptionPct,
    required this.monthSolarKwh,
    required this.monthExportKwh,
    required this.todaySolarKwh,
    required this.todayExportKwh,
    required this.autonomy,
    required this.reservePct,
    required this.sohPercent,
  });

  final DateTime at;
  final double storedWh;

  /// 0..1
  final double soc;
  final double solarW;
  final double homeLoadW;

  /// + import / − export
  final double gridW;

  /// + charge / − discharge
  final double batteryW;
  final bool gridOnline;
  final EnergyMode mode;
  final double estRuntimeH;
  final NodeState state;
  final bool nodeOnline;
  final double selfConsumptionPct;
  final double monthSolarKwh;
  final double monthExportKwh;
  final double todaySolarKwh;
  final double todayExportKwh;
  final bool autonomy;
  final int reservePct;
  final double sohPercent;
}

@immutable
class DailyStats {
  const DailyStats({
    required this.date,
    required this.solarKwh,
    required this.homeKwh,
    required this.importKwh,
    required this.exportKwh,
  });

  final DateTime date;
  final double solarKwh;
  final double homeKwh;
  final double importKwh;
  final double exportKwh;

  double get selfConsumptionPct =>
      solarKwh <= 0 ? 0 : ((solarKwh - exportKwh) / solarKwh * 100).clamp(0, 100);
  double get selfSufficiencyPct =>
      homeKwh <= 0 ? 0 : ((homeKwh - importKwh) / homeKwh * 100).clamp(0, 100);
  bool get independent => homeKwh > 0 && importKwh <= homeKwh * 0.05;

  /// Grid emission factor 0.42 kg CO₂/kWh (EU average, see DECISIONS.md).
  double get co2KgAvoided => (solarKwh - exportKwh).clamp(0, double.infinity) * 0.42 + exportKwh * 0.42;

  /// Avoided import at 0.28/kWh + export at 0.08/kWh.
  double get moneySaved => (homeKwh - importKwh).clamp(0, double.infinity) * 0.28 + exportKwh * 0.08;
}

enum InverterStatus { producing, idle, fault }

extension InverterStatusLabel on InverterStatus {
  String get label => switch (this) {
        InverterStatus.producing => 'Producing',
        InverterStatus.idle => 'Idle',
        InverterStatus.fault => 'Fault',
      };
}

@immutable
class MicroInverter {
  const MicroInverter({
    required this.id,
    required this.label,
    required this.watts,
    required this.tempC,
    required this.status,
  });
  final String id;
  final String label;
  final double watts;
  final double tempC;
  final InverterStatus status;
}

enum AlertType { outage, restored, lowReserve, firmware, overTemp, stormGuard, member }

@immutable
class AppAlert {
  const AppAlert({
    required this.id,
    required this.type,
    required this.title,
    required this.detail,
    required this.at,
  });
  final String id;
  final AlertType type;
  final String title;
  final String detail;
  final DateTime at;
}

@immutable
class Member {
  const Member({required this.id, required this.name, required this.role, this.you = false});
  final String id;
  final String name;
  final Role role;
  final bool you;
}

@immutable
class DiscoveredNode {
  const DiscoveredNode({required this.id, required this.mesh, required this.signalPercent});
  final String id;
  final String mesh;
  final int signalPercent;
}

@immutable
class PairingResult {
  const PairingResult({
    required this.node,
    required this.ownerName,
    required this.microinverters,
    required this.keyFingerprint,
  });
  final DiscoveredNode node;
  final String ownerName;
  final int microinverters;
  final String keyFingerprint;
}

enum CommissionStep { registeringKey, securingLink, syncingBridge, checkingFirmware, done }

extension CommissionStepLabel on CommissionStep {
  String get label => switch (this) {
        CommissionStep.registeringKey => 'Registering owner key',
        CommissionStep.securingLink => 'Securing local link',
        CommissionStep.syncingBridge => 'Syncing solar bridge',
        CommissionStep.checkingFirmware => 'Checking firmware',
        CommissionStep.done => 'Node ready',
      };
}

@immutable
class CommissionProgress {
  const CommissionProgress(this.step, this.progress);
  final CommissionStep step;

  /// 0..1 overall
  final double progress;
}

/// Events pushed by the node (become alerts / notifications / toasts).
enum NodeEventType { outage, restored, lowReserve, firmwareAvailable, offline, online, stormGuard }

@immutable
class NodeEvent {
  const NodeEvent(this.type, {this.runtimeH});
  final NodeEventType type;
  final double? runtimeH;
}

enum FirmwarePhase { idle, downloading, installing, restarting, done, failed }

@immutable
class FirmwareStatus {
  const FirmwareStatus({
    required this.current,
    this.available,
    this.phase = FirmwarePhase.idle,
    this.progress = 0,
  });
  final String current;
  final String? available;
  final FirmwarePhase phase;
  final double progress;
}
