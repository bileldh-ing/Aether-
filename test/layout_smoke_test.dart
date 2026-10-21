import 'package:aether_grid/app/app.dart';
import 'package:aether_grid/app/config.dart';
import 'package:aether_grid/app/providers.dart';
import 'package:aether_grid/app/router.dart';
import 'package:aether_grid/data/sources/mock/mock_power_node_source.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Smallest and largest phones in the brief (logical pixels).
const _sizes = <String, Size>{
  '360x740': Size(360, 740),
  '390x844': Size(390, 844),
  '430x932': Size(430, 932),
};

const _routes = [
  Routes.onboarding,
  Routes.permissions,
  Routes.home,
  Routes.flow,
  Routes.streak,
  Routes.gallery,
];

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  for (final size in _sizes.entries) {
    for (final route in _routes) {
      testWidgets('$route renders without overflow at ${size.key}',
          (tester) async {
        tester.view
          ..physicalSize = size.value * 3
          ..devicePixelRatio = 3;
        addTearDown(tester.view.reset);

        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final sim = MockPowerNodeSource(
          clock: () => DateTime(2026, 10, 21, 12, 30),
          autoStart: false,
        );
        final container = ProviderContainer(overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          appConfigProvider
              .overrideWithValue(const AppConfig(enableNotifications: false)),
          powerNodeRepositoryProvider.overrideWithValue(sim),
        ]);
        addTearDown(container.dispose);

        await tester.pumpWidget(UncontrolledProviderScope(
          container: container,
          child: const AetherApp(),
        ));
        container.read(routerProvider).go(route);

        // Animations loop forever, so pump fixed frames instead of settling.
        for (var i = 0; i < 12; i++) {
          sim.tick();
          await tester.pump(const Duration(milliseconds: 120));
        }

        expect(tester.takeException(), isNull);

        // On the home shell, visit every tab too.
        if (route == Routes.home) {
          for (final tab in const ['Solar', 'Insights', 'Settings', 'Energy']) {
            await tester.tap(find.bySemanticsLabel(tab));
            for (var i = 0; i < 8; i++) {
              await tester.pump(const Duration(milliseconds: 120));
            }
            expect(tester.takeException(), isNull, reason: '$tab tab');
          }
        }

        // Tear down so periodic animations and streams stop cleanly.
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 1));
      });
    }
  }
}
