import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../utils/format.dart';
import '../utils/motion.dart';
import 'app_icons.dart';
import 'tokens.dart';
import 'typography.dart';

/// Animated node diagram Solar → Core → Home ↔ Grid with flowing particles.
class FlowDiagram extends StatefulWidget {
  const FlowDiagram({
    super.key,
    required this.solarW,
    required this.homeW,
    required this.gridW,
    required this.batteryW,
    required this.soc,
    required this.gridOnline,
    this.accent = AppColors.mint,
  });

  final double solarW;
  final double homeW;

  /// + import / − export
  final double gridW;

  /// + charge / − discharge
  final double batteryW;
  final double soc;
  final bool gridOnline;
  final Color accent;

  @override
  State<FlowDiagram> createState() => _FlowDiagramState();
}

class _FlowDiagramState extends State<FlowDiagram>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 6));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (context.reduceMotion) {
      _c.stop();
    } else if (!_c.isAnimating) {
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
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth;
        final h = w * 1.05;
        final solar = Offset(w / 2, h * 0.12);
        final core = Offset(w / 2, h * 0.5);
        final home = Offset(w * 0.18, h * 0.86);
        final grid = Offset(w * 0.82, h * 0.86);
        return SizedBox(
          width: w,
          height: h,
          child: Stack(
            children: [
              RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _c,
                  builder: (context, _) => CustomPaint(
                    size: Size(w, h),
                    painter: _FlowPainter(
                      t: _c.value,
                      solar: solar,
                      core: core,
                      home: home,
                      grid: grid,
                      solarW: widget.solarW,
                      homeW: widget.homeW,
                      gridW: widget.gridOnline ? widget.gridW : 0,
                      accent: widget.accent,
                    ),
                  ),
                ),
              ),
              _node(solar, AppIcons.sunFill, AppColors.amber, 'Solar',
                  Fmt.watts(widget.solarW)),
              _node(home, AppIcons.home, AppColors.textPrimary, 'Home',
                  Fmt.watts(widget.homeW)),
              _node(
                grid,
                AppIcons.plug,
                widget.gridOnline ? AppColors.textPrimary : AppColors.amber,
                'Grid',
                !widget.gridOnline
                    ? 'Offline'
                    : widget.gridW < -5
                        ? '↑ ${Fmt.watts(-widget.gridW)}'
                        : '↓ ${Fmt.watts(widget.gridW.clamp(0, double.infinity))}',
              ),
              _core(core),
            ],
          ),
        );
      },
    );
  }

  Widget _node(
      Offset at, IconData icon, Color color, String label, String value) {
    const s = 64.0;
    return Positioned(
      left: at.dx - 60,
      top: at.dy - s / 2,
      width: 120,
      child: Semantics(
        label: '$label $value',
        child: Column(
          children: [
            Container(
              width: s,
              height: s,
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(label,
                style: AppType.body(12, color: AppColors.textSecondary)),
            const SizedBox(height: 2),
            Text(value, style: AppType.mono(13)),
          ],
        ),
      ),
    );
  }

  Widget _core(Offset at) {
    const s = 96.0;
    final dir = widget.batteryW > 20
        ? 'Charging ${Fmt.watts(widget.batteryW)}'
        : widget.batteryW < -20
            ? 'Supplying ${Fmt.watts(-widget.batteryW)}'
            : 'Holding';
    return Positioned(
      left: at.dx - 80,
      top: at.dy - s / 2,
      width: 160,
      child: Column(
        children: [
          Container(
            width: s,
            height: s,
            decoration: BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
              border: Border.all(
                  color: widget.accent.withValues(alpha: 0.7), width: 1.5),
              boxShadow: [
                BoxShadow(
                    color: widget.accent.withValues(alpha: 0.18),
                    blurRadius: 24)
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(AppIcons.bolt, color: widget.accent, size: 20),
                const SizedBox(height: 2),
                Text('${(widget.soc * 100).round()}%',
                    style: AppType.display(20,
                        weight: FontWeight.w500, tabular: true)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text('Power Core',
              style: AppType.body(12, color: AppColors.textSecondary)),
          const SizedBox(height: 2),
          Text(dir, style: AppType.mono(12, color: widget.accent)),
        ],
      ),
    );
  }
}

class _FlowPainter extends CustomPainter {
  _FlowPainter({
    required this.t,
    required this.solar,
    required this.core,
    required this.home,
    required this.grid,
    required this.solarW,
    required this.homeW,
    required this.gridW,
    required this.accent,
  });

  final double t;
  final Offset solar, core, home, grid;
  final double solarW, homeW, gridW;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    _link(canvas, solar, core, solarW, AppColors.amber);
    _link(canvas, core, home, homeW, accent);
    // Grid: import flows grid → core, export core → grid.
    if (gridW >= 0) {
      _link(canvas, grid, core, gridW, AppColors.textSecondary);
    } else {
      _link(canvas, core, grid, -gridW, accent);
    }
  }

  void _link(Canvas canvas, Offset a, Offset b, double watts, Color color) {
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = const Color(0x14FFFFFF);
    canvas.drawLine(a, b, line);
    if (watts < 10) return;
    final count = (3 + watts / 600).clamp(3, 9).round();
    final speed = (0.6 + watts / 1500).clamp(0.6, 3.0);
    final dist = (b - a).distance;
    for (var i = 0; i < count; i++) {
      final p = ((t * speed * 6 + i / count) % 1.0);
      // Skip the parts hidden under the node circles.
      final edge = 44 / dist;
      if (p < edge || p > 1 - edge) continue;
      final pos = Offset.lerp(a, b, p)!;
      final fade = math.sin(p * math.pi);
      canvas.drawCircle(
        pos,
        5,
        Paint()
          ..color = color.withValues(alpha: 0.25 * fade)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      canvas.drawCircle(
          pos, 2.2, Paint()..color = color.withValues(alpha: 0.9 * fade));
    }
  }

  @override
  bool shouldRepaint(_FlowPainter old) => true;
}
