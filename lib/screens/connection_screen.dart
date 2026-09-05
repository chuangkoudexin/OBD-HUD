import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/hud_theme.dart';
import '../models/power_curve.dart';
import '../services/obd_controller.dart';
import '../services/obd_transport.dart';
import '../services/settings_store.dart';

/// 连接与设置页
class ConnectionScreen extends StatelessWidget {
  const ConnectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final obd = context.watch<ObdController>();
    final settings = context.watch<AppSettings>();

    return LayoutBuilder(builder: (context, constraints) {
      final compact = constraints.maxWidth < 760;
      if (compact) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(10),
          child: Column(
            children: [
              SizedBox(
                height: 250,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _DevicePanel(
                        title: '经典蓝牙 (ELM327 SPP)',
                        subtitle: '老式 OBD2 蓝牙适配器',
                        devices: obd.classicDevices,
                        scanning: obd.classicScanning,
                        onStart: obd.startClassicScan,
                        onStop: obd.stopClassicScan,
                        onConnect: obd.connect,
                        enabled: true,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _DevicePanel(
                        title: 'BLE 低功耗 OBD',
                        subtitle: 'V-Link / KW902 等',
                        devices: obd.bleDevices,
                        scanning: obd.bleScanning,
                        onStart: obd.startBleScan,
                        onStop: obd.stopBleScan,
                        onConnect: obd.connect,
                        enabled: true,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 300,
                child: _SettingsPanel(obd: obd, settings: settings),
              ),
            ],
          ),
        );
      }

      return Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _DevicePanel(
                title: '经典蓝牙 (ELM327 SPP)',
                subtitle: '老式 OBD2 蓝牙适配器, 常见 OBDLink / V1.5 / mini',
                devices: obd.classicDevices,
                scanning: obd.classicScanning,
                onStart: obd.startClassicScan,
                onStop: obd.stopClassicScan,
                onConnect: obd.connect,
                enabled: true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _DevicePanel(
                title: 'BLE 低功耗 OBD',
                subtitle: 'V-Link / KW902 / iCar2 等 BLE 适配器',
                devices: obd.bleDevices,
                scanning: obd.bleScanning,
                onStart: obd.startBleScan,
                onStop: obd.stopBleScan,
                onConnect: obd.connect,
                enabled: true,
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 320,
              child: _SettingsPanel(obd: obd, settings: settings),
            ),
          ],
        ),
      );
    });
  }
}

