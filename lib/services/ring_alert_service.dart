import 'package:miaid/services/ring_family_service.dart';

/// 智能戒指异常提醒（第 3 步）的接口与模型。接口在客户端后端 `/ring/alert*`，
/// 复用 [RingFamilyService] 的鉴权请求。

/// 戴戒指的人的提醒规则。
class RingAlertSettings {
  const RingAlertSettings({
    required this.enabled,
    required this.thresholds,
    required this.defaults,
    this.updatedAt,
    this.updatedBy,
    this.updatedBySelf = true,
  });

  factory RingAlertSettings.fromJson(Map<String, dynamic> json) {
    Map<String, RingAlertThreshold> parse(Object? raw) {
      if (raw is! Map) return const {};
      return raw.map((k, v) => MapEntry('$k', RingAlertThreshold.fromJson(v is Map ? v.cast<String, dynamic>() : const {})));
    }

    return RingAlertSettings(
      enabled: json['enabled'] != false,
      thresholds: parse(json['thresholds']),
      defaults: parse(json['defaults']),
      updatedAt: _time(json['updated_at']),
      updatedBy: json['updated_by'] as String?,
      updatedBySelf: json['updated_by_self'] != false,
    );
  }

  final bool enabled;

  /// 生效中的阈值（默认值与自定义合并后）。
  final Map<String, RingAlertThreshold> thresholds;
  final Map<String, RingAlertThreshold> defaults;

  /// 最后一次修改：时间、修改人姓名、是否是戴戒指的人自己改的。
  final DateTime? updatedAt;
  final String? updatedBy;
  final bool updatedBySelf;

  /// 参与判定的指标：只有心率、血氧（与后端一致）。
  static const types = ['heart_rate', 'blood_oxygen'];
}

class RingAlertThreshold {
  const RingAlertThreshold({this.low, this.high});

  factory RingAlertThreshold.fromJson(Map<String, dynamic> json) {
    double? d(Object? v) => v is num ? v.toDouble() : null;
    return RingAlertThreshold(
      low: d(json['low']),
      high: d(json['high']),
    );
  }

  final double? low;
  final double? high;

  Map<String, dynamic> toJson() => {
        'low': low,
        'high': high,
      };
}

/// 一条提醒。
class RingAlertItem {
  const RingAlertItem({
    required this.id,
    required this.ownerUserId,
    required this.type,
    this.linkId,
    this.ownerAlias,
    this.direction,
    this.value,
    this.value2,
    this.valueText = '',
    this.unit = '',
    this.measuredAt,
    this.createdAt,
    this.pushedAt,
    this.seen,
  });

  factory RingAlertItem.fromJson(Map<String, dynamic> json) {
    return RingAlertItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      ownerUserId: (json['owner_user_id'] as num?)?.toInt() ?? 0,
      linkId: (json['link_id'] as num?)?.toInt(),
      ownerAlias: json['owner_alias'] as String?,
      type: json['type'] as String? ?? '',
      direction: json['direction'] as String?,
      value: (json['value'] as num?)?.toDouble(),
      value2: (json['value2'] as num?)?.toDouble(),
      valueText: json['value_text'] as String? ?? '',
      unit: json['unit'] as String? ?? '',
      measuredAt: _time(json['measured_at']),
      createdAt: _time(json['created_at']),
      pushedAt: _time(json['pushed_at']),
      seen: json['seen'] is bool ? json['seen'] as bool : null,
    );
  }


  final int id;
  final int ownerUserId;
  final int? linkId;
  final String? ownerAlias;
  final String type;
  final String? direction;

  final double? value;
  final double? value2;
  final String valueText;
  final String unit;
  final DateTime? measuredAt;
  final DateTime? createdAt;
  final DateTime? pushedAt;
  final bool? seen;

  bool get isHigh => direction == 'high';

  RingAlertItem copyWith({bool? seen}) {
    return RingAlertItem(
      id: id,
      ownerUserId: ownerUserId,
      linkId: linkId,
      ownerAlias: ownerAlias,
      type: type,
      direction: direction,
      value: value,
      value2: value2,
      valueText: valueText,
      unit: unit,
      measuredAt: measuredAt,
      createdAt: createdAt,
      pushedAt: pushedAt,
      seen: seen ?? this.seen,
    );
  }
}

/// 家人视角：某位长辈的提醒概况。
class RingAlertOwnerStatus {
  const RingAlertOwnerStatus({
    required this.linkId,
    required this.ownerUserId,
    required this.status,
    required this.unreadCount,
    required this.muted,
    this.alias,
    this.name,
    this.latestAlert,
  });

