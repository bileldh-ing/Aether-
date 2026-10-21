import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/design_system/toast_host.dart';
import 'brand.dart';
import 'providers.dart';
import 'router.dart';
import 'theme.dart';

class AetherApp extends ConsumerWidget {
  const AetherApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    // Keep the alert pipeline alive app-wide (events → alerts / push / toasts).
    ref.watch(alertsProvider.select((s) => s.unread));
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarContrastEnforced: false,
      ),
      child: MaterialApp.router(
        title: AppBrand.name,
        debugShowCheckedModeBanner: false,
        theme: buildAetherTheme(),
        darkTheme: buildAetherTheme(),
        themeMode: ThemeMode.dark,
        routerConfig: router,
        builder: (context, child) {
          final mq = MediaQuery.of(context);
          return MediaQuery(
            // Text scaling clamped to 1.2 so the hero layouts hold.
            data: mq.copyWith(
                textScaler: mq.textScaler
                    .clamp(minScaleFactor: 0.9, maxScaleFactor: 1.2)),
            child: ToastHost(child: child ?? const SizedBox.shrink()),
          );
        },
      ),
    );
  }
}
