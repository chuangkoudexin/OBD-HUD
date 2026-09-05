import 'dart:math';

import 'package:flutter/material.dart';

import 'hud_theme.dart';

/// 转速表分段配色策略。
///
/// 需求规则:
/// - 1000 ~ 6000 转分段显示颜色;
/// - 每 500 转切换一种颜色;
/// - 6000 转以后为红色(无数据时也只显示红色区);
/// - 其余区间颜色允许随机(每次启动随机, 保证相邻不撞色)。
class RpmColorPolicy {
  RpmColorPolicy._(this.colors);

  static const double minRpm = 1000;
  static const double maxRpm = 6000;
  static const double redlineStart = 6000;
  static const double binSize = 500;

  /// 每 500 转一个颜色, 从 1000 开始:
  /// [1000-1500), [1500-2000) ... [4500-5000), [5000-5500), [5500-6000]
  /// 最后两段固定为红色。
  final List<Color> colors;

  factory RpmColorPolicy.build({bool randomize = true, int? seed}) {
    const palette = <Color>[
      HudColors.textPrimary,
      HudColors.accent,
      HudColors.accentGreen,
      HudColors.accentYellow,
      HudColors.accentOrange,
      HudColors.accentPurple,
      HudColors.accentBlue,
      HudColors.accentTeal,
    ];

    final rng = Random(seed ?? DateTime.now().millisecondsSinceEpoch);
    final result = <Color>[];

    // 1000 ~ 6000: 10 段 (6000 以后由 redlineStart 处理为红色)
    for (int i = 0; i < 10; i++) {
      Color color;
      if (randomize) {
        color = palette[rng.nextInt(palette.length)];
        if (result.isNotEmpty && color == result.last) {
          color = palette[(palette.indexOf(color) + 1) % palette.length];
        }
      } else {
        color = palette[i % palette.length];
      }
      result.add(color);
    }

    return RpmColorPolicy._(result);
  }

  Color segmentColorAt(int rpm) {
    if (rpm < minRpm) return HudColors.stroke;
    if (rpm >= redlineStart) return HudColors.accentRed;
    final index = ((rpm - minRpm) / binSize).floor().clamp(0, colors.length - 1);
    return colors[index];
  }

  Color colorForRpm(double rpm) {
    if (rpm.isNaN || rpm < minRpm) return HudColors.stroke;
    if (rpm >= redlineStart) return HudColors.accentRed;
    final index = ((rpm - minRpm) / binSize).floor().clamp(0, colors.length - 1);
    return colors[index];
  }

  List<Color> get segmentColors => List.unmodifiable(colors);
}
