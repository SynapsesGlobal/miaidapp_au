import 'package:shared_preferences/shared_preferences.dart';

/// 用户当前所在国家的 ISO 两位编码（如 CN / AU），来源是首页定位成功后
/// HomeScreenStore 写入 SharedPreferences 的 countryCode。
/// 尚未定位过时返回 null，调用方应省略该参数而不是传空串。
Future<String?> currentCountryCode() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString('countryCode')?.trim();
    return (code == null || code.isEmpty) ? null : code;
  } catch (_) {
    return null;
  }
}
