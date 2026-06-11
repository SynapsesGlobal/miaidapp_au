import 'dart:core';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:miaid/generated/l10n.dart';
import 'package:shared_preferences/shared_preferences.dart';

@preResolve
@singleton
class AppSettings {
  static const String _kLang = 'languageCode';

  AppSettings(this.sharedPreferences)
      : localeListenable = ValueNotifier(
          localeFromCode(
            _normalizeCode(sharedPreferences.getString(_kLang) ?? 'en'),
          ),
        );

  final SharedPreferences sharedPreferences;

  /// 当前界面 locale 的可监听源：顶层 MaterialApp 监听它，locale 一变就整体重建，
  /// 让 Localizations 以新 locale 重新加载，从而所有 `S.of(context)` 文案实时刷新
  /// （不再需要重启 App）。
  final ValueNotifier<Locale> localeListenable;

  // ===== 持久化 code 字符串 <-> Flutter Locale 互转 =====
  // 绝大多数语言的 code 就是标准 languageCode（en/el/zh/ko/id）；繁体中文用带 script 的
  // 'zh_Hant'（无法用单串 Locale('zh_Hant') 表达，必须 fromSubtags）。这里集中转换。

  /// 持久化 code -> Locale。
  static Locale localeFromCode(String code) {
    if (code == 'zh_Hant') {
      return const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant');
    }
    return Locale(code);
  }

  /// Locale -> 持久化 code。
  static String codeFromLocale(Locale locale) {
    if (locale.languageCode == 'zh' && locale.scriptCode == 'Hant') {
      return 'zh_Hant';
    }
    return locale.languageCode;
  }

  /// 旧版遗留的非标准 code 兼容映射到标准 code：kor->ko、ido->id、zh_hans->zh_Hant。
  static String _normalizeCode(String code) {
    switch (code) {
      case 'kor':
        return 'ko';
      case 'ido':
        return 'id';
      case 'zh_hans':
        return 'zh_Hant';
      default:
        return code;
    }
  }

  @factoryMethod
  static Future<AppSettings> create(SharedPreferences sharedPreferences) async {
    final appSettings = AppSettings(sharedPreferences);
    await appSettings._init();
    return appSettings;
  }

  Future<void> _init() async {
    // 一次性把老用户已存的非标准 code 重写为标准 code，使所有直接读取 prefs 的地方
    // （如 e-shop、chatbot）也拿到标准 code。
    final stored = sharedPreferences.getString(_kLang);
    if (stored != null) {
      final normalized = _normalizeCode(stored);
      if (normalized != stored) {
        await sharedPreferences.setString(_kLang, normalized);
      }
    }
    await S.load(locale);
  }

  Future<void> setLocale(Locale locale) async {
    await sharedPreferences.setString(_kLang, codeFromLocale(locale));
    await S.load(locale);
    // 通知顶层 MaterialApp 重建，刷新全部界面文案。
    localeListenable.value = locale;
  }

  Locale get locale => localeFromCode(
        _normalizeCode(sharedPreferences.getString(_kLang) ?? 'en'),
      );

  // en: English, cn: Chinese
  String get languageFull {
    if (locale.languageCode == 'zh') return 'Chinese';
    if (locale.languageCode == 'en') return 'English';
    if (locale.languageCode == 'ko') return 'Korean';
    if (locale.languageCode == 'id') return 'Indonesia';
    return 'English';
  }
}
