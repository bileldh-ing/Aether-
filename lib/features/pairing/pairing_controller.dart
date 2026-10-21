import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/brand.dart';
import '../../app/providers.dart';
import '../../core/haptics/haptics.dart';
import '../../domain/entities/entities.dart';

enum PairingPhase {
  scanning,
  notFound,
  pairing,
  ready,
  commissioning,
  success,
  error
}

@immutable
class PairingState {
  const PairingState({
    this.phase = PairingPhase.scanning,
    this.node,
    this.result,
    this.step,
    this.progress = 0,
    this.error,
  });

  final PairingPhase phase;
  final DiscoveredNode? node;
  final PairingResult? result;
  final CommissionStep? step;
  final double progress;
  final String? error;

  PairingState copyWith({
    PairingPhase? phase,
    DiscoveredNode? node,
    PairingResult? result,
    CommissionStep? step,
    double? progress,
    String? error,
  }) =>
      PairingState(
        phase: phase ?? this.phase,
        node: node ?? this.node,
        result: result ?? this.result,
        step: step ?? this.step,
        progress: progress ?? this.progress,
        error: error,
      );
}

class PairingController extends Notifier<PairingState> {
  StreamSubscription<DiscoveredNode>? _scan;
  StreamSubscription<CommissionProgress>? _commission;
  Timer? _timeout;

  @override
  PairingState build() {
    ref.onDispose(_cancel);
    return const PairingState();
  }

  void _cancel() {
    _scan?.cancel();
    _commission?.cancel();
    _timeout?.cancel();
  }

  void startScan() {
    _cancel();
    state = const PairingState();
    final repo = ref.read(powerNodeRepositoryProvider);
    _timeout = Timer(const Duration(seconds: 12), () {
      if (state.phase == PairingPhase.scanning) {
        _scan?.cancel();
        state = state.copyWith(phase: PairingPhase.notFound);
      }
    });
    _scan = repo.scan(timeout: const Duration(seconds: 60)).listen(
      (node) {
        // Live RSSI updates keep refreshing the signal reading.
        if (state.phase == PairingPhase.scanning) {
          state = state.copyWith(node: node, phase: PairingPhase.pairing);
          unawaited(_pair(node));
        } else if (state.phase == PairingPhase.ready ||
            state.phase == PairingPhase.pairing) {
          state = state.copyWith(node: node);
        }
      },
      onError: (Object e) => state =
          state.copyWith(phase: PairingPhase.error, error: e.toString()),
    );
  }

  /// Pair by QR payload, e.g. `aether://pair?id=NEXUS-CORE-901`.
  void pairFromQr(String payload) {
    final id = Uri.tryParse(payload)?.queryParameters['id'] ?? payload;
    if (!id.startsWith('NEXUS-CORE-')) {
      state = state.copyWith(
          phase: PairingPhase.error,
          error:
              'That code is not an Aether Power Core. Scan the label on the back of the unit.');
      return;
    }
    _cancel();
    final node =
        DiscoveredNode(id: id, mesh: '5.8 GHz Mesh', signalPercent: 98);
    state = PairingState(phase: PairingPhase.pairing, node: node);
    unawaited(_pair(node));
  }

  Future<void> _pair(DiscoveredNode node) async {
    try {
      final pub = await ref.read(securityServiceProvider).ensureOwnerKey();
      final result = await ref
          .read(powerNodeRepositoryProvider)
          .pair(node, ownerName: AppBrand.ownerName, publicKey: pub);
      state = state.copyWith(phase: PairingPhase.ready, result: result);
    } catch (e) {
      state = state.copyWith(
          phase: PairingPhase.error,
          error:
              'Pairing failed. Keep your phone within 3 m of the Core and try again.');
    }
  }

  void initialize() {
    if (state.phase != PairingPhase.ready) return;
    state = state.copyWith(
        phase: PairingPhase.commissioning,
        progress: 0,
        step: CommissionStep.registeringKey);
    _commission = ref.read(powerNodeRepositoryProvider).commission().listen(
      (p) {
        if (p.step == CommissionStep.done) {
          state = state.copyWith(
              phase: PairingPhase.success, progress: 1, step: p.step);
          Haptics.success();
          unawaited(ref.read(settingsProvider.notifier).setPaired(true));
        } else {
          state = state.copyWith(progress: p.progress, step: p.step);
        }
      },
      onError: (Object e) => state = state.copyWith(
        phase: PairingPhase.error,
        error:
            'The Core stopped responding during setup. Power-cycle it and try again.',
      ),
    );
  }
}

final pairingProvider =
    NotifierProvider<PairingController, PairingState>(PairingController.new);
