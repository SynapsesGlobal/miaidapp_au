import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:device_info/device_info.dart';
import 'package:flutter/foundation.dart';
import 'package:miaid/services/smart_ring_models.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:rwfit_ble/rwfit_ble.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 智能戒指（RWFIT，`rwfit_ble` 插件）在 App 侧的唯一状态源。
///
/// 职责：
/// - 懒初始化 SDK（首次扫描或已绑定设备启动重连时才 `init()`，避免未用戒指的用户
///   在启动时就被 iOS 弹蓝牙权限）；
/// - 扫描 / 连接 / 重连 / 解绑，连接以 `onFunctionMenu`（设备就绪）为成功信号；
/// - 绑定设备、功能表、最近一次数据快照持久化到 SharedPreferences，冷启动即可展示；
/// - 全量健康同步与实时单次测量（心率 → 血氧 → 体温 → HRV 顺序进行，SDK 要求同一时间只能测一项）。
///
/// 页面通过 [ListenableBuilder] / [AnimatedBuilder] 监听本对象。本类不依赖多语言，
/// 错误以异常抛给页面，由页面决定提示文案。
///
/// 不走 injectable：新增 @injectable 需要重跑 build_runner，会抹掉生成 API 客户端里的手工补丁
/// （见 CLAUDE.md），所以这里用普通单例。
class SmartRingService extends ChangeNotifier {
  SmartRingService._();

  static final SmartRingService instance = SmartRingService._();

  static const _deviceKey = 'smart_ring_device';
  static const _capabilitiesKey = 'smart_ring_capabilities';
  static const _snapshotKey = 'smart_ring_snapshot';

  static const _connectTimeout = Duration(seconds: 25);
  static const _syncTimeout = Duration(minutes: 3);
  static const _measureTimeout = Duration(seconds: 90);

  /// 「立即测量」依次测的项目。
  static const measureSequence = [
    RealtimeMetric.hr,
    RealtimeMetric.bloodOxy,
    RealtimeMetric.temperature,
    RealtimeMetric.hrv,
  ];

  final RwfitBle _ring = RwfitBle.instance;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  Future<void>? _loadFuture;
  Future<void>? _initFuture;
  bool _subscribed = false;

  Completer<FunctionMenu>? _readyCompleter;
  Completer<void>? _syncCompleter;
  Completer<RealtimeMeasureResult>? _measureCompleter;

  // ---------------- 对页面暴露的状态 ----------------

  /// 已绑定（配对成功过）的戒指；null 表示未绑定。
  BleDevice? boundDevice;
  RingCapabilities capabilities = RingCapabilities.empty;
  ConnectState connectionState = ConnectState.disconnected;

  /// 收到功能表、可以下发指令。
  bool ready = false;
  int? battery;
  SmartRingSnapshot snapshot = SmartRingSnapshot.empty;

  List<BleDevice> scanResults = const [];
  bool scanning = false;
  bool syncing = false;

  /// 正在实时测量的项目；null 表示没有在测。
  RealtimeMetric? measuring;

  bool get isBound => boundDevice != null;
  bool get isConnected => ready && connectionState == ConnectState.connected;
  bool get isConnecting => connectionState == ConnectState.connecting;
  bool get busy => syncing || measuring != null;

  // ---------------- 启动 / 初始化 ----------------

  /// App 启动时调用（bootstrap）：恢复本地状态；有绑定设备时后台重连并自动同步。
  /// 任何失败都吞掉，不影响启动。
  Future<void> start() async {
    try {
      await _loadSaved();
      if (boundDevice == null) return;
      if (Platform.isAndroid && !await _hasAndroidPermissions()) return;
      await reconnect();
    } catch (e) {
      debugPrint('SmartRing: startup reconnect skipped: $e');
    }
  }

  /// 读取本地保存的设备 / 功能表 / 快照，只执行一次。
  Future<void> _loadSaved() => _loadFuture ??= () async {
        final prefs = await SharedPreferences.getInstance();
        final device = _decodeMap(prefs.getString(_deviceKey));
        if (device != null) boundDevice = BleDevice.fromMap(device);
        final caps = _decodeMap(prefs.getString(_capabilitiesKey));
        if (caps != null) capabilities = RingCapabilities(Map.unmodifiable(caps));
        final snap = _decodeMap(prefs.getString(_snapshotKey));
        if (snap != null) snapshot = SmartRingSnapshot.fromJson(snap);
        notifyListeners();
      }();

