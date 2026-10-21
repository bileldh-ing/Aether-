import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/brand.dart';
import '../../app/router.dart';
import '../../core/design_system/design_system.dart';
import '../../core/utils/motion.dart';
import '../../domain/entities/entities.dart';
import 'pairing_controller.dart';

const coreDiscHeroTag = 'aether-core-disc';

class PairingScreen extends ConsumerStatefulWidget {
  const PairingScreen({super.key, this.autoScan = true});
  final bool autoScan;

  @override
  ConsumerState<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends ConsumerState<PairingScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _burst = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void initState() {
    super.initState();
    if (widget.autoScan) {
      WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(pairingProvider.notifier).startScan());
    }
  }

  @override
  void dispose() {
    _burst.dispose();
    super.dispose();
  }

  Future<void> _onSuccess() async {
    if (context.reduceMotion) {
      _burst.value = 1;
    } else {
      await _burst.forward(from: 0);
    }
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (mounted) context.go(Routes.home);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(pairingProvider.select((s) => s.phase), (prev, next) {
      if (next == PairingPhase.success && prev != PairingPhase.success) _onSuccess();
    });
    final s = ref.watch(pairingProvider);
    final found = s.node != null && s.phase != PairingPhase.scanning && s.phase != PairingPhase.notFound;

    final pillLabel = switch (s.phase) {
      PairingPhase.scanning => 'SCANNING',
      PairingPhase.notFound => 'NO NODE FOUND',
      PairingPhase.pairing => 'SECURING',
      PairingPhase.commissioning => 'INITIALIZING',
      PairingPhase.success => 'NODE READY',
      PairingPhase.error => 'ATTENTION NEEDED',
      PairingPhase.ready => Copy.pairingReady,
    };
    final pillColor = switch (s.phase) {
      PairingPhase.notFound || PairingPhase.error => AppColors.amber,
      _ => AppColors.mint,
    };

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, box) {
            final w = box.maxWidth;
            final h = box.maxHeight;
            final outer = math.min(w * 0.66, h * 0.33);
            final inner = outer * 0.68;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.screenH),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      IconCircleButton(
                        icon: AppIcons.back,
                        semanticLabel: 'Back',
                        onTap: () => context.go(Routes.onboarding),
                      ),
                      const Spacer(),
                      StatusPill(label: pillLabel, color: pillColor),
                      const Spacer(),
                      IconCircleButton(
                        icon: AppIcons.qr,
                        semanticLabel: 'Pair with QR code',
                        onTap: () => context.push(Routes.qr),
                      ),
                    ],
                  ),
                  SizedBox(height: h * 0.045),
                  Text(
                    Copy.connectTitle,
                    textAlign: TextAlign.center,
                    style: AppType.display(math.min(32, w * 0.082), weight: FontWeight.w500),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Text(
                      Copy.connectSubtitle,
                      textAlign: TextAlign.center,
                      style: AppType.body(13.5, weight: FontWeight.w500, color: AppColors.textSecondary, height: 1.4),
                    ),
                  ),
                  const Spacer(flex: 3),
                  AnimatedBuilder(
                    animation: _burst,
                    builder: (context, _) => RadarPulse(
                      outer: outer,
                      inner: inner,
                      fast: s.phase == PairingPhase.scanning ||
                          s.phase == PairingPhase.pairing ||
                          s.phase == PairingPhase.commissioning,
                      progress: s.phase == PairingPhase.commissioning || s.phase == PairingPhase.success ? s.progress : 0,
                      burst: _burst.value,
                      color: pillColor,
                      child: Hero(
                        tag: coreDiscHeroTag,
                        child: _DiscContent(state: s, success: _burst.value > 0.3),
                      ),
                    ),
                  ),
                  const Spacer(flex: 3),
                  AnimatedSwitcher(
                    duration: context.motion(AppMotion.medium),
                    child: s.phase == PairingPhase.notFound || s.phase == PairingPhase.error
                        ? _NotFound(key: const ValueKey('nf'), message: s.error ?? Copy.notFound)
                        : _Tiles(key: const ValueKey('tiles'), visible: found, result: s.result),
                  ),
                  const Spacer(flex: 2),
                  _Cta(state: s),
                  const SizedBox(height: 16),
                  Text(
                    AppBrand.footer,
                    style: AppType.mono(10.5, weight: FontWeight.w400, color: AppColors.textTertiary),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _DiscContent extends StatelessWidget {
  const _DiscContent({required this.state, required this.success});
  final PairingState state;
  final bool success;

  @override
  Widget build(BuildContext context) {
    final node = state.node;
    final scanning = state.phase == PairingPhase.scanning || state.phase == PairingPhase.notFound;
    return Material(
      type: MaterialType.transparency,
      child: Center(
        child: AnimatedSwitcher(
          duration: context.motion(AppMotion.medium),
          child: success
              ? Column(
                  key: const ValueKey('ok'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(AppIcons.check, color: AppColors.mint, size: 44),
                    const SizedBox(height: 8),
                    Text('Node ready', style: AppType.body(13, color: AppColors.mint)),
                  ],
                )
              : scanning || node == null
                  ? Padding(
                      key: const ValueKey('scan'),
                      padding: const EdgeInsets.symmetric(horizontal: 22),
                      child: Text(
                        state.phase == PairingPhase.notFound ? 'No signal' : Copy.looking,
                        textAlign: TextAlign.center,
                        style: AppType.body(12.5, color: AppColors.textSecondary),
                      ),
                    )
                  : FittedBox(
                      key: const ValueKey('node'),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: const BoxDecoration(color: Color(0xFF2A2C2F), shape: BoxShape.circle),
                              child: Center(
                                child: Container(
                                  width: 16,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    color: AppColors.mint,
                                    shape: BoxShape.circle,
                                    boxShadow: [BoxShadow(color: AppColors.mint.withValues(alpha: 0.6), blurRadius: 10)],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(node.id, style: AppType.mono(14, weight: FontWeight.w700, spacing: 0.5)),
                            const SizedBox(height: 4),
                            Text(node.mesh, style: AppType.body(11.5, weight: FontWeight.w500, color: AppColors.textSecondary)),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: const BoxDecoration(color: AppColors.mint, shape: BoxShape.circle),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Signal ${node.signalPercent}%',
                                  style: AppType.body(11.5, weight: FontWeight.w600, color: AppColors.mint),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
        ),
      ),
    );
  }
}

class _Tiles extends StatelessWidget {
  const _Tiles({super.key, required this.visible, required this.result});
  final bool visible;
  final PairingResult? result;

  @override
  Widget build(BuildContext context) {
    final ready = result != null;
    return AnimatedOpacity(
      duration: context.motion(AppMotion.slow),
      opacity: visible ? 1 : 0.35,
      child: Column(
        children: [
          _Tile(
            icon: AppIcons.shield,
            title: Copy.ownerKey,
            subtitle: ready ? '${result!.ownerName} (Admin)' : 'Generating key…',
            trailing: ready
                ? const Icon(AppIcons.check, color: AppColors.mint, size: 22)
                : const _MiniSpinner(),
          ),
          const SizedBox(height: 12),
          _Tile(
            icon: AppIcons.inverter,
            title: Copy.inverterBridge,
            subtitle: ready ? '${result!.microinverters}x Microinverters Detected' : 'Listening for inverters…',
            trailing: ready
                ? Text(Copy.ready, style: AppType.body(13, weight: FontWeight.w600, color: AppColors.mint))
                : const _MiniSpinner(),
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.title, required this.subtitle, required this.trailing});
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;

  @override
  Widget build(BuildContext context) => SurfaceCard(
        radius: AppRadii.tile,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        semanticLabel: '$title, $subtitle',
        child: Row(
          children: [
            TintedIcon(icon: icon, size: 34),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppType.body(13.5, weight: FontWeight.w600), maxLines: 1),
                  const SizedBox(height: 3),
                  Text(subtitle, style: AppType.body(12, weight: FontWeight.w500, color: AppColors.textSecondary), maxLines: 1),
                ],
              ),
            ),
            trailing,
          ],
        ),
      );
}

class _MiniSpinner extends StatelessWidget {
  const _MiniSpinner();
  @override
  Widget build(BuildContext context) => const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 1.6, color: AppColors.mint),
      );
}

class _NotFound extends ConsumerWidget {
  const _NotFound({super.key, required this.message});
  final String message;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppType.body(13.5, weight: FontWeight.w500, color: AppColors.textSecondary, height: 1.45),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: GhostButton(label: Copy.tryAgain, onTap: () => ref.read(pairingProvider.notifier).startScan()),
              ),
              const SizedBox(width: 12),
              Expanded(child: GhostButton(label: Copy.scanQrInstead, onTap: () => context.push(Routes.qr))),
            ],
          ),
        ],
      );
}

