import 'dart:convert';
import 'dart:core';
import 'dart:ui';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/cupertino.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:injectable/injectable.dart';
import 'package:miaid/api_utils/api_parser.dart';
import 'package:miaid/api_utils/api_provider.dart';
import 'package:miaid/api_utils/consts.dart';
import 'package:miaid/api_utils/user_provider.dart';
import 'package:miaid/generated_api_code/api_client.swagger.dart';
import 'package:miaid/store/app/app_settings.dart';
import 'package:miaid/utils/geolocation.dart';
import 'package:mobx/mobx.dart';
import 'package:shared_preferences/shared_preferences.dart';
part 'home_screen_store.g.dart';

@injectable
class HomeScreenStore = _HomeScreenStore with _$HomeScreenStore;

abstract class _HomeScreenStore with Store {
  _HomeScreenStore(this.user, this.appSettings, this.api);

  final UserProvider user;
  final AppSettings appSettings;
  final ApiProvider api;

  @observable
  String? languageCode;

  @observable
  String? countryCode;

  @observable
  EmergencyNumber? emergencyNumber;

  Future<void> initState() async {
    await setLanguageCode(AppSettings.codeFromLocale(appSettings.locale));

    // 页面每次重建都会新建 store，先用上次成功定位的国家回填，
    // 返回首页时无需等待定位完成即可显示国家信息。
    await loadCachedCountryCode();
  }

  @action
  Future<void> loadCachedCountryCode() async {
    if (countryCode != null) return;

    final sharedPreferences = await SharedPreferences.getInstance();
    // 缓存也没有时（如新装的模拟器）用系统区域设置的国家兜底
    countryCode = sharedPreferences.getString('countryCode')
        ?? PlatformDispatcher.instance.locale.countryCode;
  }

  @action
  Future<void> fetchCountryCode() async {
    try {
      // 真机正常路径：定位成功直接使用获取到的国家代码
      countryCode = await getCountryCode();
    } catch (e) {
      // 定位失败（如模拟器未设置模拟定位 / 权限被拒）时回退到上次缓存的国家代码，
      // 避免 countryCode 保持 null 导致首页国家显示为空。真机定位正常时不会进入此分支。
      debugPrint('fetchCountryCode failed, fallback to cached countryCode: $e');
      await loadCachedCountryCode();
    }

    try {
      emergencyNumber = await fetchEmergencyNumber(countryCode);
    } catch (e) {
      debugPrint('fetchEmergencyNumber failed: $e');
    }
  }

  @action
  Future<void> setLanguageCode(String languageCode) async {
    this.languageCode = languageCode;

    await appSettings.setLocale(AppSettings.localeFromCode(languageCode));
  }

  Future<EmergencyNumber?> fetchEmergencyNumber(String? countryCode) async {
    if (countryCode == null) {
      return null;
    }

    var sharedPreferences = await SharedPreferences.getInstance();
    await sharedPreferences.setString('countryCode', countryCode);

    final response = await api.apiClient.emergencyNumberGetShow(country_code: countryCode);
    return await ApiSuccessParser.payloadOrThrowWithMessage(response);
  }
}

/// Determine the current position of the device.
///
/// When the location services are not enabled or permissions
/// are denied the `Future` will return an error.
Future<Position> determinePosition({
  LocationAccuracy? desiredAccuracy,
}) async {
  // Test if location services are enabled.
  var serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    // Location services are not enabled don't continue
    // accessing the position and request users of the
    // App to enable the location services.
    // print('Location services are disabled.');
    return Future.error('Location services are disabled.');
  }

  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    // 共享进行中的权限请求，避免与首页其他并发链路的 requestPermission 冲突
    permission = await MyGeoLocation.requestPermission();
    if (permission == LocationPermission.denied) {
      // Permissions are denied, next time you could try
      // requesting permissions again (this is also where
      // Android's shouldShowRequestPermissionRationale
      // returned true. According to Android guidelines
      // your App should show an explanatory UI now.
      return Future.error('Location permissions are denied');
    }
  }

  if (permission == LocationPermission.deniedForever) {
    // Permissions are denied forever, handle appropriately.
    return Future.error(
        'Location permissions are permanently denied, we cannot request permissions.');
  }

  // When we reach here, permissions are granted and we can
  // continue accessing the position of the device.
  final lastPosition = await Geolocator.getLastKnownPosition();
  if (lastPosition != null) {
    return lastPosition;
  }

  // timeLimit 防止模拟器等无定位源的环境下 getCurrentPosition 无限挂起，
  // 超时会抛 TimeoutException，由调用方走定位失败的兜底逻辑。
  // 首页急救号码、剩余问诊次数、国家信息会并发请求定位，
  // 共享进行中的定位请求，避免同时发起多次系统定位互相干扰。
  final pendingPosition = _pendingPositionRequest ??= Geolocator.getCurrentPosition(
    desiredAccuracy: desiredAccuracy ?? LocationAccuracy.medium,
    timeLimit: const Duration(seconds: 10),
  ).whenComplete(() => _pendingPositionRequest = null);
  return pendingPosition;
}

Future<Position>? _pendingPositionRequest;

Future<String?> getCountryCodeFromLocation(Position position) async {
  // TODO China, this uses Google Play services on Android so it needs to be reimplemented with some
  var longitude = position.longitude;
  var latitude = position.latitude;
  var accessToken = dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? '';
  var url = 'https://api.mapbox.com/geocoding/v5/mapbox.places/$longitude,$latitude.json?access_token=$accessToken';

  var country_code = 'AU';
  try {
    // 这次请求发生在 create-call 之前，挂起会让通话页永远停在 Connecting，
    // 且原先 http.get 在 try 外，网络异常会直接抛给上层；
    // 超时或失败一律退回默认 'AU'
    final response =
        await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) return country_code;
    final data = jsonDecode(response.body);
    for (var feature in data['features']) {
      if (!feature['place_type'].contains('country')) continue;
      var country_code = feature['properties']['short_code'];
      return country_code.toString().toUpperCase();
    }
  } catch (e) {
    print(e);
  }
  return country_code;


  /*try {
    final placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
    if (placemarks.isNotEmpty) {
      return placemarks.first.isoCountryCode;
    }
  } catch (e) {
    print(e);
  }
  return null;*/
}

Future<String?> getCountryCode() async {
  final position = await determinePosition(desiredAccuracy: LocationAccuracy.medium);
  return await getCountryCodeFromLocation(position);
}
