import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../utils/motion.dart';
import 'tokens.dart';
import 'typography.dart';

/// 270° open-bottom gauge (starts at 135°, ends at 45°). The progress arc fades
/// toward its tail so the head reads strongest, with a glowing knob.
class EnergyGauge extends StatefulWidget {
  const EnergyGauge({
    super.key,
    required this.fraction,
    required this.child,
    this.diameter = 232,
    this.color = AppColors.mint,
    this.showEndLabels = true,
    this.semanticLabel,
  });

  final double fraction;
  final Widget child;
  final double diameter;
  final Color color;
  final bool showEndLabels;
  final String? semanticLabel;

  @override
  State<EnergyGauge> createState() => _EnergyGaugeState();
}

class _EnergyGaugeState extends State<EnergyGauge> {
  double _from = 0;

  @override
  void didUpdateWidget(EnergyGauge old) {
    super.didUpdateWidget(old);
    if (old.fraction != widget.fraction) _from = old.fraction;
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.diameter;
    return Semantics(
      label: widget.semanticLabel,
      child: SizedBox(
        width: d,
        height: d,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            RepaintBoundary(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: _from, end: widget.fraction.clamp(0, 1)),
                duration: context.motion(const Duration(milliseconds: 1200)),
                curve: const _SpringCurve(),
                builder: (context, v, _) => CustomPaint(
                  size: Size.square(d),
                  painter: GaugePainter(fraction: v, color: widget.color),
                ),
              ),
            ),
            widget.child,
            if (widget.showEndLabels) ...[
              Positioned(
                left: d * 0.5 - math.cos(math.pi / 4) * d * 0.5 - 4,
                bottom: d * 0.5 - math.sin(math.pi / 4) * d * 0.5 - 22,
                child: Text('0%',
                    style: AppType.mono(10.5,
                        weight: FontWeight.w500,
                        color: AppColors.textTertiary)),
              ),
              Positioned(
                right: d * 0.5 - math.cos(math.pi / 4) * d * 0.5 - 10,
                bottom: d * 0.5 - math.sin(math.pi / 4) * d * 0.5 - 22,
                child: Text('100%',
                    style: AppType.mono(10.5,
                        weight: FontWeight.w500,
                        color: AppColors.textTertiary)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Lightly under-damped spring.
class _SpringCurve extends Curve {
  const _SpringCurve();
  @override
  double transformInternal(double t) {
    const damping = 6.5;
    const freq = 9.0;
    return 1 - math.exp(-damping * t) * math.cos(freq * t);
  }
}

class GaugePainter extends CustomPainter {
  GaugePainter(
      {required this.fraction,
      required this.color,
      this.trackColor = AppColors.track});

  final double fraction;
  final Color color;
  final Color trackColor;

  static const start = 3 * math.pi / 4; // 135°
  static const sweep = 3 * math.pi / 2; // 270°

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 6;
    final rect = Rect.fromCircle(center: c, radius: r);

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..color = trackColor;
    canvas.drawArc(rect, start, sweep, false, track);

    final f = fraction.clamp(0.0, 1.0);
    if (f <= 0.001) return;
    final s = sweep * f;

    final shader = SweepGradient(
      startAngle: 0,
      endAngle: s,
      colors: [
        color.withValues(alpha: 0.08),
        color.withValues(alpha: 0.55),
        color
      ],
      stops: const [0, 0.55, 1],
      transform: const GradientRotation(start),
    ).createShader(rect);

    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..shader = shader;
    canvas.drawArc(rect, start, s, false, arc);

    // Soft glow along the head third.
    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..color = color.withValues(alpha: 0.22)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    final headSweep = math.min(s, sweep * 0.18);
    canvas.drawArc(rect, start + s - headSweep, headSweep, false, glow);

    // Knob.
    final a = start + s;
    final p = Offset(c.dx + r * math.cos(a), c.dy + r * math.sin(a));
    canvas.drawCircle(
      p,
      9,
      Paint()
        ..color = color.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );
    canvas.drawCircle(p, 4, Paint()..color = color);
    canvas.drawCircle(
        p, 1.6, Paint()..color = Colors.white.withValues(alpha: 0.9));
  }

  @override
  bool shouldRepaint(GaugePainter old) =>
      old.fraction != fraction || old.color != color;
}
