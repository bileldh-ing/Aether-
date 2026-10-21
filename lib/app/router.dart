import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/design_system/tokens.dart';
import '../features/energy_flow/energy_flow_screen.dart';
import '../features/gallery/gallery_screen.dart';
import '../features/insights/streak_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/pairing/pairing_screen.dart';
import '../features/pairing/permissions_screen.dart';
import '../features/pairing/qr_scan_screen.dart';
import '../features/shell/home_shell.dart';
import 'providers.dart';

abstract final class Routes {
  static const onboarding = '/onboarding';
  static const permissions = '/permissions';
  static const pairing = '/pairing';
  static const qr = '/qr';
  static const home = '/home';
  static const flow = '/flow';
  static const streak = '/streak';
  static const gallery = '/gallery';
}

CustomTransitionPage<void> _fade(Widget child, GoRouterState s, {Duration d = AppMotion.medium}) =>
    CustomTransitionPage<void>(
      key: s.pageKey,
      child: child,
      transitionDuration: d,
      reverseTransitionDuration: AppMotion.fast,
      transitionsBuilder: (context, a, _, child) => FadeTransition(
        opacity: CurvedAnimation(parent: a, curve: AppMotion.curve),
        child: child,
      ),
    );

final routerProvider = Provider<GoRouter>((ref) {
  final paired = ref.read(settingsProvider).paired;
  return GoRouter(
    initialLocation: paired ? Routes.home : Routes.onboarding,
    routes: [
      GoRoute(path: Routes.onboarding, pageBuilder: (c, s) => _fade(const OnboardingScreen(), s)),
      GoRoute(path: Routes.permissions, pageBuilder: (c, s) => _fade(const PermissionsScreen(), s, d: AppMotion.hero)),
      GoRoute(path: Routes.pairing, pageBuilder: (c, s) => _fade(const PairingScreen(), s)),
      GoRoute(path: Routes.qr, builder: (c, s) => const QrScanScreen()),
      GoRoute(path: Routes.home, pageBuilder: (c, s) => _fade(const HomeShell(), s, d: AppMotion.hero)),
      GoRoute(path: Routes.flow, builder: (c, s) => const EnergyFlowScreen()),
      GoRoute(path: Routes.streak, builder: (c, s) => const StreakScreen()),
      GoRoute(path: Routes.gallery, builder: (c, s) => const GalleryScreen()),
    ],
  );
});
