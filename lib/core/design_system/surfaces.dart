import 'dart:ui';

import 'package:flutter/material.dart';

import 'tokens.dart';
import 'typography.dart';

/// Card: surface fill + 1 px hairline + faint top-inner highlight. No shadow.
class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    this.radius = AppRadii.card,
    this.padding = const EdgeInsets.all(20),
    this.onTap,
    this.color = AppColors.surface,
    this.semanticLabel,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius);
    Widget body = DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: r,
        border: Border.all(color: AppColors.border),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.center,
          colors: [Color.alphaBlend(const Color(0x0AFFFFFF), color), color],
        ),
      ),
      child: Padding(padding: padding, child: child),
    );
    if (onTap != null) {
      body = Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: r,
          splashColor: const Color(0x0DFFFFFF),
          highlightColor: const Color(0x08FFFFFF),
          child: body,
        ),
      );
    }
    return Semantics(label: semanticLabel, button: onTap != null, child: body);
  }
}

/// Glass: backdrop blur 24, white @ 7 % fill, white @ 8 % border.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.radius = AppRadii.hero,
    this.padding = EdgeInsets.zero,
    this.height,
    this.width,
    this.blur = 24,
    this.tint = AppColors.glassFill,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;
  final double? height;
  final double? width;
  final double blur;

  /// Fill over the blurred backdrop. Use a dark tint when the card floats
  /// over bright imagery so text keeps its contrast.
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius);
    return ClipRRect(
      borderRadius: r,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          height: height,
          width: width,
          padding: padding,
          decoration: BoxDecoration(
            color: tint,
            borderRadius: r,
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// 44 px circular icon button (48 dp hit target).
class IconCircleButton extends StatelessWidget {
  const IconCircleButton({
    super.key,
    required this.icon,
    required this.onTap,
    required this.semanticLabel,
    this.badge = false,
    this.size = AppSpace.iconButton,
    this.background = AppColors.surfaceHigh,
    this.foreground = AppColors.textPrimary,
    this.onLongPress,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final String semanticLabel;
  final bool badge;
  final double size;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    color: background,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Icon(icon, size: 20, color: foreground),
                ),
                if (badge)
                  Positioned(
                    right: 9,
                    top: 9,
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: AppColors.mint,
                        shape: BoxShape.circle,
                        border: Border.all(color: background, width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Full-width white CTA pill (60 px).
class PrimaryButton extends StatelessWidget {
  const PrimaryButton(
      {super.key, required this.label, required this.onTap, this.height = 60});
  final String label;
  final VoidCallback? onTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedOpacity(
          duration: AppMotion.fast,
          opacity: onTap == null ? 0.5 : 1,
          child: Container(
            height: height,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.ctaWhite,
              borderRadius: BorderRadius.circular(AppRadii.pill),
            ),
            child: Text(label,
                style: AppType.body(15,
                    weight: FontWeight.w600, color: AppColors.ctaText)),
          ),
        ),
      ),
    );
  }
}

/// Quiet secondary pill.
class GhostButton extends StatelessWidget {
  const GhostButton(
      {super.key,
      required this.label,
      required this.onTap,
      this.height = 52,
      this.color});
  final String label;
  final VoidCallback? onTap;
  final double height;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: height,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.surfaceHigh,
            borderRadius: BorderRadius.circular(AppRadii.pill),
            border: Border.all(color: AppColors.border),
          ),
          child: Text(label,
              style: AppType.body(14,
                  weight: FontWeight.w600,
                  color: color ?? AppColors.textPrimary)),
        ),
      ),
    );
  }
}

/// Small tinted square for list-tile leading icons.
class TintedIcon extends StatelessWidget {
  const TintedIcon(
      {super.key,
      required this.icon,
      this.color = AppColors.mint,
      this.size = 40,
      this.circle = false});
  final IconData icon;
  final Color color;
  final double size;
  final bool circle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: circle ? null : BorderRadius.circular(12),
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
      ),
      child: Icon(icon, size: size * 0.5, color: color),
    );
  }
}

/// Dark circle holding an accent icon (dashboard stat cards).
class DarkIconCircle extends StatelessWidget {
  const DarkIconCircle(
      {super.key, required this.icon, required this.color, this.size = 40});
  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xFF17181A),
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.border),
        ),
        child: Icon(icon, size: size * 0.5, color: color),
      );
}

class MicroLabel extends StatelessWidget {
  const MicroLabel(this.text,
      {super.key, this.color = AppColors.textSecondary, this.size = 10.5});
  final String text;
  final Color color;
  final double size;
  @override
  Widget build(BuildContext context) =>
      Text(text, style: AppType.micro(color: color, size: size));
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 20, 4, 10),
        child: Row(
          children: [
            Expanded(child: MicroLabel(text.toUpperCase())),
            if (trailing != null) trailing!,
          ],
        ),
      );
}

/// Pill-style switch matching the design language.
class AetherSwitch extends StatelessWidget {
  const AetherSwitch(
      {super.key,
      required this.value,
      required this.onChanged,
      this.semanticLabel});
  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: value,
      label: semanticLabel,
      child: GestureDetector(
        onTap: onChanged == null ? null : () => onChanged!(!value),
        child: AnimatedContainer(
          duration: AppMotion.fast,
          curve: AppMotion.curve,
          width: 48,
          height: 28,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: value ? AppColors.mint : AppColors.surfaceHigh,
            borderRadius: BorderRadius.circular(AppRadii.pill),
            border: Border.all(
                color: value ? Colors.transparent : AppColors.glassBorder),
          ),
          child: AnimatedAlign(
            duration: AppMotion.fast,
            curve: AppMotion.curve,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: value ? AppColors.ctaText : AppColors.textSecondary,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
