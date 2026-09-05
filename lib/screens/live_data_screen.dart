import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/hud_theme.dart';
import '../models/custom_gauge_item.dart';
import '../models/obd_pid.dart';
import '../services/obd_controller.dart';
import '../services/settings_store.dart';
import '../widgets/hud_value_tile.dart';

/// 实时数据总览: 显示所有可读 PIDs, 点击可加入自定义
class LiveDataScreen extends StatefulWidget {
  const LiveDataScreen({super.key});

  @override
  State<LiveDataScreen> createState() => _LiveDataScreenState();
}

class _LiveDataScreenState extends State<LiveDataScreen> {
  ObdCategory? _filter;

  @override
  Widget build(BuildContext context) {
    final obd = context.watch<ObdController>();
    final settings = context.watch<AppSettings>();
    final pids = obd.availablePids
        .where((p) => _filter == null || p.category == _filter)
        .toList();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '实时数据',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: HudColors.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                '点击卡片可加入自定义仪表',
                style: TextStyle(
                  color: HudColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              Text(
                '可用 ${pids.length} 项',
                style: const TextStyle(
                  color: HudColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                FilterChip(
                  label: const Text('全部'),
                  selected: _filter == null,
                  onSelected: (_) => setState(() => _filter = null),
                ),
                for (final c in ObdCategory.values) ...[
                  const SizedBox(width: 8),
                  FilterChip(
                    label: Text(c.label),
                    selected: _filter == c,
                    onSelected: (_) => setState(() => _filter = c),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: pids.isEmpty
                ? const Center(
                    child: Text(
                      '暂无可用数据, 请先连接 OBD 设备',
                      style: TextStyle(color: HudColors.textSecondary),
                    ),
                  )
                : GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.05,
                    ),
                    itemCount: pids.length,
                    itemBuilder: (context, i) {
                      final def = pids[i];
                      final value = obd.valueOf(def.code);
                      return HudValueTile(
                        label: def.nameZh,
                        value: value == null
                            ? '--'
                            : _format(def, value),
                        unit: def.unit,
                        accent: _colorOf(def.category),
                        sub: def.code,
                        onTap: () async {
                          await settings.addCustomItem(
                            CustomGaugeItem(pidCode: def.code),
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('${def.nameZh} 已加入自定义'),
                                duration: const Duration(seconds: 1),
                              ),
                            );
                          }
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _format(ObdPidDefinition def, double v) {
    switch (def.formula) {
      case ObdFormula.rpm:
      case ObdFormula.speedKmh:
        return v.round().toString();
      case ObdFormula.tempC:
        return v.round().toString();
      case ObdFormula.percent:
      case ObdFormula.percentSigned:
        return v.toStringAsFixed(1);
      case ObdFormula.voltage:
        return v.toStringAsFixed(2);
      case ObdFormula.mafGps:
        return v.toStringAsFixed(1);
      case ObdFormula.mapKpa:
        return v.round().toString();
      default:
        return v.toStringAsFixed(1);
    }
  }

  Color _colorOf(ObdCategory c) {
    final hex = c.hexColor.replaceFirst('0x', '');
    return Color(int.parse(hex, radix: 16) | 0xFF000000);
  }
}
