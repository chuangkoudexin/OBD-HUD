import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'obd_transport.dart';

/// ELM327 ASCII 会话层。
///
/// 负责:
/// - 初始化 AT 指令 (ATZ / ATE0 / ATL0 / ATSP0 / ATH0)
/// - 单条命令的请求/响应处理
/// - 将 ELM327 响应解析成原始数据字节
/// - 读取车辆支持的 PID 位图
class Elm327Session {
  final ObdTransport _transport;
  StreamSubscription<Uint8List>? _subscription;

  String _buffer = '';
  Completer<String>? _pending;
  final List<String> _debug = [];
  int _activeProtocol = 0;
  int _protocolPollIndex = 0;
  bool _debugFlagSent = false;

  /// 候选协议 (AndrOBD 风格轮询): 自动/早期/ISO/KWP/CAN/User
  // 先试 CAN (6/7/8/9), 再 ISO/KWP, 最后自动; 参考 AndrOBD 对现代车型的处理
  static const List<int> protocolsToTry = [6,7,8,9,3,4,5,0,1,2,10,11,12];
  int get activeProtocol => _activeProtocol;

  Elm327Session(this._transport) {
    _subscription = _transport.input.listen(
      _onData,
      onError: (Object e) {
        final pending = _pending;
        if (pending != null && !pending.isCompleted) {
          pending.completeError(e);
        }
      },
    );
  }

  void _onData(Uint8List chunk) {
    _buffer += utf8.decode(chunk, allowMalformed: true);
    final idx = _buffer.lastIndexOf('>');
    if (idx < 0) return;

    final response = _buffer.substring(0, idx + 1);
    _buffer = _buffer.substring(idx + 1);

    final pending = _pending;
    if (pending != null && !pending.isCompleted) {
      pending.complete(response);
    }
  }

  bool get isConnected => _transport.isConnected;

  /// 最近 ELM 原始收发日志 (调试用)
  List<String> get debugLog => List.unmodifiable(_debug);

  Future<void> _safeSend(String command, {Duration timeout = const Duration(seconds: 2)}) async {
    try {
      await send(command, timeout: timeout);
    } catch (_) {
      // 初始化阶段部分指令失败不影响整体流程
    }
  }

  /// 发送一条 ASCII 命令并等待 ELM327 返回提示符 '>'
  Future<String> send(
    String command, {
    Duration timeout = const Duration(seconds: 3),
  }) async {
    if (!_transport.isConnected) {
      throw StateError('OBD 适配器未连接');
    }
    _buffer = '';
    _debug.add('>> $command');
    debugPrint('ELM >> $command');
    final completer = Completer<String>();
    _pending = completer;
    try {
      await _transport.write(utf8.encode('$command\r'));
      final raw = await completer.future.timeout(timeout, onTimeout: () => 'TIMEOUT');
      _debug.add('<< ${raw.replaceAll(RegExp(r'[\r\n]+'), ' ')}');
      debugPrint('ELM << ${raw.replaceAll(RegExp(r'[\r\n]+'), ' ')}');
      if (_debug.length > 40) {
        _debug.removeRange(0, _debug.length - 40);
      }
      return raw;
    } finally {
      _pending = null;
    }
  }

  /// ELM327 初始化 (参考厂商 YMOBD 初始化队列, 兼容部分专有设备)
  Future<void> initialize() async {
    await _safeSend('ATZ', timeout: const Duration(seconds: 5));
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    await _safeSend('ATE0');
    await _safeSend('ATL0');
    await _safeSend('ATS0');
    await _safeSend('ATH1');
    await _safeSend('ATSP0');
    await _safeSend('ATSTFA');
    await _safeSend('ATAT2');
    await _safeSend('AT+DEBUG_FLG');
    await _safeSend('AT+VERSION');
    await _safeSend('ATI');
    await _safeSend('ATRV');
    final rnd = Random()
        .nextInt(0xFFFFFFFF)
        .toRadixString(16)
        .padLeft(8, '0')
        .toUpperCase();
    await _safeSend('AT+CRYPT$rnd');
    await _safeSend('020000');
    await _safeSend('0600');
    await _safeSend('0900');
    await _safeSend('ATDP');
  }

  Future<String> readVersion() async {
    try {
      return (await send('ATI', timeout: const Duration(seconds: 2)))
          .trim()
          .replaceAll(RegExp(r'[\r\n>]+'), ' ');
    } catch (_) {
      return '';
    }
  }

  Future<String> readProtocol() async {
    try {
      return (await send('ATDP', timeout: const Duration(seconds: 2)))
          .trim()
          .replaceAll(RegExp(r'[\r\n>]+'), ' ');
    } catch (_) {
      return '';
    }
  }

  /// 查询一个 PID, 返回原始数据字节 (不含 Mode/PID 头)
  Future<List<int>?> query(String command) async {
    // 超时/无数据时: 先恢复协议再重试一次, 兼容慢启动/慢响应车辆
    for (int attempt = 0; attempt < 2; attempt++) {
      final bytes = await _queryOnce(command);
      if (bytes != null) return bytes;
      if (attempt == 0) {
        // 厂商 YMOBD: 遇到读不到数据先发 AT+DEBUG_FLG
        if (!_debugFlagSent) {
          await _safeSend('AT+DEBUG_FLG', timeout: const Duration(seconds: 3));
          _debugFlagSent = true;
          await Future<void>.delayed(const Duration(milliseconds: 300));
        }
        await _recoverProtocol();
      } else {
        await Future<void>.delayed(const Duration(milliseconds: 120));
      }
    }
    return null;
  }

