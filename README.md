# OBD HUD (Flutter)

一个横屏车载 OBD HUD 应用: 手机通过蓝牙连接 ELM327 OBD2 适配器, 实时显示
发动机转速、车速、水温、进气温度、涡轮压力、节气门开度、空气流量等关键数据。

> **开源协议**: MIT License, 详见 `LICENSE`。
>
> **直接下载 APK**: [obd-hud-release.apk](https://github.com/chuangkoudexin/OBD-/releases/download/v1.0.0/obd-hud-release.apk)

> ✅ 已在小米 17ProMax (1920x1200) 真机安装验证:
> - 主仪表 / 实时数据 / 自定义 / 连接 四页均可正常显示与切换;
> - BLE 扫描正常, 实测扫描到附近 3 个 BLE 设备;
> - 添加显示项对话框、连接与显示设置均可用;
> - 截图见 `screenshots/` 目录。

## 功能

- **横屏沉浸式设计**: 深色 HUD 风格, 左侧导航切换页面。
- **左侧 Tab 栏布局**(第一版风格, Tab 栏贴左避开打孔屏摄像头):
  1. 主页(默认): 马力机风格双曲线(马力 PS + 扭矩 N·m) + 当前转速参考线, 内置 4G63S4T 推算曲线。
  2. 主仪表: 曲线式转速表 + 底部三组可选数据(温度/速度、进气/增压、燃油/电气)。
  3. 实时数据: 所有可读取的 PID 按分类展示, 点击卡片可加入自定义。
  4. 自定义: 手动添加/删除/排序显示项, 支持小/中/大三种卡片尺寸, 配置持久化。
  5. 连接: 经典蓝牙 SPP 与 BLE 两种适配器扫描、连接、断开与显示设置。
- **双蓝牙支持**:
  - 经典蓝牙 SPP (老式 ELM327 OBD2 适配器, Android 常用);
  - BLE OBD2 适配器 (V-Link / KW902 / iCar2 等)。
- **转速表分段配色**:
  - 1000~6000 rpm 每 500 转切换一种颜色;
  - 6000 rpm 以后固定为红色(未连接/无转速时也只显示红区);
  - 连接后颜色随当前转速依次点亮, 支持"随机配色"开关, 每次启动随机(相邻段不撞色)。
- **PID 覆盖**: 内置 30+ 常用 OBD-II Mode 01 PID 目录, 连接后自动读取 0100/0120/0140/0160
  支持位图, 只轮询车辆真正支持的 PID。
  - 转速、车速、发动机负荷、点火提前角、冷却液温度、进气温度、环境温度、机油温度(非标准);
  - MAP 进气歧管绝对压力、MAF 空气流量、节气门开度、油门踏板位置、大气压力;
  - **涡轮压力**(由 MAP - BARO 派生, 显示 bar, 1 bar = 100 kPa);
  - 燃油修正、燃油液位、燃油轨压、EGR、EVAP、电瓶电压、当量比等。
- **油耗估算**: 由 MAF 空气流量按汽油当量比推算瞬时油耗(L/h)与实时油耗(L/100km, 需车速>5km/h); 主页底部卡片可长按/点击切换显示数据。
- **多车动力曲线**: 内置 2015 哈弗 H5 2.0T (4G63S4T) 与 2013 捷达 1.6L MT 两套推算曲线, 可在"连接"页"车辆配置"处切换。
- **ELM 调试日志**: 连接页开启"显示 ELM 调试信息"后, 可看到最近 8 条原始收发命令, 便于排查读不到数据的问题。
- **数据持久化**: 自定义显示项、配色开关、上次连接的设备均保存在 SharedPreferences。

## 技术架构

| 层 | 目录 | 说明 |
| --- | --- | --- |
| 入口 | `lib/main.dart` | 横屏/沉浸式设置, Provider 装配 |
| 组件 | `lib/widgets/` | `RpmGauge` 自绘转速表、`HudValueTile` 玻璃卡片 |
| 页面 | `lib/screens/` | 主仪表 / 实时数据 / 自定义 / 连接 |
| 模型 | `lib/models/` | PID 定义与解析、自定义显示项 |
| 服务 | `lib/services/` | 蓝牙传输抽象、ELM327 会话、轮询控制器、设置存储 |

### 数据流

```
OBD 适配器(经典蓝牙/BLE)
        ↓ Uint8List
ObdTransport (ClassicBluetoothTransport / BleTransport)
        ↓
Elm327Session (AT 初始化 + 请求/响应 + PID 位图)
        ↓
ObdController (按优先级轮询支持的 PID, 维护 Telemetry 快照)
        ↓ ChangeNotifier
UI (RpmGauge / HudValueTile / 实时数据 / 自定义)
```

## 快速开始

```bash
cd obd_hud
flutter pub get
flutter run
```

- 需要 Android SDK (建议 API 34+) 与 JDK 17 才能构建 APK:
  ```bash
  flutter build apk --debug
  ```
- 真机测试步骤:
  1. 将 ELM327 OBD2 适配器插到车辆 OBD 口并启动车辆;
  2. 手机蓝牙配对适配器(经典蓝牙可直接配对, BLE 无需配对);
  3. 打开 App → 连接 → 选择对应类型扫描 → 点击设备;
  4. 连接成功后自动进入数据轮询。

## 权限

- Android 12+:
  `BLUETOOTH_SCAN`, `BLUETOOTH_CONNECT`, `BLUETOOTH_ADVERTISE`;
- Android 11 及以下:
  `BLUETOOTH`, `BLUETOOTH_ADMIN`, 定位权限(扫描蓝牙需要);
- iOS:
  `NSBluetoothAlwaysUsageDescription` / `NSBluetoothPeripheralUsageDescription`
  (经典蓝牙 SPP 插件仅支持 Android, iOS 请使用 BLE 适配器)。

## 工程化 / 维护

- **一键构建**: Windows 下直接运行 `build_apk.bat` 即可打包 APK(脚本已自动配置 JDK / Android SDK / Pub 缓存 / Flutter 自带 MinGit, 解决 git 不在 PATH 的问题)。
- **CI**: 已提供 `.github/workflows/ci.yml`, 提交后自动执行 `flutter analyze` → `flutter test` → `flutter build apk`。
- **全局错误兜底**: `main.dart` 中使用 `runZonedGuarded` + `FlutterError.onError` 捕获未处理异常并记录日志。
- **测试**: 覆盖 RPM 配色规则、OBD PID 解析公式、涡轮压力 bar 派生换算、自定义项迁移等核心逻辑。

> 说明: 在缺少 HOME/USERPROFILE 的受限 CI 环境中运行 `flutter test` 可能触发 test_core 的
> `_globalConfigPath` 崩溃, 设置 `USERPROFILE / HOME / APPDATA` 环境变量即可。

## 已知限制 / TODO

- 机油温度 PID 0x5C 非 SAE 标准, 部分车型不支持, 读不到会显示 `--`。
- 涡轮压力为派生值(MAP - BARO), 仅对带 MAP 传感器的增压车型有意义。
- 部分品牌的厂商自定义 PID(如水温扩展)未包含, 后续可按车型补充。
- iOS 上经典蓝牙 SPP 通道不可用(插件仅 Android), 已提供 BLE 通道。
- 后续可扩展: 故障码(DTC)读取、数据记录导出、小地图转速趋势曲线。
