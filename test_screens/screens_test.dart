// Renders every main screen to PNG for visual review against the references.
// Run with: flutter test test_screens --update-goldens
// Output lands in test_screens/goldens/.
// ignore_for_file: invalid_use_of_visible_for_testing_member
import 'package:aether_grid/app/app.dart';
import 'package:aether_grid/app/config.dart';
import 'package:aether_grid/app/providers.dart';
import 'package:aether_grid/app/router.dart';
import 'package:aether_grid/core/design_system/typography.dart';
import 'package:aether_grid/data/sources/mock/mock_power_node_source.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _loadFonts() async {
  Future<void> family(String name, List<String> files) async {
    final loader = FontLoader(name);
    for (final f in files) {
      loader.addFont(rootBundle.load('assets/google_fonts/$f'));
    }
    await loader.load();
  }

  await family('Outfit', [
    'Outfit-Light.ttf',
    'Outfit-Regular.ttf',
    'Outfit-Medium.ttf',
    'Outfit-SemiBold.ttf',
    'Outfit-Bold.ttf',
  ]);
  await family('Manrope', [
    'Manrope-Regular.ttf',
    'Manrope-Medium.ttf',
    'Manrope-SemiBold.ttf',
    'Manrope-Bold.ttf',
  ]);
  await family('JetBrains Mono', [
    'JetBrainsMono-Regular.ttf',
    'JetBrainsMono-SemiBold.ttf',
    'JetBrainsMono-Bold.ttf',
  ]);
  final icons = FontLoader('MaterialIcons')
    ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
  await icons.load();
}

class _Shot {
  const _Shot(this.name, this.route, {this.tab, this.swipes = 0, this.setup});
  final String name;
  final String route;
  final String? tab;
  final int swipes;
  final void Function(MockPowerNodeSource sim)? setup;
}

final _shots = <_Shot>[
  const _Shot('01_onboarding_1', Routes.onboarding),
  const _Shot('02_onboarding_2', Routes.onboarding, swipes: 1),
  const _Shot('03_onboarding_3', Routes.onboarding, swipes: 2),
  const _Shot('04_permissions', Routes.permissions),
  const _Shot('05_dashboard', Routes.home),
  _Shot('06_dashboard_outage', Routes.home, setup: (s) => s.triggerOutage()),
  const _Shot('07_solar', Routes.home, tab: 'Solar'),
  const _Shot('08_insights', Routes.home, tab: 'Insights'),
  const _Shot('09_settings', Routes.home, tab: 'Settings'),
  const _Shot('10_energy_flow', Routes.flow),
  const _Shot('11_streak', Routes.streak),
  const _Shot('12_gallery', Routes.gallery),
];

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    AppType.useGoogleFonts = false;
    await _loadFonts();
  });

  for (final shot in _shots) {
    testWidgets(shot.name, (tester) async {
      tester.view
        ..physicalSize = const Size(390 * 2, 844 * 2)
        ..devicePixelRatio = 2;
      addTearDown(tester.view.reset);

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final sim = MockPowerNodeSource(
        clock: () => DateTime(2026, 10, 21, 12, 30),
        autoStart: false,
      );
      shot.setup?.call(sim);
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
      // Decode the product image before going further.
      await tester.runAsync(() async {
        final ctx = tester.element(find.byType(AetherApp));
        await precacheImage(
            const AssetImage('assets/images/aether_core.png'), ctx);
      });
      container.read(routerProvider).go(shot.route);
      await _frames(tester, sim, 10);

      if (shot.tab != null) {
        await tester.tap(find.bySemanticsLabel(shot.tab!));
        await _frames(tester, sim, 10);
      }
      for (var i = 0; i < shot.swipes; i++) {
        await tester.fling(find.byType(PageView), const Offset(-300, 0), 1500);
        await _frames(tester, sim, 10);
      }
      await _frames(tester, sim, 15);

      await expectLater(
        find.byType(AetherApp),
        matchesGoldenFile('goldens/${shot.name}.png'),
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    });
  }
}

Future<void> _frames(
    WidgetTester tester, MockPowerNodeSource sim, int count) async {
  for (var i = 0; i < count; i++) {
    sim.tick();
    await tester.pump(const Duration(milliseconds: 100));
  }
}
