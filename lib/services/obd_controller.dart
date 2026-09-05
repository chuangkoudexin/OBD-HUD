import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart' as classic;
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as ble;
import 'package:permission_handler/permission_handler.dart';

import '../models/obd_pid.dart';
import 'elm327_session.dart';
import 'obd_transport.dart';
import 'settings_store.dart';

/// OBD 连接状态
enum ObdConnectionStatus {
  idle,
  scanning,
  connecting,
  connected,
  error,
}

/// 数据核心控制器: 设备扫描 / 连接 / ELM327 轮询 / 遥测快照
class ObdController extends ChangeNotifier {
  ObdController({required AppSettings settings}) : _settings = settings;

  final AppSettings _settings;

  ObdTransport? _transport;
  Elm327Session? _session;

  final Map<String, double> _snapshot = {};
  Set<String> _supported = {};

  bool _polling = false;
  bool _disposed = false;
  final int _lastLatencyMs = 0;
  int _pollCycle = 0;
  DateTime? _lastNotify;
  String? _lastError;

  ObdConnectionStatus _status = ObdConnectionStatus.idle;
  String _statusMessage = '未连接';
  String? _connectedName;
  TransportKind? _connectedKind;
  String? _elmVersion;
  String? _protocol;

  // 扫描状态
  final List<ObdDeviceRef> _classicDevices = [];
  final List<ObdDeviceRef> _bleDevices = [];
  StreamSubscription<Object?>? _classicSub;
  StreamSubscription<List<ble.ScanResult>>? _bleSub;
  bool _classicScanning = false;
  bool _bleScanning = false;
  bool _bluetoothAvailable = false;

  ObdConnectionStatus get status => _status;
  String get statusMessage => _statusMessage;
  String? get connectedName => _connectedName;
  TransportKind? get connectedKind => _connectedKind;
  String? get elmVersion => _elmVersion;
  String? get protocol => _protocol;
  int get lastLatencyMs => _lastLatencyMs;
  int get pollCycle => _pollCycle;
  String? get lastError => _lastError;
  bool get bluetoothAvailable => _bluetoothAvailable;
  bool get isConnected => _status == ObdConnectionStatus.connected;
  bool get classicScanning => _classicScanning;
  bool get bleScanning => _bleScanning;
  List<ObdDeviceRef> get classicDevices => List.unmodifiable(_classicDevices);
  List<ObdDeviceRef> get bleDevices => List.unmodifiable(_bleDevices);
  int get livePidCount => _snapshot.length;

  /// 最近 ELM 原始收发日志 (调试用)
  List<String> get elmDebugLog => _session?.debugLog ?? const [];

  /// 启动时检查蓝牙/申请权限
  Future<void> init() async {
    await _requestPermissions();
    try {
      final available = await classic.FlutterBluetoothSerial.instance.isAvailable;
      _bluetoothAvailable = available ?? false;
    } catch (_) {
      _bluetoothAvailable = false;
    }
    _statusMessage = _bluetoothAvailable ? '蓝牙可用, 请选择设备' : '当前平台不可用经典蓝牙, 可使用 BLE';
    notifyListeners();

    // 自动连接上次使用的设备 (车载场景免点击, 也便于诊断)
    if (_settings.autoConnectLast &&
        _settings.lastDeviceAddress.isNotEmpty &&
        _settings.lastTransport.isNotEmpty) {
      final kind = _settings.lastTransport == 'ble'
          ? TransportKind.ble
          : TransportKind.classic;
      await connect(ObdDeviceRef(
        address: _settings.lastDeviceAddress,
        name: _settings.lastDeviceName,
        kind: kind,
      ));
    }
  }

  Future<bool> _requestPermissions() async {
    try {
      var permissions = <Permission>[];
      if (Platform.isAndroid) {
        permissions = [
          Permission.bluetoothScan,
          Permission.bluetoothConnect,
          Permission.locationWhenInUse,
        ];
      } else if (Platform.isIOS) {
        permissions = [Permission.bluetooth];
      }
      if (permissions.isEmpty) return true;
      final result = await permissions.request();
      for (final status in result.values) {
        if (status.isDenied) return false;
      }
      return true;
    } catch (_) {
      return true;
    }
  }

  Future<bool> requestPermissions() => _requestPermissions();

  // ---------------- 经典蓝牙扫描 ----------------

  Future<void> startClassicScan() async {
    await _requestPermissions();
    _classicScanning = true;
    _lastError = null;
    notifyListeners();

    try {
      final bonded = await classic.FlutterBluetoothSerial.instance.getBondedDevices();
      for (final d in bonded) {
        if (!_classicDevices.any((e) => e.address == d.address)) {
          _classicDevices.add(ObdDeviceRef(
            address: d.address,
            name: d.name ?? '',
            kind: TransportKind.classic,
            bonded: true,
          ));
        }
      }
    } catch (_) {}

    try {
      await classic.FlutterBluetoothSerial.instance.cancelDiscovery();
    } catch (_) {}

    try {
      final stream = classic.FlutterBluetoothSerial.instance.startDiscovery();
      _classicSub = stream.listen((result) {
        if (_disposed) return;
        final device = result.device;
        if (!_classicDevices.any((e) => e.address == device.address)) {
          _classicDevices.add(ObdDeviceRef(
            address: device.address,
            name: device.name ?? '',
            kind: TransportKind.classic,
            rssi: result.rssi,
            bonded: device.isBonded,
          ));
        }
        _notifyThrottled();
      }, onError: (Object e) {
        _lastError = '经典蓝牙扫描出错: $e';
        _classicScanning = false;
        notifyListeners();
      }, onDone: () {
        _classicScanning = false;
        _notifyThrottled();
      });
    } catch (e) {
      _lastError = '经典蓝牙扫描失败: $e';
      _classicScanning = false;
      notifyListeners();
    }
  }

