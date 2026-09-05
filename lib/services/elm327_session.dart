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
    await _safeSend('ATH1');
    await _safeSend('ATSP0');
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
    // 超时/无数据时重试一次, 兼容慢启动的 ELM327
    for (int attempt = 0; attempt < 2; attempt++) {
      final bytes = await _queryOnce(command);
      if (bytes != null) return bytes;
      await Future<void>.delayed(const Duration(milliseconds: 120));
    }
    return null;
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

  /// 读取 01 00 / 01 20 / 01 40 / 01 60 支持位图
  Future<Set<String>> readSupportedPids() async {
    final supported = <String>{};
    const blocks = [0x00, 0x20, 0x40, 0x60];

    for (final block in blocks) {
      final command = '01${block.toRadixString(16).padLeft(2, '0').toUpperCase()}';
      final bytes = await query(command);
      if (bytes == null || bytes.length < 4) continue;

      for (int i = 0; i < 4; i++) {
        for (int bit = 0; bit < 8; bit++) {
          if ((bytes[i] & (0x80 >> bit)) != 0) {
            final pid = block + i * 8 + bit + 1;
            final code = '01${pid.toRadixString(16).padLeft(2, '0').toUpperCase()}';
            supported.add(code);
          }
        }
      }
    }

    return supported;
  }

  void dispose() {
    _subscription?.cancel();
  }
}
