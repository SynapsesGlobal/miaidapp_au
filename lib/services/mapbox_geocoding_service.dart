import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// Mapbox 地址联想 / 反查结果。
class MapboxPlace {
  const MapboxPlace({
    required this.placeName,
    required this.latitude,
    required this.longitude,
  });

  final String placeName;
  final double latitude;
  final double longitude;
}

/// 一次联想请求的结果：[failed] 为 true 表示请求本身没成功（无 token、超时、
/// 网络异常、非 200），和"查到了但没有匹配"区分开，界面据此提示重试而不是"没找到"。
class MapboxSearchResult {
  const MapboxSearchResult._(this.places, this.failed);

  const MapboxSearchResult.success(List<MapboxPlace> places) : this._(places, false);

  const MapboxSearchResult.failure() : this._(const [], true);

  final List<MapboxPlace> places;
  final bool failed;

  bool get isEmpty => places.isEmpty;
}

/// 收货地址自动补全与反查：调 Mapbox Geocoding v5。
///
/// 复用首页坐标转城市所用的 MAPBOX_ACCESS_TOKEN（.env），不引入额外插件。
/// 只做网络请求与解析，防抖和过期结果丢弃由调用方（购物车页）处理。
class MapboxGeocodingService {
  MapboxGeocodingService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _timeout = Duration(seconds: 8);

  /// 联想返回的要素类型：除门牌地址、POI、城市外，也接受郊区 / 街区 / 邮编，
  /// 新小区或拼写不全时用户至少能选到一个粗粒度位置，再用地图或补充栏细化。
  static const _searchTypes = 'address,poi,place,locality,neighborhood,postcode';

  /// 正向联想（autocomplete=true）。
  ///
  /// [proximityLatitude] / [proximityLongitude] 传药店坐标，让结果优先靠近药店；
  /// [countryCode] 传药店所在国家（ISO 3166-1 alpha-2），把结果限定在该国；
  /// [language] 传 App 当前语言标签（如 zh-Hant），结果名称尽量用该语言。
  /// 少于 3 个字符直接返回空的成功结果，不发请求。
  Future<MapboxSearchResult> search(
    String query, {
    double? proximityLatitude,
    double? proximityLongitude,
    String? countryCode,
    String? language,
    int limit = 8,
  }) async {
    final trimmed = query.trim();
    if (trimmed.length < 3) return const MapboxSearchResult.success([]);
    final token = dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? '';
    if (token.isEmpty) {
      debugPrint('[MapboxGeocoding] MAPBOX_ACCESS_TOKEN missing');
      return const MapboxSearchResult.failure();
    }

    final params = <String, String>{
      'access_token': token,
      'autocomplete': 'true',
      'fuzzyMatch': 'true',
      'limit': '$limit',
      'types': _searchTypes,
    };
    if (proximityLatitude != null && proximityLongitude != null) {
      // Mapbox 的 proximity 是 "经度,纬度"
      params['proximity'] = '$proximityLongitude,$proximityLatitude';
    }
    if (countryCode != null && countryCode.trim().isNotEmpty) {
      params['country'] = countryCode.trim().toLowerCase();
    }
    if (language != null && language.isNotEmpty) {
      params['language'] = language;
    }

    final uri = Uri.https(
      'api.mapbox.com',
      '/geocoding/v5/mapbox.places/${Uri.encodeComponent(trimmed)}.json',
      params,
    );
    final places = await _request(uri);
    return places == null ? const MapboxSearchResult.failure() : MapboxSearchResult.success(places);
  }

  /// 坐标反查地址，用于"使用当前位置"和地图选点后回填地址文本。
  /// 取最具体的一条结果（Mapbox 按具体到粗略排序）；失败或无结果返回 null，
  /// 调用方保留坐标、让用户自己补地址文本。
  Future<MapboxPlace?> reverse(
    double latitude,
    double longitude, {
    String? language,
  }) async {
    final token = dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? '';
    if (token.isEmpty) return null;
    final params = <String, String>{
      'access_token': token,
      'types': _searchTypes,
      'limit': '1',
    };
    if (language != null && language.isNotEmpty) {
      params['language'] = language;
    }
    final uri = Uri.https(
      'api.mapbox.com',
      '/geocoding/v5/mapbox.places/$longitude,$latitude.json',
      params,
    );
    final places = await _request(uri);
    if (places == null || places.isEmpty) return null;
    // 反查结果的坐标是要素中心，不是用户选的点；地址文本用它，坐标仍以用户的为准
    return MapboxPlace(
      placeName: places.first.placeName,
      latitude: latitude,
      longitude: longitude,
    );
  }

  /// 发请求并解析 features；请求失败（超时、异常、非 200）返回 null。
  Future<List<MapboxPlace>?> _request(Uri uri) async {
    try {
      final response = await _client.get(uri).timeout(_timeout);
      if (response.statusCode != 200) {
        debugPrint('[MapboxGeocoding] ${response.statusCode}: ${response.body}');
        return null;
      }
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final features = (json['features'] as List<dynamic>?) ?? const [];
      final places = <MapboxPlace>[];
      for (final feature in features) {
        if (feature is! Map<String, dynamic>) continue;
        final center = feature['center'];
        final name = feature['place_name'];
        if (center is! List || center.length < 2 || name is! String) continue;
        final lng = (center[0] as num?)?.toDouble();
        final lat = (center[1] as num?)?.toDouble();
        if (lat == null || lng == null) continue;
        places.add(MapboxPlace(placeName: name, latitude: lat, longitude: lng));
      }
      return places;
    } catch (e) {
      debugPrint('[MapboxGeocoding] request failed: $e');
      return null;
    }
  }
}
