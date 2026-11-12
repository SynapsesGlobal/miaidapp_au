import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:miaid/api_utils/api_provider.dart';
import 'package:miaid/services/smart_ring_models.dart';
import 'package:miaid/services/smart_ring_service.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// 分享戒指数据失败；[message] 来自后端（可能为空，调用方给默认文案）。
class CallRingShareException implements Exception {
  const CallRingShareException(this.message);

  final String message;

  @override
  String toString() => 'CallRingShareException: $message';
}

/// 一条分享到通话上的戒指快照（后端 `call_ring_snapshots` 记录）。
/// [payload] 是患者端 [CallRingShareService.buildPayload] 生成的 JSON，医生端据此渲染。
class CallRingSnapshotRecord {
  const CallRingSnapshotRecord({
    required this.id,
    required this.callId,
    required this.payload,
    this.deviceName,
    this.deviceModel,
    this.firmware,
    this.capturedAt,
    this.createdAt,
  });

  factory CallRingSnapshotRecord.fromJson(Map<String, dynamic> json) {
    final payload = json['payload'];
    return CallRingSnapshotRecord(
      id: (json['id'] as num?)?.toInt() ?? 0,
      callId: (json['call_id'] as num?)?.toInt() ?? 0,
      payload: payload is Map ? payload.cast<String, dynamic>() : const <String, dynamic>{},
      deviceName: json['device_name'] as String?,
      deviceModel: json['device_model'] as String?,
      firmware: json['firmware'] as String?,
      capturedAt: _parseTime(json['captured_at']),
      createdAt: _parseTime(json['created_at']),
    );
  }

  final int id;
  final int callId;
  final Map<String, dynamic> payload;
  final String? deviceName;
  final String? deviceModel;
  final String? firmware;
  final DateTime? capturedAt;
  final DateTime? createdAt;

  Map<String, dynamic>? _map(Object? v) => v is Map ? v.cast<String, dynamic>() : null;

  Map<String, dynamic> get device => _map(payload['device']) ?? const <String, dynamic>{};
  Map<String, dynamic> get metrics => _map(payload['metrics']) ?? const <String, dynamic>{};
  Map<String, dynamic>? get sleep => _map(payload['sleep']);
  Map<String, dynamic>? get steps => _map(payload['steps']);

  /// 患者给戒指起的昵称，没有则是蓝牙名。
  String get displayName {
    final nickname = device['nickname'];
    if (nickname is String && nickname.isNotEmpty) return nickname;
    if (deviceName != null && deviceName!.isNotEmpty) return deviceName!;
    final name = device['name'];
    return name is String && name.isNotEmpty ? name : 'RWFIT Ring';
  }

  int? get battery => (device['battery'] as num?)?.toInt();
  DateTime? get lastSyncAt => _parseTime(payload['last_sync_at']);

  /// 单值指标（心率、血氧等）；血压用 [bloodPressure]。
  SharedMetric? metric(String key) {
    final m = _map(metrics[key]);
    final value = m?['value'];
    if (m == null || value is! num) return null;
    return SharedMetric(value: value.toDouble(), unit: m['unit'] as String? ?? '', time: _parseTime(m['time']));
  }

  SharedBloodPressure? get bloodPressure {
    final m = _map(metrics['blood_pressure']);
    final sys = m?['systolic'];
    final dia = m?['diastolic'];
    if (m == null || sys is! num || dia is! num) return null;
    return SharedBloodPressure(systolic: sys.toInt(), diastolic: dia.toInt(), time: _parseTime(m['time']));
  }

  static DateTime? _parseTime(Object? v) => v is String ? DateTime.tryParse(v)?.toLocal() : null;
}

class SharedMetric {
  const SharedMetric({required this.value, required this.unit, this.time});

  final double value;
  final String unit;
  final DateTime? time;
}

class SharedBloodPressure {
  const SharedBloodPressure({required this.systolic, required this.diastolic, this.time});

  final int systolic;
  final int diastolic;
  final DateTime? time;

