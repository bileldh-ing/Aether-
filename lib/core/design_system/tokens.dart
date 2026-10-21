import 'package:flutter/material.dart';

/// Colour tokens sampled from the reference screens (see docs/DECISIONS.md).
abstract final class AppColors {
  static const bgTop = Color(0xFF2A2D30);
  static const bgBottom = Color(0xFF101113);
  static const bg = Color(0xFF141517);
  static const surface = Color(0xFF1D1E20);
  static const surfaceHigh = Color(0xFF252629);
  static const border = Color(0x0FFFFFFF); // white @ 6 %
  static const glassFill = Color(0x12FFFFFF); // white @ 7 %
  static const glassBorder = Color(0x14FFFFFF); // white @ 8 %
  static const textPrimary = Color(0xFFF4F5F6);
  static const textSecondary = Color(0xFF8C9096);
  static const textTertiary = Color(0xFF5E6268);
  static const mint = Color(0xFF7CE3B9);
  static const mintDim = Color(0x247CE3B9); // mint @ 14 %
  static const amber = Color(0xFFF4B740);
  static const danger = Color(0xFFFF6B6B);
  static const avatarTeal = Color(0xFF12907F);
  static const ctaWhite = Color(0xFFFFFFFF);
  static const ctaText = Color(0xFF111214);
  static const track = Color(0x14FFFFFF); // white @ 8 %
  static const divider = Color(0x0FFFFFFF);
}

abstract final class AppRadii {
  static const hero = 32.0;
  static const card = 28.0;
  static const tile = 24.0;
  static const pill = 999.0;
}

abstract final class AppSpace {
  static const screenH = 20.0;
  static const cardGap = 12.0;
  static const navClearance = 108.0;
  static const iconButton = 44.0;
}

abstract final class AppMotion {
  static const curve = Curves.easeOutCubic;
  static const fast = Duration(milliseconds: 220);
  static const medium = Duration(milliseconds: 360);
  static const slow = Duration(milliseconds: 600);
  static const hero = Duration(milliseconds: 700);
  static const breathe = Duration(milliseconds: 2400);
}
