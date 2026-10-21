import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design_system/design_system.dart';
import '../dashboard/dashboard_screen.dart';
import '../insights/insights_screen.dart';
import '../settings/settings_screen.dart';
import '../solar/solar_screen.dart';

class HomeTabController extends Notifier<int> {
  @override
  int build() => 0;
  void select(int i) => state = i;
}

final homeTabProvider = NotifierProvider<HomeTabController, int>(HomeTabController.new);

const _items = [
  NavItem(AppIcons.bolt, 'Energy'),
  NavItem(AppIcons.sun, 'Solar'),
  NavItem(AppIcons.chart, 'Insights'),
  NavItem(AppIcons.gear, 'Settings'),
];

class HomeShell extends ConsumerWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(homeTabProvider);
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          IndexedStack(
            index: tab,
            children: const [DashboardScreen(), SolarScreen(), InsightsScreen(), SettingsScreen()],
          ),
          // Fade content out under the floating nav.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 110 + bottom,
            child: const IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x00141517), Color(0xE6141517)],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: (bottom > 0 ? bottom : 0) + 20,
            child: Center(
              child: FloatingNavPill(
                items: _items,
                index: tab,
                onChanged: (i) => ref.read(homeTabProvider.notifier).select(i),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
