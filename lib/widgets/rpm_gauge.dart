import 'package:flutter/material.dart';

import '../core/hud_theme.dart';
import '../core/rpm_color_policy.dart';

/// 曲线式转速表: 转速区间沿一条弧线曲线显示 (1 ~ 6000, 红色尾段 6000+)
class RpmGauge extends StatelessWidget {
  final double rpm;
  final double maxRpm;
  final RpmColorPolicy? colorPolicy;
  final bool showDigital;
  final bool active;

  const RpmGauge({
    super.key,
    required this.rpm,
    this.maxRpm = 7000,
    this.colorPolicy,
    this.showDigital = true,
    this.active = true,
  });

  @override
  Widget build(BuildContext context) {
    final policy = colorPolicy ?? RpmColorPolicy.build(randomize: false);
    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth;
      final h = constraints.maxHeight;

      return Stack(
        alignment: Alignment.center,
        children: [
          // 环境光晕
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  colors: [Color(0x1F00E5FF), Color(0x00000000)],
                  stops: [0.0, 0.8],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: CustomPaint(
              painter: _CurveRpmPainter(
                rpm: rpm,
                maxRpm: maxRpm,
                policy: policy,
                active: active,
              ),
            ),
          ),
          ..._labelWidgets(w, h, maxRpm),
          if (showDigital)
            Positioned(
              left: 0,
              right: 0,
              bottom: 6,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ShaderMask(
                    shaderCallback: (rect) => const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFFFFFFFF),
                        Color(0xFFC9F6FF),
                        Color(0xFF4FD9FF),
                      ],
                    ).createShader(rect),
                    child: Text(
                      rpm.round().toString(),
                      style: const TextStyle(
                        fontSize: 52,
                        fontWeight: FontWeight.w900,
                        fontFeatures: [FontFeature.tabularFigures()],
                        color: Colors.white,
                        shadows: [
                          Shadow(color: HudColors.accent, blurRadius: 28),
                        ],
                      ),
                    ),
                  ),
                  const Text(
                    'R P M',
                    style: TextStyle(
                      fontSize: 13,
                      letterSpacing: 7,
                      color: HudColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
    });
  }

  List<Widget> _labelWidgets(double w, double h, double maxRpm) {
    final widgets = <Widget>[];
    for (int v = 0; v <= 6000; v += 1000) {
      final t = (v / maxRpm).clamp(0.0, 1.0);
      final pos = _curvePoint(w, h, t);
      widgets.add(
        Positioned(
          left: pos.dx - 20,
          top: pos.dy - 26,
          width: 40,
          child: Text(
            v.toString(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Color(0xCCD9ECFF),
              shadows: [Shadow(color: Colors.black, blurRadius: 6)],
            ),
          ),
        ),
      );
    }
    return widgets;
  }

  static Offset _curvePoint(double w, double h, double t) {
    final p0 = Offset(w * 0.08, h * 0.82);
    final p1 = Offset(w * 0.50, h * 0.08);
    final p2 = Offset(w * 0.92, h * 0.82);
    final u = 1 - t;
    return Offset(
      u * u * p0.dx + 2 * u * t * p1.dx + t * t * p2.dx,
      u * u * p0.dy + 2 * u * t * p1.dy + t * t * p2.dy,
    );
  }
}

class _CurveRpmPainter extends CustomPainter {
  final double rpm;
  final double maxRpm;
  final RpmColorPolicy policy;
  final bool active;

  _CurveRpmPainter({
    required this.rpm,
    required this.maxRpm,
    required this.policy,
    required this.active,
  });

  Path _curvePath(Size size) {
    return Path()
      ..moveTo(size.width * 0.08, size.height * 0.82)
      ..quadraticBezierTo(
        size.width * 0.50,
        size.height * 0.08,
        size.width * 0.92,
        size.height * 0.82,
      );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final path = _curvePath(size);
    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return;
    final metric = metrics.first;
    final length = metric.length;

    // 背景轨道
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 22
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF0A1017),
    );

    // 分段颜色曲线
    const step = 500;
    for (int v = 0; v < 7000; v += step) {
      final startD = length * ((v / maxRpm).clamp(0.0, 1.0));
      final endD = length * (((v + step) / maxRpm).clamp(0.0, 1.0));
      final subPath = metric.extractPath(startD, endD);

      final bool isRed = v >= RpmColorPolicy.redlineStart;
      final bool reached = active && rpm >= v + 1;
      final Color color;
      if (isRed) {
        color = HudColors.accentRed;
      } else if (reached) {
        color = policy.segmentColorAt(v);
      } else {
        color = const Color(0xFF16202E);
      }

      // 光晕
      canvas.drawPath(
        subPath,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 30
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9)
          ..color = color.withValues(alpha: 0.28),
      );

      // 主体
      canvas.drawPath(
        subPath,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 18
          ..strokeCap = StrokeCap.round
          ..color = color,
      );
    }

    // 刻度
    for (int v = 0; v <= 7000; v += 500) {
      final t = (v / maxRpm).clamp(0.0, 1.0);
      final tangent = metric.getTangentForOffset(length * t);
      if (tangent == null) continue;
      final normal = Offset(-tangent.vector.dy, tangent.vector.dx);
      final len = v % 1000 == 0 ? 16.0 : 10.0;
      canvas.drawLine(
        tangent.position - normal * len,
        tangent.position + normal * len,
        Paint()
          ..color = v % 1000 == 0
              ? const Color(0xCCE7F0FF)
              : const Color(0x553B5270)
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
      );
    }

    // 当前转速标记
    final mt = (rpm / maxRpm).clamp(0.0, 1.0);
    final marker = metric.getTangentForOffset(length * mt);
    if (marker != null) {
      final color = rpm < RpmColorPolicy.minRpm
          ? const Color(0xFFEAF2FF)
          : policy.colorForRpm(rpm);
      canvas.drawCircle(
        marker.position,
        16,
        Paint()
          ..color = color.withValues(alpha: 0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
      );
      canvas.drawCircle(marker.position, 8, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant _CurveRpmPainter old) =>
      old.rpm != rpm ||
      old.maxRpm != maxRpm ||
      old.policy != policy ||
      old.active != active;
}
