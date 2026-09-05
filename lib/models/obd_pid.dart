import 'dart:math' as math;

/// OBD-II 数据分类
enum ObdCategory {
  engine('发动机', '0xFF8A65'),
  air('进气/空气', '0x4FC3F7'),
  fuel('燃油', '0xFFD54F'),
  temp('温度', '0xFF7043'),
  electrical('电气/电源', '0xBA68C8'),
  turbo('增压', '0xFF5252'),
  misc('其它', '0x9E9E9E');

  const ObdCategory(this.label, this.hexColor);
  final String label;
  final String hexColor;
}

/// PID 数值解析方式
enum ObdFormula {
  raw,
  rpm,
  speedKmh,
  tempC,
  tempCDiv10,
  percent,
  percentSigned,
  timing,
  mapKpa,
  mafGps,
  voltage,
  seconds,
  km,
  fuelPressureRelKpa,
  fuelPressureAbsKpa,
  vaporPressurePa,
  lambda,
  boostKpa,
  boostPsi,
  boostBar,
}

/// 一条 OBD PID 定义
class ObdPidDefinition {
  final String code;
  final String nameZh;
  final String nameEn;
  final String unit;
  final ObdCategory category;
  final ObdFormula formula;
  final int expectedBytes;
  final int intervalMs;
  final bool derived;
  final String? hint;

  const ObdPidDefinition({
    required this.code,
    required this.nameZh,
    required this.nameEn,
    required this.unit,
    required this.category,
    required this.formula,
    this.expectedBytes = 1,
    this.intervalMs = 500,
    this.derived = false,
    this.hint,
  });
}

/// PID 解析器 (SAE J1979 标准公式)
class ObdPidParser {
  ObdPidParser._();

  static double? parse(ObdPidDefinition def, List<int> b) {
    if (b.isEmpty) return null;
    final int a = b[0];
    switch (def.formula) {
      case ObdFormula.raw:
        return b.length > 1 ? (a * 256 + b[1]).toDouble() : a.toDouble();
      case ObdFormula.rpm:
        return b.length >= 2 ? (a * 256 + b[1]) / 4 : null;
      case ObdFormula.speedKmh:
        return a.toDouble();
      case ObdFormula.tempC:
        return (a - 40).toDouble();
      case ObdFormula.tempCDiv10:
        if (b.length >= 2) return (a * 256 + b[1]) / 10 - 40;
        return null;
      case ObdFormula.percent:
        return a * 100 / 255;
      case ObdFormula.percentSigned:
        return a / 128 - 100;
      case ObdFormula.timing:
        return a / 2 - 64;
      case ObdFormula.mapKpa:
        return a.toDouble();
      case ObdFormula.mafGps:
        return b.length >= 2 ? (a * 256 + b[1]) / 100 : null;
      case ObdFormula.voltage:
        if (b.length >= 2) return (a * 256 + b[1]) / 1000;
        return null;
      case ObdFormula.seconds:
        return b.length >= 2 ? (a * 256 + b[1]).toDouble() : a.toDouble();
      case ObdFormula.km:
        return b.length >= 2 ? (a * 256 + b[1]).toDouble() : a.toDouble();
      case ObdFormula.fuelPressureRelKpa:
        return b.length >= 2 ? (a * 256 + b[1]) * 0.079 : null;
      case ObdFormula.fuelPressureAbsKpa:
        return b.length >= 2 ? (a * 256 + b[1]) * 10 : null;
      case ObdFormula.vaporPressurePa:
        if (b.length >= 2) return ((a * 256 + b[1]) - 32768) / 4;
        return null;
      case ObdFormula.lambda:
        if (b.length >= 2) return (a * 256 + b[1]) / 32768;
        return null;
      case ObdFormula.boostKpa:
      case ObdFormula.boostPsi:
      case ObdFormula.boostBar:
        return null; // 由控制器根据 MAP/BARO 计算
    }
  }
}

/// 内置 PID 目录(覆盖常用 Mode 01 数据)
class ObdCatalog {
  ObdCatalog._();

