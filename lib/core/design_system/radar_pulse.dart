import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../utils/motion.dart';
import 'tokens.dart';

/// Pairing radar: faint outer ring with slow expanding ripples, an inner
/// surface disc with a glowing mint border, and an optional progress ring
/// that fills during commissioning. [burst] (0..1) plays the success burst.
class RadarPulse extends StatefulWidget {
  const RadarPulse({
    super.key,
    required this.outer,
    required this.inner,
    required this.child,
    this.progress = 0,
    this.fast = false,
    this.burst = 0,
    this.color = AppColors.mint,
  });

  final double outer;
  final double inner;
  final Widget child;
  final double progress;
  final bool fast;
  final double burst;
  final Color color;

  @override
  State<RadarPulse> createState() => _RadarPulseState();
}

class _RadarPulseState extends State<RadarPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: _period);

  Duration get _period => widget.fast
      ? const Duration(milliseconds: 1400)
      : const Duration(milliseconds: 4200);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(RadarPulse old) {
    super.didUpdateWidget(old);
    if (old.fast != widget.fast) {
      _c.duration = _period;
      _sync(restart: true);
    }
  }

  void _sync({bool restart = false}) {
    if (context.reduceMotion) {
      _c.stop();
    } else if (restart || !_c.isAnimating) {
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
    return SizedBox(
      width: widget.outer,
      height: widget.outer,
      child: Stack(
        alignment: Alignment.center,
        children: [
          RepaintBoundary(
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, _) => CustomPaint(
                size: Size.square(widget.outer),
                painter: _RadarPainter(
                  t: context.reduceMotion ? -1 : _c.value,
                  inner: widget.inner,
                  progress: widget.progress,
                  burst: widget.burst,
                  color: widget.color,
                ),
              ),
            ),
          ),
          SizedBox(
              width: widget.inner,
              height: widget.inner,
              child: ClipOval(child: widget.child)),
        ],
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  _RadarPainter({
    required this.t,
    required this.inner,
    required this.progress,
    required this.burst,
    required this.color,
  });

  final double t;
  final double inner;
  final double progress;
  final double burst;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final outerR = size.width / 2 - 1;
    final innerR = inner / 2;

    // Outer static ring + soft inner fill.
    canvas.drawCircle(
      c,
      outerR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0x0DFFFFFF),
    );
    canvas.drawCircle(c, outerR, Paint()..color = const Color(0x05FFFFFF));

    // Ripples.
    if (t >= 0) {
      for (var i = 0; i < 2; i++) {
        final p = (t + i * 0.5) % 1.0;
        final r = innerR + (outerR - innerR) * Curves.easeOut.transform(p);
        canvas.drawCircle(
          c,
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = color.withValues(alpha: 0.22 * (1 - p)),
        );
      }
    }

    // Inner disc.
    canvas.drawCircle(c, innerR, Paint()..color = AppColors.surface);
    canvas.drawCircle(
      c,
      innerR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..color = color.withValues(alpha: 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawCircle(
      c,
      innerR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = color.withValues(alpha: 0.7),
    );

    // Commissioning progress.
    if (progress > 0) {
      final rect = Rect.fromCircle(center: c, radius: innerR);
      canvas.drawArc(
        rect,
        -math.pi / 2,
        2 * math.pi * progress.clamp(0, 1),
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round
          ..color = color,
      );
      canvas.drawArc(
        rect,
        -math.pi / 2,
        2 * math.pi * progress.clamp(0, 1),
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10
          ..color = color.withValues(alpha: 0.25)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    }

    // Success burst.
    if (burst > 0) {
      final r = innerR +
          (outerR * 1.2 - innerR) * Curves.easeOutCubic.transform(burst);
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3 * (1 - burst) + 0.5
          ..color = color.withValues(alpha: 0.8 * (1 - burst)),
      );
      canvas.drawCircle(c, innerR,
          Paint()..color = color.withValues(alpha: 0.12 * (1 - burst)));
    }
  }

  @override
  bool shouldRepaint(_RadarPainter old) =>
      old.t != t ||
      old.progress != progress ||
      old.burst != burst ||
      old.color != color;
}
