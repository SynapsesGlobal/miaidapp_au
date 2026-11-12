import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:miaid/api_utils/api_provider.dart';
import 'package:miaid/services/call_ring_share_service.dart';
import 'package:miaid/services/smart_ring_models.dart';
import 'package:miaid/services/smart_ring_service.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// 家人共享接口失败；[message] 来自后端（可能为空，调用方给默认文案）。
class RingFamilyException implements Exception {
  const RingFamilyException(this.message);

  final String message;

  @override
  String toString() => 'RingFamilyException: $message';
}

/// 能查看我戒指数据的家人。
class RingFamilyViewer {
  const RingFamilyViewer({required this.linkId, required this.name, this.avatarUrl, this.linkedAt});

  factory RingFamilyViewer.fromJson(Map<String, dynamic> json) {
    return RingFamilyViewer(
      linkId: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      avatarUrl: json['avatar_url'] as String?,
      linkedAt: _parseTime(json['linked_at']),
    );
  }

  final int linkId;
  final String name;
  final String? avatarUrl;
  final DateTime? linkedAt;
}

/// 我关注的家人（戴戒指的人）。
class RingFamilyOwner {
  const RingFamilyOwner({
    required this.linkId,
    required this.name,
    this.alias,
    this.avatarUrl,
    this.phone,
    this.linkedAt,
    this.snapshotAt,
    this.battery,
  });

  factory RingFamilyOwner.fromJson(Map<String, dynamic> json) {
    return RingFamilyOwner(
      linkId: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      alias: json['alias'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      phone: json['phone'] as String?,
      linkedAt: _parseTime(json['linked_at']),
      snapshotAt: _parseTime(json['snapshot_at']),
      battery: (json['battery'] as num?)?.toInt(),
    );
  }

  final int linkId;

  /// 对方账号上的姓名。
  final String name;

  /// 我给对方起的称呼（如「妈妈」）。
  final String? alias;
  final String? avatarUrl;
  final String? phone;
  final DateTime? linkedAt;

  /// 对方最近一次上传戒指数据的时间；没上传过为空。
  final DateTime? snapshotAt;
  final int? battery;

  /// 优先显示称呼。
  String get displayName => alias != null && alias!.isNotEmpty ? alias! : name;
}

class RingFamilySummary {
  const RingFamilySummary({required this.viewers, required this.owners});

  factory RingFamilySummary.fromJson(Map<String, dynamic> json) {
    List<T> list<T>(Object? raw, T Function(Map<String, dynamic>) parse) => raw is List
        ? raw.whereType<Map<dynamic, dynamic>>().map((e) => parse(e.cast<String, dynamic>())).toList()
        : <T>[];
    return RingFamilySummary(
      viewers: list(json['members'], RingFamilyViewer.fromJson),
      owners: list(json['owners'], RingFamilyOwner.fromJson),
    );
  }

  final List<RingFamilyViewer> viewers;
  final List<RingFamilyOwner> owners;
}

/// 走势图上的一个点；[value2] 只有血压有（舒张压）。
class RingTrendPoint {
  const RingTrendPoint({required this.time, required this.value, this.value2, this.realtime = false});

  final DateTime time;
  final double value;
  final double? value2;
  final bool realtime;
}

/// 一项指标在一个时间范围内的读数，按时间升序。
class RingTrend {
  const RingTrend({required this.from, required this.to, required this.points});

  factory RingTrend.fromJson(Map<String, dynamic> json) {
    final raw = json['points'];
    final points = <RingTrendPoint>[];
    if (raw is List) {
      for (final p in raw) {
        if (p is! Map) continue;
        final time = _parseTime(p['t']);
        final value = p['v'];
        final value2 = p['v2'];
        if (time == null || value is! num) continue;
        points.add(RingTrendPoint(
          time: time,
          value: value.toDouble(),
          value2: value2 is num ? value2.toDouble() : null,
          realtime: p['realtime'] == true,
        ));
      }
    }
    final now = DateTime.now();
    return RingTrend(
      from: _parseTime(json['from']) ?? now.subtract(const Duration(hours: 24)),
      to: _parseTime(json['to']) ?? now,
      points: points,
    );
  }

  final DateTime from;
  final DateTime to;
  final List<RingTrendPoint> points;

  bool get isEmpty => points.isEmpty;
}

class RingFamilyInvite {
  const RingFamilyInvite({required this.code, required this.expiresAt});

  final String code;
  final DateTime expiresAt;
}

/// 家人的最新戒指面板数据；[record] 为空表示对方还没上传过。
class RingFamilySnapshot {
  const RingFamilySnapshot({required this.owner, this.record});

  final RingFamilyOwner owner;
  final CallRingSnapshotRecord? record;
}

/// 智能戒指家人共享：邀请码绑定、解绑、上传自己的最新快照、查看家人的最新快照。
///
/// 接口在客户端后端（endpointSub）的 `/ring/...`，不在 swagger 里，按项目惯例直接用 http 调用。
class RingFamilyService {
  RingFamilyService(this.api);

  final ApiProvider api;

