import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:miaid/generated/l10n.dart';
import 'package:miaid/services/smart_ring_service.dart';

/// Android：戒指已绑定时挂一个前台服务（常驻通知）保活，让 App 退到后台后
/// [SmartRingService] 的蓝牙连接、定时同步和 RingCloudSync 的上传能继续；解绑后停止。
///
/// 服务本身不做事（见 android RingSyncService），所有戒指逻辑仍在主 isolate。
/// iOS 没有对应机制，这里什么都不做。
class RingKeepAlive {
  RingKeepAlive._();

  static final RingKeepAlive instance = RingKeepAlive._();

  static const _channel = MethodChannel('miaid/ring_sync_service');

  bool _started = false;
  bool _running = false;
  bool _syncing = false;

  void start() {
    if (!Platform.isAndroid || _started) return;
    _started = true;
    SmartRingService.instance.addListener(_sync);
    _sync();
  }

  /// 回到前台时按绑定状态校正一次（服务可能被系统杀掉、或语言切换后需要更新通知文案）。
  void onAppResumed() {
    if (!_started) return;
    _running = false;
    _sync();
  }

  void _sync() {
    unawaited(_apply(SmartRingService.instance.isBound));
  }

  Future<void> _apply(bool want) async {
    if (_syncing || want == _running) return;
    _syncing = true;
    try {
      if (want) {
        String title;
        String text;
        try {
          title = S.current.smartRingSyncServiceTitle;
          text = S.current.smartRingSyncServiceText;
        } catch (_) {
          title = 'MiAid';
          text = 'Syncing smart ring data';
        }
        await _channel.invokeMethod<bool>('start', {'title': title, 'text': text, 'channelName': title});
      } else {
        await _channel.invokeMethod<bool>('stop');
      }
      _running = want;
    } on PlatformException catch (e) {
      debugPrint('SmartRing: keep-alive service ${want ? 'start' : 'stop'} failed: ${e.message}');
    } on MissingPluginException {
      // 原生侧没有注册（例如热重载前的旧进程），忽略
    } finally {
      _syncing = false;
    }
    // 处理期间状态又变了，再对一次
    if (SmartRingService.instance.isBound != _running) _sync();
  }
}
