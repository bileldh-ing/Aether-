import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'tokens.dart';

/// Type helpers. `useGoogleFonts` is switched off in tests so goldens never
/// hit the network.
abstract final class AppType {
  static bool useGoogleFonts = true;

  static const _tabular = [FontFeature.tabularFigures()];

  static TextStyle _build(
    String family,
    TextStyle Function({TextStyle? textStyle}) google, {
    required double size,
    FontWeight weight = FontWeight.w400,
    Color color = AppColors.textPrimary,
    double? spacing,
    double? height,
    bool tabular = false,
  }) {
    final base = TextStyle(
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: spacing,
      height: height,
      fontFeatures: tabular ? _tabular : null,
    );
    if (!useGoogleFonts) return base.copyWith(fontFamily: family);
    return google(textStyle: base);
  }

  /// Display / numbers.
  static TextStyle display(
    double size, {
    FontWeight weight = FontWeight.w500,
    Color color = AppColors.textPrimary,
    double? height,
    bool tabular = false,
  }) =>
      _build(
        'Outfit',
        ({TextStyle? textStyle}) => GoogleFonts.outfit(textStyle: textStyle),
        size: size,
        weight: weight,
        color: color,
        spacing: -size * 0.015,
        height: height,
        tabular: tabular,
      );

  /// Body / UI.
  static TextStyle body(
    double size, {
    FontWeight weight = FontWeight.w500,
    Color color = AppColors.textPrimary,
    double? spacing,
    double? height,
    bool tabular = false,
  }) =>
      _build(
        'Manrope',
        ({TextStyle? textStyle}) => GoogleFonts.manrope(textStyle: textStyle),
        size: size,
        weight: weight,
        color: color,
        spacing: spacing,
        height: height,
        tabular: tabular,
      );

  /// Data, IDs, firmware strings.
  static TextStyle mono(
    double size, {
    FontWeight weight = FontWeight.w600,
    Color color = AppColors.textPrimary,
    double? spacing,
  }) =>
      _build(
        'JetBrains Mono',
        ({TextStyle? textStyle}) =>
            GoogleFonts.jetBrainsMono(textStyle: textStyle),
        size: size,
        weight: weight,
        color: color,
        spacing: spacing,
        tabular: true,
      );

  /// Uppercase micro labels (status pills, section labels).
  static TextStyle micro({
    Color color = AppColors.textSecondary,
    double size = 10.5,
    FontWeight weight = FontWeight.w600,
    double spacing = 1.4,
  }) =>
      body(size, weight: weight, color: color, spacing: spacing);
}
