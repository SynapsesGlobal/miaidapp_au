import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../api_utils/api_provider.dart';
import '../../utils/configure_dependencies.dart';
import 'models/hospital_booking.dart';

/// miaid 后端的医院预约查询接口（需要登录：x-access-token）。
/// 与 chatbot 模块其他 miaid 接口一样直接用 http，不走生成的 Chopper client
class HospitalBookingApi {
  final http.Client _client;

  HospitalBookingApi({http.Client? client}) : _client = client ?? http.Client();

  /// 预约请求列表，新的在前
  Future<List<HospitalBooking>> fetchBookings() async {
    final payload = await _get('/api/v1/hospital-bookings');
    return (payload as List? ?? const [])
        .whereType<Map>()
        .map((item) => HospitalBooking.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  /// 单次预约请求的详情：症状、发送过的医院及各自的确认状态
  Future<HospitalBooking> fetchBooking(int bookingId) async {
    final payload = await _get('/api/v1/hospital-bookings/$bookingId');
    return HospitalBooking.fromJson(Map<String, dynamic>.from(payload as Map));
  }

  Future<dynamic> _get(String path) async {
    final api = getIt<ApiProvider>();
    final user = api.userProvider.user;
    final response = await _client.get(Uri.parse('${api.baseUrl}$path'), headers: {
      'Accept': 'application/json',
      'x-user-id': user?.id.toString() ?? '',
      'x-api-key': api.apiKey,
      'x-access-token': user?.accessToken ?? '',
    });
    if (response.statusCode != 200) {
      throw HospitalBookingApiException(response.statusCode, response.body);
    }
    return jsonDecode(utf8.decode(response.bodyBytes))['payload'];
  }
}

class HospitalBookingApiException implements Exception {
  final int statusCode;
  final String body;

  HospitalBookingApiException(this.statusCode, this.body);

  @override
  String toString() => 'HospitalBookingApiException($statusCode): $body';
}
