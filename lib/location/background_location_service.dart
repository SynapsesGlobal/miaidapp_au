import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../api_utils/api_provider.dart';
import '../store/home/home_screen_store.dart';
import '../utils/configure_dependencies.dart';

class BackgroundLocationService {
  static Future<void> sendPositionToBackend() async {
    try {
      final position = await determinePosition(desiredAccuracy: LocationAccuracy.medium);
      final api = getIt<ApiProvider>();
      if(api.userProvider.user == null)  return;

      final headers = <String, String>{
        'Content-Type': 'application/json',
        'x-access-token': api.userProvider.user!.accessToken.toString(),
        'x-api-key': api.apiKey,
      };

      final data = <String, dynamic>{
        'latitude': position.latitude,
        'longitude': position.longitude,
      };

      final url = Uri.parse(api.baseUrl+'/api/v1/save-position');
      final response = await http.post(url, headers: headers, body: jsonEncode(data),);
      if (response.statusCode == 200) {} else {print(response);}
    } catch (e) {
      print('定位报错了吗？');
      print(e);
    }
  }
}