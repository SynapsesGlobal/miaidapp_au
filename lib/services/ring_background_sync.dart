import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:miaid/services/ring_cloud_sync.dart';
import 'package:miaid/services/smart_ring_service.dart';

/// iOS：系统后台刷新（BGAppRefreshTask）唤醒时补一次戒指同步并上传。
///
/// 原生 AppDelegate 在戒指已绑定时按 15 分钟间隔向系统申请后台刷新（实际时机由系统决定），
/// 任务触发后通过 MethodChannel 调到这里：未连接先重连，再同步健康数据，最后把快照和读数队列推到后端，
/// 整个过程控制在 25 秒内以免被系统强杀。配合 Info.plist 的 `bluetooth-central` 后台模式，
/// 退后台期间与戒指的连接通常还在，同步很快。Android 不用这套（有前台服务保活）。
class RingBackgroundSync {
  RingBackgroundSync._();

  static final RingBackgroundSync instance = RingBackgroundSync._();

  static const _channel = MethodChannel('miaid/ring_background');
  static const _budget = Duration(seconds: 25);
  static const _connectTimeout = Duration(seconds: 12);
  static const _syncTimeout = Duration(seconds: 15);

  bool _started = false;
  bool _enabled = false;
  bool _running = false;

  void start() {
    if (!Platform.isIOS || _started) return;
    _started = true;
    _channel.setMethodCallHandler(_onCall);
    SmartRingService.instance.addListener(_syncEnabled);
    _syncEnabled();
  }

  /// 告诉原生侧要不要继续申请后台刷新（只在绑定了戒指时申请）。
  void _syncEnabled() {
    final want = SmartRingService.instance.isBound;
    if (want == _enabled) return;
    _enabled = want;
    unawaited(_channel.invokeMethod<void>('setEnabled', want).catchError((Object e) {
      debugPrint('SmartRing: background setEnabled failed: $e');
    }));
  }

  Future<dynamic> _onCall(MethodCall call) async {
    switch (call.method) {
      case 'sync':
        return _run();
      case 'cancel':
        return null;
      default:
        throw MissingPluginException();
    }
  }

  /// 返回 true 表示这次有成功同步（供原生侧标记任务结果）。
  Future<bool> _run() async {
    final ring = SmartRingService.instance;
    if (_running || !ring.isBound) return false;
    _running = true;
    final started = DateTime.now();
    var ok = false;
    try {
      await ring.ensureInitialized().timeout(const Duration(seconds: 5));
      if (!ring.isConnected) {
        try {
          await ring.reconnect().timeout(_connectTimeout);
        } catch (e) {
          debugPrint('SmartRing: background reconnect failed: $e');
        }
      }
      if (ring.isConnected && !ring.busy) {
        try {
          await ring.syncHealthData().timeout(_syncTimeout);
          ok = true;
        } catch (e) {
          debugPrint('SmartRing: background sync failed: $e');
        }
      }
      final left = _budget - DateTime.now().difference(started);
      if (left > const Duration(seconds: 3)) {
        await RingCloudSync.instance.flush().timeout(left, onTimeout: () {});
      }
    } catch (e) {
      debugPrint('SmartRing: background task failed: $e');
    } finally {
      _running = false;
    }
    debugPrint('SmartRing: background task done ok=$ok in ${DateTime.now().difference(started).inSeconds}s');
    return ok;
  }
}
