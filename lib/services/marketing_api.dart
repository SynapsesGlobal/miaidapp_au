import 'package:miaid/config/api_settings.dart';
import 'package:miaid/store/app/app_settings.dart';
import 'package:miaid/utils/configure_dependencies.dart';

/// marketing（miaid_mispace 后端）请求的公共部分。
///
/// 后端 `api.locale` 中间件按 `lang` 参数 → `X-App-Locale` 头 → `Accept-Language` 头
/// 的顺序解析语言，再用 `Languages::resolveCode` 映射到已启用的语言（无法匹配时退回
/// 默认语言 en），分类名、商品标题/描述/说明/资格/地点、公司名/简介等翻译字段都按该
/// 语言返回。这里统一把 App 当前界面语言带给后端，所有 marketing 请求都应使用
/// [headers] 而不是各自拼 header。
class MarketingApi {
  MarketingApi._();

  /// App 界面语言 code（AppSettings 持久化的 en/zh/zh_Hant/ko/id/el）→ 后端
  /// `languages.code`（en/zh_CN/ko/id …）。后端没有的语言会被 `resolveCode` 按主语言
  /// 匹配（zh_TW → zh_CN）或退回默认语言，所以这里只做精确命名，不做兜底。
  static String localeCode() {
    final locale = getIt<AppSettings>().locale;
    if (locale.languageCode == 'zh') {
      return locale.scriptCode == 'Hant' ? 'zh_TW' : 'zh_CN';
    }
    return locale.languageCode;
  }

  /// marketing 请求的 header：鉴权 key + 当前语言。
  static Map<String, String> headers() {
    final lang = localeCode();
    return <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'x-api-key': getIt<ApiSettings>().marketingApiKey,
      'X-App-Locale': lang,
      'Accept-Language': lang.replaceAll('_', '-'),
    };
  }
}
