import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:obd_hud/core/rpm_color_policy.dart';
import 'package:obd_hud/widgets/rpm_gauge.dart';

void main() {
  test('RPM 配色: 6000 转以后为红色', () {
    final policy = RpmColorPolicy.build(randomize: false);
    expect(policy.colorForRpm(5999), isNot(policy.colorForRpm(6000)));
    expect(policy.colorForRpm(6000), policy.colorForRpm(6500));
    expect(policy.colorForRpm(5500), policy.colorForRpm(5999));
    expect(policy.segmentColorAt(6000), policy.segmentColorAt(6500));
    expect(policy.segmentColorAt(5500), isNot(policy.segmentColorAt(6000)));
  });

  test('RPM 配色: 每 500 转切换颜色', () {
    final policy = RpmColorPolicy.build(randomize: false);
    expect(policy.colorForRpm(1000), isNot(policy.colorForRpm(1500)));
    expect(policy.colorForRpm(1500), isNot(policy.colorForRpm(2000)));
  });

  testWidgets('转速表渲染', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              height: 300,
              child: RpmGauge(rpm: 3000),
            ),
          ),
        ),
      ),
    );
    expect(find.byType(RpmGauge), findsOneWidget);
    expect(find.text('R P M'), findsOneWidget);
    expect(find.text('3000'), findsWidgets);
  });
}
