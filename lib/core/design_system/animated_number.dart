import 'package:flutter/material.dart';

import '../utils/motion.dart';
import 'tokens.dart';

/// Counts up from 0 on first paint, then tweens between updates (never snaps).
class AnimatedNumber extends StatefulWidget {
  const AnimatedNumber({
    super.key,
    required this.value,
    required this.style,
    this.format,
    this.duration = AppMotion.slow,
    this.countUp = true,
  });

  final double value;
  final TextStyle style;
  final String Function(double v)? format;
  final Duration duration;
  final bool countUp;

  @override
  State<AnimatedNumber> createState() => _AnimatedNumberState();
}

class _AnimatedNumberState extends State<AnimatedNumber> {
  late double _from = widget.countUp ? 0 : widget.value;

  @override
  void didUpdateWidget(AnimatedNumber old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) _from = old.value;
  }

  @override
  Widget build(BuildContext context) {
    final first = _from == 0 && widget.countUp;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: _from, end: widget.value),
      duration: context.motion(first ? const Duration(milliseconds: 1100) : widget.duration),
      curve: AppMotion.curve,
      builder: (context, v, _) => Text(
        widget.format?.call(v) ?? v.round().toString(),
        style: widget.style,
        maxLines: 1,
      ),
    );
  }
}
