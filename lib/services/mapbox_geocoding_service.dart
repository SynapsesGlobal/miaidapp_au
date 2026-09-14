import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// Mapbox 地址联想结果。
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

/// 收货地址自动补全：调 Mapbox Geocoding v5 的正向地理编码（autocomplete=true）。
///
/// 复用首页坐标转城市所用的 MAPBOX_ACCESS_TOKEN（.env），不引入额外插件。
/// 只做网络请求与解析，防抖和过期结果丢弃由调用方（购物车页）处理。
class MapboxGeocodingService {
  MapboxGeocodingService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _timeout = Duration(seconds: 8);

  /// [proximityLatitude] / [proximityLongitude] 传药店坐标，让结果优先靠近药店。
  /// token 缺失、网络异常或非 200 时返回空列表，不抛异常。
  Future<List<MapboxPlace>> search(
    String query, {
    double? proximityLatitude,
    double? proximityLongitude,
    String? language,
    int limit = 5,
  }) async {
    final trimmed = query.trim();
    final token = dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? '';
    if (trimmed.length < 3 || token.isEmpty) return const [];

    final params = <String, String>{
      'access_token': token,
      'autocomplete': 'true',
      'limit': '$limit',
      'types': 'address,poi,place',
    };
    if (proximityLatitude != null && proximityLongitude != null) {
      // Mapbox 的 proximity 是 "经度,纬度"
      params['proximity'] = '$proximityLongitude,$proximityLatitude';
    }
    if (language != null && language.isNotEmpty) {
      params['language'] = language;
    }

    final uri = Uri.https(
      'api.mapbox.com',
      '/geocoding/v5/mapbox.places/${Uri.encodeComponent(trimmed)}.json',
      params,
    );

    try {
      final response = await _client.get(uri).timeout(_timeout);
      if (response.statusCode != 200) {
        debugPrint('[MapboxGeocoding] ${response.statusCode}: ${response.body}');
        return const [];
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
      debugPrint('[MapboxGeocoding] search failed: $e');
      return const [];
    }
  }
}