/// White CTA that morphs into a 4-step progress capsule.
class _Cta extends ConsumerWidget {
  const _Cta({required this.state});
  final PairingState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final running = state.phase == PairingPhase.commissioning || state.phase == PairingPhase.success;
    final enabled = state.phase == PairingPhase.ready;
    return AnimatedSwitcher(
      duration: context.motion(AppMotion.medium),
      transitionBuilder: (c, a) => FadeTransition(
        opacity: a,
        child: ScaleTransition(scale: Tween(begin: 0.96, end: 1.0).animate(a), child: c),
      ),
      child: running
          ? _ProgressCapsule(key: const ValueKey('p'), state: state)
          : PrimaryButton(
              key: const ValueKey('b'),
              label: Copy.initialize,
              height: 56,
              onTap: enabled ? () => ref.read(pairingProvider.notifier).initialize() : null,
            ),
    );
  }
}

class _ProgressCapsule extends StatelessWidget {
  const _ProgressCapsule({super.key, required this.state});
  final PairingState state;

  @override
  Widget build(BuildContext context) {
    final step = state.step ?? CommissionStep.registeringKey;
    final idx = step == CommissionStep.done ? 4 : step.index + 1;
    return Semantics(
      liveRegion: true,
      label: '${step.label}, step $idx of 4',
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Stack(
          alignment: Alignment.centerLeft,
          children: [
            Row(
              children: [
                if (step == CommissionStep.done)
                  const Icon(AppIcons.check, color: AppColors.mint, size: 18)
                else
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 1.8, color: AppColors.mint),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: context.motion(AppMotion.fast),
                    child: Text(
                      step.label,
                      key: ValueKey(step),
                      style: AppType.body(14, weight: FontWeight.w600),
                    ),
                  ),
                ),
                Text('$idx/4', style: AppType.mono(12, color: AppColors.textSecondary)),
              ],
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 8,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: state.progress,
                  minHeight: 2,
                  color: AppColors.mint,
                  backgroundColor: AppColors.track,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
