import 'package:flutter_test/flutter_test.dart';

import 'package:obd_hud/models/custom_gauge_item.dart';
import 'package:obd_hud/models/obd_pid.dart';

void main() {
  group('OBD PID 解析', () {
    ObdPidDefinition def(String code) => ObdCatalog.byCode[code]!;

    test('转速公式 (010C)', () {
      expect(ObdPidParser.parse(def('010C'), [0x1A, 0xF8]), closeTo(1726, 0.01));
    });

    test('冷却液温度 (0105)', () {
      expect(ObdPidParser.parse(def('0105'), [0x64]), 60);
    });

    test('空气流量 (0110)', () {
      expect(ObdPidParser.parse(def('0110'), [0x0A, 0x28]), closeTo(26.0, 0.01));
    });

    test('节气门开度 (0111)', () {
      expect(ObdPidParser.parse(def('0111'), [0x80]), closeTo(50.196, 0.01));
    });

    test('进气歧管绝对压力 (010B)', () {
      expect(ObdPidParser.parse(def('010B'), [0x64]), 100);
    });

    test('涡轮压力派生值换算为 bar', () {
      expect(ObdCatalog.derivedBoostBar(120, 100), closeTo(0.2, 0.001));
    });
  });

  group('自定义显示项迁移', () {
    test('旧 boostKpa 自动迁移为 boostBar', () {
      final items =
          CustomGaugeItem.decodeList('[{"pidCode":"boostKpa","size":"large"}]');
      expect(items.single.pidCode, 'boostBar');
      expect(items.single.size, GaugeTileSize.large);
    });
  });
}