  String get text => '$systolic/$diastolic';
}

/// 视频通话中把智能戒指的最近数据分享给医生：把 [SmartRingService.snapshot] 序列化后
/// POST 到 portal 的 `/calls/{id}/ring-snapshot`，挂在本次通话上，医生端再按通话读取。
///
/// 接口不在 swagger 里，按项目惯例直接用 http 调用，不改生成的客户端。
class CallRingShareService {
  CallRingShareService(this.api);

  final ApiProvider api;

  /// 患者端：上传当前快照；成功返回后端生成的快照 id。
  Future<int?> share({required int callId, required SmartRingService ring}) async {
    final payload = buildPayload(ring, appVersion: await _appVersion());
    final firmware = ring.firmware;
    final body = <String, dynamic>{
      'payload': payload,
      'captured_at': payload['captured_at'],
      'device_name': ring.displayName,
      if (firmware != null && firmware.deviceClazz.isNotEmpty) 'device_model': firmware.deviceClazz,
      if (firmware != null && firmware.deviceNo.isNotEmpty) 'firmware': firmware.deviceNo,
    };

    final http.Response response;
    try {
      response = await http.post(_uri(callId), headers: _headers(), body: jsonEncode(body));
    } catch (e) {
      debugPrint('SmartRing: share to doctor failed: $e');
      throw const CallRingShareException('');
    }

    final json = _decode(response);
    if (response.statusCode == 200 && json['result'] == true) {
      final data = json['payload'];
      return data is Map ? (data['id'] as num?)?.toInt() : null;
    }
    debugPrint('SmartRing: share to doctor rejected ${response.statusCode}: ${response.body}');
    throw CallRingShareException(json['message'] as String? ?? '');
  }

  /// 医生端：取本次通话最新一条快照；传 [since] 只要比它新的，没有则返回 null（后端 204）。
  Future<CallRingSnapshotRecord?> fetchLatest({required int callId, int? since}) async {
    final uri = since != null && since > 0
        ? _uri(callId).replace(queryParameters: {'since': '$since'})
        : _uri(callId);
    final http.Response response;
    try {
      response = await http.get(uri, headers: _headers());
    } catch (e) {
      debugPrint('SmartRing: fetch shared snapshot failed: $e');
      throw const CallRingShareException('');
    }
    if (response.statusCode == 204) return null;
    final json = _decode(response);
    if (response.statusCode == 200 && json['result'] == true) {
      final data = json['payload'];
      return data is Map ? CallRingSnapshotRecord.fromJson(data.cast<String, dynamic>()) : null;
    }
    debugPrint('SmartRing: fetch shared snapshot rejected ${response.statusCode}: ${response.body}');
    throw CallRingShareException(json['message'] as String? ?? '');
  }

  Uri _uri(int callId) => Uri.parse('${api.apiSettings.endpoint}/calls/$callId/ring-snapshot');

  Map<String, String> _headers() => {
        'x-api-key': api.apiSettings.apiKey,
        'x-access-token': api.userProvider.user?.accessToken ?? '',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };

