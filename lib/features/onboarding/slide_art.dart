import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/design_system/design_system.dart';
import '../../core/utils/motion.dart';

/// Slide 1 hero: sun with slowly rotating rays rising over a solar arc.
class SunArt extends StatefulWidget {
  const SunArt({super.key, required this.size});
  final double size;
  @override
  State<SunArt> createState() => _SunArtState();
}

class _SunArtState extends State<SunArt> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 14));

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
  Widget build(BuildContext context) => RepaintBoundary(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => CustomPaint(size: Size.square(widget.size), painter: _SunPainter(_c.value)),
        ),
      );
}

class _SunPainter extends CustomPainter {
  _SunPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final c = Offset(w / 2, w * 0.42);
    final sunR = w * 0.13;

    // Sun path arcs.
    for (var i = 0; i < 3; i++) {
      final r = w * (0.30 + i * 0.09);
      canvas.drawArc(
        Rect.fromCircle(center: Offset(w / 2, w * 0.78), radius: r),
        math.pi,
        math.pi,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = Colors.white.withValues(alpha: 0.06 + 0.02 * (2 - i)),
      );
    }
    // Harvest arc (mint), sweeping with time.
    final sweep = math.pi * (0.35 + 0.65 * (0.5 - 0.5 * math.cos(t * 2 * math.pi)));
    canvas.drawArc(
      Rect.fromCircle(center: Offset(w / 2, w * 0.78), radius: w * 0.39),
      math.pi,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = AppColors.mint,
    );

    // Glow.
    canvas.drawCircle(
      c,
      sunR * 2.6,
      Paint()
        ..shader = RadialGradient(
          colors: [AppColors.amber.withValues(alpha: 0.28), AppColors.amber.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: c, radius: sunR * 2.6)),
    );
    // Rays.
    final ray = Paint()
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..color = AppColors.amber.withValues(alpha: 0.85);
    for (var i = 0; i < 12; i++) {
      final a = t * 2 * math.pi + i * math.pi / 6;
      final pulse = 0.5 + 0.5 * math.sin(t * 12 * math.pi + i);
      final r1 = sunR * 1.35;
      final r2 = sunR * (1.65 + 0.2 * pulse);
      canvas.drawLine(
        c + Offset(math.cos(a), math.sin(a)) * r1,
        c + Offset(math.cos(a), math.sin(a)) * r2,
        ray,
      );
    }
    canvas.drawCircle(c, sunR, Paint()..color = AppColors.amber);
    canvas.drawCircle(c, sunR * 0.62, Paint()..color = const Color(0xFFFFD27A));

    // Horizon + panels.
    final horizonY = w * 0.78;
    canvas.drawLine(
      Offset(w * 0.06, horizonY),
      Offset(w * 0.94, horizonY),
      Paint()
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: 0.12),
    );
    for (var i = 0; i < 3; i++) {
      final x = w * (0.24 + i * 0.2);
      final path = Path()
        ..moveTo(x, horizonY - 4)
        ..lineTo(x + w * 0.15, horizonY - 4)
        ..lineTo(x + w * 0.12, horizonY - w * 0.10)
        ..lineTo(x + w * 0.03, horizonY - w * 0.10)
        ..close();
      canvas.drawPath(path, Paint()..color = const Color(0xFF23272B));
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = AppColors.mint.withValues(alpha: 0.45),
      );
    }
  }

  @override
  bool shouldRepaint(_SunPainter old) => old.t != t;
}

/// Slide 2 hero: the gauge ring with a pulsing grid line.
class GridArt extends StatefulWidget {
  const GridArt({super.key, required this.size});
  final double size;
  @override
  State<GridArt> createState() => _GridArtState();
}

class _GridArtState extends State<GridArt> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600));

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
    final d = widget.size * 0.72;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          RepaintBoundary(
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, _) => CustomPaint(size: Size.square(widget.size), painter: _GridPainter(_c.value)),
            ),
          ),
          SizedBox(
            width: d,
            height: d,
            child: CustomPaint(painter: GaugePainter(fraction: 0.84, color: AppColors.mint)),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('< 20 ms', style: AppType.display(widget.size * 0.13, weight: FontWeight.w300)),
              const SizedBox(height: 4),
              Text('Island switch-over', style: AppType.body(12, color: AppColors.mint)),
            ],
          ),
        ],
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  _GridPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final grid = Paint()
      ..strokeWidth = 1
      ..color = Colors.white.withValues(alpha: 0.045);
    for (var i = 1; i < 8; i++) {
      final p = w * i / 8;
      canvas.drawLine(Offset(p, 0), Offset(p, w), grid);
      canvas.drawLine(Offset(0, p), Offset(w, p), grid);
    }
    // Pulse travelling along the horizontal mains line.
    final y = w * 0.5;
    canvas.drawLine(
      Offset(0, y),
      Offset(w, y),
      Paint()
        ..strokeWidth = 1
        ..color = AppColors.mint.withValues(alpha: 0.18),
    );
    final x = w * t;
    canvas.drawLine(
      Offset((x - w * 0.18).clamp(0, w), y),
      Offset(x, y),
      Paint()
        ..strokeWidth = 2
        ..shader = LinearGradient(colors: [AppColors.mint.withValues(alpha: 0), AppColors.mint])
            .createShader(Rect.fromLTWH(x - w * 0.18, y - 1, w * 0.18, 2)),
    );
    canvas.drawCircle(
      Offset(x, y),
      6,
      Paint()
        ..color = AppColors.mint.withValues(alpha: 0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    // Radial fade so the grid dissolves at the edges.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0x00000000), Color(0xFF1A1C1E)],
          stops: [0.45, 1],
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(_GridPainter old) => old.t != t;
}
