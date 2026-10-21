import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../haptics/haptics.dart';
import '../utils/motion.dart';
import 'app_icons.dart';
import 'surfaces.dart';
import 'tokens.dart';
import 'typography.dart';

/// Glass track: [white ‹ back] [mint bolt thumb → drag] SWIPE TO CONNECT >> [▶ end cap].
/// Drag the thumb ≥ 85 % of the way to complete; releasing early springs back.
class SwipeToConnect extends StatefulWidget {
  const SwipeToConnect({
    super.key,
    required this.onComplete,
    this.onBack,
    this.label = 'SWIPE TO CONNECT',
    this.height = 64,
  });

  final VoidCallback onComplete;
  final VoidCallback? onBack;
  final String label;
  final double height;

  @override
  State<SwipeToConnect> createState() => _SwipeToConnectState();
}

class _SwipeToConnectState extends State<SwipeToConnect>
    with TickerProviderStateMixin {
  late final AnimationController _pos =
      AnimationController.unbounded(vsync: this);
  late final AnimationController _shimmer = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1800));
  bool _done = false;

  static const _pad = 8.0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (context.reduceMotion) {
      _shimmer.stop();
    } else if (!_shimmer.isAnimating) {
      _shimmer.repeat();
    }
  }

  @override
  void dispose() {
    _pos.dispose();
    _shimmer.dispose();
    super.dispose();
  }

  void _release(double maxDx) {
    if (_done) return;
    final p = _pos.value / maxDx;
    if (p >= 0.85) {
      _done = true;
      Haptics.swipeComplete();
      _pos
          .animateTo(maxDx,
              duration: context.motion(AppMotion.fast), curve: AppMotion.curve)
          .whenComplete(() {
        widget.onComplete();
        Future<void>.delayed(const Duration(milliseconds: 900), () {
          if (!mounted) return;
          _done = false;
          _pos.value = 0;
        });
      });
    } else {
      final sim = SpringSimulation(
        const SpringDescription(mass: 1, stiffness: 420, damping: 26),
        _pos.value,
        0,
        0,
      );
      _pos.animateWith(sim);
    }
  }

  @override
  Widget build(BuildContext context) {
    final knob = widget.height - _pad * 2;
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth;
        final thumbStart = _pad + knob + 6;
        final maxDx = w - _pad - knob - thumbStart;
        return Semantics(
          label: 'Swipe to connect',
          hint: 'Drag the bolt to the right to start pairing',
          onTap: widget.onComplete,
          child: GlassCard(
            height: widget.height,
            radius: AppRadii.pill,
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                // Back.
                Positioned(
                  left: _pad,
                  child: _Circle(
                    size: knob,
                    color: AppColors.ctaWhite,
                    onTap: widget.onBack,
                    child: const Icon(AppIcons.chevronLeft,
                        size: 18, color: AppColors.ctaText),
                  ),
                ),
                // Label + shimmering chevrons.
                AnimatedBuilder(
                  animation: _pos,
                  builder: (context, child) => Opacity(
                    opacity: (1 - (_pos.value / maxDx) * 1.4).clamp(0, 1),
                    child: child,
                  ),
                  child: Padding(
                    padding: EdgeInsets.only(
                        left: thumbStart + knob + 14, right: knob + _pad + 8),
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            widget.label,
                            maxLines: 1,
                            overflow: TextOverflow.fade,
                            softWrap: false,
                            style: AppType.micro(
                                color: const Color(0xD9FFFFFF),
                                size: 11,
                                spacing: 1.6),
                          ),
                        ),
                        const SizedBox(width: 10),
                        _Chevrons(animation: _shimmer),
                      ],
                    ),
                  ),
                ),
                // End cap.
                Positioned(
                  right: _pad,
                  child: _Circle(
                    size: knob,
                    color: const Color(0x2EFFFFFF),
                    child: const Icon(AppIcons.play,
                        size: 16, color: Colors.white),
                  ),
                ),
                // Thumb.
                AnimatedBuilder(
                  animation: _pos,
                  builder: (context, _) {
                    final dx = _pos.value.clamp(0.0, maxDx);
                    final p = dx / maxDx;
                    return Positioned(
                      left: thumbStart + dx,
                      child: GestureDetector(
                        onHorizontalDragUpdate: (d) {
                          if (_done) return;
                          _pos.value =
                              (_pos.value + d.delta.dx).clamp(0, maxDx);
                        },
                        onHorizontalDragEnd: (_) => _release(maxDx),
                        child: Container(
                          width: knob,
                          height: knob,
                          decoration: BoxDecoration(
                            color: AppColors.mint,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.mint
                                    .withValues(alpha: 0.25 + 0.45 * p),
                                blurRadius: 10 + 18 * p,
                              ),
                            ],
                          ),
                          child: const Icon(AppIcons.bolt,
                              size: 20, color: AppColors.ctaText),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Circle extends StatelessWidget {
  const _Circle(
      {required this.size,
      required this.color,
      required this.child,
      this.onTap});
  final double size;
  final Color color;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Center(child: child),
        ),
      );
}

class _Chevrons extends StatelessWidget {
  const _Chevrons({required this.animation});
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) => ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (r) {
          final x = -1.5 + animation.value * 3;
          return LinearGradient(
            begin: Alignment(x - 0.6, 0),
            end: Alignment(x + 0.6, 0),
            colors: const [Color(0x66FFFFFF), Colors.white, Color(0x66FFFFFF)],
          ).createShader(r);
        },
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(AppIcons.chevronRight, size: 13, color: Colors.white),
            Icon(AppIcons.chevronRight, size: 13, color: Colors.white),
          ],
        ),
      ),
    );
  }
}

/// Simple pager control for slides 1–2: white ‹ and mint › in the same track.
class PagerControl extends StatelessWidget {
  const PagerControl(
      {super.key,
      required this.onNext,
      this.onBack,
      this.height = 64,
      this.label = 'NEXT'});
  final VoidCallback onNext;
  final VoidCallback? onBack;
  final double height;
  final String label;

  @override
  Widget build(BuildContext context) {
    const pad = 8.0;
    final knob = height - pad * 2;
    return GlassCard(
      height: height,
      radius: AppRadii.pill,
      padding: const EdgeInsets.symmetric(horizontal: pad),
      child: Row(
        children: [
          AnimatedOpacity(
            duration: AppMotion.fast,
            opacity: onBack == null ? 0.25 : 1,
            child: Semantics(
              button: true,
              label: 'Previous slide',
              child: _Circle(
                size: knob,
                color: AppColors.ctaWhite,
                onTap: onBack,
                child: const Icon(AppIcons.chevronLeft,
                    size: 18, color: AppColors.ctaText),
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(label,
                  style: AppType.micro(
                      color: const Color(0xD9FFFFFF), size: 11, spacing: 1.6)),
            ),
          ),
          Semantics(
            button: true,
            label: 'Next slide',
            child: _Circle(
              size: knob,
              color: AppColors.mint,
              onTap: onNext,
              child: const Icon(AppIcons.chevronRight,
                  size: 18, color: AppColors.ctaText),
            ),
          ),
        ],
      ),
    );
  }
}
