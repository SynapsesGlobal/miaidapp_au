import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:http/http.dart' as http;

const String _channelId = 'location_upload_channel';
const String _channelName = 'Location tracker';
const int _notificationId = 888;
// 与 CN 版一致：30 分钟上传一次（服务启动时会先立即上传一次）
const int kUploadIntervalSeconds = 1800;

/// 模拟后端接口 — 替换为真实 URL 和逻辑
Future<void> uploadLocation(double latitude, double longitude) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final baseUrl = prefs.getString('base_url') ?? '';
    final apiKey = prefs.getString('api_key') ?? '';
    final userId = prefs.getString('user_id') ?? '';

    // 后端 savePosition 从请求体取 user_id（不读 header），缺了会直接 422。
    final data = <String, dynamic>{
      'user_id': userId,
      'latitude': latitude,
      'longitude': longitude,
    };
    final headers = <String, String>{
      'x-user-id': userId,
      'x-api-key': apiKey,
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    final url = Uri.parse(baseUrl+'/api/v1/save-position');
    final response = await http.post(url, headers: headers, body: jsonEncode(data),);
    if (response.statusCode == 200) {} else {print(response);}
  } catch (e) {
    debugPrint('[LocationService] 上传失败: $e');
  }
}

// ── iOS：主 isolate 中通过位置流实现后台上传 ──────────────────────────────
//
// 原因：flutter_background_service 在 iOS 上创建的后台 isolate 无法访问
// 位置权限上下文，导致 kCLErrorDomain error 1（权限拒绝）。
// 正确做法是在主 isolate 中使用 AppleSettings.allowBackgroundLocationUpdates，
// 配合 Info.plist 的 UIBackgroundModes=location，让系统保持 App 位置唤醒。

class IosLocationTracker {
  IosLocationTracker._();

  // _timer 驱动定时上传；_keepAliveSub 让系统在后台持续唤醒 App
  static Timer? _timer;
  static StreamSubscription<Position>? _keepAliveSub;

  static final _controller =
      StreamController<Map<String, dynamic>>.broadcast();

  /// UI 层监听此流获取位置更新
  static Stream<Map<String, dynamic>> get updates => _controller.stream;

  static bool get isRunning => _timer != null;

  static Future<void> start() async {
    if (_timer != null) return;

    // 启动低精度位置流：不处理数据，仅让 CLLocationManager 保持活跃，
    // 确保 App 在后台不被系统挂起（依赖 UIBackgroundModes=location）。
    _keepAliveSub = Geolocator.getPositionStream(
      locationSettings: AppleSettings(
        accuracy: LocationAccuracy.reduced,
        allowBackgroundLocationUpdates: true,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
        activityType: ActivityType.other,
      ),
    ).listen(
      (_) {}, // 仅保活，数据由定时器按需获取
      onError: (e) => debugPrint('[LocationService] iOS 位置流错误: $e'),
    );

    // 立即执行一次，再按固定间隔定时上传
    await _uploadOnce();
    _timer = Timer.periodic(
      const Duration(seconds: kUploadIntervalSeconds),
      (_) => _uploadOnce(),
    );
  }

  static Future<void> _uploadOnce() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );
      final now = DateTime.now();
      await uploadLocation(position.latitude, position.longitude);
      _controller.add({
        'latitude': position.latitude,
        'longitude': position.longitude,
        'timestamp': now.toIso8601String(),
      });
    } catch (e) {
      debugPrint('[LocationService] iOS 获取位置失败: $e');
    }
  }

  static void stop() {
    _timer?.cancel();
    _timer = null;
    _keepAliveSub?.cancel();
    _keepAliveSub = null;
  }
}

// ── Android：flutter_background_service 前台服务 ───────────────────────────

/// iOS 后台唤醒回调（必须是顶层函数）
@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}

/// Android 后台服务入口（必须是顶层函数，@pragma 防止 tree-shaking）
@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((_) {
      service.setAsForegroundService();
    });
    service.on('setAsBackground').listen((_) {
      service.setAsBackgroundService();
    });
  }

  service.on('stopService').listen((_) => service.stopSelf());

  // 立即执行一次，再按间隔定时执行
  await _doUpload(service);
  Timer.periodic(
    const Duration(seconds: kUploadIntervalSeconds),
    (_) async => _doUpload(service),
  );
}

Future<void> _doUpload(ServiceInstance service) async {
  if (service is AndroidServiceInstance && await service.isForegroundService()) {
    await service.setForegroundNotificationInfo(
      title: _channelName,
      content: 'Last upload: ${_fmtTime(DateTime.now())}',
    );
  }

  try {
    if (!await Geolocator.isLocationServiceEnabled()) return;

    final perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return;

    final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      timeLimit: const Duration(seconds: 15),
    );

    await uploadLocation(pos.latitude, pos.longitude);
    service.invoke('update', {
      'latitude': pos.latitude,
      'longitude': pos.longitude,
      'timestamp': DateTime.now().toIso8601String(),
    });
  } catch (e) {
    debugPrint('[LocationService] 获取位置失败: $e');
  }
}

String _fmtTime(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:'
    '${t.minute.toString().padLeft(2, '0')}:'
    '${t.second.toString().padLeft(2, '0')}';

/// 初始化并启动 Android 前台服务
Future<void> initializeAndroidService() async {
  final service = FlutterBackgroundService();

  // 创建通知频道（Android 8.0+ 必须）
  const channel = AndroidNotificationChannel(
    _channelId,
    _channelName,
    description: 'Uploads your location periodically while tracking is on',
    importance: Importance.low,
  );
  await FlutterLocalNotificationsPlugin().resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: true,
      isForegroundMode: true,
      notificationChannelId: _channelId,
      initialNotificationTitle: _channelName,
      initialNotificationContent: 'Location tracking is running',
      foregroundServiceNotificationId: _notificationId,
    ),
    // iOS 不使用此服务，关闭自动启动
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );

  await service.startService();
}