  static Map<String, dynamic> _decode(http.Response response) {
    try {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  /// 组装发给后端的快照 JSON（见 docs/smart-ring-share.md 4.1）。
  /// 没有数据的指标直接省略；时间统一为 UTC ISO 8601。家人共享上传最新快照（[RingFamilyService]）也用它。
  static Map<String, dynamic> buildPayload(SmartRingService ring, {String? appVersion}) {
    final snap = ring.snapshot;
    final firmware = ring.firmware;

    Map<String, dynamic>? metric(RingMetric? m, String unit) => m == null
        ? null
        : {
            'value': m.value,
            'unit': unit,
            'time': _iso(m.time),
            'realtime': m.realtime,
          };

    final metrics = <String, dynamic>{
      'heart_rate': metric(snap.heartRate, 'bpm'),
      'blood_oxygen': metric(snap.bloodOxygen, '%'),
      'temperature': metric(snap.temperature, '°C'),
      'hrv': metric(snap.hrv, 'ms'),
      'stress': metric(snap.pressure, ''),
      'blood_pressure': snap.bloodPressure == null
          ? null
          : {
              'systolic': snap.bloodPressure!.systolic,
              'diastolic': snap.bloodPressure!.diastolic,
              'unit': 'mmHg',
              'time': _iso(snap.bloodPressure!.time),
              'realtime': snap.bloodPressure!.realtime,
            },
      'blood_sugar': metric(snap.bloodSugar, 'mmol/L'),
    }..removeWhere((_, v) => v == null);

    final sleep = snap.sleep;
    final steps = snap.steps;
    return <String, dynamic>{
      'device': <String, dynamic>{
        'name': ring.boundDevice?.name ?? '',
        if (ring.nickname != null) 'nickname': ring.nickname,
        if (firmware != null && firmware.deviceClazz.isNotEmpty) 'model': firmware.deviceClazz,
        if (firmware != null && firmware.deviceNo.isNotEmpty) 'firmware': firmware.deviceNo,
        if (ring.battery != null) 'battery': ring.battery,
      },
      'captured_at': _iso(DateTime.now()),
      'metrics': metrics,
      if (sleep != null)
        'sleep': <String, dynamic>{
          'date': _date(sleep.date),
          'total_minutes': sleep.totalMinutes,
          'deep': sleep.deepMinutes,
          'light': sleep.lightMinutes,
          'rem': sleep.remMinutes,
          'awake': sleep.awakeMinutes,
          if (sleep.beginTime != null) 'begin': _iso(sleep.beginTime!),
          if (sleep.endTime != null) 'end': _iso(sleep.endTime!),
        },
      if (steps != null)
        'steps': <String, dynamic>{
          'date': _date(steps.date),
          'steps': steps.steps,
          'distance_m': steps.distanceMeters,
          'calories': steps.calories,
        },
      if (snap.lastSyncAt != null) 'last_sync_at': _iso(snap.lastSyncAt!),
      if (appVersion != null) 'app_version': appVersion,
    };
  }

  static String _iso(DateTime t) => t.toUtc().toIso8601String();

  static String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static Future<String?> _appVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return '${info.version}+${info.buildNumber}';
    } catch (_) {
      return null;
    }
  }
}

/// 医生端：通话期间轮询本次通话的戒指快照，有新数据时通知界面（红点、面板刷新）。
///
/// 通话 id 在加入频道后才有，所以用 [callIdProvider] 每次取；取不到就跳过本轮。
class CallRingShareReceiver extends ChangeNotifier {
  CallRingShareReceiver(this._service);

  static const Duration pollInterval = Duration(seconds: 15);

  final CallRingShareService _service;

  Timer? _timer;
  int? Function()? _callIdProvider;
  bool _fetching = false;
  bool _disposed = false;

  CallRingSnapshotRecord? latest;

  /// 收到新快照后、医生还没打开面板看过。
  bool hasUnread = false;

  bool get active => _timer != null;

  void start(int? Function() callIdProvider) {
    if (_timer != null) return;
    _callIdProvider = callIdProvider;
    _timer = Timer.periodic(pollInterval, (_) => unawaited(refresh()));
    unawaited(refresh());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// 立刻拉一次（面板里的刷新按钮也用它）。
  Future<void> refresh() async {
    final callId = _callIdProvider?.call();
    if (callId == null || _fetching || _disposed) return;
    _fetching = true;
    try {
      final record = await _service.fetchLatest(callId: callId, since: latest?.id);
      if (_disposed || record == null) return;
      // 通话切换时 since 失效，后端可能返回旧 id；只接受更新的
      if (latest != null && record.id <= latest!.id && record.callId == latest!.callId) return;
      latest = record;
      hasUnread = true;
      notifyListeners();
    } catch (e) {
      debugPrint('SmartRing: poll shared snapshot failed: $e');
    } finally {
      _fetching = false;
    }
  }

  void markRead() {
    if (!hasUnread) return;
    hasUnread = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    stop();
    super.dispose();
  }
}
