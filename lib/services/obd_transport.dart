import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart' as classic;
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as ble;

/// 蓝牙传输类型
enum TransportKind {
  classic('经典蓝牙 SPP'),
  ble('BLE 低功耗');

  const TransportKind(this.label);
  final String label;
}

/// 一个可连接的 OBD 设备
class ObdDeviceRef {
  final String address;
  final String name;
  final TransportKind kind;
  final int? rssi;
  final bool bonded;

  const ObdDeviceRef({
    required this.address,
    required this.name,
    required this.kind,
    this.rssi,
    this.bonded = false,
  });

  String get displayName => name.trim().isEmpty ? address : name.trim();

  String get kindLabel => kind.label;
}

/// 蓝牙传输抽象: 经典 SPP 与 BLE 共用同一接口
abstract class ObdTransport {
  TransportKind get kind;
  String? get deviceName;
  bool get isConnected;
  Stream<Uint8List> get input;

  Future<void> connect(ObdDeviceRef device);
  Future<void> write(List<int> data);
  Future<void> disconnect();
}

/// 经典蓝牙 SPP (ELM327 老式 OBD 适配器)
class ClassicBluetoothTransport implements ObdTransport {
  classic.BluetoothConnection? _connection;
  StreamSubscription<Uint8List>? _subscription;
  final StreamController<Uint8List> _input = StreamController<Uint8List>.broadcast();
  String? _deviceName;

  @override
  TransportKind get kind => TransportKind.classic;

  @override
  String? get deviceName => _deviceName;

  @override
  bool get isConnected => _connection?.isConnected ?? false;

  @override
  Stream<Uint8List> get input => _input.stream;

  @override
  Future<void> connect(ObdDeviceRef device) async {
    await disconnect();
    _connection = await classic.BluetoothConnection.toAddress(device.address);
    _deviceName = device.displayName;
    _subscription = _connection!.input?.listen(
      (data) {
        if (!_input.isClosed) _input.add(data);
      },
      onError: (Object e) {
        if (!_input.isClosed) _input.addError(e);
      },
      onDone: () {
        if (!_input.isClosed) _input.add(Uint8List(0));
      },
    );
    if (_subscription == null) {
      throw StateError('经典蓝牙连接后没有输入流');
    }
  }

  @override
  Future<void> write(List<int> data) async {
    final connection = _connection;
    if (connection == null || !connection.isConnected) {
      throw StateError('经典蓝牙未连接');
    }
    connection.output.add(Uint8List.fromList(data));
    await connection.output.allSent;
  }

  @override
  Future<void> disconnect() async {
    await _subscription?.cancel();
    _subscription = null;
    try {
      await _connection?.close();
    } catch (_) {}
    _connection = null;
  }
}

/// BLE OBD (V-Link / KW902 / iCar2 等)
class BleTransport implements ObdTransport {
  ble.BluetoothDevice? _device;
  ble.BluetoothCharacteristic? _write;
  final StreamController<Uint8List> _input = StreamController<Uint8List>.broadcast();
  final List<StreamSubscription<List<int>>> _subscriptions = [];
  String? _deviceName;

  @override
  TransportKind get kind => TransportKind.ble;

  @override
  String? get deviceName => _deviceName;

  @override
  bool get isConnected => _device?.isConnected ?? false;

  @override
  Stream<Uint8List> get input => _input.stream;

  @override
  Future<void> connect(ObdDeviceRef device) async {
    await disconnect();
    final target = ble.BluetoothDevice.fromId(device.address);
    _device = target;
    _deviceName = device.displayName;

    await target.connect(timeout: const Duration(seconds: 20), mtu: 512);
    final services = await target.discoverServices();

    for (final service in services) {
      for (final characteristic in service.characteristics) {
        final uuid = characteristic.uuid.toString().toLowerCase();
        final canWrite = characteristic.properties.write ||
            characteristic.properties.writeWithoutResponse;
        if (canWrite) {
          _write ??= characteristic;
          if (uuid.contains('fff2') || uuid.contains('ffe1')) {
            _write = characteristic;
          }
        }
        final canNotify =
            characteristic.properties.notify || characteristic.properties.indicate;
        if (canNotify) {
          if (!characteristic.isNotifying) {
            await characteristic.setNotifyValue(true);
          }
          final sub = characteristic.lastValueStream.listen((data) {
            if (!_input.isClosed) _input.add(Uint8List.fromList(data));
          }, onError: (Object e) {
            if (!_input.isClosed) _input.addError(e);
          });
          _subscriptions.add(sub);
        }
      }
    }

    if (_write == null) {
      throw StateError('未在设备上找到可写特征, 可能不是标准 ELM327 BLE');
    }
  }

  @override
  Future<void> write(List<int> data) async {
    final characteristic = _write;
    final device = _device;
    if (characteristic == null || device == null || !device.isConnected) {
      throw StateError('BLE 未连接');
    }
    await characteristic.write(
      data,
      withoutResponse: characteristic.properties.writeWithoutResponse,
    );
  }

  @override
  Future<void> disconnect() async {
    for (final sub in _subscriptions) {
      await sub.cancel();
    }
    _subscriptions.clear();
    final device = _device;
    _device = null;
    _write = null;
    if (device != null) {
      try {
        await device.disconnect();
      } catch (_) {}
    }
  }
}
