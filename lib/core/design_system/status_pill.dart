import 'package:flutter/material.dart';

import '../utils/motion.dart';
import 'tokens.dart';
import 'typography.dart';

/// `● GRID ONLINE` pill with a slow 2.4 s breathing dot.
class StatusPill extends StatefulWidget {
  const StatusPill(
      {super.key,
      required this.label,
      this.color = AppColors.mint,
      this.breathe = true});
  final String label;
  final Color color;
  final bool breathe;

  @override
  State<StatusPill> createState() => _StatusPillState();
}

class _StatusPillState extends State<StatusPill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: AppMotion.breathe);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(StatusPill old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    if (widget.breathe && !context.reduceMotion) {
      if (!_c.isAnimating) _c.repeat(reverse: true);
    } else {
      _c
        ..stop()
        ..value = 1;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Status: ${widget.label.toLowerCase()}',
      child: Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _c,
              builder: (context, _) {
                final t = Curves.easeInOut.transform(_c.value);
                return Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: widget.color.withValues(alpha: 0.55 + 0.45 * t),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: widget.color.withValues(alpha: 0.5 * t),
                          blurRadius: 6 + 4 * t),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(width: 8),
            AnimatedSwitcher(
              duration: AppMotion.fast,
              child: Text(
                widget.label,
                key: ValueKey(widget.label),
                style: AppType.micro(
                    color: AppColors.textPrimary, size: 10.5, spacing: 1.2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
