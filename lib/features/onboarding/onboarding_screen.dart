import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/brand.dart';
import '../../app/router.dart';
import '../../core/design_system/design_system.dart';
import '../../core/utils/motion.dart';
import '../../domain/entities/entities.dart';
import 'slide_art.dart';

class _Slide {
  const _Slide({
    required this.badge,
    required this.badgeIcon,
    required this.line1,
    required this.line2,
    required this.cardTitle,
    required this.cardSubtitle,
    required this.cardIcon,
  });
  final String badge;
  final IconData badgeIcon;
  final String line1;
  final String line2;
  final String cardTitle;
  final String cardSubtitle;
  final IconData cardIcon;
}

const _slides = [
  _Slide(
    badge: 'Solar-Ready',
    badgeIcon: AppIcons.sunFill,
    line1: 'Harvest',
    line2: 'Every Ray',
    cardTitle: 'Live Harvest',
    cardSubtitle: '3 microinverters · 4.2 kW peak',
    cardIcon: AppIcons.sunFill,
  ),
  _Slide(
    badge: 'Grid Intelligence',
    badgeIcon: AppIcons.bolt,
    line1: 'Own Your',
    line2: 'Energy',
    cardTitle: 'Auto Island Mode',
    cardSubtitle: 'Switches in under 20 ms',
    cardIcon: AppIcons.bolt,
  ),
  _Slide(
    badge: AppBrand.badge,
    badgeIcon: AppIcons.chip,
    line1: 'Smart Home',
    line2: 'Power Core',
    cardTitle: 'Full Home Backup',
    cardSubtitle: '26.4 kWh · 42 Hours Active',
    cardIcon: AppIcons.home,
  ),
];

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, this.initialPage = 0});
  final int initialPage;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late final PageController _pc =
      PageController(initialPage: widget.initialPage);
  late int _page = widget.initialPage;
  bool _zoom = false;

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  void _go(int p) => _pc.animateToPage(p,
      duration: context.motion(AppMotion.slow), curve: AppMotion.curve);

  Future<void> _connect() async {
    setState(() => _zoom = true);
    await Future<void>.delayed(
        context.motion(const Duration(milliseconds: 420)));
    if (!mounted) return;
    context.go(Routes.permissions);
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.bgTop, AppColors.bgBottom],
          ),
        ),
        child: LayoutBuilder(
          builder: (context, box) {
            final w = box.maxWidth;
            final h = box.maxHeight;
            const control = 60.0;
            final bottomInset = math.max(pad.bottom, 12.0) + 14;
            return Stack(
              children: [
                // Slides (badge, headline, hero, info card).
                PageView.builder(
                  controller: _pc,
                  itemCount: _slides.length,
                  onPageChanged: (p) => setState(() => _page = p),
                  itemBuilder: (context, i) => _SlideView(
                    slide: _slides[i],
                    index: i,
                    width: w,
                    height: h,
                    topInset: pad.top,
                    bottomReserved: bottomInset + control + 18,
                    zoom: _zoom && i == 2,
                  ),
                ),
                // Top row.
                Positioned(
                  left: AppSpace.screenH + 2,
                  right: AppSpace.screenH + 2,
                  top: pad.top + 18,
                  child: Row(
                    children: [
                      const Icon(AppIcons.bolt,
                          color: AppColors.mint, size: 20),
                      const SizedBox(width: 10),
                      Text.rich(
                        TextSpan(
                          text: AppBrand.wordmark,
                          children: [
                            TextSpan(
                                text: '.',
                                style: AppType.body(15,
                                    weight: FontWeight.w800,
                                    color: AppColors.mint))
                          ],
                        ),
                        style: AppType.body(15,
                            weight: FontWeight.w800, spacing: 2),
                      ),
                      const Spacer(),
                      _Dots(count: _slides.length, index: _page),
                    ],
                  ),
                ),
                // Bottom control.
                Positioned(
                  left: AppSpace.screenH - 2,
                  right: AppSpace.screenH - 2,
                  bottom: bottomInset,
                  child: AnimatedSwitcher(
                    duration: context.motion(AppMotion.medium),
                    child: _page < 2
                        ? PagerControl(
                            key: const ValueKey('pager'),
                            height: control,
                            label: _page == 0
                                ? 'SWIPE OR TAP NEXT'
                                : 'ALMOST THERE',
                            onBack: _page == 0 ? null : () => _go(_page - 1),
                            onNext: () => _go(_page + 1),
                          )
                        : SwipeToConnect(
                            key: const ValueKey('swipe'),
                            height: control,
                            onBack: () => _go(1),
                            onComplete: _connect,
                          ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index});
  final int count;
  final int index;

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Slide ${index + 1} of $count',
        child: Row(
          children: [
            for (var i = 0; i < count; i++)
              AnimatedContainer(
                duration: context.motion(AppMotion.medium),
                margin: const EdgeInsets.only(left: 6),
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i == index
                      ? AppColors.mint
                      : Colors.white.withValues(alpha: 0.25),
                ),
              ),
          ],
        ),
      );
}

class _SlideView extends StatelessWidget {
  const _SlideView({
    required this.slide,
    required this.index,
    required this.width,
    required this.height,
    required this.topInset,
    required this.bottomReserved,
    required this.zoom,
  });

  final _Slide slide;
  final int index;
  final double width;
  final double height;
  final double topInset;
  final double bottomReserved;
  final bool zoom;

  @override
  Widget build(BuildContext context) {
    final w = width;
    final h = height;
    final headline = (w * 0.105).clamp(34.0, 46.0);
    final badgeTop = topInset + 18 + h * 0.10;
    final heroTop = h * 0.405;
    final cardBottom = bottomReserved + h * 0.105;

    final Widget hero = switch (index) {
      0 => SunArt(size: w * 0.78),
      1 => GridArt(size: w * 0.8),
      _ => _FloatingProduct(width: w * 0.6),
    };

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Hero.
        Positioned(
          left: 0,
          right: 0,
          top: index == 2 ? heroTop : heroTop - w * 0.06,
          child: Center(
            child: AnimatedScale(
              scale: zoom ? 1.14 : 1,
              duration: context.motion(AppMotion.hero),
              curve: AppMotion.curve,
              child: hero,
            ),
          ),
        ),
        // Badge + headline.
        Positioned(
          left: AppSpace.screenH - 4,
          right: AppSpace.screenH,
          top: badgeTop,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 28,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1F2123),
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(slide.badgeIcon, size: 13, color: AppColors.mint),
                    const SizedBox(width: 7),
                    Text(slide.badge,
                        style: AppType.body(12, color: AppColors.textPrimary)),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(slide.line1,
                  style: AppType.display(headline,
                      weight: FontWeight.w400, height: 1.04)),
              Text(
                slide.line2,
                style: AppType.display(headline,
                    weight: FontWeight.w400,
                    color: AppColors.textSecondary,
                    height: 1.04),
              ),
            ],
          ),
        ),
        // Floating glass info card.
        Positioned(
          left: w * 0.1,
          right: w * 0.1,
          bottom: cardBottom,
          child: _InfoCard(slide: slide),
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.slide});
  final _Slide slide;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${slide.cardTitle}. ${slide.cardSubtitle}',
      child: GlassCard(
        height: 64,
        radius: AppRadii.hero,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                  color: Color(0xFF16181A), shape: BoxShape.circle),
              child: Icon(slide.cardIcon, color: AppColors.mint, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(slide.cardTitle,
                      style: AppType.body(14, weight: FontWeight.w600),
                      maxLines: 1),
                  const SizedBox(height: 2),
                  Text(
                    slide.cardSubtitle,
                    style: AppType.body(12,
                        weight: FontWeight.w500,
                        color: AppColors.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: AppColors.mint,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: AppColors.mint.withValues(alpha: 0.5),
                      blurRadius: 8)
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Product hero floating ±6 px on a 5 s loop.
class _FloatingProduct extends StatefulWidget {
  const _FloatingProduct({required this.width});
  final double width;
  @override
  State<_FloatingProduct> createState() => _FloatingProductState();
}

class _FloatingProductState extends State<_FloatingProduct>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 5));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    context.reduceMotion ? _c.stop() : _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, math.sin(_c.value * 2 * math.pi) * 6),
        child: child,
      ),
      child: ProductHero(
          width: widget.width, state: NodeState.idle, reflection: false),
    );
  }
}
