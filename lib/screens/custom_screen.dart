import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/hud_theme.dart';
import '../models/custom_gauge_item.dart';
import '../models/obd_pid.dart';
import '../services/obd_controller.dart';
import '../services/settings_store.dart';
import '../widgets/hud_value_tile.dart';

enum _TileAction { delete, up, down, small, medium, large }

/// 自定义仪表盘: 手动添加/排序/调整显示项
class CustomScreen extends StatefulWidget {
  const CustomScreen({super.key});

  @override
  State<CustomScreen> createState() => _CustomScreenState();
}

class _CustomScreenState extends State<CustomScreen> {
  Future<void> _showAddDialog() async {
    final settings = context.read<AppSettings>();
    final existing = settings.customItems.map((e) => e.pidCode).toSet();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('添加显示项'),
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          content: SizedBox(
            width: 480,
            height: 420,
            child: ListView(
              children: [
                for (final def in ObdCatalog.all)
                  ListTile(
                    dense: true,
                    leading: Icon(
                      Icons.add_circle_outline,
                      color: existing.contains(def.code)
                          ? HudColors.textSecondary
                          : HudColors.accent,
                    ),
                    title: Text(def.nameZh),
                    subtitle: Text('${def.code} · ${def.unit}'),
                    trailing: existing.contains(def.code)
                        ? const Text(
                            '已添加',
                            style: TextStyle(
                              color: HudColors.textSecondary,
                              fontSize: 12,
                            ),
                          )
                        : null,
                    onTap: () async {
                      await settings.addCustomItem(
                        CustomGaugeItem(pidCode: def.code),
                      );
                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop();
                      }
                    },
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('关闭'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final obd = context.watch<ObdController>();
    final settings = context.watch<AppSettings>();
    final items = settings.customItems;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '自定义仪表',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: HudColors.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                '点击卡片可删除/调整大小, 上移/下移排序',
                style: TextStyle(
                  color: HudColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _showAddDialog,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('添加显示项'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: items.isEmpty
                ? const Center(
                    child: Text(
                      '还没有显示项, 点击右上角"添加显示项"',
                      style: TextStyle(color: HudColors.textSecondary),
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      const columns = 12;
                      const spacing = 12.0;
                      final unit =
                          (constraints.maxWidth - spacing * (columns - 1)) /
                              columns;
                      return SingleChildScrollView(
                        child: Wrap(
                          spacing: spacing,
                          runSpacing: spacing,
                          children: [
                            for (int i = 0; i < items.length; i++)
                              _buildItem(
                                context,
                                settings,
                                obd,
                                items,
                                i,
                                unit,
                                spacing,
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildItem(
    BuildContext context,
    AppSettings settings,
    ObdController obd,
    List<CustomGaugeItem> items,
    int index,
    double unit,
    double spacing,
  ) {
    final item = items[index];
    final def = ObdCatalog.byCode[item.pidCode];
    final value = obd.valueOf(item.pidCode);
    final label = item.title?.isNotEmpty == true ? item.title! : (def?.nameZh ?? item.pidCode);

    final cols = item.size.cols;
    final width = unit * cols + spacing * (cols - 1);
    final height = item.size == GaugeTileSize.large ? 165.0 : 120.0;

    return SizedBox(
      width: width,
      height: height,
      child: PopupMenuButton<_TileAction>(
        onSelected: (action) async {
          final list = List<CustomGaugeItem>.of(settings.customItems);
          switch (action) {
            case _TileAction.delete:
              list.removeAt(index);
              await settings.setCustomItems(list);
              break;
            case _TileAction.up:
              if (index > 0) {
                list[index - 1] = item;
                list[index] = items[index - 1];
                await settings.setCustomItems(list);
              }
              break;
            case _TileAction.down:
              if (index < list.length - 1) {
                list[index + 1] = item;
                list[index] = items[index + 1];
                await settings.setCustomItems(list);
              }
              break;
            case _TileAction.small:
            case _TileAction.medium:
            case _TileAction.large:
              final size = action == _TileAction.small
                  ? GaugeTileSize.small
                  : action == _TileAction.medium
                      ? GaugeTileSize.medium
                      : GaugeTileSize.large;
              list[index] = item.copyWith(size: size);
              await settings.setCustomItems(list);
              break;
          }
        },
        itemBuilder: (context) => [
          if (index > 0)
            const PopupMenuItem(value: _TileAction.up, child: Text('上移')),
          if (index < items.length - 1)
            const PopupMenuItem(value: _TileAction.down, child: Text('下移')),
          const PopupMenuDivider(),
          const PopupMenuItem(value: _TileAction.small, child: Text('尺寸: 小')),
          const PopupMenuItem(value: _TileAction.medium, child: Text('尺寸: 中')),
          const PopupMenuItem(value: _TileAction.large, child: Text('尺寸: 大')),
          const PopupMenuDivider(),
          const PopupMenuItem(value: _TileAction.delete, child: Text('删除')),
        ],
        child: HudValueTile(
          label: label,
          value: value == null
              ? '--'
              : value == value.roundToDouble()
                  ? value.round().toString()
                  : value.toStringAsFixed(1),
          unit: def?.unit ?? '',
          accent: def == null
              ? HudColors.textSecondary
              : _colorOf(def.category),
          sub: def?.code ?? item.pidCode,
          large: item.size == GaugeTileSize.large,
        ),
      ),
    );
  }

  Color _colorOf(ObdCategory c) {
    final hex = c.hexColor.replaceFirst('0x', '');
    return Color(int.parse(hex, radix: 16) | 0xFF000000);
  }
}
