import 'dart:async';
import 'dart:io';

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api_utils/api_provider.dart';
import '../utils/configure_dependencies.dart';
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

  /// 解析后端返回的追踪开关，兼容新旧格式：新版接口返回 true/false，
  /// 旧版（及 PDO 序列化）返回 1/"1"。
  static bool isTrackingOpen(dynamic value) =>
      value == true || value == 1 || value == '1';

  /// 申请权限并按平台启动服务，幂等（重复调用无副作用）。
  static Future<void> start() async {
    await _requestPermissions();
    if (Platform.isAndroid) {
      await initializeAndroidService();
    } else {
      await IosLocationTracker.start();
    }
  }

  /// App 启动时调用：若已登录（客户角色）且本地缓存的追踪开关为开，
  /// 恢复定位上传服务，不必等进入首页后的后端查询。
  /// 必须在 getHome()（内部的 getUserOnAppStart 加载持久化用户）之后调用。
  /// 本地开关由设置页提交和首页的后端同步逻辑共同维护；
  /// 若与后端不一致，以首页查询到的后端值为准（会纠正本地缓存并停启服务）。
  static Future<void> restoreIfEnabled() async {
    var pref = await SharedPreferences.getInstance();
    if (!(pref.getBool('open_position_tracking') ?? false)) return;

    final api = getIt<ApiProvider>();
    final user = api.userProvider.user;
    // 位置追踪仅面向客户角色
    if (user == null || user.doctor != null || user.translator != null) return;

    // 刷新 Android 后台 isolate 上传所需的凭据（isolate 无法访问 getIt，
    // 只能从 SharedPreferences 读取），避免依赖“先进过首页”的写入时序。
    await pref.setString('base_url', api.baseUrl);
    await pref.setString('api_key', api.apiKey);
    await pref.setString('user_id', user.id.toString());

    await start();
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

    // 后台位置：仅 iOS 申请"始终允许"（配合 UIBackgroundModes location）。
    // Android 不申请 ACCESS_BACKGROUND_LOCATION——定位前台服务在前台启动后，
    // whileInUse 权限即可在后台继续定位上传，还能避免 Play 后台定位专项审核。
    if (Platform.isIOS && locationPerm == LocationPermission.whileInUse) {
      await Permission.locationAlways.request();
    }

    // 通知权限（Android 13+ 前台服务必须）
    if (Platform.isAndroid) {
      await Permission.notification.request();
    }
  }
}
