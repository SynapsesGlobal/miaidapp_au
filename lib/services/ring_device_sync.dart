import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:miaid/api_utils/api_provider.dart';
import 'package:miaid/services/ring_alert_service.dart';
import 'package:miaid/services/ring_family_service.dart';
import 'package:miaid/services/smart_ring_models.dart';
import 'package:miaid/services/smart_ring_service.dart';
import 'package:miaid/store/app/app_settings.dart';
import 'package:miaid/utils/configure_dependencies.dart';

/// 把后端的家人提醒阈值写进戒指：戒指端的心率 / 血氧报警用同一份阈值，超标时戒指自己震动提醒本人，
/// 不依赖手机在不在身边。
///
/// 时机：戒指每次就绪（连接 / 重连）、App 回到前台、本人在设置页保存阈值后；家人改的阈值在
/// 下一次就绪 / 回前台时同步到戒指。只对已登录的客户账号、已绑定戒指时工作。
class RingDeviceSync {
  RingDeviceSync._();

  static final RingDeviceSync instance = RingDeviceSync._();

  final SmartRingService _ring = SmartRingService.instance;
  bool _started = false;
  bool _syncing = false;

  /// 本次会话是否已把 App 语言和时区偏移告诉后端（本人阈值提醒的推送文案 / 时间用）。
  bool _localeSynced = false;

  /// 本次连接是否已经同步过（断开后重置，就绪时再同步一次）。
  bool _syncedThisConnection = false;

  void start() {
    if (_started) return;
    _started = true;
    _ring.addListener(_onRingChanged);
    _onRingChanged();
  }

  void onAppResumed() {
    if (_ring.isConnected) unawaited(sync());
  }

  void _onRingChanged() {
    if (!_ring.isConnected) {
      _syncedThisConnection = false;
      return;
    }
    if (_syncedThisConnection) return;
    _syncedThisConnection = true;
    unawaited(sync());
  }

  /// 拉自己的阈值并写进戒指；[settings] 已有时（设置页刚保存）不再请求。失败只记日志，下次再试。
  Future<void> sync({RingAlertSettings? settings}) async {
    if (_syncing || !_ring.isBound) return;
    final api = _api();
    final user = api?.userProvider.user;
    if (api == null || user == null || api.userProvider.isDoctor || api.userProvider.isTranslator) return;
    _syncing = true;
    try {
      final service = RingAlertService(RingFamilyService(api));
      if (settings == null) {
        if (!_localeSynced) {
          // 语言和手机时区偏移一起报上去：本人阈值提醒推送的文案和时间按它们显示
          settings = await service.updateSettings({
            'locale': _localeTag(),
            'tz_offset': DateTime.now().timeZoneOffset.inMinutes,
          });
          _localeSynced = true;
        } else {
          settings = await service.fetchSettings();
        }
      }
      await _ring.applyAlertConfig(toConfig(settings));
    } catch (e) {
      debugPrint('SmartRing: alert config sync failed: $e');
      _syncedThisConnection = false;
    } finally {
      _syncing = false;
    }
  }

  static String _localeTag() {
    final locale = getIt<AppSettings>().localeListenable.value;
    return locale.scriptCode != null && locale.scriptCode!.isNotEmpty
        ? '${locale.languageCode}_${locale.scriptCode}'
        : locale.languageCode;
  }

  static RingAlertConfig toConfig(RingAlertSettings settings) {
    final hr = settings.thresholds['heart_rate'];
    final spo2 = settings.thresholds['blood_oxygen'];
    return RingAlertConfig(
      enabled: settings.enabled,
      hrLow: hr?.low?.round(),
      hrHigh: hr?.high?.round(),
      spo2Low: spo2?.low?.round(),
    );
  }

  ApiProvider? _api() {
    try {
      return getIt<ApiProvider>();
    } catch (_) {
      return null;
    }
  }
}
