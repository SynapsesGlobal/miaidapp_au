import 'dart:convert';
import 'package:flutter/services.dart';

import '../api_utils/api_provider.dart';
import '../utils/configure_dependencies.dart';
import 'package:http/http.dart' as http;

class IosLocationService {
  static const _channel = MethodChannel('com.miaid.location');

  static void init() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'uploadLocation') {
        final latitude = call.arguments['lat'] as double;
        final longitude = call.arguments['lng'] as double;
        try {
          final api = getIt<ApiProvider>();
          if(api.userProvider.user == null)  return;

          final headers = <String, String>{
            'Content-Type': 'application/json',
            'x-access-token': api.userProvider.user!.accessToken.toString(),
            'x-api-key': api.apiKey,
          };

          final data = <String, dynamic>{
            'latitude': latitude,
            'longitude': longitude,
          };

          final url = Uri.parse(api.baseUrl+'/api/v1/save-position');
          final response = await http.post(url, headers: headers, body: jsonEncode(data),);
          if (response.statusCode == 200) {} else {print(response);}
        } catch (e) {
          print('定位报错了吗？');
          print(e);
        }
      }
    });
  }

  static Future<void> start() async {
    await _channel.invokeMethod('startLocationService');
  }

  static Future<void> stop() async {
    await _channel.invokeMethod('stopLocationService');
  }
}
