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
/// 新提醒弹框都监听它。弹框同一条只弹一次（已弹过的 id 记在本机）。
/// 只对已登录的客户账号工作。轮询是兜底，推送才是主通道，所以频率压得很低：
/// 关注了长辈每 5 分钟一次，没关注任何人每 30 分钟一次；回到前台、收到推送、进家人共享页时立即拉一次；
/// 退到后台停止。这样 1 万个前台用户大约每秒 30 个请求，而不是按 60 秒轮询的 170 个。
class RingAlertCenter extends ChangeNotifier {
  RingAlertCenter._();

  static final RingAlertCenter instance = RingAlertCenter._();

  /// 关注了长辈时的轮询间隔。
  static const pollInterval = Duration(minutes: 5);

  /// 没关注任何人时的轮询间隔（只是为了发现刚绑定的情况，进家人共享页也会立即刷新）。
  static const idleInterval = Duration(minutes: 30);
  static const _shownKey = 'smart-ring-alert-popup-shown';

  RingAlertService? _service;
  Timer? _timer;
  bool _started = false;
  bool _fetching = false;
  bool _inBackground = false;

  RingAlertStatus status = RingAlertStatus.empty;
  DateTime? lastFetchedAt;

  /// 已经弹过窗的提醒 id（所有级别，同一条只弹一次）。
  Set<int> _shownCritical = {};
  bool _shownLoaded = false;

  /// 本次会话已把 App 语言同步到后端的绑定。
  final Set<int> _localeSynced = {};

  /// 由 main 注入：弹出「新提醒」弹框（传入所有还没看过、且没弹过的提醒，最严重的排前面）。
  Future<void> Function(List<RingAlertItem> alerts)? alertHandler;
  bool _popupShowing = false;

  RingAlertService get service => _service ??= RingAlertService(RingFamilyService(getIt<ApiProvider>()));

  int get unreadCount => status.unreadCount;

  RingAlertOwnerStatus? ownerStatus(int linkId) {
    for (final o in status.owners) {
      if (o.linkId == linkId) return o;
    }
    return null;
  }

  void start() {
    if (_started) return;
    _started = true;
    unawaited(refresh());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _started = false;
  }

  /// 回到前台：立即拉一次并恢复轮询。
  void onAppResumed() {
    _inBackground = false;
    unawaited(refresh());
  }

  /// 退到后台：停止轮询，省流量也不打扰后端。
  void onAppPaused() {
    _inBackground = true;
    _timer?.cancel();
    _timer = null;
  }

  /// 按当前状态安排下一次轮询：有关注的长辈 5 分钟，没有 30 分钟；后台不排。
  void _scheduleNext() {
    _timer?.cancel();
    _timer = null;
    if (!_started || _inBackground) return;
    final interval = status.owners.isEmpty ? idleInterval : pollInterval;
    _timer = Timer(interval, () => unawaited(refresh()));
  }

  /// 收到 ring_alert 推送时调用。
  void onPush() => unawaited(refresh());

  bool get _eligible {
    final user = getIt<UserProvider>().user;
    return user != null && user.customer != null;
  }

  Future<void> refresh() async {
    if (_fetching) return;
    if (!_eligible) {
      _scheduleNext();
      return;
    }
    _fetching = true;
    try {
      final next = await service.fetchStatus();
      status = next;
      lastFetchedAt = DateTime.now();
      notifyListeners();
      unawaited(_syncLocale(next));
      await _maybeShowPopup(next);
    } on RingFamilyException catch (e) {
      debugPrint('RingAlert: status failed: $e');
    } finally {
      _fetching = false;
      _scheduleNext();
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

  Future<void> _maybeShowPopup(RingAlertStatus next) async {
    final handler = alertHandler;
    if (handler == null || _popupShowing) return;
    await _loadShown();
    final fresh = next.unseenAlerts.where((a) => !_shownCritical.contains(a.id)).toList();
    if (fresh.isEmpty) return;
    _shownCritical.addAll(fresh.map((a) => a.id));
    unawaited(_saveShown());
    _popupShowing = true;
    try {
      await handler(fresh);
    } catch (e) {
      debugPrint('RingAlert: popup failed: $e');
    } finally {
      _popupShowing = false;
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
