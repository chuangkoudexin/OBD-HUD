import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/hud_theme.dart';
import '../services/obd_controller.dart';
import 'connection_screen.dart';
import 'custom_screen.dart';
import 'dashboard_screen.dart';
import 'live_data_screen.dart';
import 'power_screen.dart';

/// 应用外壳: 左侧 Tab 栏(第一版布局) + 顶部状态栏 + 单页内容
class HudShell extends StatefulWidget {
  const HudShell({super.key});

  @override
  State<HudShell> createState() => _HudShellState();
}

class _HudShellState extends State<HudShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<ObdController>().init();
    });
  }

  @override
  Widget build(BuildContext context) {
    const pages = <Widget>[
      PowerScreen(),
      DashboardScreen(),
      LiveDataScreen(),
      CustomScreen(),
      ConnectionScreen(),
    ];

    return Scaffold(
      body: Row(
        children: [
          // Tab 栏尽量靠左, 避开打孔屏中央摄像头
          NavigationRail(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            labelType: NavigationRailLabelType.all,
            minWidth: 64,
            leading: const SizedBox(width: 64, height: 8),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.trending_up),
                label: Text('主页'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.speed),
                label: Text('主仪表'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.view_quilt),
                label: Text('实时数据'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.dashboard_customize),
                label: Text('自定义'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.bluetooth),
                label: Text('连接'),
              ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: Column(
              children: [
                const _StatusBar(),
                const Divider(height: 1),
                Expanded(
                  child: IndexedStack(index: _index, children: pages),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar();

  @override
  Widget build(BuildContext context) {
    final obd = context.watch<ObdController>();
    final Color dot;
    switch (obd.status) {
      case ObdConnectionStatus.connected:
        dot = HudColors.ok;
        break;
      case ObdConnectionStatus.connecting:
      case ObdConnectionStatus.scanning:
        dot = HudColors.warn;
        break;
      case ObdConnectionStatus.error:
        dot = HudColors.danger;
        break;
      case ObdConnectionStatus.idle:
        dot = HudColors.textSecondary;
        break;
    }

    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: HudColors.bgPanelAlt,
      child: Row(
        children: [
          _dot(dot),
          const SizedBox(width: 10),
          Text(
            obd.statusMessage,
            style: const TextStyle(
              color: HudColors.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 14),
          if (obd.connectedName != null) ...[
            const Icon(Icons.link, size: 14, color: HudColors.textSecondary),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                obd.connectedName!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: HudColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ),
          ],
          const Spacer(),
          if (obd.isConnected) ...[
            Text(
              'PID ${obd.livePidCount} · 周期 ${obd.pollCycle}',
              style: const TextStyle(
                color: HudColors.textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 12),
            if (obd.elmVersion != null)
              Text(
                obd.elmVersion!,
                style: const TextStyle(
                  color: HudColors.accentTeal,
                  fontSize: 12,
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _dot(Color color) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.7), blurRadius: 8),
        ],
      ),
    );
  }
}