  factory RingAlertOwnerStatus.fromJson(Map<String, dynamic> json) {
    final latest = json['latest_alert'];
    return RingAlertOwnerStatus(
      linkId: (json['link_id'] as num?)?.toInt() ?? 0,
      ownerUserId: (json['owner_user_id'] as num?)?.toInt() ?? 0,
      alias: json['alias'] as String?,
      name: json['name'] as String?,
      status: json['status'] as String? ?? 'normal',
      unreadCount: (json['unread_count'] as num?)?.toInt() ?? 0,
      muted: json['muted'] == true,
      latestAlert: latest is Map ? RingAlertItem.fromJson(latest.cast<String, dynamic>()) : null,
    );
  }

  final int linkId;
  final int ownerUserId;
  final String? alias;
  final String? name;

  /// normal / abnormal
  final String status;
  final int unreadCount;
  final bool muted;
  final RingAlertItem? latestAlert;

  String get displayName => alias != null && alias!.isNotEmpty ? alias! : (name ?? '');
  bool get isNormal => status == 'normal';
}

class RingAlertStatus {
  const RingAlertStatus({required this.unreadCount, required this.owners});

  factory RingAlertStatus.fromJson(Map<String, dynamic> json) {
    final owners = json['owners'];
    return RingAlertStatus(
      unreadCount: (json['unread_count'] as num?)?.toInt() ?? 0,
      owners: owners is List
          ? owners.whereType<Map<dynamic, dynamic>>().map((e) => RingAlertOwnerStatus.fromJson(e.cast<String, dynamic>())).toList()
          : const [],
    );
  }

  static const empty = RingAlertStatus(unreadCount: 0, owners: []);

  final int unreadCount;
  final List<RingAlertOwnerStatus> owners;

  /// 首页横幅 / 弹框：所有长辈中还没看过的最新提醒（按时间倒序）。看过即不再显示，不需要手动处理。
  List<RingAlertItem> get unseenAlerts {
    final list = <RingAlertItem>[];
    for (final o in owners) {
      final a = o.latestAlert;
      if (a != null && a.seen == false) list.add(a);
    }
    list.sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
    return list;
  }
}

class RingAlertService {
  RingAlertService(this.family);

  final RingFamilyService family;

  /// 自己的规则；传 [linkId] 时是某位长辈的规则（家人代为查看 / 修改，同一份设置）。
  Future<RingAlertSettings> fetchSettings({int? linkId}) async {
    return RingAlertSettings.fromJson(await family.requestPayload('GET', _settingsPath(linkId)));
  }

  /// 只传需要改的字段；阈值传 `{type: {field: value}}`，value 为 null 表示恢复默认。
  Future<RingAlertSettings> updateSettings(Map<String, dynamic> changes, {int? linkId}) async {
    return RingAlertSettings.fromJson(await family.requestPayload('PUT', _settingsPath(linkId), body: changes));
  }

  static String _settingsPath(int? linkId) => linkId == null ? '/ring/alert-settings' : '/ring/family/$linkId/alert-settings';

  Future<List<RingAlertItem>> fetchAlerts({int? linkId, int? beforeId, int limit = 50}) async {
    final query = <String, String>{
      if (linkId != null) 'link_id': '$linkId',
      if (beforeId != null) 'before_id': '$beforeId',
      'limit': '$limit',
    };
    final payload = await family.requestPayload('GET', '/ring/alerts?${Uri(queryParameters: query).query}');
    return _list(payload['alerts']);
  }

  /// 自己（戴戒指的人）的提醒历史。
  Future<List<RingAlertItem>> fetchMine({int? beforeId, int limit = 50}) async {
    final query = <String, String>{if (beforeId != null) 'before_id': '$beforeId', 'limit': '$limit'};
    final payload = await family.requestPayload('GET', '/ring/alerts/mine?${Uri(queryParameters: query).query}');
    return _list(payload['alerts']);
  }

  Future<RingAlertStatus> fetchStatus() async {
    return RingAlertStatus.fromJson(await family.requestPayload('GET', '/ring/alerts/status'));
  }

  Future<void> markSeen({List<int>? ids, int? linkId}) async {
    if ((ids == null || ids.isEmpty) && linkId == null) return;
    await family.requestPayload('POST', '/ring/alerts/seen', body: {
      if (ids != null && ids.isNotEmpty) 'ids': ids,
      if (linkId != null) 'link_id': linkId,
    });
  }

  Future<void> updatePreferences(int linkId, {bool? muted, String? locale}) async {
    await family.requestPayload('PUT', '/ring/family/$linkId/alerts', body: {
      if (muted != null) 'muted': muted,
      if (locale != null) 'locale': locale,
    });
  }

  static List<RingAlertItem> _list(Object? raw) => raw is List
      ? raw.whereType<Map<dynamic, dynamic>>().map((e) => RingAlertItem.fromJson(e.cast<String, dynamic>())).toList()
      : <RingAlertItem>[];
}

DateTime? _time(Object? v) => v is String ? DateTime.tryParse(v)?.toLocal() : null;