  Future<void> stopClassicScan() async {
    _classicScanning = false;
    await _classicSub?.cancel();
    _classicSub = null;
    try {
      await classic.FlutterBluetoothSerial.instance.cancelDiscovery();
    } catch (_) {}
    notifyListeners();
  }

  // ---------------- BLE 扫描 ----------------

  Future<void> startBleScan() async {
    await _requestPermissions();
    _bleScanning = true;
    _lastError = null;
    notifyListeners();

    try {
      await ble.FlutterBluePlus.setLogLevel(ble.LogLevel.none);
    } catch (_) {}

    try {
      await ble.FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 20),
        androidScanMode: ble.AndroidScanMode.lowLatency,
      );
      _bleSub = ble.FlutterBluePlus.onScanResults.listen((results) {
        if (_disposed) return;
        for (final r in results) {
          final name = r.advertisementData.advName.isNotEmpty
              ? r.advertisementData.advName
              : r.device.platformName;
          if (!_bleDevices.any((e) => e.address == r.device.remoteId.str)) {
            _bleDevices.add(ObdDeviceRef(
              address: r.device.remoteId.str,
              name: name,
              kind: TransportKind.ble,
              rssi: r.rssi,
            ));
          }
        }
        _notifyThrottled();
      }, onError: (Object e) {
        _lastError = 'BLE 扫描出错: $e';
        _bleScanning = false;
        notifyListeners();
      });
      Timer(const Duration(seconds: 21), () {
        if (_bleScanning && !_disposed) {
          stopBleScan();
        }
      });
    } catch (e) {
      _lastError = 'BLE 扫描失败: $e';
      _bleScanning = false;
      notifyListeners();
    }
  }

  Future<void> stopBleScan() async {
    _bleScanning = false;
    await _bleSub?.cancel();
    _bleSub = null;
    try {
      await ble.FlutterBluePlus.stopScan();
    } catch (_) {}
    notifyListeners();
  }

  // ---------------- 连接 / 断开 ----------------

  Future<void> connect(ObdDeviceRef device) async {
    if (_status == ObdConnectionStatus.connecting) return;
    _status = ObdConnectionStatus.connecting;
    _statusMessage = '正在连接 ${device.displayName} ...';
    _lastError = null;
    notifyListeners();

    try {
      await _tryDisconnectTransport();

      final ObdTransport transport = device.kind == TransportKind.classic
          ? ClassicBluetoothTransport()
          : BleTransport();
      _transport = transport;
      await transport.connect(device);

      final session = Elm327Session(transport);
      _session = session;
      await session.initialize();

      _elmVersion = await session.readVersion();
      _protocol = await session.readProtocol();

      _supported = await session.readSupportedPids();
      _snapshot.clear();
      _pollCycle = 0;

      _connectedName = device.displayName;
      _connectedKind = device.kind;
      _status = ObdConnectionStatus.connected;
      _statusMessage = '已连接';

      await _settings.setLastDevice(
        address: device.address,
        name: device.displayName,
        transport: device.kind.name,
      );

      _startPolling();
    } catch (e, st) {
      _lastError = e.toString();
      _status = ObdConnectionStatus.error;
      _statusMessage = '连接失败: $e';
      await _tryDisconnectTransport();
      debugPrint('OBD connect error: $e\n$st');
    } finally {
      notifyListeners();
    }
  }

  Future<void> disconnect() async {
    _polling = false;
    await _tryDisconnectTransport();
    _status = ObdConnectionStatus.idle;
    _statusMessage = '未连接';
    _connectedName = null;
    _connectedKind = null;
    _supported = {};
    _snapshot.clear();
    _elmVersion = null;
    _protocol = null;
    notifyListeners();
  }

  Future<void> _tryDisconnectTransport() async {
    _session?.dispose();
    _session = null;
    try {
      await _transport?.disconnect();
    } catch (_) {}
    _transport = null;
  }

  // ---------------- 轮询 ----------------

  void _startPolling() {
    _polling = true;
    _pollLoop();
  }

  Future<void> _pollLoop() async {
    final interval = _settings.pollIntervalMs;
    while (_polling && !_disposed && isConnected) {
      final cycle = _buildCycle();
      final sw = Stopwatch()..start();
      for (final def in cycle) {
        if (!_polling || _disposed || !isConnected) break;
        try {
          await _queryOne(def);
        } catch (_) {}
        if (sw.elapsedMilliseconds > 250) break;
      }
      _pollCycle++;
      _notifyThrottled();
      await Future<void>.delayed(Duration(milliseconds: interval));
    }
  }

  List<ObdPidDefinition> _buildCycle() {
    // 核心 PID 始终轮询, 防止支持位图读取错误时转速等关键数据读不出来
    const priority = <String>[
      '010C', '010D', '0105', '0104', '010B', '0110', '0111', '0149', '010F', '010E',
    ];
    bool ok(String code) {
      if (priority.contains(code)) return true;
      if (_supported.isEmpty) return false;
      return _supported.contains(code);
    }

    final core = <ObdPidDefinition>[];
    for (final code in priority) {
      final def = ObdCatalog.byCode[code];
      if (def != null && ok(code)) core.add(def);
    }

    final rest = <ObdPidDefinition>[
      for (final d in ObdCatalog.all)
        if (!d.derived && d.intervalMs >= 500 && ok(d.code)) d,
    ]..sort((a, b) => a.intervalMs.compareTo(b.intervalMs));

    final result = <ObdPidDefinition>[...core, ...rest];
    if (_snapshot.containsKey('010B') && _snapshot.containsKey('0133')) {
      result.add(ObdCatalog.byCode['boostBar']!);
    }
    return result;
  }

  Future<void> _queryOne(ObdPidDefinition def) async {
    final session = _session;
    if (session == null) return;

    if (def.derived) {
      _updateDerived();
      return;
    }

    final bytes = await session.query(def.code);
    if (bytes == null || bytes.isEmpty) {
      _snapshot.remove(def.code);
      return;
    }
    final raw = ObdPidParser.parse(def, bytes);
    final value = ObdCatalog.clampValue(def, raw);
    if (value == null) {
      _snapshot.remove(def.code);
    } else {
      _snapshot[def.code] = value;
    }
    _notifyThrottled();
  }

  void _updateDerived() {
    final map = _snapshot['010B'];
    final baro = _snapshot['0133'];
    if (map != null && baro != null) {
      final boostBar = ObdCatalog.derivedBoostBar(map, baro);
      if (boostBar != null) _snapshot['boostBar'] = boostBar;
    }
  }

  /// 手动重新读取支持 PID 列表
  Future<void> refreshSupported() async {
    final session = _session;
    if (session == null) return;
    _statusMessage = '重新读取支持列表...';
    notifyListeners();
    _supported = await session.readSupportedPids();
    _statusMessage = '已连接';
    notifyListeners();
  }

  void _notifyThrottled() {
    if (_disposed) return;
    final now = DateTime.now();
    if (_lastNotify != null &&
        now.difference(_lastNotify!) < const Duration(milliseconds: 80)) {
      return;
    }
    _lastNotify = now;
    notifyListeners();
  }

  // ---------------- 数据访问 ----------------

  bool isPidAvailable(String code) {
    final def = ObdCatalog.byCode[code];
    if (def == null) return false;
    if (def.derived) {
      return _snapshot.containsKey('010B') && _snapshot.containsKey('0133');
    }
    if (_supported.isEmpty) {
      return code == '010C' || code == '010D' || code == '0105' ||
          code == '0104' || code == '010B' || code == '0110' ||
          code == '0111' || code == '0149' || code == '010F';
    }
    return _supported.contains(code);
  }

  List<ObdPidDefinition> get availablePids => [
        for (final d in ObdCatalog.all)
          if (isPidAvailable(d.code)) d,
      ];

  double? valueOf(String code) => _snapshot[code];
  Map<String, double> get values => Map.unmodifiable(_snapshot);

  double get rpm => _snapshot['010C'] ?? 0;
  double get speed => _snapshot['010D'] ?? 0;
  double get coolant => _snapshot['0105'] ?? 0;
  double get intakeTemp => _snapshot['010F'] ?? 0;
  double get boostKpa => _snapshot['boostKpa'] ?? (_snapshot['boostBar'] ?? 0) * 100;
  double get boostBar => _snapshot['boostBar'] ?? 0;
  double get throttle => _snapshot['0111'] ?? 0;
  double get engineLoad => _snapshot['0104'] ?? 0;
  double get maf => _snapshot['0110'] ?? 0;
  double get voltage => _snapshot['0142'] ?? 0;
  double get map => _snapshot['010B'] ?? 0;
  double get baro => _snapshot['0133'] ?? 0;

  /// 瞬时油耗 (L/h): 由 MAF 空气流量按汽油当量比估算
  double get fuelRateLPerHour {
    if (!isConnected || maf <= 0) return 0;
    return maf / 14.7 * 3600 / 745.0;
  }

  /// 实时油耗 (L/100km): 车速 <5km/h 时无法计算
  double? get fuelConsumptionLPer100km {
    if (!isConnected || speed <= 5) return null;
    return fuelRateLPerHour / speed * 100;
  }

  @override
  void dispose() {
    _disposed = true;
    _polling = false;
    _classicSub?.cancel();
    _bleSub?.cancel();
    _session?.dispose();
    _transport?.disconnect();
    super.dispose();
  }
}