import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:miaid/api_utils/api_provider.dart';
import 'package:miaid/services/call_ring_share_service.dart';
import 'package:miaid/services/ring_family_service.dart';
import 'package:miaid/services/smart_ring_models.dart';
import 'package:miaid/services/smart_ring_service.dart';
import 'package:miaid/utils/configure_dependencies.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 戒指数据一有更新就上传到后端：最新快照（家人看面板用）+ 逐条历史读数（走势图用）。
///
/// 历史读数来自 [SmartRingService.onReadings]，先进本机持久化的待上传队列再分批上报，
/// 断网、App 被杀都不丢；同步明细每次可能带回已经报过的旧数据，用每个指标的「已入队最新时间」
/// 过滤掉，手动测量的读数时间不连续，不走这个过滤，只按键去重。
///
/// 监听 [SmartRingService]：它在连接状态、测量进度变化时也会通知，所以这里对快照内容做签名，
/// 只有读数 / 电量真的变了才上传；实时测量期间读数连续变化，用 [_delay] 合并成一次。
/// 上传失败保留「待上传」状态，下次数据变化或回到前台时重试。
/// 仅客户账号上传（医生 / 翻译不戴戒指），未登录或未绑定戒指时什么都不做。
class RingCloudSync {
  RingCloudSync._();

  static final RingCloudSync instance = RingCloudSync._();

  /// 数据变化后等多久再上传，用来合并连续的变化。
  static const _delay = Duration(seconds: 5);

  final SmartRingService _ring = SmartRingService.instance;

  bool _started = false;
  Timer? _timer;
  bool _uploading = false;

  /// 最近一次成功上传的内容签名（含用户 id，换账号后会重新上传）。
  String? _uploadedSignature;

  void start() {
    if (_started) return;
    _started = true;
    _ring.addListener(_onRingChanged);
    _ring.onReadings = _onReadings;
    _onRingChanged();
    unawaited(_loadQueue().then((_) => _scheduleReadings()));
  }

  /// 回到前台时调用：之前失败过的在这里补传。
  void onAppResumed() {
    _onRingChanged();
    _scheduleReadings();
  }

  // ---------------- 历史读数 ----------------

  static const _queueKey = 'smart-ring-readings-queue';
  static const _watermarkKey = 'smart-ring-readings-watermark';

  /// [_watermark] 里记录「某天已入队的步数」的键前缀，后面跟当天的时间戳（秒）。
  static const _stepsSentPrefix = 'steps@';

  /// 后端单次上限。
  static const _batchSize = 500;

  /// 长期传不上去时队列的上限，超出丢最旧的。
  static const _maxQueue = 5000;

  /// 待上传的读数，键见 [RingReading.key]。
  final Map<String, RingReading> _queue = <String, RingReading>{};

  /// 每个指标已入队的同步读数的最新时间（秒），用来跳过同步重复带回的旧明细。
  final Map<String, int> _watermark = <String, int>{};

  bool _queueLoaded = false;
  Timer? _readingsTimer;
  bool _uploadingReadings = false;

  void _onReadings(List<RingReading> readings) {
    var added = false;
    for (final r in readings) {
      final sec = r.time.millisecondsSinceEpoch ~/ 1000;
      if (r.type == SmartRingSyncParser.stepsType) {
        // 步数是当天累计值，同一天会反复变大：数值变了就重新入队覆盖，没变就跳过
        final sentKey = '$_stepsSentPrefix$sec';
        final value = r.value.round();
        if (_watermark[sentKey] == value) continue;
        _watermark[sentKey] = value;
        _queue[r.key] = r;
        added = true;
        continue;
      }
      if (!r.realtime) {
        if (sec <= (_watermark[r.type] ?? 0)) continue;
        _watermark[r.type] = sec;
      }
      if (_queue.containsKey(r.key)) continue;
      _queue[r.key] = r;
      added = true;
    }
    if (!added) return;
    // 「某天已入队的步数」只需要留最近十来天的
    final cutoff = DateTime.now().subtract(const Duration(days: 10)).millisecondsSinceEpoch ~/ 1000;
    _watermark.removeWhere((key, _) =>
        key.startsWith(_stepsSentPrefix) && (int.tryParse(key.substring(_stepsSentPrefix.length)) ?? 0) < cutoff);
    while (_queue.length > _maxQueue) {
      _queue.remove(_queue.keys.first);
    }
    unawaited(_saveQueue());
    _scheduleReadings();
  }

