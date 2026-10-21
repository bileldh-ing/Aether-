import 'package:flutter/material.dart';

import '../haptics/haptics.dart';
import '../utils/motion.dart';
import 'surfaces.dart';
import 'tokens.dart';

class NavItem {
  const NavItem(this.icon, this.label);
  final IconData icon;
  final String label;
}

/// Floating glass navigation. The selected item sits in a white circle that
/// slides between items with a spring.
class FloatingNavPill extends StatelessWidget {
  const FloatingNavPill({
    super.key,
    required this.items,
    required this.index,
    required this.onChanged,
    this.height = 64,
    this.slot = 54,
    this.circle = 48,
  });

  final List<NavItem> items;
  final int index;
  final ValueChanged<int> onChanged;
  final double height;
  final double slot;
  final double circle;

  @override
  Widget build(BuildContext context) {
    const pad = 8.0;
    final width = items.length * slot + pad * 2;
    return GlassCard(
      height: height,
      width: width,
      radius: AppRadii.pill,
      child: Stack(
        children: [
          AnimatedPositioned(
            duration: context.motion(const Duration(milliseconds: 520)),
            curve: Curves.easeOutBack,
            left: pad + index * slot + (slot - circle) / 2,
            top: (height - 2 - circle) / 2,
            child: Container(
              width: circle,
              height: circle,
              decoration: const BoxDecoration(color: AppColors.ctaWhite, shape: BoxShape.circle),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: pad),
            child: Row(
              children: [
                for (var i = 0; i < items.length; i++)
                  Semantics(
                    button: true,
                    selected: i == index,
                    label: items[i].label,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        if (i == index) return;
                        Haptics.nav();
                        onChanged(i);
                      },
                      child: SizedBox(
                        width: slot,
                        height: height - 2,
                        child: Center(
                          child: TweenAnimationBuilder<Color?>(
                            tween: ColorTween(
                              end: i == index ? AppColors.ctaText : AppColors.textSecondary,
                            ),
                            duration: context.motion(AppMotion.fast),
                            builder: (context, c, _) => Icon(items[i].icon, size: 21, color: c),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
