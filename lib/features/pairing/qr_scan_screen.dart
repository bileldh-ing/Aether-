import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/design_system/design_system.dart';
import 'pairing_controller.dart';

/// Pair by scanning the QR label on the back of the Core
/// (payload `aether://pair?id=NEXUS-CORE-901`).
class QrScanScreen extends ConsumerStatefulWidget {
  const QrScanScreen({super.key});
  @override
  ConsumerState<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends ConsumerState<QrScanScreen> {
  bool _handled = false;

  void _use(String payload) {
    if (_handled) return;
    _handled = true;
    ref.read(pairingProvider.notifier).pairFromQr(payload);
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: MobileScanner(
              onDetect: (capture) {
                final raw = capture.barcodes.isEmpty
                    ? null
                    : capture.barcodes.first.rawValue;
                if (raw != null) _use(raw);
              },
              errorBuilder: (context, error) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    'Camera unavailable. Allow camera access in Settings, or use Bluetooth pairing.',
                    textAlign: TextAlign.center,
                    style: AppType.body(14, color: AppColors.textSecondary),
                  ),
                ),
              ),
            ),
          ),
          // Viewfinder.
          Center(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: AppColors.mint, width: 2),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.screenH, vertical: 8),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconCircleButton(
                          icon: AppIcons.close,
                          semanticLabel: 'Close',
                          onTap: () => context.pop()),
                      const Spacer(),
                      const StatusPill(label: 'SCAN QR CODE'),
                      const Spacer(),
                      const SizedBox(width: 48),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    'Point at the QR label on the back of your Power Core.',
                    textAlign: TextAlign.center,
                    style: AppType.body(14, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 16),
                  GhostButton(
                      label: 'Use demo code',
                      onTap: () => _use('aether://pair?id=NEXUS-CORE-901')),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
