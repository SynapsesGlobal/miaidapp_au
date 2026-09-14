import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:miaid/api_utils/api_provider.dart';

/// 药店配送能力：GET /checkDeliveryAvailable/{pharmacy}
///
/// 除原有的开关外，后端还下发寄送运费与寄送半径，App 不再写死这两个参数。
/// 生成的 swagger 模型字段固定且手工补丁易被 build_runner 覆盖，所以这里用原始 JSON 解析。
class DeliveryAvailability {
  const DeliveryAvailability({
    required this.deliveryAvailable,
    required this.pickupAvailable,
    this.message,
    required this.deliveryFee,
    required this.radiusKm,
  });

  final bool deliveryAvailable;
  final bool pickupAvailable;
  final String? message;

  /// 寄送运费（主单位，如 19.9），与药店币种一致。只有 deliveryAvailable 为 true 时才有意义
  final double deliveryFee;

  /// 寄送半径（公里）。只有 deliveryAvailable 为 true 时才有意义
  final double radiusKm;

  double get radiusMeters => radiusKm * 1000;

  /// 半径的展示文本：5 → "5"，7.5 → "7.5"
  String get radiusLabel => radiusKm == radiusKm.roundToDouble()
      ? radiusKm.toStringAsFixed(0)
      : radiusKm.toString();

  factory DeliveryAvailability.fromJson(Map<String, dynamic> json) {
    final fee = _toDouble(json['delivery_fee']);
    final radiusKm = _toDouble(json['delivery_radius_km']);
    // 运费和半径必须由后端下发，App 不保留任何默认值：
    // 缺任一项（旧后端）就视为该药店不可寄送，只允许自取
    final configured = fee != null && radiusKm != null && radiusKm > 0;
    if (!configured) {
      debugPrint('[DeliveryAvailability] delivery_fee / delivery_radius_km missing, delivery disabled');
    }
    return DeliveryAvailability(
      deliveryAvailable: (_toBool(json['status']) ?? false) && configured,
      // 旧后端没有 pickup_status 时默认支持自取，保持升级前行为
      pickupAvailable: _toBool(json['pickup_status']) ?? true,
      message: json['message'] as String?,
      deliveryFee: fee ?? 0,
      radiusKm: radiusKm ?? 0,
    );
  }

  static bool? _toBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final v = value.toLowerCase();
      if (v == 'true' || v == '1') return true;
      if (v == 'false' || v == '0') return false;
    }
    return null;
  }

  static double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}

/// 查询药店配送能力；网络错误、非 200 或解析失败时返回 null，由调用方按"仅自取"兜底。
Future<DeliveryAvailability?> fetchDeliveryAvailability(
  ApiProvider api,
  int pharmacyId,
) async {
  try {
    final endpoint = api.apiSettings.endpointSub;
    final response = await http.get(
      Uri.parse('$endpoint/checkDeliveryAvailable/$pharmacyId'),
      headers: {
        'x-api-key': api.apiKey,
        'x-access-token': api.userProvider.user?.accessToken ?? '',
        'Accept': 'application/json',
      },
    ).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      debugPrint('[DeliveryAvailability] ${response.statusCode}: ${response.body}');
      return null;
    }
    final json = jsonDecode(response.body);
    if (json is! Map<String, dynamic>) return null;
    return DeliveryAvailability.fromJson(json);
  } catch (e) {
    debugPrint('[DeliveryAvailability] failed: $e');
    return null;
  }
}
