import 'dart:async';
import 'dart:io';

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import 'background_service.dart';

/// 定时位置上传服务的统一入口。
///
/// 用法：在 main() 中调用 [LocationUploadService.start()]，无需关心平台差异。
///
/// ```dart
/// Future<void> main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   await LocationUploadService.start();
///   runApp(const MyApp());
/// }
/// ```
class LocationUploadService {
  LocationUploadService._();

  /// 申请权限并按平台启动服务，幂等（重复调用无副作用）。
  static Future<void> start() async {
    await _requestPermissions();
    if (Platform.isAndroid) {
      await initializeAndroidService();
    } else {
      await IosLocationTracker.start();
    }
  }

  /// 停止服务。
  static Future<void> stop() async{
    if (Platform.isAndroid) {
      FlutterBackgroundService().invoke('stopService');
    } else {
      IosLocationTracker.stop();
    }
  }

  /// 服务是否正在运行。
  static Future<bool> get isRunning async {
    if (Platform.isAndroid) {
      return FlutterBackgroundService().isRunning();
    }
    return IosLocationTracker.isRunning;
  }

  /// 每次成功上传后广播一条位置记录，可供 UI 层选择性监听。
  ///
  /// 字段：`latitude`(double)、`longitude`(double)、`timestamp`(String ISO-8601)
  static Stream<Map<String, dynamic>> get updates {
    if (Platform.isAndroid) {
      return FlutterBackgroundService()
          .on('update')
          .where((e) => e != null)
          .cast<Map<String, dynamic>>();
    }
    return IosLocationTracker.updates;
  }

  // ── 内部：权限申请 ─────────────────────────────────────────────────────────

  static Future<void> _requestPermissions() async {
    var locationPerm = await Geolocator.checkPermission();
    if (locationPerm == LocationPermission.denied) {
      locationPerm = await Geolocator.requestPermission();
    }

    // 后台位置（Android 10+ 需单独申请；iOS 需用户选择"始终允许"）
    if (locationPerm == LocationPermission.whileInUse) {
      await Permission.locationAlways.request();
    }

    // 通知权限（Android 13+ 前台服务必须）
    if (Platform.isAndroid) {
      await Permission.notification.request();
    }
  }
}