  void _scheduleReadings() {
    if (_queue.isEmpty || _readingsTimer != null || _uploadingReadings) return;
    _readingsTimer = Timer(_delay, () {
      _readingsTimer = null;
      unawaited(_uploadReadings());
    });
  }

  Future<void> _uploadReadings() async {
    final api = _api();
    if (api == null || !_canUpload(api) || _uploadingReadings || _queue.isEmpty) return;
    _uploadingReadings = true;
    var ok = true;
    try {
      while (_queue.isNotEmpty) {
        final batch = _queue.values.take(_batchSize).toList();
        await RingFamilyService(api).uploadReadings(batch);
        for (final r in batch) {
          _queue.remove(r.key);
        }
        debugPrint('SmartRing: ${batch.length} readings uploaded, ${_queue.length} left');
      }
    } catch (e) {
      ok = false;
      debugPrint('SmartRing: readings upload failed: $e');
    } finally {
      _uploadingReadings = false;
      unawaited(_saveQueue());
    }
    // 上传期间又来了新读数：成功则继续；失败等下次新读数 / 回前台再试
    if (ok) _scheduleReadings();
  }

  bool _canUpload(ApiProvider api) =>
      api.userProvider.user != null && !api.userProvider.isDoctor && !api.userProvider.isTranslator;

  Future<void> _loadQueue() async {
    if (_queueLoaded) return;
    _queueLoaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawQueue = prefs.getString(_queueKey);
      if (rawQueue != null && rawQueue.isNotEmpty) {
        final decoded = jsonDecode(rawQueue);
        if (decoded is List) {
          for (final item in decoded) {
            final r = RingReading.fromJson(item);
            // 启动后、加载完成前已经入队的同键读数保留新的
            if (r != null) _queue.putIfAbsent(r.key, () => r);
          }
        }
      }
      final rawMark = prefs.getString(_watermarkKey);
      if (rawMark != null && rawMark.isNotEmpty) {
        final decoded = jsonDecode(rawMark);
        if (decoded is Map) {
          decoded.forEach((key, value) {
            if (key is String && value is num && value.toInt() > (_watermark[key] ?? 0)) {
              _watermark[key] = value.toInt();
            }
          });
        }
      }
    } catch (e) {
      debugPrint('SmartRing: load readings queue failed: $e');
    }
  }

  Future<void> _saveQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_queueKey, jsonEncode(_queue.values.map((r) => r.toJson()).toList()));
      await prefs.setString(_watermarkKey, jsonEncode(_watermark));
    } catch (e) {
      debugPrint('SmartRing: save readings queue failed: $e');
    }
  }

  // ---------------- 最新快照 ----------------

  void _onRingChanged() {
    if (_timer != null || _uploading) return;
    if (_currentSignature() == _uploadedSignature) return;
    _timer = Timer(_delay, () {
      _timer = null;
      unawaited(_upload());
    });
  }

  /// 没有可上传的内容（未登录、非客户、未绑定、还没有任何读数）时返回已上传的签名，表示「无需上传」。
  String? _currentSignature() {
    final api = _api();
    final user = api?.userProvider.user;
    if (api == null || user == null || api.userProvider.isDoctor || api.userProvider.isTranslator) {
      return _uploadedSignature;
    }
    if (!_ring.isBound) return _uploadedSignature;
    final payload = CallRingShareService.buildPayload(_ring)..remove('captured_at');
    final metrics = payload['metrics'];
    final hasData = (metrics is Map && metrics.isNotEmpty) || payload['sleep'] != null || payload['steps'] != null;
    if (!hasData) return _uploadedSignature;
    return '${user.accessToken.hashCode}|${jsonEncode(payload)}';
  }

  Future<void> _upload() async {
    final api = _api();
    final signature = _currentSignature();
    if (api == null || signature == _uploadedSignature || _uploading) return;
    _uploading = true;
    try {
      await RingFamilyService(api).uploadSnapshot(_ring);
      _uploadedSignature = signature;
      debugPrint('SmartRing: snapshot uploaded');
    } catch (e) {
      debugPrint('SmartRing: snapshot upload failed: $e');
    } finally {
      _uploading = false;
    }
    // 上传期间数据又变了：成功则再排一次；失败不立刻重试，等下次变化 / 回前台
    if (_uploadedSignature == signature) _onRingChanged();
  }

  ApiProvider? _api() {
    try {
      return getIt<ApiProvider>();
    } catch (_) {
      return null;
    }
  }
}
