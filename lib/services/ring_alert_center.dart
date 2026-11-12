import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:miaid/api_utils/api_provider.dart';
import 'package:miaid/api_utils/user_provider.dart';
import 'package:miaid/services/ring_alert_service.dart';
import 'package:miaid/services/ring_family_service.dart';
import 'package:miaid/store/app/app_settings.dart';
import 'package:miaid/utils/configure_dependencies.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 家人端提醒状态中心：App 在前台时每 60 秒拉一次 `/ring/alerts/status`，回到前台 / 收到推送时立即拉。
///
/// 推送只是「叫人来看」，异常状态以这里拉到的为准：首页横幅、Me 页红点、家人列表状态、
/// 高危弹窗都监听它。高危弹窗同一条只弹一次（已弹过的 id 记在本机）。
/// 只对已登录的客户账号工作；没有关注任何人时接口返回空列表，开销很小。
class RingAlertCenter extends ChangeNotifier {
  RingAlertCenter._();

  static final RingAlertCenter instance = RingAlertCenter._();

  static const pollInterval = Duration(seconds: 60);
  static const _shownKey = 'smart-ring-alert-critical-shown';

  RingAlertService? _service;
  Timer? _timer;
  bool _started = false;
  bool _fetching = false;

  RingAlertStatus status = RingAlertStatus.empty;
  DateTime? lastFetchedAt;

  /// 已经弹过窗的高危提醒 id。
  Set<int> _shownCritical = {};
  bool _shownLoaded = false;

  /// 本次会话已把 App 语言同步到后端的绑定。
  final Set<int> _localeSynced = {};

  /// 由 main 注入：弹出高危提醒弹层。
  Future<void> Function(RingAlertItem alert)? criticalHandler;

  RingAlertService get service => _service ??= RingAlertService(RingFamilyService(getIt<ApiProvider>()));

  int get unreadCount => status.unreadCount;

  /// 当前最需要关注的提醒（首页横幅用）；没有为空。
  RingAlertItem? get bannerAlert => status.activeAlerts.isEmpty ? null : status.activeAlerts.first;

  int get bannerExtraCount => status.activeAlerts.isEmpty ? 0 : status.activeAlerts.length - 1;

  RingAlertOwnerStatus? ownerStatus(int linkId) {
    for (final o in status.owners) {
      if (o.linkId == linkId) return o;
    }
    return null;
  }

  void start() {
    if (_started) return;
    _started = true;
    _timer = Timer.periodic(pollInterval, (_) => unawaited(refresh()));
    unawaited(refresh());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _started = false;
  }

  void onAppResumed() => unawaited(refresh());

  /// 收到 ring_alert 推送时调用。
  void onPush() => unawaited(refresh());

  bool get _eligible {
    final user = getIt<UserProvider>().user;
    return user != null && user.customer != null;
  }

  Future<void> refresh() async {
    if (_fetching || !_eligible) return;
    _fetching = true;
    try {
      final next = await service.fetchStatus();
      status = next;
      lastFetchedAt = DateTime.now();
      notifyListeners();
      unawaited(_syncLocale(next));
      await _maybeShowCritical(next);
    } on RingFamilyException catch (e) {
      debugPrint('RingAlert: status failed: $e');
    } finally {
      _fetching = false;
    }
  }

  /// 本地先把某几条标成已读（界面立即更新），再通知后端。
  Future<void> markSeen({List<int>? ids, int? linkId}) async {
    try {
      await service.markSeen(ids: ids, linkId: linkId);
    } on RingFamilyException catch (e) {
      debugPrint('RingAlert: mark seen failed: $e');
    }
    unawaited(refresh());
  }

  Future<void> _maybeShowCritical(RingAlertStatus next) async {
    final critical = next.criticalUnseen;
    final handler = criticalHandler;
    if (critical == null || handler == null) return;
    await _loadShown();
    if (_shownCritical.contains(critical.id)) return;
    _shownCritical.add(critical.id);
    unawaited(_saveShown());
    try {
      await handler(critical);
    } catch (e) {
      debugPrint('RingAlert: critical dialog failed: $e');
    }
  }

  Future<void> _loadShown() async {
    if (_shownLoaded) return;
    _shownLoaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      _shownCritical = (prefs.getStringList(_shownKey) ?? const []).map(int.tryParse).whereType<int>().toSet();
    } catch (_) {}
  }

  Future<void> _saveShown() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // 只保留最近 50 条，避免无限增长
      final ids = _shownCritical.toList()..sort();
      await prefs.setStringList(_shownKey, ids.skip(ids.length > 50 ? ids.length - 50 : 0).map((e) => '$e').toList());
    } catch (_) {}
  }

  /// 把 App 语言写到每条绑定上，后端据此生成推送文案；每条绑定每次会话只同步一次。
  Future<void> _syncLocale(RingAlertStatus next) async {
    final locale = getIt<AppSettings>().localeListenable.value;
    final tag = locale.scriptCode != null && locale.scriptCode!.isNotEmpty
        ? '${locale.languageCode}_${locale.scriptCode}'
        : locale.languageCode;
    for (final o in next.owners) {
      if (_localeSynced.contains(o.linkId)) continue;
      _localeSynced.add(o.linkId);
      try {
        await service.updatePreferences(o.linkId, locale: tag);
      } on RingFamilyException catch (e) {
        _localeSynced.remove(o.linkId);
        debugPrint('RingAlert: sync locale failed: $e');
      }
    }
  }

  /// 登出 / 切换账号时清空（轮询继续，下一次会按新账号拉取）。
  void reset() {
    status = RingAlertStatus.empty;
    _localeSynced.clear();
    notifyListeners();
  }
}
