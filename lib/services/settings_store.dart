import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/rpm_color_policy.dart';
import '../models/custom_gauge_item.dart';
import '../models/power_curve.dart';

/// 应用设置(持久化到 SharedPreferences)
class AppSettings extends ChangeNotifier {
  final SharedPreferences _prefs;

  AppSettings(this._prefs) {
    _load();
  }

  static Future<AppSettings> create() async {
    final prefs = await SharedPreferences.getInstance();
    return AppSettings(prefs);
  }

  bool _randomRpmColors = true;
  bool _showElmDebug = false;
  bool _autoConnectLast = false;
  int _pollIntervalMs = 40;
  String _lastDeviceAddress = '';
  String _lastDeviceName = '';
  String _lastTransport = '';
  List<CustomGaugeItem> _customItems = [];
  String _selectedVehicleId = PowerCurveModel.havalH5.id;
  RpmColorPolicy? _rpmPolicy;

  bool get randomRpmColors => _randomRpmColors;
  RpmColorPolicy get rpmPolicy =>
      _rpmPolicy ??= RpmColorPolicy.build(randomize: _randomRpmColors);
  bool get showElmDebug => _showElmDebug;
  bool get autoConnectLast => _autoConnectLast;
  int get pollIntervalMs => _pollIntervalMs;
  String get lastDeviceAddress => _lastDeviceAddress;
  String get lastDeviceName => _lastDeviceName;
  String get lastTransport => _lastTransport;
  List<CustomGaugeItem> get customItems => List.unmodifiable(_customItems);
  String get selectedVehicleId => _selectedVehicleId;
  PowerCurveModel get vehicleProfile => PowerCurveModel.byId(_selectedVehicleId);

  void _load() {
    _randomRpmColors = _prefs.getBool('randomRpmColors') ?? true;
    _showElmDebug = _prefs.getBool('showElmDebug') ?? false;
    _autoConnectLast = _prefs.getBool('autoConnectLast') ?? false;
    _pollIntervalMs = _prefs.getInt('pollIntervalMs') ?? 40;
    _lastDeviceAddress = _prefs.getString('lastDeviceAddress') ?? '';
    _lastDeviceName = _prefs.getString('lastDeviceName') ?? '';
    _lastTransport = _prefs.getString('lastTransport') ?? '';
    _customItems = CustomGaugeItem.decodeList(_prefs.getString('customItems'));
    _selectedVehicleId =
        _prefs.getString('selectedVehicleId') ?? PowerCurveModel.havalH5.id;
  }

  Future<void> setRandomRpmColors(bool value) async {
    _randomRpmColors = value;
    _rpmPolicy = RpmColorPolicy.build(randomize: value);
    notifyListeners();
    await _prefs.setBool('randomRpmColors', value);
  }

  Future<void> setShowElmDebug(bool value) async {
    _showElmDebug = value;
    notifyListeners();
    await _prefs.setBool('showElmDebug', value);
  }

  Future<void> setAutoConnectLast(bool value) async {
    _autoConnectLast = value;
    notifyListeners();
    await _prefs.setBool('autoConnectLast', value);
  }

  Future<void> setPollIntervalMs(int value) async {
    _pollIntervalMs = value.clamp(20, 200);
    notifyListeners();
    await _prefs.setInt('pollIntervalMs', _pollIntervalMs);
  }

  Future<void> setSelectedVehicle(String id) async {
    _selectedVehicleId = id;
    notifyListeners();
    await _prefs.setString('selectedVehicleId', id);
  }

  Future<void> setLastDevice({
    required String address,
    required String name,
    required String transport,
  }) async {
    _lastDeviceAddress = address;
    _lastDeviceName = name;
    _lastTransport = transport;
    await _prefs.setString('lastDeviceAddress', address);
    await _prefs.setString('lastDeviceName', name);
    await _prefs.setString('lastTransport', transport);
    notifyListeners();
  }

  Future<void> setCustomItems(List<CustomGaugeItem> items) async {
    _customItems = List.of(items);
    notifyListeners();
    await _prefs.setString('customItems', CustomGaugeItem.encodeList(items));
  }

  Future<void> addCustomItem(CustomGaugeItem item) async {
    final list = List<CustomGaugeItem>.of(_customItems);
    list.removeWhere((e) => e.pidCode == item.pidCode);
    list.add(item);
    await setCustomItems(list);
  }

  Future<void> removeCustomItem(String pidCode) async {
    final list = List<CustomGaugeItem>.of(_customItems)
      ..removeWhere((e) => e.pidCode == pidCode);
    await setCustomItems(list);
  }
}
