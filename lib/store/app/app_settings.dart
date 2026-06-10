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
          Locale(sharedPreferences.getString(_kLang) ?? 'en'),
        );

  final SharedPreferences sharedPreferences;

  /// 当前界面 locale 的可监听源：顶层 MaterialApp 监听它，locale 一变就整体重建，
  /// 让 Localizations 以新 locale 重新加载，从而所有 `S.of(context)` 文案实时刷新
  /// （不再需要重启 App）。
  final ValueNotifier<Locale> localeListenable;

  @factoryMethod
  static Future<AppSettings> create(SharedPreferences sharedPreferences) async {
    final appSettings = AppSettings(sharedPreferences);
    await appSettings._init();
    return appSettings;
  }

  Future<void> _init() async {
    await S.load(locale);
  }

  Future<void> setLocale(Locale locale) async {
    await sharedPreferences.setString(_kLang, locale.languageCode);
    await S.load(locale);
    // 通知顶层 MaterialApp 重建，刷新全部界面文案。
    localeListenable.value = locale;
  }

  Locale get locale => Locale(sharedPreferences.getString(_kLang) ?? 'en');

  // en: English, cn: Chinese
  String get languageFull {
    if (locale.languageCode == 'zh') return 'Chinese';
    if (locale.languageCode == 'en') return 'English';
    if (locale.languageCode == 'kor') return 'Korean';
    if (locale.languageCode == 'ido') return 'Indonesia';
    return 'English';
  }
}