  /// 初始化 SDK 并挂上事件订阅，只执行一次；失败后允许重试。
  Future<void> ensureInitialized() => _initFuture ??= _initialize();

  Future<void> _initialize() async {
    try {
      await _loadSaved();
      _subscribe();
      await _ring.init();
    } catch (e) {
      _initFuture = null;
      rethrow;
    }
  }

  void _subscribe() {
    if (_subscribed) return;
    _subscribed = true;
    _subscriptions.addAll([
      _ring.onScanResult.listen(_onScanResult),
      _ring.onScanFinish.listen((_) {
        scanning = false;
        notifyListeners();
      }),
      _ring.onConnectState.listen((event) {
        _log('connectState=${event.state.name} name=${event.name} mac=${event.mac} reason=${event.reason}');
        _onConnectState(event);
      }),
      _ring.onFunctionMenu.listen((menu) {
        _log('functionMenu(ready) name=${menu.name} mac=${menu.mac} uuid=${menu.uuid} '
            'caps=${menu.raw.entries.where((e) => e.value == true).map((e) => e.key).join(',')}');
        _onFunctionMenu(menu);
      }),
      _ring.onBatteryChanged.listen((info) {
        _log('battery=${info.power}% charging=${info.charging}');
        battery = info.power;
        notifyListeners();
      }),
      _ring.onSyncResult.listen((result) {
        _log('syncResult type=${result.type} days=${result.data.length} '
            'items=${result.data.fold<int>(0, (n, d) => n + ((d['items'] as List?)?.length ?? 0))} '
            'first=${result.data.isEmpty ? '-' : result.data.first}');
        snapshot = SmartRingSyncParser.applySyncResult(snapshot, result);
        notifyListeners();
      }),
      _ring.onSyncFinish.listen((_) {
        _log('syncFinish hr=${snapshot.heartRate?.value} spo2=${snapshot.bloodOxygen?.value} '
            'temp=${snapshot.temperature?.value} hrv=${snapshot.hrv?.value} '
            'sleepMin=${snapshot.sleep?.totalMinutes} steps=${snapshot.steps?.steps}');
        _completeSync();
      }),
      _ring.onSyncError.listen((error) {
        _log('syncError $error');
        final code = error['code'];
        _completeSync(RwfitException(code is num ? code.toInt() : -1, 'sync error'));
      }),
      _ring.onRealtimeData.listen((data) {
        _log('realtime type=${data.type?.name} value=${data.value} diastolic=${data.diastolic} t=${data.timestampSec}');
        snapshot = SmartRingSyncParser.applyRealtime(snapshot, data);
        notifyListeners();
      }),
      _ring.onRealtimeMeasureComplete.listen((result) {
        _log('measureComplete success=${result.isSuccess} errorCode=${result.errorCode}');
        final completer = _measureCompleter;
        if (completer != null && !completer.isCompleted) completer.complete(result);
      }),
    ]);
  }

  /// 调试日志（仅 debug 构建输出），前缀 `SmartRing:`，真机联调时用 `flutter run` 控制台或
  /// `adb logcat -s flutter` / Xcode 控制台过滤查看。
  static void _log(String message) {
    if (kDebugMode) debugPrint('SmartRing: $message');
  }

  // ---------------- 权限 ----------------

  /// Android 12+ 需要运行时蓝牙权限；Android 11 及以下扫描 BLE 依赖定位权限。
  /// iOS 由系统在首次使用蓝牙时自动弹窗，这里直接返回 true。
  Future<bool> requestPermissions() async {
    if (!Platform.isAndroid) return true;
    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();
    final bluetoothOk =
        statuses[Permission.bluetoothScan]!.isGranted && statuses[Permission.bluetoothConnect]!.isGranted;
    if (!bluetoothOk) return false;
    if (await _androidSdkInt() >= 31) return true;
    return statuses[Permission.locationWhenInUse]!.isGranted;
  }

