import 'package:flutter/material.dart';

import '../core/hud_theme.dart';
import '../models/power_curve.dart';

/// 马力机风格双曲线图: 蓝色=马力(PS), 橙色=扭矩(N·m)
class PowerCurveChart extends StatelessWidget {
  final double? currentRpm;
  final PowerCurveModel profile;

  const PowerCurveChart({
    super.key,
    this.currentRpm,
    this.profile = PowerCurveModel.havalH5,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _PowerCurvePainter(currentRpm: currentRpm, profile: profile),
      child: const SizedBox.expand(),
    );
  }
}

class _PowerCurvePainter extends CustomPainter {
  final double? currentRpm;
  final PowerCurveModel profile;

  _PowerCurvePainter({this.currentRpm, this.profile = PowerCurveModel.havalH5});

  static const double _left = 56;
  static const double _right = 26;
  static const double _top = 34;
  static const double _bottom = 42;
  static const double _maxPs = 210;
  static const double _maxNm = 350;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTRB(
      _left,
      _top,
      size.width - _right,
      size.height - _bottom,
    );

    double xOf(double rpm) => rect.left + rect.width * (rpm / profile.maxRpm);
    double yOfPs(double ps) => rect.bottom - rect.height * (ps / _maxPs);
    double yOfNm(double nm) => rect.bottom - rect.height * (nm / _maxNm);

    // 背景
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Colors.transparent,
    );

    // 网格 + 坐标标尺
    final gridPaint = Paint()
      ..color = const Color(0x263B5270)
      ..strokeWidth = 1;
    for (int ps = 0; ps <= 200; ps += 50) {
      final y = yOfPs(ps.toDouble());
      canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), gridPaint);
      _label(canvas, ps.toString(), Offset(rect.left - 8, y), alignRight: true);
    }
    for (int nm = 0; nm <= 300; nm += 100) {
      final y = yOfNm(nm.toDouble());
      canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), gridPaint);
      _label(canvas, nm.toString(), Offset(rect.right + 8, y), alignRight: false);
    }

    // X 轴刻度
    for (int rpm = 0; rpm <= profile.maxRpm; rpm += 1000) {
      final x = xOf(rpm.toDouble());
      canvas.drawLine(
        Offset(x, rect.bottom),
        Offset(x, rect.bottom + 4),
        Paint()..color = const Color(0x663B5270)..strokeWidth = 2,
      );
      _label(canvas, rpm.toString(), Offset(x, rect.bottom + 8), alignRight: false, centerX: true);
    }

    // X / Y 轴名
    _label(canvas, '转速 RPM', Offset(rect.center.dx, size.height - 4), alignRight: false, centerX: true);
    canvas.save();
    canvas.translate(12, rect.center.dy);
    canvas.rotate(-3.1415926 / 2);
    _label(canvas, '马力 PS / 扭矩 N·m', Offset.zero, alignRight: false, centerX: true);
    canvas.restore();

    // 功率曲线 (PS) - 蓝色, 带渐变填充
    final psPath = Path();
    final pts = profile.points;
    psPath.moveTo(xOf(pts.first.rpm.toDouble()), yOfPs(pts.first.powerPs));
    for (final p in pts.skip(1)) {
      psPath.lineTo(xOf(p.rpm.toDouble()), yOfPs(p.powerPs));
    }

    final fillPath = Path.from(psPath)
      ..lineTo(xOf(pts.last.rpm.toDouble()), rect.bottom)
      ..lineTo(xOf(pts.first.rpm.toDouble()), rect.bottom)
      ..close();
    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [HudColors.accentBlue.withValues(alpha: 0.30), HudColors.accentBlue.withValues(alpha: 0.02)],
        ).createShader(rect),
    );
    canvas.drawPath(
      psPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = HudColors.accentBlue,
    );

    // 扭矩曲线 (N·m) - 橙色
    final nmPath = Path();
    nmPath.moveTo(xOf(pts.first.rpm.toDouble()), yOfNm(pts.first.torqueNm));
    for (final p in pts.skip(1)) {
      nmPath.lineTo(xOf(p.rpm.toDouble()), yOfNm(p.torqueNm));
    }
    canvas.drawPath(
      nmPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = HudColors.accentOrange,
    );

    // 峰值标注
    final peakX = xOf(profile.peakPowerRpm.toDouble());
    final peakY = yOfPs(profile.peakPowerPs);
    canvas.drawCircle(Offset(peakX, peakY), 5, Paint()..color = HudColors.accentBlue);
    _label(canvas, '${profile.peakPowerPs.round()} PS', Offset(peakX, peakY - 14), alignRight: false, centerX: true);

    // 当前转速参考线
    final rpm = currentRpm;
    if (rpm != null && rpm > 0) {
      final x = xOf(rpm.clamp(0, profile.maxRpm).toDouble());
      canvas.drawLine(
        Offset(x, rect.top),
        Offset(x, rect.bottom),
        Paint()
          ..color = HudColors.accentGreen.withValues(alpha: 0.7)
          ..strokeWidth = 2,
      );
      final ps = profile.powerPsAt(rpm.round());
      final nm = profile.torqueAt(rpm.round());
      canvas.drawCircle(
        Offset(x, yOfPs(ps)),
        4.5,
        Paint()..color = HudColors.accentGreen,
      );
      _label(
        canvas,
        ps.round().toString(),
        Offset(x, yOfPs(ps) - 14),
        alignRight: false,
        centerX: true,
      );
      canvas.drawCircle(
        Offset(x, yOfNm(nm)),
        4.5,
        Paint()..color = HudColors.accentGreen,
      );
    }

    // 图例
    _legend(canvas, '马力(PS)', HudColors.accentBlue, Offset(_left + 4, 14));
    _legend(canvas, '扭矩(N·m)', HudColors.accentOrange, Offset(_left + 110, 14));
  }

  void _label(
    Canvas canvas,
    String text,
    Offset pos, {
    bool alignRight = false,
    bool centerX = false,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(fontSize: 10, color: HudColors.textSecondary),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    double dx = pos.dx;
    if (alignRight) dx -= tp.width;
    if (centerX) dx -= tp.width / 2;
    tp.paint(canvas, Offset(dx, pos.dy - tp.height / 2));
  }

  void _legend(Canvas canvas, String text, Color color, Offset pos) {
    canvas.drawLine(
      pos,
      pos + Offset(18, 0),
      Paint()
        ..color = color
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(fontSize: 10, color: HudColors.textSecondary),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, pos + Offset(24, -5));
  }

  @override
  bool shouldRepaint(covariant _PowerCurvePainter old) =>
      old.currentRpm != currentRpm || old.profile.id != profile.id;
}
