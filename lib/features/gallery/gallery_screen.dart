import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/design_system/design_system.dart';
import '../../domain/entities/entities.dart';

/// Debug route `/gallery`: every design-system widget in one place.
class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});
  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  double _soc = 0.84;
  int _nav = 0;
  NodeState _led = NodeState.idle;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
              AppSpace.screenH, 8, AppSpace.screenH, 40),
          children: [
            Row(
              children: [
                IconCircleButton(
                    icon: AppIcons.back,
                    semanticLabel: 'Back',
                    onTap: () => context.pop()),
                const Spacer(),
                const StatusPill(label: 'GALLERY'),
                const Spacer(),
                const SizedBox(width: 48),
              ],
            ),
            const SectionHeader('Status pills'),
            const Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                StatusPill(label: 'GRID ONLINE'),
                StatusPill(label: 'PAIRING READY'),
                StatusPill(label: 'ISLAND MODE', color: AppColors.amber),
                StatusPill(
                    label: 'NODE OFFLINE',
                    color: AppColors.textTertiary,
                    breathe: false),
              ],
            ),
            const SectionHeader('EnergyGauge + AnimatedNumber'),
            SurfaceCard(
              radius: AppRadii.hero,
              child: Column(
                children: [
                  EnergyGauge(
                    fraction: _soc,
                    diameter: 200,
                    child: AnimatedNumber(
                      value: _soc * 1024,
                      style: AppType.display(48,
                          weight: FontWeight.w300, tabular: true),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Slider(
                      value: _soc, onChanged: (v) => setState(() => _soc = v)),
                ],
              ),
            ),
            const SectionHeader('LedRingGlow · ProductHero'),
            SurfaceCard(
              child: Column(
                children: [
                  ProductHero(width: 150, state: _led),
                  const SizedBox(height: 40),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final s in NodeState.values)
                        GestureDetector(
                          onTap: () => setState(() => _led = s),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: s == _led
                                  ? AppColors.mint
                                  : AppColors.surfaceHigh,
                              borderRadius:
                                  BorderRadius.circular(AppRadii.pill),
                            ),
                            child: Text(
                              s.name,
                              style: AppType.body(11,
                                  color: s == _led
                                      ? AppColors.ctaText
                                      : AppColors.textSecondary),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SectionHeader('RadarPulse'),
            Center(
              child: RadarPulse(
                outer: 240,
                inner: 160,
                progress: 0.6,
                child: Center(
                    child: Text('NEXUS-CORE-901',
                        style: AppType.mono(13, weight: FontWeight.w700))),
              ),
            ),
            const SectionHeader('SwipeToConnect · PagerControl'),
            SwipeToConnect(onComplete: () {}),
            const SizedBox(height: 12),
            PagerControl(onNext: () {}, onBack: () {}),
            const SectionHeader('FloatingNavPill'),
            Center(
              child: FloatingNavPill(
                items: const [
                  NavItem(AppIcons.bolt, 'Energy'),
                  NavItem(AppIcons.sun, 'Solar'),
                  NavItem(AppIcons.chart, 'Insights'),
                  NavItem(AppIcons.gear, 'Settings'),
                ],
                index: _nav,
                onChanged: (i) => setState(() => _nav = i),
              ),
            ),
            const SectionHeader('GlassCard · buttons'),
            const GlassCard(
              height: 64,
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Glass surface')),
            ),
            const SizedBox(height: 12),
            PrimaryButton(label: 'Initialize Smart Node', onTap: () {}),
            const SizedBox(height: 12),
            GhostButton(label: 'Try again', onTap: () {}),
            const SectionHeader('FlowDiagram'),
            const FlowDiagram(
                solarW: 2400,
                homeW: 620,
                gridW: -1500,
                batteryW: 280,
                soc: 0.84,
                gridOnline: true),
          ],
        ),
      ),
    );
  }
}
