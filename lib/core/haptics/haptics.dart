import 'package:flutter/services.dart';

/// Haptic vocabulary (section 3.4).
abstract final class Haptics {
  static Future<void> nav() => HapticFeedback.selectionClick();
  static Future<void> toggle() => HapticFeedback.lightImpact();
  static Future<void> swipeComplete() => HapticFeedback.mediumImpact();
  static Future<void> success() => HapticFeedback.heavyImpact();
}
