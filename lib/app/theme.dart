import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

import '../core/design_system/tokens.dart';
import '../core/design_system/typography.dart';

/// Dark-only theme. Material is used only as plumbing; every visible surface is
/// a custom widget, so the default Material look never shows.
ThemeData buildAetherTheme() {
  final base = ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.bg,
    canvasColor: AppColors.bg,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.mint,
      secondary: AppColors.mint,
      surface: AppColors.surface,
      error: AppColors.danger,
      onPrimary: AppColors.ctaText,
      onSurface: AppColors.textPrimary,
    ),
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(
      fontFamily: AppType.useGoogleFonts ? null : 'Manrope',
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.transparent,
      elevation: 0,
      modalBarrierColor: Color(0xB3000000),
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: AppColors.mint,
      inactiveTrackColor: AppColors.surfaceHigh,
      thumbColor: AppColors.ctaWhite,
      overlayColor: AppColors.mintDim,
      trackHeight: 4,
      showValueIndicator: ShowValueIndicator.never,
    ),
    textSelectionTheme: const TextSelectionThemeData(cursorColor: AppColors.mint),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
  );
}