  static const List<ObdPidDefinition> all = [
    // ---- 发动机核心 ----
    ObdPidDefinition(
      code: '010C', nameZh: '发动机转速', nameEn: 'Engine RPM', unit: 'rpm',
      category: ObdCategory.engine, formula: ObdFormula.rpm,
      expectedBytes: 2, intervalMs: 200,
    ),
    ObdPidDefinition(
      code: '010D', nameZh: '车速', nameEn: 'Vehicle Speed', unit: 'km/h',
      category: ObdCategory.engine, formula: ObdFormula.speedKmh,
      expectedBytes: 1, intervalMs: 200,
    ),
    ObdPidDefinition(
      code: '0104', nameZh: '发动机负荷', nameEn: 'Engine Load', unit: '%',
      category: ObdCategory.engine, formula: ObdFormula.percent,
      expectedBytes: 1, intervalMs: 250,
    ),
    ObdPidDefinition(
      code: '010E', nameZh: '点火提前角', nameEn: 'Timing Advance', unit: '°',
      category: ObdCategory.engine, formula: ObdFormula.timing,
      expectedBytes: 1, intervalMs: 500,
    ),
    ObdPidDefinition(
      code: '011F', nameZh: '运行时间', nameEn: 'Run Time', unit: 's',
      category: ObdCategory.engine, formula: ObdFormula.seconds,
      expectedBytes: 2, intervalMs: 1000,
    ),

    // ---- 温度 ----
    ObdPidDefinition(
      code: '0105', nameZh: '冷却液温度', nameEn: 'Coolant Temp', unit: '°C',
      category: ObdCategory.temp, formula: ObdFormula.tempC,
      expectedBytes: 1, intervalMs: 250,
    ),
    ObdPidDefinition(
      code: '010F', nameZh: '进气温度', nameEn: 'Intake Air Temp', unit: '°C',
      category: ObdCategory.temp, formula: ObdFormula.tempC,
      expectedBytes: 1, intervalMs: 500,
    ),
    ObdPidDefinition(
      code: '0146', nameZh: '环境温度', nameEn: 'Ambient Air Temp', unit: '°C',
      category: ObdCategory.temp, formula: ObdFormula.tempC,
      expectedBytes: 1, intervalMs: 1000,
    ),
    ObdPidDefinition(
      code: '015C', nameZh: '机油温度', nameEn: 'Engine Oil Temp', unit: '°C',
      category: ObdCategory.temp, formula: ObdFormula.tempC,
      expectedBytes: 1, intervalMs: 500,
      hint: '部分车型支持(非标准 PID)',
    ),
    ObdPidDefinition(
      code: '013C', nameZh: '催化器温度1', nameEn: 'Catalyst Temp B1', unit: '°C',
      category: ObdCategory.temp, formula: ObdFormula.tempCDiv10,
      expectedBytes: 2, intervalMs: 1000,
    ),
    ObdPidDefinition(
      code: '013D', nameZh: '催化器温度2', nameEn: 'Catalyst Temp B2', unit: '°C',
      category: ObdCategory.temp, formula: ObdFormula.tempCDiv10,
      expectedBytes: 2, intervalMs: 1000,
    ),

    // ---- 进气/空气 ----
    ObdPidDefinition(
      code: '010B', nameZh: '进气歧管绝对压力', nameEn: 'MAP', unit: 'kPa',
      category: ObdCategory.air, formula: ObdFormula.mapKpa,
      expectedBytes: 1, intervalMs: 250,
    ),
    ObdPidDefinition(
      code: '0110', nameZh: '空气流量', nameEn: 'MAF', unit: 'g/s',
      category: ObdCategory.air, formula: ObdFormula.mafGps,
      expectedBytes: 2, intervalMs: 300,
    ),
    ObdPidDefinition(
      code: '0111', nameZh: '节气门开度', nameEn: 'Throttle Position', unit: '%',
      category: ObdCategory.air, formula: ObdFormula.percent,
      expectedBytes: 1, intervalMs: 250,
    ),
    ObdPidDefinition(
      code: '0149', nameZh: '油门踏板位置D', nameEn: 'Accelerator Pedal D', unit: '%',
      category: ObdCategory.air, formula: ObdFormula.percent,
      expectedBytes: 1, intervalMs: 250,
    ),
    ObdPidDefinition(
      code: '014A', nameZh: '油门踏板位置E', nameEn: 'Accelerator Pedal E', unit: '%',
      category: ObdCategory.air, formula: ObdFormula.percent,
      expectedBytes: 1, intervalMs: 250,
    ),
    ObdPidDefinition(
      code: '0145', nameZh: '相对节气门位置', nameEn: 'Relative Throttle', unit: '%',
      category: ObdCategory.air, formula: ObdFormula.percent,
      expectedBytes: 1, intervalMs: 500,
    ),
    ObdPidDefinition(
      code: '0147', nameZh: '绝对节气门位置', nameEn: 'Absolute Throttle', unit: '%',
      category: ObdCategory.air, formula: ObdFormula.percent,
      expectedBytes: 1, intervalMs: 500,
    ),
    ObdPidDefinition(
      code: '014C', nameZh: '节气门执行器', nameEn: 'Throttle Actuator', unit: '%',
      category: ObdCategory.air, formula: ObdFormula.percent,
      expectedBytes: 1, intervalMs: 500,
    ),
    ObdPidDefinition(
      code: '0143', nameZh: '绝对负荷', nameEn: 'Absolute Load', unit: '%',
      category: ObdCategory.air, formula: ObdFormula.percent,
      expectedBytes: 2, intervalMs: 500,
    ),

    // ---- 增压 ----
    ObdPidDefinition(
      code: '0133', nameZh: '大气压力', nameEn: 'Barometric Pressure', unit: 'kPa',
      category: ObdCategory.turbo, formula: ObdFormula.mapKpa,
      expectedBytes: 1, intervalMs: 1000,
    ),
    ObdPidDefinition(
      code: 'boostBar', nameZh: '涡轮增压压力', nameEn: 'Boost (MAP-BARO)', unit: 'bar',
      category: ObdCategory.turbo, formula: ObdFormula.boostBar,
      derived: true, intervalMs: 250,
      hint: '由 MAP 与大气压力计算, 1 bar = 100 kPa',
    ),

    // ---- 燃油 ----
    ObdPidDefinition(
      code: '0106', nameZh: '短期燃油修正1', nameEn: 'STFT Bank1', unit: '%',
      category: ObdCategory.fuel, formula: ObdFormula.percentSigned,
      expectedBytes: 1, intervalMs: 500,
    ),
    ObdPidDefinition(
      code: '0107', nameZh: '长期燃油修正1', nameEn: 'LTFT Bank1', unit: '%',
      category: ObdCategory.fuel, formula: ObdFormula.percentSigned,
      expectedBytes: 1, intervalMs: 500,
    ),
    ObdPidDefinition(
      code: '0108', nameZh: '短期燃油修正2', nameEn: 'STFT Bank2', unit: '%',
      category: ObdCategory.fuel, formula: ObdFormula.percentSigned,
      expectedBytes: 1, intervalMs: 500,
    ),
    ObdPidDefinition(
      code: '0109', nameZh: '长期燃油修正2', nameEn: 'LTFT Bank2', unit: '%',
      category: ObdCategory.fuel, formula: ObdFormula.percentSigned,
      expectedBytes: 1, intervalMs: 500,
    ),
    ObdPidDefinition(
      code: '012F', nameZh: '燃油液位', nameEn: 'Fuel Level', unit: '%',
      category: ObdCategory.fuel, formula: ObdFormula.percent,
      expectedBytes: 1, intervalMs: 1000,
    ),
    ObdPidDefinition(
      code: '0122', nameZh: '燃油轨压(相对)', nameEn: 'Fuel Rail P (Rel)', unit: 'kPa',
      category: ObdCategory.fuel, formula: ObdFormula.fuelPressureRelKpa,
      expectedBytes: 2, intervalMs: 500,
    ),
    ObdPidDefinition(
      code: '0123', nameZh: '燃油轨压(绝对)', nameEn: 'Fuel Rail P (Abs)', unit: 'kPa',
      category: ObdCategory.fuel, formula: ObdFormula.fuelPressureAbsKpa,
      expectedBytes: 2, intervalMs: 500,
    ),
    ObdPidDefinition(
      code: '0151', nameZh: '燃油类型', nameEn: 'Fuel Type', unit: '',
      category: ObdCategory.fuel, formula: ObdFormula.raw,
      expectedBytes: 1, intervalMs: 10000,
      hint: '不同值代表汽油/柴油/乙醇等',
    ),
    ObdPidDefinition(
      code: '0152', nameZh: '乙醇燃油占比', nameEn: 'Ethanol %', unit: '%',
      category: ObdCategory.fuel, formula: ObdFormula.percent,
      expectedBytes: 1, intervalMs: 1000,
    ),
    ObdPidDefinition(
      code: '012C', nameZh: 'EGR指令', nameEn: 'Commanded EGR', unit: '%',
      category: ObdCategory.fuel, formula: ObdFormula.percent,
      expectedBytes: 1, intervalMs: 1000,
    ),
    ObdPidDefinition(
      code: '012E', nameZh: '吹扫阀指令', nameEn: 'Evap Purge', unit: '%',
      category: ObdCategory.fuel, formula: ObdFormula.percent,
      expectedBytes: 1, intervalMs: 1000,
    ),

    // ---- 电气 ----
    ObdPidDefinition(
      code: '0142', nameZh: '电瓶电压', nameEn: 'Control Module Voltage', unit: 'V',
      category: ObdCategory.electrical, formula: ObdFormula.voltage,
      expectedBytes: 2, intervalMs: 500,
    ),
    ObdPidDefinition(
      code: '0144', nameZh: '当量比', nameEn: 'Equivalence Ratio', unit: 'λ',
      category: ObdCategory.electrical, formula: ObdFormula.lambda,
      expectedBytes: 2, intervalMs: 500,
    ),

    // ---- 其它 ----
    ObdPidDefinition(
      code: '0121', nameZh: 'MIL点亮行驶距离', nameEn: 'Dist w/ MIL', unit: 'km',
      category: ObdCategory.misc, formula: ObdFormula.km,
      expectedBytes: 2, intervalMs: 5000,
    ),
    ObdPidDefinition(
      code: '0131', nameZh: '清除码后里程', nameEn: 'Dist Since Clear', unit: 'km',
      category: ObdCategory.misc, formula: ObdFormula.km,
      expectedBytes: 2, intervalMs: 5000,
    ),
    ObdPidDefinition(
      code: '0130', nameZh: '热机次数', nameEn: 'Warm-ups', unit: '',
      category: ObdCategory.misc, formula: ObdFormula.raw,
      expectedBytes: 1, intervalMs: 5000,
    ),
    ObdPidDefinition(
      code: '0132', nameZh: 'EVAP蒸汽压力', nameEn: 'EVAP Vapor P', unit: 'Pa',
      category: ObdCategory.misc, formula: ObdFormula.vaporPressurePa,
      expectedBytes: 2, intervalMs: 2000,
    ),
  ];

