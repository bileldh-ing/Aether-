import 'package:flutter/widgets.dart';

extension MotionX on BuildContext {
  /// True when the OS asks for reduced motion.
  bool get reduceMotion => MediaQuery.maybeDisableAnimationsOf(this) ?? false;

  /// Returns [d], or zero when reduced motion is on.
  Duration motion(Duration d) => reduceMotion ? Duration.zero : d;
}

/// A repeating controller that stays still under reduced motion.
mixin LoopingAnimation<T extends StatefulWidget> on State<T>, TickerProviderStateMixin<T> {
  late final AnimationController loop;
  Duration get loopDuration;
  bool get loopReverse => false;

  @override
  void initState() {
    super.initState();
    loop = AnimationController(vsync: this, duration: loopDuration);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (context.reduceMotion) {
      loop
        ..stop()
        ..value = 0.5;
    } else if (!loop.isAnimating) {
      loop.repeat(reverse: loopReverse);
    }
  }

  @override
  void dispose() {
    loop.dispose();
    super.dispose();
  }
}
