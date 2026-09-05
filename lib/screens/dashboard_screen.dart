import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/hud_theme.dart';
import '../services/obd_controller.dart';
import '../services/settings_store.dart';
import '../widgets/hud_value_tile.dart';
import '../widgets/rpm_gauge.dart';

/// 主仪表盘: 曲线转速表 + 底部三组可选数据
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _section = 0;

  @override
  Widget build(BuildContext context) {
    final obd = context.watch<ObdController>();
    final settings = context.watch<AppSettings>();

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: RpmGauge(
                rpm: obd.rpm,
                colorPolicy: settings.rpmPolicy,
                active: obd.isConnected,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _SectionButton(
                icon: Icons.thermostat,
                label: '温度/速度',
                selected: _section == 0,
                onTap: () => setState(() => _section = 0),
              ),
              const SizedBox(width: 14),
              _SectionButton(
                icon: Icons.air,
                label: '进气/增压',
                selected: _section == 1,
                onTap: () => setState(() => _section = 1),
              ),
              const SizedBox(width: 14),
              _SectionButton(
                icon: Icons.local_gas_station,
                label: '燃油/电气',
                selected: _section == 2,
                onTap: () => setState(() => _section = 2),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 108,
            child: _buildTiles(obd),
          ),
        ],
      ),
    );
  }

  Widget _buildTiles(ObdController obd) {
    switch (_section) {
      case 1:
        return Row(
          children: [
            Expanded(
              child: HudValueTile(
                label: '涡轮压力',
                value: obd.boostBar.toStringAsFixed(2),
                unit: 'bar',
                accent: HudColors.accentRed,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: HudValueTile(
                label: '进气压力',
                value: _text(obd.valueOf('010B')),
                unit: 'kPa',
                accent: HudColors.accentBlue,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: HudValueTile(
                label: '空气流量',
                value: _text(obd.valueOf('0110')),
                unit: 'g/s',
                accent: HudColors.accentPurple,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: HudValueTile(
                label: '节气门',
                value: _text(obd.valueOf('0111')),
                unit: '%',
                accent: HudColors.accent,
              ),
            ),
          ],
        );
      case 2:
        return Row(
          children: [
            Expanded(
              child: HudValueTile(
                label: '电瓶电压',
                value: obd.voltage > 0 ? obd.voltage.toStringAsFixed(2) : '--',
                unit: 'V',
                accent: HudColors.accentYellow,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: HudValueTile(
                label: '燃油液位',
                value: _text(obd.valueOf('012F')),
                unit: '%',
                accent: HudColors.accentOrange,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: HudValueTile(
                label: '点火提前角',
                value: _text(obd.valueOf('010E')),
                unit: '°',
                accent: HudColors.accentTeal,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: HudValueTile(
                label: '当量比',
                value: _text(obd.valueOf('0144')),
                unit: 'λ',
                accent: HudColors.accentGreen,
              ),
            ),
          ],
        );
      default:
        return Row(
          children: [
            Expanded(
              child: HudValueTile(
                label: '车速',
                value: obd.speed.round().toString(),
                unit: 'km/h',
                accent: HudColors.accentGreen,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: HudValueTile(
                label: '发动机负荷',
                value: obd.engineLoad.round().toString(),
                unit: '%',
                accent: HudColors.accentOrange,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: HudValueTile(
                label: '冷却液温度',
                value: _text(obd.valueOf('0105')),
                unit: '°C',
                accent: HudColors.accentRed,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: HudValueTile(
                label: '进气温度',
                value: _text(obd.valueOf('010F')),
                unit: '°C',
                accent: HudColors.accentTeal,
              ),
            ),
          ],
        );
    }
  }

  static String _text(double? v) {
    if (v == null || v.isNaN) return '--';
    return v.roundToDouble() == v ? v.round().toString() : v.toStringAsFixed(1);
  }
}

class _SectionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SectionButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 84,
          height: 66,
          decoration: BoxDecoration(
            color: selected ? HudColors.accent.withValues(alpha: 0.16) : HudColors.bgPanelAlt,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? HudColors.accent : HudColors.stroke,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 22,
                color: selected ? HudColors.accent : HudColors.textSecondary,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: selected ? HudColors.accent : HudColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
