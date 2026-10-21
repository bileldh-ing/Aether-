import 'dart:math' as math;

/// Deterministic day model used by the simulator.
/// Sunrise 06:40, solar peak 12:30, sunset 19:50 (local time).
abstract final class DayCurves {
  static const sunriseMin = 6 * 60 + 40;
  static const peakMin = 12 * 60 + 30;
  static const sunsetMin = 19 * 60 + 50;

  /// Array peak (3 microinverters).
  static const peakW = 4200.0;

  /// Clear-sky shape 0..1 for a minute of the day.
  static double solarShape(double minuteOfDay) {
    if (minuteOfDay <= sunriseMin || minuteOfDay >= sunsetMin) return 0;
    final double x;
    if (minuteOfDay < peakMin) {
      x = (minuteOfDay - sunriseMin) / (peakMin - sunriseMin) * math.pi / 2;
    } else {
      x = math.pi / 2 +
          (minuteOfDay - peakMin) / (sunsetMin - peakMin) * math.pi / 2;
    }
    return math.pow(math.sin(x), 1.6).toDouble();
  }

  /// Home consumption in W: base load + morning and evening peaks.
  static double homeLoad(double minuteOfDay) {
    double bump(double centreMin, double widthMin, double height) {
      final d = (minuteOfDay - centreMin) / widthMin;
      return height * math.exp(-d * d);
    }

    return 330 +
        bump(7 * 60 + 30, 55, 820) +
        bump(13 * 60, 70, 260) +
        bump(19 * 60 + 40, 95, 1250) +
        bump(22 * 60, 60, 300);
  }

  /// Weather factor for a given day, deterministic from the date.
  static double weather(DateTime day) {
    final seed = day.year * 1000 + day.month * 40 + day.day;
    final r = math.Random(seed).nextDouble();
    return 0.72 + r * 0.28;
  }

  static double minuteOf(DateTime t) => t.hour * 60 + t.minute + t.second / 60;
}