class _DevicePanel extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<ObdDeviceRef> devices;
  final bool scanning;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final Future<void> Function(ObdDeviceRef) onConnect;
  final bool enabled;

  const _DevicePanel({
    required this.title,
    required this.subtitle,
    required this.devices,
    required this.scanning,
    required this.onStart,
    required this.onStop,
    required this.onConnect,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: HudColors.bgPanelAlt,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: HudColors.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: HudColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: HudColors.textSecondary,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (scanning)
                IconButton(
                  onPressed: onStop,
                  tooltip: '停止扫描',
                  icon: const Icon(
                    Icons.stop_circle_outlined,
                    color: HudColors.warn,
                  ),
                )
              else
                FilledButton.icon(
                  onPressed: enabled ? onStart : null,
                  icon: const Icon(Icons.radar, size: 16),
                  label: const Text('扫描'),
                ),
              const SizedBox(width: 10),
              Expanded(
                child: scanning
                    ? const LinearProgressIndicator(minHeight: 2)
                    : const SizedBox(),
              ),
              Text(
                '${devices.length} 个设备',
                style: const TextStyle(
                  color: HudColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: devices.isEmpty
                ? const Center(
                    child: Text(
                      '点击"扫描"查找设备; 经典蓝牙也会列出已配对设备',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: HudColors.textSecondary, fontSize: 12),
                    ),
                  )
                : ListView.separated(
                    itemCount: devices.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final d = devices[i];
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          d.kind == TransportKind.classic
                              ? Icons.bluetooth
                              : Icons.bluetooth_audio,
                          color: HudColors.accent,
                        ),
                        title: Text(
                          d.displayName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: HudColors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          '${d.address}${d.rssi != null ? '  RSSI ${d.rssi}' : ''}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: HudColors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                        trailing: d.bonded
                            ? const Icon(
                                Icons.link,
                                size: 14,
                                color: HudColors.accentGreen,
                              )
                            : const Icon(
                                Icons.chevron_right,
                                color: HudColors.textSecondary,
                              ),
                        onTap: () => onConnect(d),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _SettingsPanel extends StatelessWidget {
  final ObdController obd;
  final AppSettings settings;

  const _SettingsPanel({required this.obd, required this.settings});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: HudColors.bgPanelAlt,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: HudColors.stroke),
      ),
      child: SingleChildScrollView(
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '连接与显示设置',
            style: TextStyle(
              color: HudColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            '车辆配置',
            style: TextStyle(color: HudColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final p in PowerCurveModel.profiles)
                ChoiceChip(
                  label: Text(p.name),
                  selected: settings.vehicleProfile.id == p.id,
                  onSelected: (_) => settings.setSelectedVehicle(p.id),
                ),
            ],
          ),
          const SizedBox(height: 6),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text('转速表随机配色', style: TextStyle(fontSize: 13)),
            subtitle: const Text('6000 转以后为红色', style: TextStyle(fontSize: 11)),
            value: settings.randomRpmColors,
            onChanged: settings.setRandomRpmColors,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text('自动连接上次设备', style: TextStyle(fontSize: 13)),
            value: settings.autoConnectLast,
            onChanged: settings.setAutoConnectLast,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text('显示 ELM 调试信息', style: TextStyle(fontSize: 13)),
            value: settings.showElmDebug,
            onChanged: settings.setShowElmDebug,
          ),
          const SizedBox(height: 6),
          const Text(
            '轮询间隔',
            style: TextStyle(color: HudColors.textSecondary, fontSize: 12),
          ),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: settings.pollIntervalMs.toDouble(),
                  min: 20,
                  max: 200,
                  divisions: 9,
                  label: '${settings.pollIntervalMs} ms',
                  onChanged: (v) => settings.setPollIntervalMs(v.round()),
                ),
              ),
              SizedBox(
                width: 56,
                child: Text(
                  '${settings.pollIntervalMs}ms',
                  style: const TextStyle(color: HudColors.textPrimary, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (obd.elmVersion != null && settings.showElmDebug) ...[
            Text(
              'ELM: ${obd.elmVersion}',
              style: const TextStyle(color: HudColors.accentTeal, fontSize: 11),
            ),
          ],
          if (obd.protocol != null && settings.showElmDebug) ...[
            Text(
              '协议: ${obd.protocol}',
              style: const TextStyle(color: HudColors.accentTeal, fontSize: 11),
            ),
          ],
          if (settings.showElmDebug && obd.elmDebugLog.isNotEmpty) ...[
            const SizedBox(height: 6),
            const Text(
              'ELM 原始日志:',
              style: TextStyle(color: HudColors.accentTeal, fontSize: 11),
            ),
            Text(
              obd.elmDebugLog.length <= 8
                  ? obd.elmDebugLog.join('\n')
                  : obd.elmDebugLog.sublist(obd.elmDebugLog.length - 8).join('\n'),
              maxLines: 8,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: HudColors.textSecondary, fontSize: 9),
            ),
          ],
          if (obd.lastError != null && obd.status == ObdConnectionStatus.error) ...[
            const SizedBox(height: 6),
            Text(
              '错误: ${obd.lastError}',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: HudColors.danger, fontSize: 11),
            ),
          ],
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: obd.isConnected ? obd.refreshSupported : null,
                  child: const Text('重新读取 PID'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: HudColors.danger,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: obd.isConnected ? obd.disconnect : null,
                  child: const Text('断开连接'),
                ),
              ),
            ],
          ),
        ],
        ),
      ),
    );
  }
}
