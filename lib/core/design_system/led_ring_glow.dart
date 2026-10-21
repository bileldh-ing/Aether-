import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/entities/entities.dart';
import '../utils/motion.dart';
import 'tokens.dart';

/// Where the LED ring sits inside `assets/images/aether_core.png` (the cut-out,
/// cropped to the product). Fractions of the image size, so they survive any
/// display scale. Re-measure if the image is re-cropped.
/// In the original 1024×1536 photo the ring is at (0.481, 0.416), Ø 0.123·w.
abstract final class AetherCoreImage {
  static const asset = 'assets/images/aether_core.png';
  static const aspect = 697 / 1280; // width / height of the cut-out
  static const ringCenter = Offset(0.472, 0.390);
  static const ringDiameter = 0.181; // × image width
}

enum LedPattern { breathe, fill, doublePulse, fastPulse, sweep, steady }

@immutable
class LedSpec {
  const LedSpec(this.color, this.pattern, this.period);
  final Color color;
  final LedPattern pattern;
  final Duration period;

  /// Section 6.3: device state ↔ LED ring ↔ app. One mapping for everything.
  static LedSpec of(NodeState s) => switch (s) {
        NodeState.idle => const LedSpec(
            AppColors.mint, LedPattern.breathe, Duration(milliseconds: 4200)),
        NodeState.charging => const LedSpec(
            AppColors.mint, LedPattern.fill, Duration(milliseconds: 2200)),
        NodeState.discharging => const LedSpec(AppColors.mint,
            LedPattern.doublePulse, Duration(milliseconds: 2600)),
        NodeState.island => const LedSpec(
            AppColors.amber, LedPattern.breathe, Duration(milliseconds: 3200)),
        NodeState.lowReserve => const LedSpec(
            AppColors.amber, LedPattern.fastPulse, Duration(milliseconds: 800)),
        NodeState.pairing => const LedSpec(
            AppColors.mint, LedPattern.sweep, Duration(milliseconds: 1600)),
        NodeState.updating => const LedSpec(
            Colors.white, LedPattern.breathe, Duration(milliseconds: 3600)),
        NodeState.offline => const LedSpec(
            AppColors.textTertiary, LedPattern.steady, Duration(seconds: 1)),
        NodeState.fault => const LedSpec(
            AppColors.danger, LedPattern.steady, Duration(seconds: 1)),
      };
}

/// Animated additive glow drawn exactly over the physical LED ring.
class LedRingGlow extends StatefulWidget {
  const LedRingGlow(
      {super.key, required this.spec, required this.diameter, this.boost = 0});
  final LedSpec spec;
  final double diameter;

  /// 0..1 extra intensity (used during commissioning).
  final double boost;

  @override
  State<LedRingGlow> createState() => _LedRingGlowState();
}

class _LedRingGlowState extends State<LedRingGlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: widget.spec.period);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(LedRingGlow old) {
    super.didUpdateWidget(old);
    if (old.spec.period != widget.spec.period) _c.duration = widget.spec.period;
    _sync();
  }

  void _sync() {
    if (context.reduceMotion || widget.spec.pattern == LedPattern.steady) {
      _c
        ..stop()
        ..value = 0.75;
    } else if (!_c.isAnimating) {
      _c.repeat();
    } else {
      // Restart so a new period takes effect.
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pad = widget.diameter * 1.6;
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => CustomPaint(
            size: Size.square(widget.diameter + pad),
            painter: LedRingPainter(
              color: widget.spec.color,
              pattern: widget.spec.pattern,
              t: _c.value,
              ringDiameter: widget.diameter,
              boost: widget.boost,
            ),
          ),
        ),
      ),
    );
  }
}

class LedRingPainter extends CustomPainter {
  LedRingPainter({
    required this.color,
    required this.pattern,
    required this.t,
    required this.ringDiameter,
    this.boost = 0,
  });

  final Color color;
  final LedPattern pattern;
  final double t;
  final double ringDiameter;
  final double boost;