  Future<bool> _hasAndroidPermissions() async {
    if (!await Permission.bluetoothConnect.isGranted) return false;
    if (await _androidSdkInt() >= 31) return true;
    return Permission.locationWhenInUse.isGranted;
  }

  Future<int> _androidSdkInt() async {
    try {
      return (await DeviceInfoPlugin().androidInfo).version.sdkInt;
    } catch (_) {
      return 31;
    }
  }

  // ---------------- 扫描 ----------------

  /// 开始扫描（SDK 10 秒后自动结束，结束时 [scanning] 置回 false）。
  Future<void> startScan() async {
    await ensureInitialized();
    scanResults = const [];
    scanning = true;
    notifyListeners();
    try {
      await _ring.startScan();
    } catch (e) {
      scanning = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> stopScan() async {
    if (!scanning) return;
    try {
      await _ring.stopScan();
    } catch (_) {
      // 停止失败不影响后续连接
    }
    scanning = false;
    notifyListeners();
  }

  void _onScanResult(BleDevice device) {
    _log('scanResult name=${device.name} mac=${device.mac} uuid=${device.uuid} rssi=${device.rssi}');
    final id = _identity(device.uuid, device.mac);
    final list = [
      for (final d in scanResults)
        if (_identity(d.uuid, d.mac) != id) d,
      device,
    ]..sort((a, b) => b.rssi.compareTo(a.rssi));
    scanResults = List.unmodifiable(list);
    notifyListeners();
  }

  // ---------------- 连接 / 重连 / 解绑 ----------------

  /// 连接扫描到的设备，直到设备就绪（收到功能表）才返回；失败或超时抛异常。
  Future<void> connect(BleDevice device) async {
    await ensureInitialized();
    await stopScan();
    if (isConnected && boundDevice != null && _identity(boundDevice!.uuid, boundDevice!.mac) == _identity(device.uuid, device.mac)) {
      return;
    }
    await _connectAndWaitReady(() => _ring.connect(device));
  }

  /// 重连已绑定设备。
  Future<void> reconnect() async {
    final device = boundDevice;
    if (device == null) throw StateError('no bound device');
    await ensureInitialized();
    if (isConnected || isConnecting) return;
    await _connectAndWaitReady(() async {
      // iOS 重连前必须先声明绑定态；Android 为 no-op
      await _ring.iosSetBindedStatus(true);
      await _ring.reconnect(device);
    });
  }

  Future<void> _connectAndWaitReady(Future<void> Function() action) async {
    final previous = _readyCompleter;
    if (previous != null && !previous.isCompleted) previous.completeError(StateError('superseded'));
    final completer = Completer<FunctionMenu>();
    _readyCompleter = completer;
    connectionState = ConnectState.connecting;
    ready = false;
    notifyListeners();
    try {
      await action();
      await completer.future.timeout(_connectTimeout);
    } catch (e) {
      if (identical(_readyCompleter, completer)) {
        _readyCompleter = null;
        if (!ready) connectionState = ConnectState.failed;
        notifyListeners();
      }
      rethrow;
    }
  }

  void _onConnectState(ConnectStateEvent event) {
    connectionState = event.state;
    if (event.state != ConnectState.connected) ready = false;
    if (event.state == ConnectState.failed) {
      final completer = _readyCompleter;
      if (completer != null && !completer.isCompleted) {
        completer.completeError(RwfitException(-1, event.reason ?? 'connect failed'));
      }
    }
    if (event.state == ConnectState.failed || event.state == ConnectState.disconnected) {
      _completeSync(RwfitException(-1, 'disconnected'));
      _completeMeasure(RwfitException(-1, 'disconnected'));
    }
    notifyListeners();
  }

  Future<void> _onFunctionMenu(FunctionMenu menu) async {
    final previous = boundDevice;
    final mac = menu.mac.isNotEmpty ? menu.mac : (previous?.mac ?? '');
    final uuid = (menu.uuid?.isNotEmpty ?? false) ? menu.uuid : previous?.uuid;
    final changed = previous == null || _identity(previous.uuid, previous.mac) != _identity(uuid, mac);
    boundDevice = BleDevice(
      name: menu.name.isNotEmpty ? menu.name : (previous?.name ?? ''),
      mac: mac,
      rssi: 0,
      uuid: uuid,
    );
    capabilities = RingCapabilities(Map.unmodifiable(menu.raw));
    connectionState = ConnectState.connected;
    ready = true;
    if (changed) {
      snapshot = SmartRingSnapshot.empty;
      battery = null;
    }
    final completer = _readyCompleter;
    _readyCompleter = null;
    if (completer != null && !completer.isCompleted) completer.complete(menu);
    notifyListeners();

    await _persistDevice();
    try {
      await _ring.iosSetBindedStatus(true);
    } catch (_) {}
    unawaited(_refreshBattery());
    // 就绪后自动拉一次历史数据，进入看板即有内容
    unawaited(syncHealthData().catchError((Object e) {
      debugPrint('SmartRing: auto sync failed: $e');
    }));
  }

  Future<void> _refreshBattery() async {
    try {
      battery = await _ring.getPower();
      notifyListeners();
    } catch (e) {
      debugPrint('SmartRing: getPower failed: $e');
    }
  }

  /// 断开但保留绑定（下次可重连）。
  Future<void> disconnect() async {
    await ensureInitialized();
    try {
      await _ring.disconnect();
    } finally {
      ready = false;
      connectionState = ConnectState.disconnected;
      notifyListeners();
    }
  }

  /// 解绑：下发解绑指令、清除 iOS 绑定态、清空本地所有戒指数据。
  Future<void> unbind() async {
    await ensureInitialized();
    try {
      await _ring.unbind();
    } catch (e) {
      debugPrint('SmartRing: unbind command failed: $e');
    }
    try {
      await _ring.disconnect();
    } catch (_) {}
    try {
      await _ring.iosSetBindedStatus(false);
    } catch (_) {}
    final error = StateError('unbound');
    final readyCompleter = _readyCompleter;
    _readyCompleter = null;
    if (readyCompleter != null && !readyCompleter.isCompleted) readyCompleter.completeError(error);
    _completeSync(error);
    _completeMeasure(error);
    boundDevice = null;
    capabilities = RingCapabilities.empty;
    ready = false;
    connectionState = ConnectState.disconnected;
    battery = null;
    snapshot = SmartRingSnapshot.empty;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_deviceKey);
    await prefs.remove(_capabilitiesKey);
    await prefs.remove(_snapshotKey);
  }

  // ---------------- 健康数据同步 ----------------

  /// 全量同步历史数据（步数、睡眠、定时监测的体征），完成后更新快照并持久化。
  Future<void> syncHealthData() async {
    final pending = _syncCompleter;
    if (pending != null) return pending.future;
    if (measuring != null) throw StateError('measuring');
    if (!isConnected) await reconnect();
    final completer = Completer<void>();
    _syncCompleter = completer;
    syncing = true;
    notifyListeners();
    try {
      await _ring.syncAllHealthData();
      await completer.future.timeout(_syncTimeout);
      snapshot = snapshot.copyWith(lastSyncAt: DateTime.now());
      await _persistSnapshot();
    } finally {
      if (identical(_syncCompleter, completer)) _syncCompleter = null;
      syncing = false;
      notifyListeners();
    }
  }

  void _completeSync([Object? error]) {
    final completer = _syncCompleter;
    if (completer == null || completer.isCompleted) return;
    if (error == null) {
      completer.complete();
    } else {
      completer.completeError(error);
    }
  }

  // ---------------- 实时测量 ----------------

  /// 依次实时测量设备支持的项目（见 [measureSequence]），任一项失败即中止并抛出。
  Future<void> measureNow() async {
    if (busy) return;
    if (!isConnected) await reconnect();
    final metrics = measureSequence.where(capabilities.supportsRealtime).toList();
    try {
      for (final metric in metrics) {
        if (!isConnected) throw RwfitException(-1, 'disconnected');
        await _measure(metric);
      }
    } finally {
      await _persistSnapshot();
    }
  }

  Future<void> _measure(RealtimeMetric metric) async {
    final completer = Completer<RealtimeMeasureResult>();
    _measureCompleter = completer;
    measuring = metric;
    notifyListeners();
    try {
      _log('startRealtimeMeasure ${metric.name}');
      await _ring.startRealtimeMeasure(metric);
      final result = await completer.future.timeout(_measureTimeout);
      if (!result.isSuccess) throw RwfitException(result.errorCode, 'measure failed');
    } finally {
      if (identical(_measureCompleter, completer)) _measureCompleter = null;
      try {
        await _ring.stopRealtimeMeasure(metric);
      } catch (_) {}
      measuring = null;
      notifyListeners();
    }
  }

  void _completeMeasure(Object error) {
    final completer = _measureCompleter;
    if (completer == null || completer.isCompleted) return;
    completer.completeError(error);
  }

  // ---------------- 全天定时监测设置 ----------------

  /// 该项目的检测间隔是否可选 30/60 分钟（心率、体温）；其余固定 60 分钟。
  static bool supportsInterval30(RealtimeMetric metric) =>
      metric == RealtimeMetric.hr || metric == RealtimeMetric.temperature;

  /// 读取戒指上某项全天监测的当前配置。未连接时先重连。
  Future<TimedConfig> getTimedConfig(RealtimeMetric metric) async {
    if (!isConnected) await reconnect();
    switch (metric) {
      case RealtimeMetric.hr:
        return _ring.getTimedHeartRate();
      case RealtimeMetric.bloodOxy:
        return _ring.getTimedBloodOxygen();
      case RealtimeMetric.hrv:
        return _ring.getTimedHRV();
      case RealtimeMetric.pressure:
        return _ring.getTimedStress();
      case RealtimeMetric.bloodSugar:
        return _ring.getTimedBloodSugar();
      case RealtimeMetric.bloodPressure:
        return _ring.getTimedBloodPressure();
      case RealtimeMetric.temperature:
        return _ring.getTimedBodyTemperature();
    }
  }

  /// 设置某项全天监测。时段固定全天（00:00–23:59），间隔只接受 30/60，
  /// 不支持 30 的项目强制为 60。
  Future<void> setTimedConfig(RealtimeMetric metric, {required bool enabled, int intervalMinutes = 60}) async {
    if (!isConnected) await reconnect();
    final duration = supportsInterval30(metric) && intervalMinutes == 30 ? 30 : 60;
    final config = TimedConfig(isOpen: enabled, duration: duration);
    _log('setTimedConfig ${metric.name} open=$enabled every=${duration}min');
    switch (metric) {
      case RealtimeMetric.hr:
        return _ring.setTimedHeartRate(config);
      case RealtimeMetric.bloodOxy:
        return _ring.setTimedBloodOxygen(config);
      case RealtimeMetric.hrv:
        return _ring.setTimedHRV(config);
      case RealtimeMetric.pressure:
        return _ring.setTimedStress(config);
      case RealtimeMetric.bloodSugar:
        return _ring.setTimedBloodSugar(config);
      case RealtimeMetric.bloodPressure:
        return _ring.setTimedBloodPressure(config);
      case RealtimeMetric.temperature:
        return _ring.setTimedBodyTemperature(config);
    }
  }

  // ---------------- 持久化 ----------------

  Future<void> _persistDevice() async {
    final device = boundDevice;
    if (device == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_deviceKey, jsonEncode(device.toMap()));
      await prefs.setString(_capabilitiesKey, jsonEncode(capabilities.raw));
    } catch (e) {
      debugPrint('SmartRing: persist device failed: $e');
    }
  }

  Future<void> _persistSnapshot() async {
    if (boundDevice == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_snapshotKey, jsonEncode(snapshot.toJson()));
    } catch (e) {
      debugPrint('SmartRing: persist snapshot failed: $e');
    }
  }

  static Map<String, dynamic>? _decodeMap(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map ? decoded.cast<String, dynamic>() : null;
    } catch (_) {
      return null;
    }
  }

  /// 设备标识：iOS 优先 uuid（系统配对后扫描结果可能没有 MAC），Android 用 MAC。
  static String _identity(String? uuid, String mac) {
    final value = (uuid != null && uuid.isNotEmpty) ? uuid : mac;
    return value.toUpperCase();
  }

  @override
  void dispose() {
    for (final s in _subscriptions) {
      s.cancel();
    }
    _subscriptions.clear();
    super.dispose();
  }
}
