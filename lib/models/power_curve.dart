/// 发动机动力曲线模型: 支持多车型切换
///
/// 曲线为按各车型官方峰值 + 自然吸气/涡轮特性推算,
/// 功率曲线 = 扭矩 x 转速换算 (P = T * rpm / 9549)。
class PowerCurvePoint {
  final int rpm;
  final double torqueNm;

  const PowerCurvePoint(this.rpm, this.torqueNm);

  double get powerKw => torqueNm * rpm / 9549;
  double get powerPs => powerKw * 1.35962;
}

class PowerCurveModel {
  final String id;
  final String name;
  final String engine;
  final int maxRpm;
  final int peakPowerRpm;
  final double peakPowerPs;
  final double peakTorqueNm;
  final String torquePlateau;
  final List<PowerCurvePoint> points;

  const PowerCurveModel({
    required this.id,
    required this.name,
    required this.engine,
    required this.maxRpm,
    required this.peakPowerRpm,
    required this.peakPowerPs,
    required this.peakTorqueNm,
    required this.torquePlateau,
    required this.points,
  });

  double torqueAt(int rpm) {
    if (rpm <= points.first.rpm) return points.first.torqueNm;
    if (rpm >= points.last.rpm) return points.last.torqueNm;
    for (int i = 1; i < points.length; i++) {
      final a = points[i - 1];
      final b = points[i];
      if (rpm >= a.rpm && rpm <= b.rpm) {
        final t = (rpm - a.rpm) / (b.rpm - a.rpm);
        return a.torqueNm + (b.torqueNm - a.torqueNm) * t;
      }
    }
    return points.last.torqueNm;
  }

  double powerPsAt(int rpm) {
    final kw = torqueAt(rpm) * rpm / 9549;
    return kw * 1.35962;
  }

  // ---------------- 车型库 ----------------

  /// 2015 哈弗 H5 2.0T (4G63S4T): 190 PS @ 5200, 约 257 N·m 平台
  static const PowerCurveModel havalH5 = PowerCurveModel(
    id: 'haval_h5_4g63s4t',
    name: '2015 哈弗 H5 2.0T',
    engine: '4G63S4T 汽油涡轮',
    maxRpm: 6000,
    peakPowerRpm: 5200,
    peakPowerPs: 190,
    peakTorqueNm: 257,
    torquePlateau: '2400-4800',
    points: [
      PowerCurvePoint(800, 150),
      PowerCurvePoint(1000, 170),
      PowerCurvePoint(1200, 195),
      PowerCurvePoint(1500, 215),
      PowerCurvePoint(1800, 232),
      PowerCurvePoint(2000, 242),
      PowerCurvePoint(2400, 250),
      PowerCurvePoint(2800, 252),
      PowerCurvePoint(3200, 254),
      PowerCurvePoint(3600, 255),
      PowerCurvePoint(4000, 255),
      PowerCurvePoint(4400, 254),
      PowerCurvePoint(4800, 250),
      PowerCurvePoint(5200, 257),
      PowerCurvePoint(5600, 230),
      PowerCurvePoint(6000, 200),
    ],
  );

  /// 2013 捷达 1.6L MT: 110 PS @ 5800, 160 N·m @ 3800
  static const PowerCurveModel jetta2013 = PowerCurveModel(
    id: 'jetta_2013_1_6_mt',
    name: '2013 捷达 1.6L MT',
    engine: '1.6L MPI 手动',
    maxRpm: 6500,
    peakPowerRpm: 5800,
    peakPowerPs: 110,
    peakTorqueNm: 160,
    torquePlateau: '约 3800',
    points: [
      PowerCurvePoint(800, 92),
      PowerCurvePoint(1000, 105),
      PowerCurvePoint(1500, 125),
      PowerCurvePoint(2000, 138),
      PowerCurvePoint(2500, 148),
      PowerCurvePoint(3000, 155),
      PowerCurvePoint(3500, 159),
      PowerCurvePoint(3800, 160),
      PowerCurvePoint(4200, 158),
      PowerCurvePoint(4600, 154),
      PowerCurvePoint(5000, 148),
      PowerCurvePoint(5400, 140),
      PowerCurvePoint(5800, 132),
      PowerCurvePoint(6000, 128),
      PowerCurvePoint(6300, 120),
      PowerCurvePoint(6500, 115),
    ],
  );

  static const List<PowerCurveModel> profiles = [havalH5, jetta2013];

  static PowerCurveModel byId(String? id) {
    for (final p in profiles) {
      if (p.id == id) return p;
    }
    return havalH5;
  }
}

/// 保持旧引用兼容
class PowerCurveOldModel {
  static int get maxRpm => PowerCurveModel.havalH5.maxRpm;
  static int get peakPowerRpm => PowerCurveModel.havalH5.peakPowerRpm;
  static double get peakPowerPs => PowerCurveModel.havalH5.peakPowerPs;
  static double get peakTorqueNm => PowerCurveModel.havalH5.peakTorqueNm;
  static List<PowerCurvePoint> get points => PowerCurveModel.havalH5.points;
  static double torqueAt(int rpm) => PowerCurveModel.havalH5.torqueAt(rpm);
  static double powerPsAt(int rpm) => PowerCurveModel.havalH5.powerPsAt(rpm);
}
