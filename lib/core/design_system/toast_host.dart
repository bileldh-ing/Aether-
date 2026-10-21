import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../utils/motion.dart';
import 'app_icons.dart';
import 'surfaces.dart';
import 'tokens.dart';
import 'typography.dart';

/// Calm glass toast that floats near the top of every screen.
class ToastHost extends ConsumerWidget {
  const ToastHost({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final toast = ref.watch(toastProvider);
    final top = MediaQuery.paddingOf(context).top + 64;
    return Stack(
      children: [
        child,
        Positioned(
          left: 20,
          right: 20,
          top: top,
          child: IgnorePointer(
            child: AnimatedSwitcher(
              duration: context.motion(AppMotion.medium),
              switchInCurve: AppMotion.curve,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, a) => FadeTransition(
                opacity: a,
                child: SlideTransition(
                  position: Tween(begin: const Offset(0, -0.3), end: Offset.zero).animate(a),
                  child: child,
                ),
              ),
              child: toast == null
                  ? const SizedBox.shrink()
                  : Center(
                      key: ValueKey(toast),
                      child: Semantics(
                        liveRegion: true,
                        child: GlassCard(
                          radius: AppRadii.pill,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                switch (toast.tone) {
                                  ToastTone.success => AppIcons.check,
                                  ToastTone.warning => AppIcons.warning,
                                  ToastTone.neutral => AppIcons.bolt,
                                },
                                size: 16,
                                color: toast.tone == ToastTone.warning ? AppColors.amber : AppColors.mint,
                              ),
                              const SizedBox(width: 10),
                              Flexible(
                                child: Text(
                                  toast.message,
                                  style: AppType.body(13, weight: FontWeight.w600),
                                  maxLines: 2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}
