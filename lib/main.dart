import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/hud_theme.dart';
import 'screens/hud_shell.dart';
import 'services/obd_controller.dart';
import 'services/settings_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 全局错误兜底: 未捕获异常统一记录, 不让 App 静默崩溃
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('FlutterError: ${details.exceptionAsString()}');
  };

  runZonedGuarded(() async {
    // 横屏 + 沉浸式 HUD 显示
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ));

    final settings = await AppSettings.create();
    final obd = ObdController(settings: settings);
    await obd.init();

    runApp(ObdHudApp(settings: settings, obd: obd));
  }, (error, stack) {
    debugPrint('Uncaught app error: $error\n$stack');
  });
}

class ObdHudApp extends StatelessWidget {
  final AppSettings settings;
  final ObdController obd;

  const ObdHudApp({super.key, required this.settings, required this.obd});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider.value(value: obd),
      ],
      child: MaterialApp(
        title: 'OBD HUD',
        debugShowCheckedModeBanner: false,
        theme: HudTheme.dark(),
        home: const HudShell(),
      ),
    );
  }
}
