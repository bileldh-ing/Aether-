import 'package:intl/intl.dart';

abstract final class Fmt {
  static final _int = NumberFormat.decimalPattern('en');

  static String wh(double v) => _int.format(v.round());
  static String kwh(double v) =>
      v >= 100 ? _int.format(v.round()) : v.toStringAsFixed(1);
  static String pct(double v, {int digits = 1}) =>
      '${v.toStringAsFixed(digits)}%';

  static String watts(double w) {
    final a = w.abs();
    if (a >= 1000) return '${(w / 1000).toStringAsFixed(2)} kW';
    return '${w.round()} W';
  }

  static String hours(double h) {
    if (h <= 0) return '0 h';
    if (h < 1) return '${(h * 60).round()} min';
    if (h < 10) {
      final hh = h.floor();
      final mm = ((h - hh) * 60).round();
      return mm == 0 ? '$hh h' : '$hh h $mm min';
    }
    return '${h.round()} h';
  }

  static String relative(DateTime t, DateTime now) {
    final d = now.difference(t);
    if (d.inSeconds < 60) return 'Just now';
    if (d.inMinutes < 60) return '${d.inMinutes} min ago';
    if (d.inHours < 24) return '${d.inHours} h ago';
    if (d.inDays == 1) return 'Yesterday';
    return DateFormat('d MMM').format(t);
  }

  static String clock(DateTime t) => DateFormat('HH:mm').format(t);
}