  double get _intensity {
    switch (pattern) {
      case LedPattern.breathe:
        return 0.55 + 0.45 * (0.5 - 0.5 * math.cos(t * 2 * math.pi));
      case LedPattern.fastPulse:
        return 0.35 + 0.65 * math.pow(math.sin(t * math.pi), 2).toDouble();
      case LedPattern.doublePulse:
        double bump(double c) =>
            math.exp(-math.pow((t - c) / 0.07, 2).toDouble());
        return 0.5 + 0.5 * math.max(bump(0.2), bump(0.42));
      case LedPattern.fill:
        return 0.65 + 0.35 * t;
      case LedPattern.sweep:
        return 0.85;
      case LedPattern.steady:
        return 0.8;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = ringDiameter / 2 * 0.86;
    final stroke = ringDiameter * 0.085;
    final k = (_intensity + boost * 0.4).clamp(0.0, 1.3);
    final rect = Rect.fromCircle(center: c, radius: r);

    // Wide additive bloom.
    final bloom = Paint()
      ..blendMode = BlendMode.plus
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke * 3.2
      ..color = color.withValues(alpha: (0.30 * k).clamp(0, 1))
      ..maskFilter =
          MaskFilter.blur(BlurStyle.normal, (18 + 10 * k).clamp(18, 28));
    // Tight glow.
    final glow = Paint()
      ..blendMode = BlendMode.plus
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke * 1.6
      ..color = color.withValues(alpha: (0.55 * k).clamp(0, 1))
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, stroke * 1.2);
    // Core line.
    final core = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = Color.lerp(color, Colors.white, 0.25)!
          .withValues(alpha: (0.7 + 0.3 * k).clamp(0, 1));

    switch (pattern) {
      case LedPattern.sweep:
        final a = t * 2 * math.pi - math.pi / 2;
        canvas.drawCircle(c, r, core..color = color.withValues(alpha: 0.25));
        final seg = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round
          ..shader = SweepGradient(
            colors: [color.withValues(alpha: 0), color],
            stops: const [0.55, 1],
            transform: GradientRotation(a - 2 * math.pi * 0.98),
          ).createShader(rect);
        canvas.drawArc(rect, a - math.pi * 1.2, math.pi * 1.2, false, bloom);
        canvas.drawArc(rect, a - math.pi * 1.2, math.pi * 1.2, false, seg);
      case LedPattern.fill:
        // Upward fill from the bottom of the ring.
        final sweep = 2 * math.pi * Curves.easeInOut.transform(t);
        canvas.drawCircle(c, r, core..color = color.withValues(alpha: 0.45));
        canvas.drawCircle(c, r, bloom..color = color.withValues(alpha: 0.18));
        final full = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..color = Color.lerp(color, Colors.white, 0.3)!;
        canvas.drawArc(rect, math.pi / 2 - sweep / 2, sweep, false, glow);
        canvas.drawArc(rect, math.pi / 2 - sweep / 2, sweep, false, full);
      default:
        canvas.drawCircle(c, r, bloom);
        canvas.drawCircle(c, r, glow);
        canvas.drawCircle(c, r, core);
    }
  }

  @override
  bool shouldRepaint(LedRingPainter old) =>
      old.t != t ||
      old.color != color ||
      old.pattern != pattern ||
      old.boost != boost;
}

/// The product cut-out on the dark background: radial mint glow behind,
/// floor shadow, faint reflection, and the live LED overlay on the ring.
class ProductHero extends StatelessWidget {
  const ProductHero({
    super.key,
    required this.width,
    required this.state,
    this.boost = 0,
    this.reflection = true,
  });

  final double width;
  final NodeState state;
  final double boost;
  final bool reflection;

  @override
  Widget build(BuildContext context) {
    final h = width / AetherCoreImage.aspect;
    final ringD = width * AetherCoreImage.ringDiameter;
    final ringC = Offset(width * AetherCoreImage.ringCenter.dx,
        h * AetherCoreImage.ringCenter.dy);
    final spec = LedSpec.of(state);

    return Semantics(
      image: true,
      label: 'Aether Smart Home Power Core',
      child: SizedBox(
        width: width,
        height: h,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Radial glow behind the product.
            Positioned(
              left: -width * 0.45,
              right: -width * 0.45,
              top: h * 0.05,
              height: h * 0.8,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      spec.color.withValues(alpha: 0.12),
                      spec.color.withValues(alpha: 0)
                    ],
                    stops: const [0, 0.7],
                  ),
                ),
              ),
            ),
            // Floor shadow.
            Positioned(
              left: width * 0.04,
              right: width * 0.04,
              top: h * 0.965,
              height: h * 0.05,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius:
                      BorderRadius.all(Radius.elliptical(width, h * 0.05)),
                  gradient: const RadialGradient(
                      colors: [Color(0x99000000), Color(0x00000000)]),
                ),
              ),
            ),
            // Faint reflection.
            if (reflection)
              Positioned(
                left: 0,
                right: 0,
                top: h * 0.995,
                height: h * 0.22,
                child: ClipRect(
                  child: ShaderMask(
                    shaderCallback: (r) => const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x1FFFFFFF), Color(0x00FFFFFF)],
                    ).createShader(r),
                    blendMode: BlendMode.dstIn,
                    child: Transform.flip(
                      flipY: true,
                      child: Image.asset(
                        AetherCoreImage.asset,
                        width: width,
                        height: h,
                        fit: BoxFit.fill,
                        alignment: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),
              ),
            Positioned.fill(
              child: Image.asset(AetherCoreImage.asset,
                  fit: BoxFit.fill, filterQuality: FilterQuality.medium),
            ),
            Positioned(
              left: ringC.dx - (ringD + ringD * 1.6) / 2,
              top: ringC.dy - (ringD + ringD * 1.6) / 2,
              child: LedRingGlow(spec: spec, diameter: ringD, boost: boost),
            ),
          ],
        ),
      ),
    );
  }
}
