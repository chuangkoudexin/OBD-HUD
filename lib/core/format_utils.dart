import 'dart:math' as math;

/// 数值格式化工具
class FormatUtils {
  FormatUtils._();

  static String val(double? v, {String unit = '', int decimals = 0}) {
    if (v == null || v.isNaN || v.isInfinite) return '--';
    final s = v.toStringAsFixed(decimals);
    return unit.isEmpty ? s : '$s $unit';
  }

  static String signed(double? v, {int decimals = 1}) {
    if (v == null || v.isNaN || v.isInfinite) return '--';
    final s = v.abs().toStringAsFixed(decimals);
    return v >= 0 ? '+$s' : '-$s';
  }

  static double cToF(double c) => c * 9 / 5 + 32;
  static double fToC(double f) => (f - 32) * 5 / 9;
  static double kpaToPsi(double kpa) => kpa * 0.1450377377;
  static double kpaToBar(double kpa) => kpa / 100.0;

  static double clamp(double v, double lo, double hi) => math.max(lo, math.min(hi, v));
}