  Future<RingFamilySummary> fetch() async {
    final json = await _request('GET', '/ring/family');
    return RingFamilySummary.fromJson(_payload(json));
  }

  /// 生成 6 位邀请码（后端 10 分钟有效，旧码随即作废）。
  Future<RingFamilyInvite> createInvite() async {
    final payload = _payload(await _request('POST', '/ring/family/invite'));
    final code = payload['code'] as String? ?? '';
    final ttl = (payload['ttl_seconds'] as num?)?.toInt() ?? 600;
    if (code.isEmpty) throw const RingFamilyException('');
    // 用后端给的时长在本机计时，避免手机时钟不准导致倒计时出错
    return RingFamilyInvite(code: code, expiresAt: DateTime.now().add(Duration(seconds: ttl)));
  }

  /// 家人输入邀请码绑定，返回绑定到的人。
  Future<RingFamilyOwner> accept(String code, {String? alias}) async {
    final payload = _payload(await _request('POST', '/ring/family/accept', body: {
      'code': code,
      if (alias != null && alias.isNotEmpty) 'alias': alias,
    }));
    final link = payload['link'];
    if (link is! Map) throw const RingFamilyException('');
    return RingFamilyOwner.fromJson(link.cast<String, dynamic>());
  }

  /// 解除绑定（双方都可以），返回最新列表。
  Future<RingFamilySummary> remove(int linkId) async {
    final json = await _request('DELETE', '/ring/family/$linkId');
    return RingFamilySummary.fromJson(_payload(json));
  }

  Future<RingFamilySnapshot> fetchSnapshot(int linkId) async {
    final payload = _payload(await _request('GET', '/ring/family/$linkId/snapshot'));
    final link = payload['link'];
    final snapshot = payload['snapshot'];
    if (link is! Map) throw const RingFamilyException('');
    return RingFamilySnapshot(
      owner: RingFamilyOwner.fromJson(link.cast<String, dynamic>()),
      record: snapshot is Map ? CallRingSnapshotRecord.fromJson(snapshot.cast<String, dynamic>()) : null,
    );
  }

  /// 上传自己戒指的最新快照，覆盖后端上一份。快照 JSON 与通话分享用同一结构。
  Future<void> uploadSnapshot(SmartRingService ring) async {
    final payload = CallRingShareService.buildPayload(ring, appVersion: await _appVersion());
    final firmware = ring.firmware;
    await _request('POST', '/ring/snapshot', body: {
      'payload': payload,
      'captured_at': payload['captured_at'],
      'device_name': ring.displayName,
      if (firmware != null && firmware.deviceClazz.isNotEmpty) 'device_model': firmware.deviceClazz,
      if (firmware != null && firmware.deviceNo.isNotEmpty) 'firmware': firmware.deviceNo,
    });
  }

  /// 批量上报历史读数（后端单次最多 500 条，按指标 + 测量时间去重）。
  Future<void> uploadReadings(List<RingReading> readings) async {
    await _request('POST', '/ring/readings', body: {
      'readings': readings.map((r) => r.toJson()).toList(),
    });
  }

  /// 某项指标最近的走势。[linkId] 为空查自己的，否则查该绑定对应的家人。
  Future<RingTrend> fetchTrend({required String type, required String range, int? linkId}) async {
    final path = linkId == null ? '/ring/readings' : '/ring/family/$linkId/readings';
    final json = await _request('GET', '$path?type=$type&range=$range');
    return RingTrend.fromJson(_payload(json));
  }

  Map<String, dynamic> _payload(Map<String, dynamic> json) {
    final payload = json['payload'];
    return payload is Map ? payload.cast<String, dynamic>() : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> _request(String method, String path, {Map<String, dynamic>? body}) async {
    final uri = Uri.parse('${api.apiSettings.endpointSub}$path');
    final headers = {
      'x-api-key': api.apiSettings.apiKeySub,
      'x-access-token': api.userProvider.user?.accessToken ?? '',
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };

    final http.Response response;
    try {
      final request = http.Request(method, uri)..headers.addAll(headers);
      if (body != null) request.body = jsonEncode(body);
      response = await http.Response.fromStream(await request.send().timeout(const Duration(seconds: 20)));
    } catch (e) {
      debugPrint('RingFamily: $method $path failed: $e');
      throw const RingFamilyException('');
    }

    Map<String, dynamic> json;
    try {
      json = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      json = <String, dynamic>{};
    }
    if (response.statusCode == 200 && json['result'] == true) return json;
    debugPrint('RingFamily: $method $path rejected ${response.statusCode}: ${response.body}');
    throw RingFamilyException(json['message'] as String? ?? '');
  }

  static String? _cachedAppVersion;

  static Future<String?> _appVersion() async {
    if (_cachedAppVersion != null) return _cachedAppVersion;
    try {
      final info = await PackageInfo.fromPlatform();
      return _cachedAppVersion = '${info.version}+${info.buildNumber}';
    } catch (_) {
      return null;
    }
  }
}

DateTime? _parseTime(Object? v) => v is String ? DateTime.tryParse(v)?.toLocal() : null;