  /// 恢复 OBD 协议: 关闭/重开协议, 延长 ELM 等待时间 (参考 AndrOBD 自适应超时)
  Future<void> _recoverProtocol() async {
    await _safeSend('ATPC', timeout: const Duration(seconds: 2));
    // AndrOBD 风格: 错误后自动换下一个协议重试
    if (_protocolPollIndex >= protocolsToTry.length) {
      _protocolPollIndex = 0;
    }
    _activeProtocol = protocolsToTry[_protocolPollIndex++];
    await _safeSend('ATSP$_activeProtocol', timeout: const Duration(seconds: 3));
    await _safeSend('ATSTFA', timeout: const Duration(seconds: 2));
    await _safeSend('ATAT2', timeout: const Duration(seconds: 2));
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }

  Future<List<int>?> _queryOnce(String command) async {
    final raw = await send(command, timeout: const Duration(seconds: 3));
    final normalized = raw.replaceAll(RegExp(r'[\r\n]+'), ' ');

    if (normalized.contains('TIMEOUT') ||
        normalized.contains('NO DATA') ||
        normalized.contains('?') ||
        normalized.contains('CAN ERROR') ||
        normalized.contains('UNABLE') ||
        normalized.contains('BUS INIT')) {
      return null;
    }

    final matches = RegExp(r'[0-9A-Fa-f]{2}').allMatches(normalized);
    final bytes = <int>[
      for (final m in matches) int.tryParse(m.group(0)!, radix: 16) ?? -1,
    ].where((b) => b >= 0).toList();
    if (bytes.isEmpty) return null;

    final mode = int.tryParse(command.substring(0, 2), radix: 16);
    final pid = int.tryParse(command.substring(2, 4), radix: 16);
    if (mode == null || pid == null) return null;

    for (int i = 0; i < bytes.length - 1; i++) {
      if (bytes[i] == mode && bytes[i + 1] == pid) {
        return bytes.sublist(i + 2);
      }
    }

    // 兜底: 有些 ELM327 会带帧头, 直接找 Mode 字节 (如 41)
    for (int i = 0; i < bytes.length - 1; i++) {
      if (bytes[i] == mode) {
        return bytes.sublist(i + 2);
      }
    }
    return null;
  }

  /// 读取 01 00 / 01 20 / 01 40 / 01 60 支持位图 (AndrOBD 风格协议轮询)
  Future<Set<String>> readSupportedPids() async {
    // 1) 逐个尝试候选协议, 找到能收到 0100 数据为止
    _protocolPollIndex = 0;
    for (final proto in protocolsToTry) {
      await _safeSend('ATSP$proto', timeout: const Duration(seconds: 3));
      await _safeSend('ATSTFA', timeout: const Duration(seconds: 2));
      var probe = await _queryOnce('0100');
      // 厂商 YMOBD: 遇到 UNABLE 先发一次 AT+DEBUG_FLG 解锁再重试
      if ((probe == null) && !_debugFlagSent) {
        await _safeSend('AT+DEBUG_FLG', timeout: const Duration(seconds: 3));
        _debugFlagSent = true;
        await Future<void>.delayed(const Duration(milliseconds: 300));
        probe = await _queryOnce('0100');
      }
      if (probe == null || probe.length < 4) continue;
      _activeProtocol = proto;
      _protocolPollIndex = protocolsToTry.indexOf(proto) + 1;
      // 现代 CAN 车型: 锁定发动机 ECU 地址 (7E0)
      if (proto >= 6 && proto <= 9) {
        await _safeSend('ATSH7E0');
        await _safeSend('ATCRA7E0');
      }

      final supported = <String>{};
      _parseSupportedBlock('0100', probe, 0x00, supported);
      for (final block in const [0x20, 0x40, 0x60]) {
        final command = '01${block.toRadixString(16).padLeft(2, '0').toUpperCase()}';
        final bytes = await _queryOnce(command);
        if (bytes != null && bytes.length >= 4) {
          _parseSupportedBlock(command, bytes, block, supported);
        }
      }
      return supported;
    }

    // 2) 全部失败: 回退自动协议再做一次常规扫描
    await _safeSend('ATSP0', timeout: const Duration(seconds: 3));
    await _safeSend('ATSTFA', timeout: const Duration(seconds: 2));
    _activeProtocol = 0;
    final supported = <String>{};
    for (final block in const [0x00, 0x20, 0x40, 0x60]) {
      final command = '01${block.toRadixString(16).padLeft(2, '0').toUpperCase()}';
      final bytes = await query(command);
      if (bytes != null && bytes.length >= 4) {
        _parseSupportedBlock(command, bytes, block, supported);
      }
    }
    return supported;
  }

  void _parseSupportedBlock(
    String command,
    List<int> bytes,
    int block,
    Set<String> supported,
  ) {
    for (int i = 0; i < 4; i++) {
      for (int bit = 0; bit < 8; bit++) {
        if ((bytes[i] & (0x80 >> bit)) != 0) {
          final pid = block + i * 8 + bit + 1;
          supported.add('01${pid.toRadixString(16).padLeft(2, '0').toUpperCase()}');
        }
      }
    }
  }

  void dispose() {
    _subscription?.cancel();
  }
}
