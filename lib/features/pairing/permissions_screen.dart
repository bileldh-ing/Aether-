import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../app/brand.dart';
import '../../app/providers.dart';
import '../../app/router.dart';
import '../../core/design_system/design_system.dart';

/// Pre-permission explainer (Bluetooth, Nearby Devices, Notifications).
class PermissionsScreen extends ConsumerStatefulWidget {
  const PermissionsScreen({super.key});
  @override
  ConsumerState<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends ConsumerState<PermissionsScreen> {
  bool _busy = false;
  bool _denied = false;

  Future<void> _allow() async {
    setState(() => _busy = true);
    var granted = true;
    try {
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        final statuses = await [
          Permission.bluetoothScan,
          Permission.bluetoothConnect,
          if (Platform.isIOS) Permission.bluetooth,
        ].request();
        granted = statuses.values.every((s) => s.isGranted || s.isLimited);
        await ref.read(notificationServiceProvider).requestPermission();
      }
    } catch (_) {
      // Emulators without BLE: the simulator does not need it.
      granted = true;
    }
    if (!mounted) return;
    // The simulated Core needs no radio, so a denial only blocks real hardware.
    final mock = ref.read(appConfigProvider).useMockDevice;
    if (!granted && !mock) {
      setState(() {
        _busy = false;
        _denied = true;
      });
      return;
    }
    context.go(Routes.pairing);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.screenH),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              IconCircleButton(
                icon: AppIcons.back,
                semanticLabel: 'Back',
                onTap: () => context.go(Routes.onboarding),
              ),
              const SizedBox(height: 28),
              Text('Let’s find your\nPower Core', style: AppType.display(32, weight: FontWeight.w600, height: 1.1)),
              const SizedBox(height: 10),
              Text(
                'Aether talks to the Core directly over Bluetooth and your local network. Nothing leaves your home without your say.',
                style: AppType.body(14, weight: FontWeight.w400, color: AppColors.textSecondary, height: 1.45),
              ),
              const SizedBox(height: 28),
              const _Row(
                icon: AppIcons.bluetooth,
                title: 'Bluetooth',
                body: 'Finds the Core and hands it your Wi-Fi details during setup.',
              ),
              const _Row(
                icon: AppIcons.nearby,
                title: 'Nearby Devices',
                body: 'Lets the app see Aether hardware within a few metres.',
              ),
              const _Row(
                icon: AppIcons.bell,
                title: 'Notifications',
                body: 'Tells you the moment the grid drops or your reserve runs low.',
              ),
              const Spacer(),
              if (_denied)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: SurfaceCard(
                    radius: AppRadii.tile,
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Icon(AppIcons.warning, color: AppColors.amber, size: 18),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Bluetooth access is off for ${AppBrand.name}. Turn it on in Settings › Apps › Aether Grid, then come back.',
                            style: AppType.body(13, weight: FontWeight.w500, color: AppColors.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              PrimaryButton(
                label: _denied ? 'Open settings' : Copy.allowAccess,
                onTap: _busy ? null : (_denied ? openAppSettings : _allow),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.title, required this.body});
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: SurfaceCard(
          radius: AppRadii.tile,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              TintedIcon(icon: icon),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppType.body(14, weight: FontWeight.w600)),
                    const SizedBox(height: 3),
                    Text(body, style: AppType.body(12.5, weight: FontWeight.w500, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}
