import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/hud_theme.dart';
import '../models/power_curve.dart';
import '../services/obd_controller.dart';
import '../services/settings_store.dart';
import '../widgets/power_curve_chart.dart';

/// 主页(动力曲线): 马力机风格双曲线 + 可编辑底部数据卡片
class PowerScreen extends StatelessWidget {
  const PowerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final obd = context.watch<ObdController>();
    final settings = context.watch<AppSettings>();
    final profile = settings.vehicleProfile;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '动力曲线',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: HudColors.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${profile.name} · ${profile.engine} (推算曲线)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: HudColors.textSecondary, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '峰值 ${profile.peakPowerPs.round()} PS @ ${profile.peakPowerRpm} rpm · '
            '${profile.peakTorqueNm.round()} N·m @ ${profile.torquePlateau}',
            style: const TextStyle(
              color: HudColors.accentTeal,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: PowerCurveChart(
              currentRpm: obd.isConnected && obd.rpm > 0 ? obd.rpm : null,
              profile: profile,
            ),
          ),
          const SizedBox(height: 10),
          const Row(
            children: [
              Icon(Icons.touch_app, size: 14, color: HudColors.textSecondary),
              SizedBox(width: 4),
              Text(
                '长按或点击下方卡片可切换显示数据',
                style: TextStyle(color: HudColors.textSecondary, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _EditableCards(obd: obd, profile: profile),
        ],
      ),
    );
  }
}

enum _HomeMetric {
  fuelL100('实时油耗', 'L/100km'),
  fuelLh('瞬时油耗', 'L/h'),
  power('当前马力', 'PS'),
  torque('估算扭矩', 'N·m'),
  rpm('转速', 'rpm'),
  speed('车速', 'km/h'),
  coolant('冷却液温度', '°C'),
  intake('进气温度', '°C'),
  boost('涡轮压力', 'bar'),
  map('进气压力', 'kPa'),
  maf('空气流量', 'g/s'),
  throttle('节气门', '%'),
  voltage('电瓶电压', 'V'),
  fuelLevel('燃油液位', '%'),
  timing('点火提前角', '°'),
  lambda('当量比', 'λ');

  const _HomeMetric(this.label, this.unit);

  final String label;
  final String unit;
}

class _EditableCards extends StatefulWidget {
  final ObdController obd;
  final PowerCurveModel profile;

  const _EditableCards({required this.obd, required this.profile});

  @override
  State<_EditableCards> createState() => _EditableCardsState();
}

class _EditableCardsState extends State<_EditableCards> {
  final List<_HomeMetric> _metrics = [
    _HomeMetric.fuelL100,
    _HomeMetric.fuelLh,
    _HomeMetric.power,
    _HomeMetric.rpm,
  ];

  Future<void> _edit(int index) async {
    final selected = await showModalBottomSheet<_HomeMetric>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: Text(
                '选择要显示的数据',
                style: TextStyle(
                  color: HudColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            for (final m in _HomeMetric.values)
              ListTile(
                dense: true,
                title: Text(m.label),
                subtitle: Text(m.unit),
                trailing: _metrics[index] == m
                    ? const Icon(Icons.check, color: HudColors.accent)
                    : null,
                onTap: () => Navigator.of(ctx).pop(m),
              ),
          ],
        ),
      ),
    );
    if (selected != null) {
      setState(() => _metrics[index] = selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (int i = 0; i < _metrics.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(
            child: _EditableCard(
              label: _metrics[i].label,
              value: _valueOf(widget.obd, _metrics[i]),
              unit: _metrics[i].unit,
              onEdit: () => _edit(i),
            ),
          ),
        ],
      ],
    );
  }

  String _valueOf(ObdController obd, _HomeMetric m) {
    switch (m) {
      case _HomeMetric.rpm:
        return _fmt(obd.isConnected ? obd.rpm : null, 0);
      case _HomeMetric.speed:
        return _fmt(obd.isConnected ? obd.speed : null, 0);
      case _HomeMetric.coolant:
        return _fmt(obd.isConnected ? obd.coolant : null, 0);
      case _HomeMetric.intake:
        return _fmt(obd.isConnected ? obd.intakeTemp : null, 0);
      case _HomeMetric.fuelL100:
        return _fmt(obd.fuelConsumptionLPer100km, 1);
      case _HomeMetric.fuelLh:
        return _fmt(
          obd.isConnected && obd.fuelRateLPerHour > 0
              ? obd.fuelRateLPerHour
              : null,
          1,
        );
      case _HomeMetric.power:
        return _fmt(
          obd.isConnected ? widget.profile.powerPsAt(obd.rpm.round()) : null,
          0,
        );
      case _HomeMetric.torque:
        return _fmt(
          obd.isConnected ? widget.profile.torqueAt(obd.rpm.round()) : null,
          0,
        );
      case _HomeMetric.boost:
        return _fmt(obd.isConnected ? obd.boostBar : null, 2);
      case _HomeMetric.map:
        return _fmt(obd.isConnected ? obd.map : null, 0);
      case _HomeMetric.maf:
        return _fmt(obd.isConnected ? obd.maf : null, 1);
      case _HomeMetric.throttle:
        return _fmt(obd.isConnected ? obd.throttle : null, 0);
      case _HomeMetric.voltage:
        return _fmt(obd.isConnected ? obd.voltage : null, 2);
      case _HomeMetric.fuelLevel:
        return _fmt(obd.valueOf('012F'), 0);
      case _HomeMetric.timing:
        return _fmt(obd.valueOf('010E'), 1);
      case _HomeMetric.lambda:
        return _fmt(obd.valueOf('0144'), 2);
    }
  }

  static String _fmt(double? v, int decimals) {
    if (v == null || v.isNaN || v.isInfinite) return '--';
    return v.toStringAsFixed(decimals);
  }
}

class _EditableCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final VoidCallback onEdit;

  const _EditableCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onEdit,
      onLongPress: onEdit,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: HudColors.bgPanelAlt,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: HudColors.stroke),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: HudColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ),
                const Icon(Icons.edit, size: 12, color: HudColors.textSecondary),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                color: HudColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              unit,
              style: const TextStyle(color: HudColors.textSecondary, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}