  static final Map<String, ObdPidDefinition> byCode = {
    for (final d in all) d.code: d,
  };

  static const List<String> _defaultSupported = ['010C', '010D', '0105', '010F', '010B', '0110', '0111', '0104'];

  static List<ObdPidDefinition> get commonFirst => [
        for (final code in _defaultSupported) byCode[code]!,
        for (final d in all)
          if (!_defaultSupported.contains(d.code) && !d.derived) d,
      ];

  static double? clampValue(ObdPidDefinition def, double? v) {
    if (v == null || v.isNaN) return null;
    switch (def.formula) {
      case ObdFormula.rpm:
        return v.clamp(0, 16000).toDouble();
      case ObdFormula.speedKmh:
        return v.clamp(0, 400).toDouble();
      case ObdFormula.tempC:
        return v.clamp(-40, 220).toDouble();
      case ObdFormula.percent:
        return v.clamp(0, 100).toDouble();
      case ObdFormula.percentSigned:
        return v.clamp(-100, 100).toDouble();
      default:
        return v;
    }
  }

  static double? derivedBoostKpa(double? map, double? baro) {
    if (map == null || baro == null) return null;
    return math.max(0.0, map - baro);
  }

  static double? derivedBoostPsi(double? map, double? baro) {
    final kpa = derivedBoostKpa(map, baro);
    if (kpa == null) return null;
    return kpa * 0.1450377377;
  }

  static double? derivedBoostBar(double? map, double? baro) {
    final kpa = derivedBoostKpa(map, baro);
    if (kpa == null) return null;
    return kpa / 100.0;
  }
}
